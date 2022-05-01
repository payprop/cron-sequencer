#!perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

require_ok('Cron::Sequencer')
    or BAIL_OUT('When Cron::Sequencer fails to even load, nothing is going to work');

isa_ok(Cron::Sequencer->new(\""), 'Cron::Sequencer');

isa_ok(Cron::Sequencer->new('t/reminder'), 'Cron::Sequencer');

like(exception {
    Cron::Sequencer::new(\"");
}, qr/\Anew\(\) called as an instance method /, 'No copy constructor');

for ([\" ", qr/\Acrontab doesn't end with newline /, 'missing newline'],
     ["", qr/\Aempty string is not a valid filename /, 'empty string'],
     ['./solve-halting-problem.pl',
      qr!\ACan't open \./solve-halting-problem\.pl:!, 'file not found'],
     ['./Makefile.PL', qr/\ACan't parse 'use strict;'/,
      'task failed successfully'],
 ) {
    my ($input, $want, $desc) = @$_;
    my $have = exception {
        Cron::Sequencer->new($input);
    };
    like($have, $want, $desc);
}

done_testing();
