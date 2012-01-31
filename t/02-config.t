#!perl -T

use Test::More tests => 6;
use Test::Exception;
use lib "lib";

use strict;
use warnings;
use Log::Log4perl qw(:easy);

BEGIN { 
  use_ok('RUM::Config', qw(parse_config format_config parse_organisms));
}

my $valid_config_text = join("", map("$_\n", ('a' .. 'i')));
my $valid_config_hashref = {
    "gene-annotation-file" => "a",
    "bowtie-bin" => "b",
    "blat-bin" => "c",
    "mdust-bin" => "d",
    "bowtie-genome-index" => "e",
    "bowtie-gene-index" => "f",
    "blat-genome-index" => "g",
    "script-dir" => "h",
    "lib-dir" => "i"
};

# Parse_Config a valid config file
do {
    open my $config_in, "<", \$valid_config_text;
    is_deeply(parse_config($config_in), $valid_config_hashref, 
              "Parse_Config valid config file");
};

# Parse_Config a config file that's too long
do {
    my $config_text = join("", map("$_\n", ('a' .. 'z')));
    open my $config_in, "<", \$config_text;
    throws_ok { parse_config($config_in) } qr/too many lines/i,
        "Throw when a config file is too long";
};

# Parse_Config a config file that's too short
do {
    my $config_text = join("", map("$_\n", ('a' .. 'd')));
    open my $config_in, "<", \$config_text;
    throws_ok { parse_config($config_in) } qr/not enough lines/i,
        "Throw when a config file is too long";
};

# Stringify a config file
do {
    is(format_config(%{$valid_config_hashref}),
       $valid_config_text,
       "Stringify a config file");
};

################################################################################
#
# Parsing organisms.txt
#


my $valid_org_text = <<ORGANISMS;
-- Homo sapiens [build hg18] (human) start --
http://itmat.rum.s3.amazonaws.com/rum.config_hg18
http://itmat.rum.s3.amazonaws.com/indexes/hg18_genome.1.ebwt
http://itmat.rum.s3.amazonaws.com/indexes/hg18_genome.2.ebwt
http://itmat.rum.s3.amazonaws.com/indexes/hg18_genome.3.ebwt
http://itmat.rum.s3.amazonaws.com/indexes/hg18_genome.4.ebwt
http://itmat.rum.s3.amazonaws.com/indexes/hg18_genome.rev.1.ebwt
http://itmat.rum.s3.amazonaws.com/indexes/hg18_genome.rev.2.ebwt
http://itmat.rum.s3.amazonaws.com/indexes/hg18_refseq_ucsc_vega_genes.1.ebwt
http://itmat.rum.s3.amazonaws.com/indexes/hg18_refseq_ucsc_vega_genes.2.ebwt
http://itmat.rum.s3.amazonaws.com/indexes/hg18_refseq_ucsc_vega_genes.3.ebwt
http://itmat.rum.s3.amazonaws.com/indexes/hg18_refseq_ucsc_vega_genes.4.ebwt
http://itmat.rum.s3.amazonaws.com/indexes/hg18_refseq_ucsc_vega_genes.rev.1.ebwt
http://itmat.rum.s3.amazonaws.com/indexes/hg18_refseq_ucsc_vega_genes.rev.2.ebwt
http://itmat.rum.s3.amazonaws.com/indexes/hg18_genome_one-line-seqs.fa.gz
http://itmat.rum.s3.amazonaws.com/indexes/hg18_refseq_ucsc_vega_gene_info.txt
-- Homo sapiens [build hg18] (human) end --

-- Homo sapiens [build hg19] (human) start --
http://itmat.rum.s3.amazonaws.com/rum.config_hg19
http://itmat.rum.s3.amazonaws.com/indexes/hg19_genome.1.ebwt
http://itmat.rum.s3.amazonaws.com/indexes/hg19_genome.2.ebwt
http://itmat.rum.s3.amazonaws.com/indexes/hg19_genome.3.ebwt
http://itmat.rum.s3.amazonaws.com/indexes/hg19_genome.4.ebwt
http://itmat.rum.s3.amazonaws.com/indexes/hg19_genome.rev.1.ebwt
http://itmat.rum.s3.amazonaws.com/indexes/hg19_genome.rev.2.ebwt
http://itmat.rum.s3.amazonaws.com/indexes/hg19_refseq_ucsc_vega_genes.1.ebwt
http://itmat.rum.s3.amazonaws.com/indexes/hg19_refseq_ucsc_vega_genes.2.ebwt
http://itmat.rum.s3.amazonaws.com/indexes/hg19_refseq_ucsc_vega_genes.3.ebwt
http://itmat.rum.s3.amazonaws.com/indexes/hg19_refseq_ucsc_vega_genes.4.ebwt
http://itmat.rum.s3.amazonaws.com/indexes/hg19_refseq_ucsc_vega_genes.rev.1.ebwt
http://itmat.rum.s3.amazonaws.com/indexes/hg19_refseq_ucsc_vega_genes.rev.2.ebwt
http://itmat.rum.s3.amazonaws.com/indexes/hg19_genome_one-line-seqs.fa.gz
http://itmat.rum.s3.amazonaws.com/indexes/hg19_refseq_ucsc_vega_gene_info.txt
-- Homo sapiens [build hg19] (human) end --
ORGANISMS

do {
    open my $in, "<", \$valid_org_text;
    my @got = parse_organisms($in);

    my @expected = (
        { 
            latin => "Homo sapiens",
            common => "human",
            build => "hg18",
            files => [
                "http://itmat.rum.s3.amazonaws.com/rum.config_hg18",
                "http://itmat.rum.s3.amazonaws.com/indexes/hg18_genome.1.ebwt",
                "http://itmat.rum.s3.amazonaws.com/indexes/hg18_genome.2.ebwt",
                "http://itmat.rum.s3.amazonaws.com/indexes/hg18_genome.3.ebwt",
                "http://itmat.rum.s3.amazonaws.com/indexes/hg18_genome.4.ebwt",
                "http://itmat.rum.s3.amazonaws.com/indexes/hg18_genome.rev.1.ebwt",
                "http://itmat.rum.s3.amazonaws.com/indexes/hg18_genome.rev.2.ebwt",
                "http://itmat.rum.s3.amazonaws.com/indexes/hg18_refseq_ucsc_vega_genes.1.ebwt",
                "http://itmat.rum.s3.amazonaws.com/indexes/hg18_refseq_ucsc_vega_genes.2.ebwt",
                "http://itmat.rum.s3.amazonaws.com/indexes/hg18_refseq_ucsc_vega_genes.3.ebwt",
                "http://itmat.rum.s3.amazonaws.com/indexes/hg18_refseq_ucsc_vega_genes.4.ebwt",
                "http://itmat.rum.s3.amazonaws.com/indexes/hg18_refseq_ucsc_vega_genes.rev.1.ebwt",
                "http://itmat.rum.s3.amazonaws.com/indexes/hg18_refseq_ucsc_vega_genes.rev.2.ebwt",
                "http://itmat.rum.s3.amazonaws.com/indexes/hg18_genome_one-line-seqs.fa.gz",
                "http://itmat.rum.s3.amazonaws.com/indexes/hg18_refseq_ucsc_vega_gene_info.txt",
            ]
        },
        {
            latin => "Homo sapiens",
            common => "human",
            build => "hg19",
            files => [
                "http://itmat.rum.s3.amazonaws.com/rum.config_hg19",
                "http://itmat.rum.s3.amazonaws.com/indexes/hg19_genome.1.ebwt",
                "http://itmat.rum.s3.amazonaws.com/indexes/hg19_genome.2.ebwt",
                "http://itmat.rum.s3.amazonaws.com/indexes/hg19_genome.3.ebwt",
                "http://itmat.rum.s3.amazonaws.com/indexes/hg19_genome.4.ebwt",
                "http://itmat.rum.s3.amazonaws.com/indexes/hg19_genome.rev.1.ebwt",
                "http://itmat.rum.s3.amazonaws.com/indexes/hg19_genome.rev.2.ebwt",
                "http://itmat.rum.s3.amazonaws.com/indexes/hg19_refseq_ucsc_vega_genes.1.ebwt",
                "http://itmat.rum.s3.amazonaws.com/indexes/hg19_refseq_ucsc_vega_genes.2.ebwt",
                "http://itmat.rum.s3.amazonaws.com/indexes/hg19_refseq_ucsc_vega_genes.3.ebwt",
                "http://itmat.rum.s3.amazonaws.com/indexes/hg19_refseq_ucsc_vega_genes.4.ebwt",
                "http://itmat.rum.s3.amazonaws.com/indexes/hg19_refseq_ucsc_vega_genes.rev.1.ebwt",
                "http://itmat.rum.s3.amazonaws.com/indexes/hg19_refseq_ucsc_vega_genes.rev.2.ebwt",
                "http://itmat.rum.s3.amazonaws.com/indexes/hg19_genome_one-line-seqs.fa.gz",
                "http://itmat.rum.s3.amazonaws.com/indexes/hg19_refseq_ucsc_vega_gene_info.txt",
            ]
        });

    is_deeply(\@got, \@expected, "Parse valid organisims.txt file");
          
}
