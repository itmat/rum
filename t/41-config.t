use Test::More tests => 20;
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

my $config = RUM::Config->new(output_dir => "foo");

is($config->output_dir, "foo");
is($config->reads_fa, "foo/reads.fa", "Getting property");

my $chunk = $config->for_chunk(1);
is($chunk->reads_fa, "foo/reads.fa.1", "Getting property for chunk");


