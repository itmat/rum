use Test::More tests => 27;
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
    use_ok('RUM::Workflows');
    use_ok('RUM::Config');
}                                               

my $repo = RUM::Repository->new(root_dir => "$Bin/../_testing");

# This will fail if indexes are not installed, but that's ok, because
# we'll skip the tests anyway.
my @indexes = eval { $repo->indexes(pattern => qr/TAIR/); };

my $out_dir = "$Bin/tmp/40-workflows";
my $state_dir = "$out_dir/state";
my $conf_dir = $repo->conf_dir;
my $index_dir = $repo->indexes_dir;
my $annotations = "$index_dir/Arabidopsis_thaliana_TAIR10_ensembl_gene_info.txt";

SKIP: {

    skip "no index", 2 unless @indexes == 1;
    my $index = $indexes[0];
    my $config = RUM::Config->new(
        chunk         => 1,
        output_dir    => $out_dir,
        paired_end    => 1,
        read_length   => 75,
        match_length_cutoff => 35,
        max_insertions => 1,
        rum_config_file => "$conf_dir/rum.config_Arabidopsis",
        strand_specific => 0,
        alt_genes => undef
    );

    $config->load_rum_config_file;
    rmtree($out_dir);
    mkpath($config->state_dir);
    
    is($config->genome_bowtie_out, "$out_dir/X.1", "genome bowtie out");
    is($config->blat_output, "$out_dir/R.1.blat", "blat out");

    my $chunk = RUM::Workflows->chunk_workflow($config);

    open my $dot, ">", "workflow.dot";
    $chunk->state_machine->dotty($dot);
    close ($dot);
    
    open my $script_file, ">", "$out_dir/run.sh" or die "Can't open script";
    $chunk->shell_script($script_file);
}

sub would_run {
    my ($w, $command_re) = @_;
    ok(grep(/$command_re/, $w->all_commands), "$command_re would be run");
}

sub would_not_run {
    my ($w, $command_re) = @_;
    ok( ! grep(/$command_re/, $w->all_commands), "$command_re would not be run");
}

my $c = RUM::Config->new(
    output_dir => $out_dir,
    dna => 0,
    genome_only => 0,
    strand_specific => 0,
    name => "foo",
    num_chunks => 2,
    rum_config_file => "$conf_dir/rum.config_Arabidopsis",
    alt_quant_model => "",
    alt_genes => undef,
);
$c->load_rum_config_file;
my $w = RUM::Workflows->postprocessing_workflow($c);
my @commands = $w->all_commands;
would_run($w, qr/merge rum_unique/i);
would_run($w, qr/merge rum_nu/i);
would_run($w, qr/compute mapping stat/i);
would_run($w, qr/merge quants/i);
would_not_run($w, 'merge_alt_quants');

$c = RUM::Config->new(
    output_dir => $out_dir,
    dna => 0,
    genome_only => 0,
    strand_specific => 0,
    name => "foo",
    num_chunks => 2,
    strand_specific => 1,
    rum_config_file => "$conf_dir/rum.config_Arabidopsis",
    alt_quant_model => "",
    alt_genes => undef
);
$c->load_rum_config_file;
$w = RUM::Workflows->postprocessing_workflow($c);
@commands = $w->all_commands;

would_not_run($w, qr/merge quants$/i);
would_run($w, qr/merge.quants.p.*s/i);
would_run($w, qr/merge.quants.p.*a/i);
would_run($w, qr/merge.quants.m.*s/i);
would_run($w, qr/merge.quants.m.*a/i);
would_run($w, qr/merge.strand.specific.quants/i);

# Alt quants

$c = RUM::Config->new(
    output_dir => $out_dir,
    dna => 0,
    genome_only => 0,
    strand_specific => 0,
    name => "foo",
    num_chunks => 2,
    rum_config_file => "$conf_dir/rum.config_Arabidopsis",
    alt_quant_model => "foobar",
    alt_genes => undef
);
$c->load_rum_config_file;
$w = RUM::Workflows->postprocessing_workflow($c);
@commands = $w->all_commands;
would_run($w, qr/merge.*quants$/i);
would_run($w, qr/merge.alt.quants/i);

$c = RUM::Config->new(
    output_dir => $out_dir,
    dna => 0,
    genome_only => 0,
    strand_specific => 0,
    name => "foo",
    num_chunks => 2,
    strand_specific => 1,
    rum_config_file => "$conf_dir/rum.config_Arabidopsis",
    alt_quant_model => "foobar",
    alt_genes => undef
);
$c->load_rum_config_file;
$w = RUM::Workflows->postprocessing_workflow($c);
@commands = $w->all_commands;

would_run($w, qr/merge.quants.*p.*s/i);
would_run($w, qr/merge.quants.*p.*a/i);
would_run($w, qr/merge.quants.*m.*s/i);
would_run($w, qr/merge.quants.*m.*a/i);
would_run($w, qr/merge.strand.specific.quants/i);
would_run($w, qr/merge.alt.quants.*p.*s/i);
would_run($w, qr/merge.alt.quants.*p.*a/i);
would_run($w, qr/merge.alt.quants.*m.*s/i);
would_run($w, qr/merge.alt.quants.*m.*a/i);
would_run($w, qr/merge.strand.specific.alt.quants/i);

