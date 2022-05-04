#!perl

use v5.20.0;
use warnings;

package Cron::Sequencer::Output;

our $VERSION = '0.01';

use Carp qw(confess);

# TODO - take formatter options. Mininally, timezone to use
sub new {
    my ($class) = @_;
    confess('new() called as an instance method')
        if ref $class;

    return bless {}
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

        my $env = $entry->{env};
        for my $key (sort keys %$env) {
            push @output, "$key=$env->{$key}";
        }

        push @output, $entry->{command};
    }

    # This replaces the blank line
    $output[0] = $when->stringify();

    return @output;
}

54;
