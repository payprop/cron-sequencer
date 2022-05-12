#!perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;

require_ok('Cron::Sequencer')
    or BAIL_OUT('When Cron::Sequencer fails to even load, nothing is going to work');

isa_ok(Cron::Sequencer->new(\""), 'Cron::Sequencer');

isa_ok(Cron::Sequencer->new('t/reminder'), 'Cron::Sequencer');

isa_ok(Cron::Sequencer->new({ source =>'t/reminder' }), 'Cron::Sequencer');

like(exception {
    Cron::Sequencer::new(\"");
}, qr/\Anew\(\) called as an instance method /, 'No copy constructor');

for ([\" ", qr/\Acrontab doesn't end with newline /, 'missing newline'],
     ["", qr/\Aempty string is not a valid filename /, 'empty string'],
     ['./solve-halting-problem.pl',
      qr!\ACan't open \./solve-halting-problem\.pl:!, 'file not found'],
     ['./Makefile.PL', qr/\ACan't parse 'use strict;'/,
      'task failed successfully'],
     [{}, qr/\Ayou must provide a source filename or crontab contents /,
      'empty hashref'],
     [{ env => [] }, qr/\Ayou must provide a source filename or crontab contents /,
      'hashref missing relevant keys'],
     [{ source => 'perl rules', crontab => '$$$' },
      qr/\Acrontab perl rules doesn't end with newline /,
      "'source' is used in the error message, but 'crontab' is the contents"],
 ) {
    my ($input, $want, $desc) = @$_;
    my $have = exception {
        Cron::Sequencer->new($input);
    };
    like($have, $want, $desc);
}

isa_ok(Cron::Sequencer->new({ source =>'./solve-halting-problem.pl',
                              crontab => "# Something involving Bruce Schneier and a roundhouse kick\n" }), 'Cron::Sequencer',
   "With 'crontab' argument, 'source' is purely descriptive");

for my $bogus ("", "0", "-1", "fish", "1e2", " 42", "10-12", "12-10", "10-10") {
    like(exception {
        Cron::Sequencer->new({ crontab => "", ignore => [$bogus]});
    }, qr/\A'ignore' must be a positive integer, not /,
         "ignore validation traps '$bogus'");
}

done_testing();
