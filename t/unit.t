#!perl -T

use Test::More tests => 3;
use lib "lib";

BEGIN { use_ok('RUM::Index', qw(modify_fa_to_have_seq_on_one_line
                                modify_fasta_header_for_genome_seq_database)) }

sub transform_ok {
  my ($function, $input, $expected) = @_;
  open $infile, "<", \$input;
  open $outfile, ">", \(my $output);
  $function->($infile, $outfile);
  close $infile;
  close $outfile;
  is ($output, $expected);
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
               $input, $expected);
}


sub modify_fasta_header_for_genome_seq_database_ok {

  my $input = ">hg19_ct_UserTrack_3545_+ range=chrUn_gl000248:1-39786 5'pad=0 3'pad=0 strand=+ repeatMasking=none\n";


  my $expected = ">chrUn_gl000248\n";

  transform_ok(\&modify_fasta_header_for_genome_seq_database,
               $input, $expected);
}

modify_fa_to_have_seq_on_one_line_ok();
modify_fasta_header_for_genome_seq_database_ok();

