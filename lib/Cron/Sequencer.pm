#!perl

use v5.20.0;
use warnings;

package Cron::Sequencer;

our $VERSION = '0.01';

use Carp qw(croak confess);

require Cron::Sequencer::Parser;

# scalar -> filename
# ref to scalar -> contents
# hashref -> fancy

sub new {
    my ($class, @args) = @_;
    confess('new() called as an instance method')
        if ref $class;

    my @self;
    for my $arg (@args) {
        $arg = Cron::Sequencer::Parser->new($arg)
            unless UNIVERSAL::isa($arg, 'Cron::Sequencer::Parser');
        push @self, $arg->entries();
    }

    return bless \@self, $class;
}

# The intent is to avoid repeatedly calling ->next_time() on every event on
# every loop, which would make next() have O(n) performance, and looping a range
# O(n**2)

sub _next {
    my $self = shift;

    my $when = $self->[0]{next};
    my @found;

    for my $entry (@$self) {
        if ($entry->{next} < $when) {
            # If this one is earlier, discard everything we found so far
            $when = $entry->{next};
            @found = $entry;
        } elsif ($entry->{next} == $when) {
            # If it's a tie, add it to the list of found
            push @found, $entry;
        }
    }

    my @retval;

    for my $entry (@found) {
        push @retval, {
            %$entry{qw(file lineno when command env unset)},
            time => $when,
        };

        # We've "consumed" this firing, so update the cached value
        $entry->{next} = $entry->{whenever}->next_time($when);
    }

    return @retval;
}

sub sequence {
    my ($self, $start, $end) = @_;

    croak('sequence($epoch_seconds, $epoch_seconds)')
        if $start !~ /\A[1-9][0-9]*\z/ || $end !~ /\A[1-9][0-9]*\z/;

    return
        unless @$self;

    # As we have to call ->next_time(), which returns the next time *after* the
    # epoch time we pass it.
    --$start;

    for my $entry (@$self) {
        # Cache the time (in epoch seconds) for the next firing for this entry
        $entry->{next} = $entry->{whenever}->next_time($start);
    }

    my @results;
    while(my @group = $self->_next()) {
        last
            if $group[0]->{time} >= $end;

        push @results, \@group;
    }

    return @results;
}

=head1 NAME

Cron::Sequencer

=head1 SYNOPSIS

    my $crontab = Cron::Sequencer->new("/path/to/crontab");
    print encode_json([$crontab->sequence($start, $end)]);

=head1 DESCRIPTION

This class can take one or more crontabs and show the sequence of commands
that they would run for the time interval requested.

=head1 METHODS

=head2 new

C<new> takes a list of arguments each representing a crontab file, passes each
in turn to C<< Cron::Sequence::Parser->new >>, and then combines the parsed
files into a single set of crontab events.

See L<Cron::Sequence::Parser/new> for the various formats to specify a crontab
file or its contents.

=head2 sequence I<from> I<to>

Generates the sequence of commands that the crontab(s) would run for the
specific time interval. I<from> and I<to> are in epoch seconds, I<from> is
inclusive, I<end> exclusive.

Hence for this input:

    30 12 * * * lunch!
    30 12 * * 5 POETS!

Calling C<< $crontab->sequence(45000, 131400) >> generates this output:

    [
      [
        {
          command => "lunch!",
          env     => undef,
          file    => "reminder",
          lineno  => 1,
          time    => 45000,
          unset   => undef,
          when    => "30 12 * * *",
        },
      ],
    ]

where the event(s) at C<131400> are not reported, because the end is
exclusive. Whereas C<< $crontab->sequence(45000, 131401) >> shows:

    [
      [
        {
          command => "lunch!",
          env     => undef,
          file    => "reminder",
          lineno  => 1,
          time    => 45000,
          unset   => undef,
          when    => "30 12 * * *",
        },
      ],
      [
        {
          command => "lunch!",
          env     => undef,
          file    => "reminder",
          lineno  => 1,
          time    => 131400,
          unset   => undef,
          when    => "30 12 * * *",
        },
        {
          command => "POETS!",
          env     => undef,
          file    => "reminder",
          lineno  => 2,
          time    => 131400,
          unset   => undef,
          when    => "30 12 * * 5",
        },
      ],
    ]

The output is structured as a list of lists, with events that fire at the
same time grouped as lists. This makes it easier to find cases where different
crontab lines trigger at the same time.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. If you would like to contribute documentation,
features, bug fixes, or anything else then please raise an issue / pull request:

    https://github.com/Humanstate/cron-sequencer

=head1 AUTHOR

Nicholas Clark - C<nick@ccl4.org>

=cut

1;
