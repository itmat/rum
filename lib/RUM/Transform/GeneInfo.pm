package RUM::Transform::GeneInfo;

use strict;
use warnings;

use Log::Log4perl qw(:easy);

use Exporter 'import';
our %EXPORT_TAGS = 
  (
   transforms => [qw(make_master_file_of_genes
                     fix_geneinfofile_for_neg_introns
                     sort_geneinfofile
                     make_ids_unique4geneinfofile
                     get_master_list_of_exons_from_geneinfofile)]);

Exporter::export_ok_tags('transforms');

=pod

=head1 NAME

RUM::Transform::GeneInfo - Common utilities for transforming annotated gene files.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

  use RUM::Transform::GeneInfo qw(:transforms);

  make_master_file_of_genes($gene_info_files_file, $out);
  fix_geneinfofile_for_neg_introns($infile, $outfile, $starts_col, $ends_col, $exon_count_col);
  sort_geneinfofile($in, $out);

=head1 DESCRIPTION

=head2 Subroutines

=over 4

=cut

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


=item fix_geneinfofile_for_neg_introns($infile, $outfile, $starts_col, $ends_col, $exon_count_col)

Takes a UCSC gene annotation file ($infile) and outputs a file that removes
introns of zero or negative length.  You'd think there shouldn't be
such introns but for some annotation sets there are.

<starts col> is the column with the exon starts, <ends col> is the
column with the exon ends.  These are counted starting from zero.
<num exons col> is the column that has the number of exons, also
counted starting from zero.  If there is no such column, set this to
-1.

=cut
sub fix_geneinfofile_for_neg_introns {
  my ($infile, $outfile, $starts_col, $ends_col, $exon_count_col) = @_;

  while (defined (my $line = <$infile>)) {
    chomp($line);
    my @a = split(/\t/, $line);
    my $starts = $a[$starts_col];
    my $ends = $a[$ends_col];

    # Make sure the starts, ends, and exon_counts columns are
    # populated
    if(!($starts =~ /\S/)) {
	die "ERROR: the 'starts' column has empty entries\n";
    }
    if(!($ends =~ /\S/)) {
	die "ERROR: the 'ends' column has empty entries\n";
    }
    if(!($a[$exon_count_col] =~ /\S/)) {
	die "ERROR: the 'exon counts' column has empty entries\n";
    }

    $starts =~ s/,\s*$//;
    $ends =~ s/,\s*$//;
    my @S = split(/,/, $starts);
    my @E = split(/,/, $ends);
    my $start_string = $S[0] . ",";
    my $end_string = "";
    my $N = @S;
    for(my $i=1; $i<$N; $i++) {
      my $intronlength = $S[$i] - $E[$i-1];
      my $realstart = $E[$i-1] + 1;
      my $realend = $S[$i];
      my $length = $realend - $realstart + 1;
      DEBUG "length = $length";
      if($length > 0) {
        $start_string = $start_string . $S[$i] . ",";
        $end_string = $end_string . $E[$i-1] . ",";
      }
      else {
        #           print $outfile "$line\n";
        if($exon_count_col >= 0) {
          $a[$exon_count_col]--;
        }
      }
    }
    $end_string = $end_string . $E[$N-1] . ",";;
    $a[$starts_col] = $start_string;
    $a[$ends_col] = $end_string;
    print $outfile "$a[0]";
    for(my $i=1; $i<@a; $i++) {
      print $outfile "\t$a[$i]";
    }
    print $outfile "\n";
  }
  
}

=item sort_geneinfofile()

Sorts an annotated gene file first by chromosome, then by start exons, then by end exons.

=cut
sub sort_geneinfofile {
  my ($infile, $outfile) = @_;
  my (%start, %end, %chr);
  while (defined (my $line = <$infile>)) {
    chomp($line);
    my @a = split(/\t/,$line);
    $start{$line} = $a[2];
    $end{$line} = $a[3];
    $chr{$line} = $a[0];
  }

  foreach my $line (sort {
    $chr{$a} cmp $chr{$b} || $start{$a}<=>$start{$b} || $end{$a}<=>$end{$b}} keys %start) {
    print $outfile "$line\n";
  }
}

sub make_ids_unique4geneinfofile {
  my ($in, $out) = @_;
  my (%idcount, %typecount);

  while (defined (my $line = <$in>)) {
    chomp($line);
    my @a = split(/\t/,$line);
    my @b = split(/::::/,$a[7]);
    
    # Count the number of rows with the current id and type
    for(my $i=0; $i<@b; $i++) {
      $b[$i] =~ /(.*)\(([^\)]+)\)$/;
      my $id = $1;
      my $type = $2;
      $id =~ s/.*://;
      $id =~ s/\(.*//;
      $idcount{$type}{$id}++;
      $typecount{$id}{$type}++;
    }
  }
  seek $in, 0, 0;

  # Count the total number of types per id
  my %id_type_count;
  foreach my $id (keys %typecount) {
    my $cnt = 0;
    foreach my $type (keys %{$typecount{$id}}) {
      $cnt++;
    }
    $id_type_count{$id} = $cnt;
  }


  my %idcount2;
  while (defined (my $line = <$in>)) {
    chomp($line);
    my @a = split(/\t/,$line);
    my @b = split(/::::/,$a[7]);
    for(my $i=0; $i<@b; $i++) {
      $b[$i] =~ /(.*)\(([^\)]+)\)$/;
      my $id = $1;
      my $type = $2;
      $id =~ s/.*://;
      $id =~ s/\(.*//;
      $idcount2{$type}{$id}++;
      if($idcount{$type}{$id} > 1) {
        my $j = $idcount2{$type}{$id};
        my $id_with_number = $id . "[[$j]]";
        $line =~ s/$id\($type\)/$id_with_number\($type\)/;
      }
      if($id_type_count{$id} > 1) {
        $line =~ s/\($type\)/\.$type($type\)/;
      }
    }
    print $out "$line\n";
  }
}

sub get_master_list_of_exons_from_geneinfofile {
  my ($in, $out) = @_;

  my %EXONS;
  my $_;

  while(defined (my $line = <$in>)) {
    chomp($line);
    my @a = split(/\t/,$line);
    $a[5]=~ s/\s*,\s*$//;
    $a[5]=~ s/^\s*,\s*//;
    $a[6]=~ s/\s*,\s*$//;
    $a[6]=~ s/^\s*,\s*//;
    my @S = split(/,/,$a[5]);
    my @E = split(/,/,$a[6]);
    my $N = @S;
    for(my $e=0; $e<@S; $e++) {
      $S[$e]++;
      my $exon = "$a[0]:$S[$e]-$E[$e]";
      $EXONS{$exon}++;
    }
  }

  for (keys %EXONS) {
    print "$_\n";
  }
}

1;
