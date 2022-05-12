#!perl

use strict;
use warnings;

use Test::More;
use Test::Deep;
use Test::Fatal;
require DateTime;

use Cron::Sequencer::CLI qw(parse_argv calculate_start_end);

my $nowish = time;

{
    no warnings 'redefine';
    *DateTime::_core_time = sub { return $nowish };
}

my @today = calculate_start_end({ show => 'today' });

sub fake_pod2usage {
    die ["Called pod2usage", @_];
}

for (["no arguments", "",
      undef, 'exitval', 255],
     ["unknown arguments", "--bogus",
      qr/\AUnknown option: bogus\n\z/, 'exitval', 255, 'verbose', 1],
     ["--env and --hide-env together", "--hide-env file --env FOO=BAR",
      undef, 'exitval', 255,
      'message', "--env and --hide-env options can't be used together"],
     ["--env and --hide-env together (anywhere)",
      "--hide-env file1 -- file2 --env FOO=BAR",
      undef, 'exitval', 255,
      'message', "--env and --hide-env options can't be used together"],
 ) {
    my ($desc, $flat, $warn, @want) = @$_;
    my @args = split ' ', $flat;
    unshift @want, "Called pod2usage";

    my @warnings;

    cmp_deeply(exception {
        local $SIG{__WARN__} = sub {
            push @warnings, \@_;
        };
        parse_argv(\&fake_pod2usage, @args);
    }, \@want, "pod2usage called for $desc");
    if (defined $warn) {
        cmp_deeply(\@warnings, [[re($warn)]], "got expected warning from $desc");
    } else {
        cmp_deeply(\@warnings, [], "no warnings from $desc");
    }
}

my $default_output = ['hide-env', undef, count => 1];
my $default_for_file = {env => undef, source => "file"};
my @defaults = (@today, $default_output);

for (["file", [@defaults, $default_for_file]],
     ["file --show today", [@defaults, $default_for_file]],
     ["--show today file", [@defaults, $default_for_file]],
     ["--from 1 --to 11 file", [1, 11, $default_output, $default_for_file]],

     ["--from 1 --to 11 -- file", [1, 11, $default_output, $default_for_file]],
     ["--from 1 --to 11 file --", [1, 11, $default_output, $default_for_file]],

     ["--hide-env file", [@today, ['hide-env', 1, 'count', 1], $default_for_file]],
     ["--env=FOO=BAR file --env BAZ=",
      [@defaults, {env => ["FOO=BAR", "BAZ="], source => "file"}]],
 ) {
    my ($flat, $want) = @$_;
    my @args = split ' ', $flat;
    my (@have, @warnings);
    is(exception {
        local $SIG{__WARN__} = sub {
            push @warnings, \@_;
        };
        @have = parse_argv(\&fake_pod2usage, @args);
    }, undef, "no exception from $flat");
    cmp_deeply(\@warnings, [], "no warnings from $flat");
    cmp_deeply(\@have, $want, "result of parse_argv $flat");
}

done_testing();
