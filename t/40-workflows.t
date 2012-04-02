use Test::More tests => 4;
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
        rum_config_file => "$conf_dir/rum.config_Arabidopsis"
    );

    $config->load_rum_config_file;
    rmtree($out_dir);
    mkpath($config->state_dir);
    
    is($config->genome_bowtie_out, "$out_dir/X.1", "genome bowtie out");
    is($config->blat_output, "$out_dir/R.1.blat", "blat out");
    
    my $chunk = RUM::Workflows->chunk_workflow($config);

    open my $script_file, ">", "$out_dir/run.sh" or die "Can't open script";
    $chunk->shell_script($script_file);
}

sub would_run {
    my ($w, $command) = @_;
    ok(grep($_ eq $command, $w->all_commands), "$command would be run");
}

sub would_not_run {
    my ($w, $command) = @_;
    ok( ! grep($_ eq $command, $w->all_commands), "$command would not be run");
}

my $c = RUM::Config->new(
    output_dir => $out_dir,
    dna => 0,
    genome_only => 0,
    strand_specific => 0,
    name => "foo",
    num_chunks => 2
);
my $w = RUM::Workflows->postprocessing_workflow($c);
my @commands = $w->all_commands;
would_run($w, 'merge_rum_unique');
would_run($w, 'merge_rum_nu');
would_run($w, 'compute_mapping_statistics');
would_run($w, 'merge_quants');

$c = RUM::Config->new(
    output_dir => $out_dir,
    dna => 0,
    genome_only => 0,
    strand_specific => 0,
    name => "foo",
    num_chunks => 2,
    strand_specific => 1
);
my $w = RUM::Workflows->postprocessing_workflow($c);
my @commands = $w->all_commands;

would_not_run($w, 'merge_quants');
would_run($w, 'merge_quants_ps');
would_run($w, 'merge_quants_pa');
would_run($w, 'merge_quants_ms');
would_run($w, 'merge_quants_ma');

