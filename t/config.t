use strict;
use warnings;

use Test::More tests => 22;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::TestUtils;
use File::Temp qw(tempdir);


BEGIN { 
    use_ok('RUM::Config');
}                                               

my $c;

$c = RUM::Config->new();

$c = RUM::Config->new(output_dir => "foo");
is($c->output_dir, "foo");

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

$c = RUM::Config->new;
my $dir = tempdir(TEMPLATE => "config.XXXXXX", CLEANUP => 1);
$c->set(output_dir => $dir);
mkdir "$dir/.rum";
$c->set(read_length => 45);
$c->save;

$c = RUM::Config->load($dir);
is($c->read_length, 45, "Read config from file");
ok(! RUM::Config->load("/foo/bar/baz"));

$dir = ".";
$c = RUM::Config->new(output_dir => $dir);
is $c->quant(chunk => 1), "chunks/quant.1";
is $c->quant(chunk => 1,
             strand => "p",
             sense => "a"), 
    "chunks/quant.pa.1";

