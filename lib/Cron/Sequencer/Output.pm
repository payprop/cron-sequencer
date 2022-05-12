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

    my %state = %opts{count};
    if ($opts{'hide-env'}) {
        ++$state{hide_env};
    }

    return bless \%state;
}

sub render {
    my ($self, @groups) = @_;

    my @output;

    for my $group (@groups) {
        # Should this be an error?
        unless (@$group) {
            push @output, "";
            next;
        }

        # 1+ entries that all fire at the same time
        my @cluster;

        for my $entry (@$group) {
            # The first blank line we add here is replaced below with the time.
            push @cluster, "";
            if ($self->{count} > 1) {
                push @cluster, "$entry->{file}:$entry->{lineno}: $entry->{when}";
            } else {
                push @cluster, "line $entry->{lineno}: $entry->{when}";
            }

            unless ($self->{hide_env}) {
                local *_;
                push @cluster, map "unset $_", $entry->{unset}->@*
                    if $entry->{unset};
                my $env = $entry->{env};
                push @cluster, map "$_=$env->{$_}", sort keys %$env
                    if $env;
            }

            push @cluster, $entry->{command};
        }

        # This replaces the blank line at the start of the "cluster".
        my $when = DateTime->from_epoch(epoch => $group->[0]{time});
        $cluster[0] = $when->stringify();

        push @output, @cluster, "", "";
    }

    # Drop the (second) empty string added just above in the last iteration of
    # the loop. If we don't do this, the second would cause an extra blank line
    # at the end. The first empty string causes the last (real) line to get a
    # newline (a newline that we want to have).
    pop @output;

    return join "\n", @output;
}

54;
