package RUM::Transform::Fasta;

use strict;
use warnings;
use Log::Log4perl qw(:easy);
use Exporter 'import';
use RUM::ChrCmp qw(cmpChrs sort_by_chromosome);


our %EXPORT_TAGS = 
  (transforms => [qw(modify_fa_to_have_seq_on_one_line
                     modify_fasta_header_for_genome_seq_database
                     sort_genome_fa_by_chr)]);

Exporter::export_ok_tags('transforms');

=item modify_fa_to_have_seq_on_one_line($infile, $outfile)

Modify a fasta file to have the sequence all on one line. Reads from
$infile and writes to $outfile.

=cut
sub modify_fa_to_have_seq_on_one_line {
  
  my ($infile, $outfile) = @_;

  my $flag = 0;
  while(defined(my $line = <$infile>)) {
    # TODO: Using ^ anchor seems to save 15%; 61 to 53 seconds for cow
    if($line =~ />/) {
      if($flag == 0) {
        print $outfile $line;
        $flag = 1;
      } else {
        print $outfile "\n$line";
      }
    } else {
      chomp($line);
      $line = uc $line;
      print $outfile $line;
    }
  }
  print $outfile "\n";
}

=item modify_fasta_header_for_genome_seq_database($infile, $outfile

Transform each line on $infile and write to $outfile, changing any
fasta header lines that look like:

    >hg19_ct_UserTrack_3545_+ range=chrUn_gl000248:1-39786 ...

to look like:

    >chrUn_gl000248

=cut
sub modify_fasta_header_for_genome_seq_database {
  my ($infile, $outfile) = @_;
  while(defined(my $line = <$infile>)) {
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
    print $outfile "$line\n";
  }
}

=item sort_genome_fa_by_chr($infile, $outfile)

Expects an input file containing FASTA data, where adjacent sequence
lines are all concatenated together in a long line. Sorts the entries
in the file by chromosome.

=cut

sub sort_genome_fa_by_chr {

  my ($infile, $outfile) = @_;

  my %hash;
  INFO "Reading in genome";
  while (defined (my $line = <$infile>)) {
    chomp($line);
    $line =~ /^>(.*)$/;
    my $chr = $1;
    $line = <$infile>;
    chomp($line);
    $hash{$chr} = $line;
  }

  INFO "Sorting chromosomes";
  my @chromosomes = sort_by_chromosome keys %hash;
  
  INFO "Printing output";
  foreach my $chr (@chromosomes) {
    print $outfile ">$chr\n$hash{$chr}\n";
  }
}

1;
