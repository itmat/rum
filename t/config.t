use strict;
use warnings;

use Test::More tests => 29;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::TestUtils;
use File::Temp qw(tempdir);


BEGIN { 
    use_ok('RUM::Config');
}                                               

my $c;

$c = RUM::Config->new();

$c->set(output_dir => "foo");
is($c->output_dir, "foo");

sub should_quantify {
    my (%options) = @_;
    my $c = RUM::Config->new->set(%options);
    ok($c->should_quantify, "Should quantify");
}
sub should_not_quantify {
    my (%options) = @_;
    my $c = RUM::Config->new->set(%options);
    ok(!$c->should_quantify, "Should not quantify");
}

sub should_do_junctions {
    my (%options) = @_;
    my $c = RUM::Config->new->set(%options);
    ok($c->should_do_junctions, "Should do junctions");
}
sub should_not_do_junctions {
    my (%options) = @_;
    my $c = RUM::Config->new->set(%options);
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

$c = RUM::Config->new->set(output_dir => $dir)->load_default;
is($c->read_length, 45, "Read config from file");

$dir = ".";
$c = RUM::Config->new(output_dir => $dir);
is $c->quant(chunk => 1), "chunks/quant.1";
is $c->quant(chunk => 1,
             strand => "p",
             sense => "a"), 
    "chunks/quant.pa.1";

{

    my $reads = File::Temp->new(UNLINK => 1);

    my $conf = RUM::Config->new;
    @ARGV = ('--name', 'foo',
             '--chunks', 3,
             $reads->filename);

    $conf->parse_command_line(
        options => [qw(name chunks)],
        positional => [qw(forward_reads reverse_reads)]
    );

    is $conf->name, 'foo';
    is $conf->chunks, 3;
    is $conf->forward_reads, $reads;

}

{
    my $conf = RUM::Config->new;
    $conf->parse_command_line(
        options => [qw(bowtie_nu_limit no_bowtie_nu_limit)]);
    is $conf->bowtie_nu_limit, 100;
}

{
    my $conf = RUM::Config->new;
    @ARGV = ('--bowtie-nu-limit', 50);
    $conf->parse_command_line(
        options => [qw(bowtie_nu_limit no_bowtie_nu_limit)]);
    is $conf->bowtie_nu_limit, 50;
}


{
    my $conf = RUM::Config->new;
    @ARGV = ('--max-insertions', 5);
    $conf->parse_command_line(
        options => [qw(max_insertions)]);
    is $conf->max_insertions, 5;
}

{

    my $dir = tempdir(TEMPLATE => "config.XXXXXX", CLEANUP => 1);
    my $conf = RUM::Config->new->set(
        output_dir => $dir);

    $conf->set('verbose', 1);
    
    is $conf->verbose, 1, 'Verbose before saving';
    mkdir "$dir/.rum";
    $conf->save;
    
    $conf = RUM::Config->new->set(output_dir => $dir);
    $conf->load_default;
    ok ! $conf->verbose, 'Not verbose after loading again';

}
