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
    if ($opts{'hide-env'}) {
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
            local *_;
            push @output, map "unset $_", $entry->{unset}->@*
                if $entry->{unset};
            my $env = $entry->{env};
            push @output, map "$_=$env->{$_}", sort keys %$env
                if $env;
        }

        push @output, $entry->{command};
    }

    # This replaces the blank line
    $output[0] = $when->stringify();

    return @output;
}

54;
