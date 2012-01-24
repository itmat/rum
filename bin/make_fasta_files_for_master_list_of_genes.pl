#!/usr/bin/perl

# Written by Gregory R. Grant
# University of Pennsylvania, 2010

if(@ARGV<4) {
    die "
Usage: make_fasta_file_for_master_list_of_genes.pl <genome fasta> <exons> <gene info input file> <gene info output file>

This script is part of the pipeline of scripts used to create RUM indexes.
You should probably not be running it alone.  See the library file:
'how2setup_genome-indexes_forPipeline.txt'.

Note: this script will remove from the gene input file anything on a chromosome
for which there is no sequence in the <genome fasta> file.

";
}

use strict;

our %chr_hash1;
our %chr_hash2;

my (undef,
    undef,
    undef,
    $final_gene_info_file) = @ARGV;

sub read_chromosome_line {
  use strict;
  my ($in) = @_;
  my $line = <$in>;
  chomp($line);
  $line =~ />(.*)/;
  return $1; 
}

# Note: fasta file $ARGV[0] must have seq all on one line
open my $infile, "<", $ARGV[0] or die "ERROR: cannot open '$ARGV[0]' for reading\n";

my $line = <$infile>;
chomp($line);
$line =~ />(.*)/;
my $chr = $1;
print STDERR "$line\n";
$chr_hash1{$chr}++;
until($line eq '') {
    $line = <$infile>;
    chomp($line);
    my $seq = $line;
    open my $exon_in_file, $ARGV[1] or die "ERROR: cannot open '$ARGV[1]' for reading.\n";
    my $exons = &get_exons($exon_in_file, $chr, $seq);
    print STDERR "done with exons for $chr\n";

    open(my $gene_in_file, $ARGV[2]) or die "ERROR: cannot open '$ARGV[2]' for reading.\n";    
    &get_genes($gene_in_file, $chr, $seq, $exons);
    print STDERR "done with genes for $chr\n";
    $line = <$infile>;
    chomp($line);
    print STDERR "$line\n";
    $line =~ />(.*)/;
    $chr = $1; 
    $chr_hash1{$chr}++;
}

my $str = "cat $ARGV[2]";
my $flag = 0;
foreach my $key (keys %chr_hash2) {
    if($chr_hash1{$key}+0==0) {
	if($flag == 0) {
	    print STDERR "no sequence for:\n$key\n";
	    $flag = 1;
	} else {
	    print STDERR "$key\n";
	}
	$str = $str .  " | grep -v $key";
    }
}
if($flag == 1) {
    print STDERR "Removing the genes on the chromosomes for which there was no genome sequence.\n";
    $str = $str . " > $final_gene_info_file";
    print STDERR "str:\n$str\n";
    `$str`;
} else {
  my $fn = $ARGV[2];
  `cp $fn $final_gene_info_file`;
}

sub get_exons () {
  use strict;
  my ($exon_in_file, $chr, $seq) = @_;

  my %exons;

  while (defined (my $line2 = <$exon_in_file>)) {
    chomp($line2);
    $line2 =~ /(.*):(\d+)-(\d+)/;
    my $CHR = $1;
    my $START = $2;
    my $END = $3;
    $chr_hash2{$CHR}++;
    if($CHR eq $chr) {
      my $EXONSEQ = substr($seq,$START-1,$END-$START+1);
      $exons{$line2} = $EXONSEQ;
    }
  }

  return \%exons;
}

=item get_genes

=cut
sub get_genes () {
  use strict;
  my ($gene_in_file, $chr, $seq, $exons) = @_;

  while(defined (my $line2 = <$gene_in_file>)) {
    chomp($line2);
    my @a = split(/\t/,$line2);
    my $strand = $a[1];
    my $starts = $a[5];
    my $ends = $a[6];
    $starts =~ s/\s*,\s*$//;
    $ends =~ s/\s*,\s*$//;
    my @STARTS = split(/,/,$starts);
    my @ENDS = split(/,/,$ends);
    my $CHR = $a[0];

    if ($CHR eq $chr) {
      my $GENESEQ = "";
      for(my $i=0; $i<@STARTS; $i++) {
        my $s = $STARTS[$i] + 1;  # add one because of the pesky zero based ucsc coords
        my $e = $ENDS[$i];  # don't add one to the end, because of the pesky half-open based ucsc coords
        my $ex = "$CHR:$s-$e";
        $GENESEQ = $GENESEQ . $exons->{$ex};
        if(!($exons->{$ex} =~ /\S/)) {
          die "ERROR: exon for $ex not found.\n$line2\ni=$i\n";
        }
      }
      $a[7] =~ s/::::.*//;
      $a[7] =~ s/\([^\(]+$//;
      print ">$a[7]:$CHR:$a[2]-$a[3]_$a[1]\n";

      my $SEQ;
      if($a[1] eq '-') {
        $SEQ = &reversecomplement($GENESEQ);
      } else {
        $SEQ = $GENESEQ;
      }
      print "$SEQ\n";
    }
  }

}


sub reversecomplement () {
  use strict;
  my ($sq) = @_;
  my @A = split(//,$sq);
  my $rev = "";
  my $flag;
  for (my $i=@A-1; $i>=0; $i--) {
    $flag = 0;
    if($A[$i] eq 'A') {
      $rev = $rev . "T";
      $flag = 1;
    }
    if($A[$i] eq 'T') {
      $rev = $rev . "A";
      $flag = 1;
    }
    if($A[$i] eq 'C') {
      $rev = $rev . "G";
      $flag = 1;
    }
    if($A[$i] eq 'G') {
      $rev = $rev . "C";
      $flag = 1;
    }
    if($flag == 0) {
      $rev = $rev . $A[$i];
    }
  }
  return $rev;
}
