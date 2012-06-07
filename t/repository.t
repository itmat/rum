#!perl

use Test::More tests => 7;
use lib "lib";

use strict;
use warnings;

BEGIN { 
  use_ok('RUM::Repository::IndexSpec');
  use_ok('RUM::Repository');
}

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
    my @got = RUM::Repository::IndexSpec->parse($in);

    my @latins = ("Homo sapiens", "Homo sapiens");
    my @commons = ("human", "human");
    my @builds = qw(hg18 hg19);

    my @urls = (
        [
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
        ],
        [
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
    );
        
    is_deeply([map { $_->common } @got], \@commons, 
              "Parse common name correctly");

    is_deeply([map { $_->latin } @got], \@latins, 
              "Parse latin name correctly");

    is_deeply([map { $_->build } @got], \@builds, 
              "Parse build names correctly");

    is_deeply([map { [$_->urls] } @got], \@urls, 
              "Parse build names correctly");

    my $repo = RUM::Repository->new();
    like($repo->config_filename($got[0]), qr(indexes/hg18/rum_index.conf),
       "Found config file");
          
}

