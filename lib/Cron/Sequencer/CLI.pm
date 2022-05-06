#!perl

use v5.20.0;
use warnings;

package Cron::Sequencer::CLI;

use parent qw(Exporter);
require DateTime;

our $VERSION = '0.01';
our @EXPORT = qw(calculate_start_end);

sub calculate_start_end {
    my $options = shift;

    $options->{show} //= 'today';

    my ($start, $end);

    if (defined $options->{show}) {
        if ($options->{show} =~ /\A\s*(last|this|next)\s+week\s*\z/) {
            my $which = $1;
            my $start_of_week = DateTime->now()->truncate(to => 'week');
            if ($which eq 'last') {
                $end = $start_of_week->epoch();
                $start_of_week->subtract(weeks => 1);
                $start = $start_of_week->epoch();
            } else {
                $start_of_week->add(weeks => 1)
                    if $which eq 'next';
                $start = $start_of_week->epoch();
                $start_of_week->add(weeks => 1);
                $end = $start_of_week->epoch();
            }
        } elsif ($options->{show} =~ /\A\s*yesterday\s*\z/) {
            my $midnight = DateTime->today();
            $end = $midnight->epoch();
            $midnight->subtract(days => 1);
            $start = $midnight->epoch();
        } elsif ($options->{show} =~ /\A\s*(today|tomorrow)\s*\z/) {
            my $midnight = DateTime->today();
            $midnight->add(days => 1)
                if $1 eq 'tomorrow';
            $start = $midnight->epoch();
            $midnight->add(days => 1);
            $end = $midnight->epoch();
        } else {
            die "$0: Unknown time period '$options->{show}' for --show\n";
        }
    }

    return ($start, $end);
}

1;
