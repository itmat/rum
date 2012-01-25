package RUM::Transform::Fasta;

use strict;
use warnings;
use Log::Log4perl qw(:easy);
use Exporter 'import';
use RUM::ChrCmp qw(cmpChrs sort_by_chromosome);

=pod

=head1 NAME

RUM::Transform::Fasta - Common utilities for transforming fasta files.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

  use RUM::Transform::Fasta qw(:transforms);

  modify_fa_to_have_seq_on_one_line($in, $out);
  modify_fasta_header_for_genome_seq_database($in, $out);
  sort_genome_fa_by_chr($in, $out);

=head1 DESCRIPTION

=head2 Subroutines

=over 4

=cut

our %EXPORT_TAGS = 
  (transforms => [qw(modify_fa_to_have_seq_on_one_line
                     modify_fasta_header_for_genome_seq_database
                     sort_genome_fa_by_chr
                     sort_gene_fa_by_chr)]);

Exporter::export_ok_tags('transforms');


=item modify_fasta_header_for_genome_seq_database($infile, $out

Transform each line on $infile and write to $out, changing any
fasta header lines that look like:

    >hg19_ct_UserTrack_3545_+ range=chrUn_gl000248:1-39786 ...

to look like:

    >chrUn_gl000248

=cut
sub modify_fasta_header_for_genome_seq_database {
  my ($in, $out) = open_in_and_out(@_);
  while(defined(my $line = <$in>)) {
    chomp($line);
    if($line =~ /^>/) {
	$line =~ s/^>//;
        $line =~ s/.*UserTrack_3545_.*range=//;
        $line =~ s/ 5'pad=0 3'pad=0//;
        $line =~ s/ repeatMasking=none//;
        $line =~ s/ /_/g;
	$line =~ s/:[^:]+$//;
        $line = ">" . $line;
    }
    print $out "$line\n";
  }
}

=item sort_genome_fa_by_chr($in, $out)

Expects an input file containing FASTA data, where adjacent sequence
lines are all concatenated together in a long line. Sorts the entries
in the file by chromosome.

=cut

sub sort_genome_fa_by_chr {

  my ($in, $out) = open_in_and_out(@_);

  my %hash;
  INFO "Reading in genome";
  while (defined (my $line = <$in>)) {
    chomp($line);
    $line =~ /^>(.*)$/;
    my $chr = $1;
    $line = <$in>;
    chomp($line);
    $hash{$chr} = $line;
  }

  INFO "Sorting chromosomes";
  my @chromosomes = sort_by_chromosome keys %hash;
  
  INFO "Printing output";
  foreach my $chr (@chromosomes) {
    print $out ">$chr\n$hash{$chr}\n";
  }
}

=item sort_gene_fa_by_chr(IN, OUT)

Sort a gene FASTA file by chromosome. Reads from IN and writes to OUT.

=cut
sub sort_gene_fa_by_chr {
  my ($in, $out) = @_;

  my %hash;
  my %seq;

  while (defined (my $line = <$in>)) {
    chomp($line);
    $line =~ /^>(.*):([^:]+):(\d+)-(\d+)_.$/;
    my $name = $1;
    my $chr = $2;
    my $start = $3;
    my $end = $4;
    $hash{$chr}{$line}[0] = $start;
    $hash{$chr}{$line}[1] = $end;
    $hash{$chr}{$line}[2] = $name;
    my $SEQ = <$in>;
    chomp($SEQ);
    $seq{$line} = $SEQ;
  }
  
  foreach my $chr (sort {cmpChrs($a,$b)} keys %hash) {
    foreach my $line (sort {$hash{$chr}{$a}[0]<=>$hash{$chr}{$b}[0] || ($hash{$chr}{$a}[0]==$hash{$chr}{$b}[0] && $hash{$chr}{$a}[1]<=>$hash{$chr}{$b}[1]) || ($hash{$chr}{$a}[0]==$hash{$chr}{$b}[0] && $hash{$chr}{$a}[1]==$hash{$chr}{$b}[1] && $hash{$chr}{$a}[2] cmp $hash{$chr}{$b}[2])} keys %{$hash{$chr}}) {
      chomp($line);
      if($line =~ /\S/) {
        print $out $line;
        print $out "\n";
        print $out $seq{$line};
        print $out "\n";
      }
    }
  }
}

1;
