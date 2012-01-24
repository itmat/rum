package RUM::Transform::GeneInfo;

use strict;
use warnings;

use Log::Log4perl qw(:easy);

use Exporter 'import';
our @EXPORT_OK = qw(make_master_file_of_genes);

=item make_master_file_of_genes($filesfilename)

Reads in one or more files containing gene info and merges them
together. For records that exist in both files, we merge the records
together and append the names used in both files.

=cut

sub _read_files_file {
  my ($filesfile) = @_;

  my @files;
  while(defined (my $file = <$filesfile>)) {
    chomp($file);
    push @files, $file;
  }
  return @files;
}

sub make_master_file_of_genes {
  my ($filesfile, $outfile) = @_;
  my $total = 0;

  my %geneshash;

  my @files = _read_files_file($filesfile);

  for my $file (@files) {
    INFO "processing $file";
    my ($type) = $file =~ /(.*).txt$/g;
    open(my $infile, "<", $file);
    my $line = <$infile>;
    chomp($line);
    my @header = split(/\t/,$line);
    my $n = @header;

    my ($namecol, $chromcol, $strandcol, $exonStartscol, $exonEndscol);

    for(my $i=0; $i<$n; $i++) {

      if($header[$i] =~ /name/) {
        $namecol = $i;
      }
      if($header[$i] =~ /chrom/) {
        $chromcol = $i;
      }
      if($header[$i] =~ /strand/) {
        $strandcol = $i;
      }
      if($header[$i] =~ /exonStarts/) {
        $exonStartscol = $i;
      }
      if($header[$i] =~ /exonEnds/) {
        $exonEndscol = $i;
      }
    }
    # TODO: Make sure we got all the fields?

    my $cnt=0;
    while(defined (my $line = <$infile>)) {
      chomp($line);
      
      # Skip comments
      next if($line =~ /^#/);

      my @a = split(/\t/,$line);
      $a[$exonStartscol] =~ /^(\d+)/;
      my $txStart = $1;
      $a[$exonEndscol] =~ /(\d+),?$/;
      my $txEnd = $1;
      my @b = split(/,/,$a[$exonStartscol]);
      my $exonCnt = @b;
      my $info = join("\t",
                   $a[$chromcol],
                   $a[$strandcol],
                   $txStart,
                   $txEnd,
                   $exonCnt,
                   $a[$exonStartscol],
                   $a[$exonEndscol]);
      $geneshash{$info} ||= "";
      if($geneshash{$info} =~ /\S/) {
        $geneshash{$info} = $geneshash{$info} . "::::" . $a[$namecol] . "($type)";
      }
      else {
        $geneshash{$info} = $geneshash{$info} . $a[$namecol].  "($type)";
      }
      $cnt++;
    }
    INFO "$cnt lines in file\n";
    $total += $cnt;
  }
  INFO "TOTAL: $total\n";
  
  foreach my $geneinfo (keys %geneshash) {
    print $outfile "$geneinfo\t$geneshash{$geneinfo}\n";
  }
  
}
