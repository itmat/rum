use Test::More tests => 6;
use Test::Exception;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Repository;
use RUM::TestUtils;
use File::Path;
use File::Temp qw(tempdir);
use strict;
use warnings;

BEGIN { 
    use_ok('RUM::Config');
}                                               

my $c;

$c = RUM::Config->new();
throws_ok {
    $c->reads_fa;
} qr/not set/;

$c = RUM::Config->new(output_dir => "foo");
is($c->output_dir, "foo");
is($c->reads_fa, "foo/reads.fa", "Chunk suffixed with no chunk");

$c = $c->for_chunk(1);
is($c->chunk, 1, "Chunk setting");
is($c->reads_fa, "foo/reads.fa.1", "Getting property for chunk");

