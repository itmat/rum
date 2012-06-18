#!/usr/bin/perl

# Written by Gregory R. Grant
# University of Pennsylvania, 2010

use strict;
use warnings;
use autodie;

use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");

use RUM::Index;
use RUM::Repository;
use RUM::Script qw(get_options show_usage);
use RUM::Common qw(shell);

RUM::Script::import_scripts_with_logging();

use Getopt::Long;

GetOptions("name=s" => \(my $name));

if(@ARGV < 1) {
    die "
Usage: create_indexes_from_ensembl.pl <genome fasta> <gtf>

";
}

my ($genome, $gtf) = @ARGV;

my $genome_base;

if ($genome =~ /^(.*).txt/) {
    $genome_base = $1;
}
else {
    die "Genome file must end with .txt";
}

my $gene_model_name = $name . "_ensembl";

my $genome_fa                 = "${genome_base}.fa";
my $genome_one_line_seqs_temp = "${genome_base}_one-line-seqs_temp.fa";
my $genome_one_line_seqs      = "${genome_base}_one-line-seqs.fa";

open INFILE, "<", $genome;
open OUTFILE, ">", $genome_fa;
my $flag = 0;

while(my $line = <INFILE>) {
    if($line =~ />/) {
	$line =~ /^>EG:([^\s]+)\s/ or $line =~ /^>(\w+)/;
	my $chr = $1;
        if($flag == 0) {
            print OUTFILE ">$chr\n";
            $flag = 1;
        } else {
            print OUTFILE "\n>$chr\n";
        }
    } else {
        chomp($line);
        $line = uc $line;
        print OUTFILE $line;
    }
}
print "\n";
close(INFILE);
close(OUTFILE);

modify_fa_to_have_seq_on_one_line($genome_fa, $genome_one_line_seqs_temp);
sort_genome_fa_by_chr($genome_one_line_seqs_temp, $genome_one_line_seqs);
shell "perl $Bin/gtf2rum-index-builder-friendly.pl $gtf > ensembl.txt";

open my $out, ">", "gene_info_files";
print $out "ensembl.txt\n";
close $out;

shell "perl $Bin/create_gene_indexes.pl --name $gene_model_name $genome_one_line_seqs\n";

my $genome_size = RUM::Repository::genome_size($genome_one_line_seqs);

sub basename {
    my ($filename) = @_;
    my @parts = File::Spec->splitpath($filename);
    return $parts[$#parts];
}

# write rum.config file:
my $config = RUM::Index->new(
    gene_annotations           => "${gene_model_name}_gene_info.txt",
    bowtie_genome_index        => "${name}_genome",
    bowtie_transcriptome_index => "${name}_genes",
    genome_fasta               => basename($genome_one_line_seqs),
    genome_size                => $genome_size,
    directory                  => $name);

sub bowtie {
  my @cmd = ("bowtie-build", @_);
  system(@cmd) == 0 or die "Couldn't run '@cmd': $!";
}

print STDERR "\nBuilding the bowtie genome index, this could take some time...\n\n";

bowtie($genome_one_line_seqs, "${name}_genome");

my $N1 = $gene_model_name . "_gene_info_orig.txt";
my $N6 = $gene_model_name . "_gene_info.txt";
$genome_one_line_seqs = $gene_model_name . "_one-line-seqs.fa";

$gene_model_name = $gene_model_name . "_genes";
my $temp2 = $gene_model_name . ".fa";

print STDERR "Building the bowtie gene index...\n\n";

bowtie($temp2, $gene_model_name);

#unlink($genome_fa);
#unlink($genome_one_line_seqs_temp);

print STDERR "ok, all done...\n\n";
