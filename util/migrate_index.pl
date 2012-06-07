#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use lib "lib";

use File::Copy qw(cp);

use RUM::ConfigFile;
use RUM::Index;
use File::Spec;
use Cwd;

my ($config_filename, $name) = @ARGV;

print "Rebuilding index for $config_filename\n";
open my $in, "<", $config_filename;

sub genome_size {
    my ($genome_fa) = @_;
    print "Determining the size of the genome.\n";
    my $gs1 = -s $genome_fa;
    my $gs2 = 0;
    my $gs3 = 0;
    
    open my $in, "<", $genome_fa;

    local $_;
    while (defined($_ = <$in>)) {
        next unless /^>/;
        $gs2 += length;
        $gs3 += 1;
    }

    return $gs1 - $gs2 - $gs3;
}



my $config = RUM::ConfigFile->parse($in);

-d $name or mkdir $name;

my @old_files = (
    $config->gene_annotation_file,
    glob($config->bowtie_genome_index . "*"),
    glob($config->bowtie_gene_index . "*"),
    $config->blat_genome_index);
    

for my $file (@old_files) {

    my (undef, undef, $filename) = File::Spec->splitpath($file);
    my $new = File::Spec->catfile($name, $filename);

    cp $file, $new unless -e $new;
}

my (undef, undef, $gene_annotations) = 
    File::Spec->splitpath($config->gene_annotation_file);
my (undef, undef, $bowtie_genome_index) = 
    File::Spec->splitpath($config->bowtie_genome_index);
my (undef, undef, $bowtie_transcriptome_index) = 
    File::Spec->splitpath($config->bowtie_gene_index);
my (undef, undef, $genome_fasta) = 
    File::Spec->splitpath($config->blat_genome_index);
my $genome_size = genome_size($config->blat_genome_index);

my $dir = getcwd;
chdir $name;

my $index = RUM::Index->new(
    config => "$name.conf",
    gene_annotations => $gene_annotations,
    bowtie_genome_index => $bowtie_genome_index,
    bowtie_transcriptome_index => $bowtie_transcriptome_index,
    genome_fasta => $genome_fasta,
    genome_size  => $genome_size
);

$index->save;

chdir $dir;

system "tar cvfz $name.tar.gz $name";
