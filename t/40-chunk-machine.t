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
    use_ok('RUM::ChunkMachine');
    use_ok('RUM::ChunkConfig');
}                                               

my $repo = RUM::Repository->new(root_dir => "$Bin/../_testing");
my @indexes = $repo->indexes(pattern => qr/TAIR/);

my $out_dir = "$Bin/tmp/40-chunk-machine";
my $state_dir = "$out_dir/state";

SKIP: {

    skip "no index", 1 unless @indexes == 1;
    my $index = $indexes[0];
    my $config = RUM::ChunkConfig->new(
        genome_bowtie => $repo->indexes_dir . "/Arabidopsis_thaliana_TAIR10_genome",
        genome_fa   => $repo->indexes_dir . "/Arabidopsis_thaliana_TAIR10_genome_one-line-seqs.fa",
        transcriptome_bowtie => $repo->indexes_dir . "/Arabidopsis_thaliana_TAIR10_ensembl_genes",
        annotations          => $repo->indexes_dir . "/Arabidopsis_thaliana_TAIR10_ensembl_gene_info.txt",
        bin_dir       => $repo->bin_dir,
        reads         => "$INPUT_DIR/reads.fa",
        chunk         => 1,
        output_dir    => $out_dir,
        paired_end    => 1,
        read_length   => 75,
        match_length_cutoff => 35,
        max_insertions => 1
    );

    rmtree($out_dir);
    mkpath($config->state_dir);
    
    is($config->genome_bowtie_out, "$out_dir/X.1", "genome bowtie out");
    is($config->blat_output, "$out_dir/R.1.blat", "blat out");
    
    my $chunk = RUM::ChunkMachine->new($config);

    my $script = $chunk->shell_script("$out_dir/state");

    open my $script_file, ">", "$out_dir/run.sh" or die "Can't open script";
    print $script_file $script;
    close $script_file;
}
