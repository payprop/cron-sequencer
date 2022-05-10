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

    my ($start, $end);

    if (defined $options->{from} || defined $options->{to}) {
        die "$0: Can't use --show with --from or --to"
            if defined $options->{show};

        # Default is midnight gone
        my $from = $options->{from} // '+0';
        if ($from =~ /\A[1-9][0-9]*\z/) {
            # Absolute epoch seconds
            $start = $from;
        } elsif ($from =~ /\A[-+](?:0|[1-9][0-9]*)\z/) {
            # Seconds relative to midnight gone
            $start = DateTime->today()->epoch() + $from;
        } else {
            die "$0: Can't parse '$from' for --from\n";
        }

        # Default is to show 1 hour
        my $to = $options->{to} // '+3600';
        if ($to =~ /\A[1-9][0-9]+\z/) {
            # Absolute epoch seconds
            $end = $to;
        } elsif ($to =~ /\A\+[1-9][0-9]*\z/) {
            # Seconds relative to from
            # As $end >= $start, '+0' doesn't make sense
            $end = $start + $to;
        } else {
            die "$0: Can't parse '$to' for --to\n";
        }

        die "$0: End $end must be after start $start (--from=$from --to=$to)"
            if $end <= $start;
    } else {
        my $show = $options->{show} // 'today';
        if ($show =~ /\A\s*(last|this|next)\s+week\s*\z/) {
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
        } elsif ($show =~ /\A\s*yesterday\s*\z/) {
            my $midnight = DateTime->today();
            $end = $midnight->epoch();
            $midnight->subtract(days => 1);
            $start = $midnight->epoch();
        } elsif ($show =~ /\A\s*(today|tomorrow)\s*\z/) {
            my $midnight = DateTime->today();
            $midnight->add(days => 1)
                if $1 eq 'tomorrow';
            $start = $midnight->epoch();
            $midnight->add(days => 1);
            $end = $midnight->epoch();
        } else {
            die "$0: Unknown time period '$show' for --show\n";
        }
    }

    return ($start, $end);
}

1;
