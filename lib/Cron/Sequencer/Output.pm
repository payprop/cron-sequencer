#!perl

use v5.20.0;
use warnings;

package Cron::Sequencer::Output;

our $VERSION = '0.01';

use Carp qw(confess croak);

# TODO - take formatter options. Mininally, timezone to use
sub new {
    my ($class, %opts) = @_;
    confess('new() called as an instance method')
        if ref $class;

    my %state;
    if ($opts{env}) {
        croak("'env' and 'hide-env' options can't be used together")
            if $opts{'hide-env'};
        for my $pair ($opts{env}->@*) {
            # vixie crontab permits empty env variable names, so we should too
            # we don't need it *here*, but we could implement "unset" syntax as
            # FOO (ie no = sign)
            my ($name, $value) = $pair =~ /\A([^=]*)=(.*)\z/;
            croak("invalid environment variable assignment: '$pair'")
                unless defined $value;
            $state{env}{$name} = $value;
        }
    } elsif ($opts{'hide-env'}) {
        ++$state{hide_env};
    }

    return bless \%state;
}

sub format_group {
    my ($self, @entries) = @_;

    # Should this be an error?
    return ""
        unless @entries;

    my $when = DateTime->from_epoch(epoch => $entries[0]{time});

    my @output;

    for my $entry (@entries) {
        push @output, "", "line $entry->{lineno}: $entry->{when}";

        unless ($self->{hide_env}) {
            my $env = $entry->{env};
            my $default = $self->{env};
            my (@unset, @set);
            for my $key (keys %$default) {
                push @unset, "unset $key"
                    unless defined $env->{$key};
            }
            for my $key (keys %$env) {
                push @set, "$key=$env->{$key}"
                    unless defined $default->{$key} && $default->{$key} eq $env->{$key};
            }
            push @output, sort @unset;
            push @output, sort @set;
        }

        push @output, $entry->{command};
    }

    # This replaces the blank line
    $output[0] = $when->stringify();

    return @output;
}

54;
