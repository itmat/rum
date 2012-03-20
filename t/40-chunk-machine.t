use Test::More tests => 20;
use Test::Exception;
use lib "lib";

use strict;
use warnings;

BEGIN { 
    use_ok('RUM::ChunkMachine');
    use_ok('RUM::ChunkConfig');
}                                               

my $config = RUM::ChunkConfig->new(
    genome_bowtie => "/Users/midel/src/rum/bin/../indexes/Arabidopsis_thaliana_TAIR10_genome",
    transcriptome_bowtie => "/Users/midel/src/rum/bin/../indexes/Arabidopsis_thaliana_TAIR10_ensembl_genes",
    reads         => "reads",
    chunk         => 1,
    output_dir    => "out",
    paired_end    => 1,
    read_length   => 1,
    min_overlap   => 1
);

is($config->genome_bowtie_out, "out/X.1", "genome bowtie out");

my $chunk = RUM::ChunkMachine->new($config);
my $script = $chunk->shell_script("foo");

