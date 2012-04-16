#!perl
# -*- cperl -*-

use strict;
use warnings;

use Test::More tests => 4;
use FindBin qw($Bin);
use lib "$Bin/../lib";

BEGIN { use_ok('RUM::Directives') }

my $d = RUM::Directives->new;

is($d->save, undef, "Directive is initially undef");
$d->set_save;
ok($d->save, "Directive was set");
$d->unset_save;
ok( ! $d->save, "Directive was unset");
