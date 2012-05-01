#!perl
# -*- cperl -*-

use strict;
use warnings;

use Test::More tests => 4;
use FindBin qw($Bin);
use lib "$Bin/../lib";

BEGIN { use_ok('RUM::Directives') }

my $d = RUM::Directives->new;

is($d->quiet, undef, "Directive is initially undef");
$d->set_quiet;
ok($d->quiet, "Directive was set");
$d->unset_quiet;
ok( ! $d->quiet, "Directive was unset");
