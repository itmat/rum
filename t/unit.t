#!perl -T

use Test::More tests => 12;
use lib "lib";

use strict;
use warnings;
use Log::Log4perl qw(:easy);

BEGIN { 
  use_ok('RUM::Script', qw(:scripts));

  use_ok('RUM::ChrCmp', qw(cmpChrs sort_by_chromosome));
}

sub transform_ok {
  my ($function, $input, $expected, $desc) = @_;
  open my $infile, "<", \$input;
  open my $outfile, ">", \(my $output);
  $function->($infile, $outfile);
  close $infile;
  close $outfile;
  is($output, $expected, $desc);
}

sub modify_fa_to_have_seq_on_one_line_ok {

  my $input = <<INPUT;
>gi|123|ref|123sdf|Foo bar
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG
TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT
INPUT

  my $expected = <<EXPECTED;
>gi|123|ref|123sdf|Foo bar
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT
EXPECTED

  transform_ok(\&modify_fa_to_have_seq_on_one_line,
               $input, $expected, "Joining sequence lines together");
}


sub modify_fasta_header_for_genome_seq_database_ok {

  my $input = ">hg19_ct_UserTrack_3545_+ range=chrUn_gl000248:1-39786 5'pad=0 3'pad=0 strand=+ repeatMasking=none\n";


  my $expected = ">chrUn_gl000248\n";

  transform_ok(\&modify_fasta_header_for_genome_seq_database,
               $input, $expected, "Reformatting header line");
}

sub chromosome_comparison_ok {
  my @in = qw(chr2 chr26 chr19 chrX chr25 chrUn_GJ060005 chr15 chr8
              chrUn_GJ060003 chrUn_GJ058001 chr13 chrUn_GJ058006 chr21 chr5
              chr10 chr3 chrUn_GJ058004 chr1 chrUn_GJ059004 chrUn_GJ060007
              chr11 chr22 chrUn_GJ058005 chrUn_GJ060006 chrUn_GJ059003
              chrUn_GJ059001 chr28 chr12 chrUn_GJ060001 chrUn_GJ059009 chr18
              chrUn_GJ058007 chrUn_GJ060009 chr20 chrUn_GJ059008 chrUn_GJ059002 
              chrUn_GJ060004 chrUn_GJ060002 chrUn_GJ059000 chrUn_GJ058003 chr4
              chrUn_GJ060000 chrUn_GJ058008 chr7 chr29 chrUn_GJ060008
              chrUn_GJ059005 chrUn_GJ058002 chr16 chr17 chrUn_GJ059006 chrM
              chrUn_GJ058009 chrUn_GJ059007 chr14 chrUn_GJ058000 chr6 chr24
              chr23 chr9 chr27);

  my @expected = qw(chr1 chr2 chr3 chr4 chr5 chr6 chr7 chr8 chr9 chr10 chr11 
                    chr12 chr13 chr14 chr15 chr16 chr17 chr18 chr19 chr20 chr21
                    chr22 chr23 chr24 chr25 chr26 chr27 chr28 chr29 chrX chrM 
                    chrUn_GJ058000 chrUn_GJ058001 chrUn_GJ058002 chrUn_GJ058003
                    chrUn_GJ058004 chrUn_GJ058005 chrUn_GJ058006 chrUn_GJ058007 
                    chrUn_GJ058008 chrUn_GJ058009 chrUn_GJ059000 chrUn_GJ059001
                    chrUn_GJ059002 chrUn_GJ059003 chrUn_GJ059004 chrUn_GJ059005
                    chrUn_GJ059006 chrUn_GJ059007 chrUn_GJ059008 chrUn_GJ059009
                    chrUn_GJ060000 chrUn_GJ060001 chrUn_GJ060002 chrUn_GJ060003
                    chrUn_GJ060004 chrUn_GJ060005 chrUn_GJ060006 chrUn_GJ060007
                    chrUn_GJ060008 chrUn_GJ060009);
  my @got = sort_by_chromosome @in;
  is_deeply(\@got, \@expected);
}

sub reverse_complement_ok {

  my $is_rc = sub {
    my ($in, $expected) = @_;
    is(RUM::Script::reversecomplement($in), $expected); 
  };

  my @in = qw(A T C G ACCGGGTTTTT AXAA);
  my @expected = qw(T A G C AAAAACCCGGT TTXT);
  my @got = map { RUM::Script::reversecomplement($_) } @in;
  is_deeply(\@got, \@expected, "Reverse complement");
}


sub sort_genome_fa_by_chr_ok {
  my $in = <<IN;
>chr9
AA
>chr1
CC
>chrVI
GG
>chrIII
AT
>chrUn
TT
IN

  my $expected = <<OUT;
>chr1
CC
>chr9
AA
>chrIII
AT
>chrUn
TT
>chrVI
GG
OUT

  sort_genome_fa_by_chr(\$in, \(my $got));
  is($got, $expected, "Sort genome by chromosome");
}


sub sort_gene_fa_by_chr_ok {
  my $in = <<IN;
>NM_02:chr2:100-200_-
CC
>NM_02:chr2:1-50_-
GG
>NM_02:chr1:100-200_-
AA
>NM_02:chr1:1-50_-
TT
>NM_01:chr2:100-200_-
CC
>NM_01:chr2:1-50_-
GG
>NM_01:chr1:100-200_-
AA
>NM_01:chr1:1-50_-
TT
IN

  my $expected = <<OUT;
>NM_01:chr1:1-50_-
TT
>NM_02:chr1:1-50_-
TT
>NM_01:chr1:100-200_-
AA
>NM_02:chr1:100-200_-
AA
>NM_01:chr2:1-50_-
GG
>NM_02:chr2:1-50_-
GG
>NM_01:chr2:100-200_-
CC
>NM_02:chr2:100-200_-
CC
OUT
  
  sort_gene_fa_by_chr(\$in, \(my $got));
  is ($got, $expected, "Sort gene FASTA file by chromosome");
}

sub get_exons_ok {
  my $exons_in = <<EXONS;
chr1:1-5
chr1:7-12
chr2:17-24
chr2:31-45
EXONS

  my $seq = "ACGTACTGATGCATGCGCGATGCAGTCAGTAACCCCGGGTAGCAGTGACTTTGCTTTC";

my %expected1 = 
  ("chr1:1-5" => substr($seq, 0, 5),
   "chr1:7-12" => substr($seq, 6, 6));

my %expected2 = 
  ("chr2:17-24" => substr($seq, 16, 8),
   "chr2:31-45" => substr($seq, 30, 15));

  my %chromosomes;

  open my $in, "<", \$exons_in;
  my $exons1 = RUM::Script::get_exons($in, "chr1", $seq, \%chromosomes);
  seek $in, 0, 0;
  my $exons2 = RUM::Script::get_exons($in, "chr2", $seq, \%chromosomes);
  is_deeply([$exons1, $exons2],
            [\%expected1, \%expected2],
            "Get sequences for exons");

  is_deeply([sort keys %chromosomes],
            ["chr1", "chr2"],
            "Get chromosomes from exon file");
}

sub make_master_file_of_genes_ok {
  my $refseq_in = <<IN;
#name\tchrom\tstrand\texonStarts\texonEnds
NM_1234\tchr1\t+\t1,17,32\t5,22,45
NM_5432\tchr1\t-\t54,62\t60,67
NM_4321\tchr2\t+\t1,8\t7,11
NM_9876\tchr2\t+\t12,23\t20,32
IN

  my $ensembl_in = <<IN;
#name\tchrom\tstrand\texonStarts\texonEnds
ENSBTAT1234\tchr1\t+\t1,17,32\t5,22,45
ENSBTAT5432\tchr1\t-\t54,62\t70,79
ENSBTAT\tchr2\t+\t1,8\t7,11
ENSBTAT\tchr2\t+\t12,23\t34,40
IN
  
  my $expected = <<EXPECTED;
chr1	-	54	67	2	54,62	60,67	NM_5432(refseq)
chr1	+	1	45	3	1,17,32	5,22,45	NM_1234(refseq)::::ENSBTAT1234(ensembl)
chr1	-	54	79	2	54,62	70,79	ENSBTAT5432(ensembl)
chr2	+	12	32	2	12,23	20,32	NM_9876(refseq)
chr2	+	12	40	2	12,23	34,40	ENSBTAT(ensembl)
chr2	+	1	11	2	1,8	7,11	NM_4321(refseq)::::ENSBTAT(ensembl)
EXPECTED

  my $out;
  RUM::Script::_make_master_file_of_genes_impl([\$refseq_in, \$ensembl_in], 
                                               \$out,
                                               ["refseq", "ensembl"]);
  is($out, $expected, "Make master file of genes");
}

sub make_ids_unique4geneinfofile_ok {

  my @in_ids = qw{
                   NM_123(refseq)
                   NM_456(ensembl)
                   NM_789(refseq)
                   NM_789(ensembl)
                   NM_987(refseq)
                   NM_987(refseq)
                   NM_654(refseq)
                   NM_654(refseq)
                   NM_654(refseq)
                   NM_321(ensembl)
                   NM_321(ensembl)
                  };

  my @expected_ids = qw{
                         NM_123(refseq)
                         NM_456(ensembl)
                         NM_789.refseq(refseq)
                         NM_789.ensembl(ensembl)
                         NM_987[[1]](refseq)
                         NM_987[[2]](refseq)
                         NM_654[[1]](refseq)
                         NM_654[[2]](refseq)
                         NM_654[[3]](refseq)
                         NM_321[[1]](ensembl)
                         NM_321[[2]](ensembl)
                     };

  my $_;

  # Build a string that looks like an input file with our ids, which
  # are in the 8th column of the tab file.
  my $in       = join "", map { "\t\t\t\t\t\t\t$_\n" } @in_ids;
  my $expected = join "", map { "\t\t\t\t\t\t\t$_\n" } @expected_ids;

  make_ids_unique4geneinfofile(\$in, \(my $out));

  # Extract the ids from the output; split the lines and trim whitespace.
  my @out = split /\n/, $out;
  my @expected = split /\n/, $expected;
  s/\s+//g foreach @out;
  s/\s+//g foreach @expected;

  is_deeply(\@out, \@expected, "Make IDs unique");
}

modify_fa_to_have_seq_on_one_line_ok();
modify_fasta_header_for_genome_seq_database_ok();
chromosome_comparison_ok();
reverse_complement_ok();
sort_genome_fa_by_chr_ok();
sort_gene_fa_by_chr_ok();
get_exons_ok();
make_master_file_of_genes_ok();
make_ids_unique4geneinfofile_ok();
