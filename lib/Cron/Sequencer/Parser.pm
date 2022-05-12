#!perl

use v5.20.0;
use warnings;

package Cron::Sequencer::Parser;

our $VERSION = '0.01';

use Carp qw(croak confess);

require Algorithm::Cron;
use Try::Tiny;

my %aliases = (
    yearly => '0 0 1 1 *',
    annually => '0 0 1 1 *',
    monthly => '0 0 1 * *',
    weekly => '0 0 * * 0',
    daily => '0 0 * * *',
    midnight => '0 0 * * *',
    hourly => '0 * * * *',
);

# scalar -> filename
# ref to scalar -> contents
# hashref -> fancy

sub new {
    my ($class, $arg) = @_;
    confess('new() called as an instance method')
        if ref $class;

    my ($source, $crontab, $env);
    if (!defined $arg) {
        croak(__PACKAGE__ . '->new($class, $arg)');
    } elsif (ref $arg eq 'SCALAR') {
        $source = "";
        $crontab = $arg;
    } elsif (ref $arg eq 'HASH') {
        $source = $arg->{source};
        $crontab = \$arg->{crontab}
            if exists $arg->{crontab};
        if (exists $arg->{env}) {
            for my $pair ($arg->{env}->@*) {
                # vixie crontab permits empty env variable names, so we should
                # too we don't need it *here*, but we could implement "unset"
                # syntax as FOO (ie no = sign)
                my ($name, $value) = $pair =~ /\A([^=]*)=(.*)\z/;
                croak("invalid environment variable assignment: '$pair'")
                    unless defined $value;
                $env->{$name} = $value;
            }
        }
    } elsif (ref $arg) {
        confess(sprintf 'Unsupported %s reference passed to new()', ref $arg);
    } elsif ($arg eq "") {
        croak("empty string is not a valid filename");
    } else {
        $source = $arg;
    }

    if (!$crontab) {
        croak("you must provide a source filename or crontab contents")
            unless length $source;
        open my $fh, '<', $source
            or croak("Can't open $source: $!");
        local $/;
        my $contents = <$fh>;
        unless(defined $contents && close $fh) {
            croak("Can't read $source: $!");
        }
        $crontab = \$contents;
    }

    # vixie crontab refuses a crontab where the last line is missing a newline
    # (but handles an empty file)
    unless ($$crontab =~ /(?:\A|\n)\z/) {
        $source = length $source ? " $source" : "";
        croak("crontab$source doesn't end with newline");
    }

    return bless _parser($crontab, $source, $env), $class;
}

sub _parser {
    my ($crontab, $source, $default_env) = @_;
    my $diag = length $source ? " of $source" : "";
    my ($lineno, %env, @actions);
    for my $line (split "\n", $$crontab) {
        ++$lineno;
        # vixie crontab ignores leading tabs and spaces
        # See skip_comments() in misc.c
        # However the rest of the env parser uses isspace(), so will skip more
        # whitespace characters. I guess this is because the parser was
        # rewritten for version 4, and the more modern code can assume ANSI C.
        $line =~ s/\A[ \t]+//;

        next
            if $line =~ /\A(?:#|\z)/;

        # load_env() is attempted first
        # Its parser has some quirks, which I have attempted to faithfully copy:
        if ($line =~ /\A
                      (?:
                          # If ' opens, a second *must* be found to close
                          ' (*COMMIT) (?<name>[^=']*) '
                      |
                          " (*COMMIT) (?<name>[^="]*) "
                      |
                          # The C parser accepts empty variable names
                          (?<name>[^=\s\013]*)
                      )
                      [\s\013]* = [\s\013]*
                      (?:
                          # If ' opens, a second *must* be found to close
                          # *and* only trailing whitespace is permitted
                          ' (*COMMIT) (?<value>[^']*) '
                      |
                          " (*COMMIT) (?<value>[^"]*) "
                      |
                          # The C parser does not accept empty values
                          (?<value>.+?)
                      )
                      [\s\013]*
                      \z
                     /x) {
            $env{$+{name}} = $+{value};
        }
        # else it gets passed load_entry()
        elsif ($line =~ /\A\@reboot[\t ]/) {
            # We can't handle this, as we don't know when a reboot is
            next;
        } else {
            my ($time, $truetime, $command);
            if ($line =~ /\A\@([^\t ]+)[\t ]+(.*)\z/) {
                $command = $2;
                $time = '@' . $1;
                $truetime = $aliases{$1};
                croak("Unknown special string \@$1 at line $lineno$diag")
                    unless $truetime;
            } elsif ($line =~ /\A
                                (
                                    [*0-9]\S* [\t ]+
                                    [*0-9]\S* [\t ]+
                                    [*0-9]\S* [\t ]+
                                    \S+ [\t ]+
                                    \S+
                                )
                                [\t ]+
                                (
                                    # vixie cron explicitly forbids * here:
                                    [^*].*
                                )
                                \z
                              /x) {
                $command = $2;
                $time = $truetime = $1;
            } else {
                croak("Can't parse '$line' at line $lineno$diag");
            }

            my $whenever = try {
                 Algorithm::Cron->new(
                     base => 'utc',
                     crontab => $truetime,
                 );
             } catch {
                 croak("Can't parse time '$truetime' at line $lineno$diag: $_");
             };

            my %entry = (
                file => $source,
                lineno => $lineno,
                when => $time,
                command => $command,
                whenever => $whenever,
            );

            my (@unset, %set);
            for my $key (keys %$default_env) {
                push @unset, $key
                    unless defined $env{$key};
            }
            for my $key (keys %env) {
                $set{$key} = $env{$key}
                    unless defined $default_env->{$key} && $default_env->{$key} eq $env{$key};
            }
            $entry{unset} = [sort @unset]
                if @unset;
            $entry{env} = \%set
                if %set;

            push @actions, \%entry;
        }
    }
    return \@actions;
}

# "actions", "entries", "events"?
# Vixie crontab parses these with load_entry() and %ENV setting with load_env(),
# so we're refer to them as entries:
sub entries {
    my $self = shift;
    return @$self;
}

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. If you would like to contribute documentation,
features, bug fixes, or anything else then please raise an issue / pull request:

    https://github.com/Humanstate/cron-sequencer

=head1 AUTHOR

Nicholas Clark - C<nick@ccl4.org>

=cut

1;
