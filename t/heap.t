#!perl
# -*- cperl -*-

use Test::More tests => 5;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use strict;
use warnings;

BEGIN { 
  use_ok('RUM::Heap');
}

my $heap = RUM::Heap->new();
for my $x (9, 4, 7, 6, 5, 8, 3, 1, 0, 2) {
    $heap->pushon($x)
}
is($heap->poplowest(), 0, "Pop lowest");          
is($heap->poplowest(), 1, "Pop lowest");          
is($heap->poplowest(), 2, "Pop lowest");          
$heap->pushon(0);
is($heap->poplowest(), 0, "Pop lowest");
