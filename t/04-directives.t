#!perl
# -*- cperl -*-

use strict;
use warnings;

use Test::More tests => 5;
use Test::Exception;
use FindBin qw($Bin);
use lib "$Bin/../lib";

BEGIN { use_ok('RUM::Directives') }

my $d = RUM::Directives->new;

is($d->save, undef, "Directive is initially undef");
$d->set_save;
ok($d->save, "Directive was set");
ok ! $d->run, "I should not run the pipeline";
$d->unset_save;



ok( ! $d->save, "Directive was unset");




