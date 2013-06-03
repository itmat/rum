#!/usr/bin/perl

=head1 NAME

create_indexes_from_ensembl.pl

=head1 SYNOPSIS

  create_indexes_from_ensembl.pl --name NAME GENOME_FA GTF

=head1 AUTHOR

Gregory R. Grant (ggrant@grant.org)

=head1 COPYRIGHT

Copyright 2012 University of Pennsylvania

=cut

use strict;
use warnings;
use autodie;

use Getopt::Long;
use File::Copy qw(mv);
use FindBin qw($Bin);
use lib ("$Bin/../lib", "$Bin/../lib/perl5");

use RUM::Common qw(shell);
use RUM::Index;
use RUM::Repository;
use RUM::Script qw(get_options show_usage);
use RUM::Usage;

# This imports the subs from RUM::Script and wraps them in methods
# that will print a log message before and after each one runs.
RUM::Script::import_scripts_with_logging();

###
### Parse command line args
###

GetOptions("name=s" => \(my $name));

$name or RUM::Usage->bad("Please give me a name for the index, for example ".
                         "the organism name or assembly, with --name");

@ARGV == 2 or RUM::Usage->bad("Please provide the genome FASTA file and " .
                              "the GTF file");


mkdir $name unless -d $name;

###
### Some variables for filenames
###

my ($genome, $gtf) = @ARGV;

my $genome_base = $genome =~ /^(.*).txt/ && $1 or die(
    "Genome file must end with .txt");

my $gene_model_name = $name . "_ensembl";

my $genome_fa                 = "${genome_base}.fa";
my $genome_one_line_seqs_temp = "${genome_base}_one-line-seqs_temp.fa";
my $genome_one_line_seqs      = "$name/${genome_base}_one-line-seqs.fa";

open my $infile, "<", $genome;
open OUTFILE, ">", $genome_fa;
my $flag = 0;
my $chr = "";
while(my $line = <$infile>) {
    if($line =~ />/) {

	if($line =~ /^>EG:([^\s]+)\s/) {
	    $chr = $1;
	} elsif ($line =~ /^>([^\s]+)\s*/) {
	    $chr = $1;
	}
        else {
            die "Couldn't parse chromosome from $line\n";
        }

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
close($infile);
close(OUTFILE);

modify_fa_to_have_seq_on_one_line($genome_fa, $genome_one_line_seqs_temp);
sort_genome_fa_by_chr($genome_one_line_seqs_temp, $genome_one_line_seqs);
shell "perl $Bin/gtf2rum-index-builder-friendly.pl $gtf > ensembl.txt";

open my $out, ">", "gene_info_files";
print $out "ensembl.txt\n";
close $out;

shell "perl $Bin/create_gene_indexes.pl --name $gene_model_name $genome_one_line_seqs\n";

mv "${gene_model_name}_gene_info.txt", "$name/${gene_model_name}_gene_info.txt"
or die "mv ${gene_model_name}_gene_info.txt $name/${gene_model_name}_gene_info.txt: $!"; 

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
    bowtie_transcriptome_index => "${gene_model_name}_genes",
    genome_fasta               => basename($genome_one_line_seqs),
    genome_size                => $genome_size,
    directory                  => $name);
$config->save;

sub bowtie {
  my @cmd = ("bowtie-build", @_);
  system(@cmd) == 0 or die "Couldn't run '@cmd': $!";
}

print STDERR "\nBuilding the bowtie genome index, this could take some time...\n\n";

bowtie($genome_one_line_seqs, "$name/${name}_genome");

my $N1 = $gene_model_name . "_gene_info_orig.txt";
my $N6 = $gene_model_name . "_gene_info.txt";
$genome_one_line_seqs = $gene_model_name . "_one-line-seqs.fa";

$gene_model_name = $gene_model_name . "_genes";
my $temp2 = $gene_model_name . ".fa";

print STDERR "Building the bowtie gene index...\n\n";

bowtie($temp2, "$name/$gene_model_name");

unlink($temp2);
unlink($genome_fa);
unlink($genome_one_line_seqs_temp);
unlink("gene_info_files");
unlink("ensembl.txt");
unlink($N1);

print STDERR "ok, all done...\n\n";
