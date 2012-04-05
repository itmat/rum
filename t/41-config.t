use Test::More tests => 22;
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


sub should_quantify {
    my (%options) = @_;
    my $c = RUM::Config->new(%options);
    ok($c->should_quantify, "Should quantify");
}
sub should_not_quantify {
    my (%options) = @_;
    my $c = RUM::Config->new(%options);
    ok(!$c->should_quantify, "Should not quantify");
}

sub should_do_junctions {
    my (%options) = @_;
    my $c = RUM::Config->new(%options);
    ok($c->should_do_junctions, "Should do junctions");
}
sub should_not_do_junctions {
    my (%options) = @_;
    my $c = RUM::Config->new(%options);
    ok(!$c->should_do_junctions, "Should not do junctions");
}



should_quantify(    dna => 0, genome_only => 0, quantify => 0);
should_quantify(    dna => 0, genome_only => 0, quantify => 1);
should_not_quantify(dna => 0, genome_only => 1, quantify => 0);
should_quantify(    dna => 0, genome_only => 1, quantify => 1);
should_not_quantify(dna => 1, genome_only => 0, quantify => 0);
should_quantify(    dna => 1, genome_only => 0, quantify => 1);
should_not_quantify(dna => 1, genome_only => 1, quantify => 0);
should_quantify(    dna => 1, genome_only => 1, quantify => 1);

should_do_junctions(    dna => 0, genome_only => 0, junctions => 0);
should_do_junctions(    dna => 0, genome_only => 0, junctions => 1);
should_do_junctions(    dna => 0, genome_only => 1, junctions => 0);
should_do_junctions(    dna => 0, genome_only => 1, junctions => 1);
should_not_do_junctions(dna => 1, genome_only => 0, junctions => 0);
should_do_junctions(    dna => 1, genome_only => 0, junctions => 1);
should_do_junctions(    dna => 1, genome_only => 1, junctions => 0);
should_do_junctions(    dna => 1, genome_only => 1, junctions => 1);
