package RUM::Script;

=pod

=head1 NAME

RUM::Script - Common utilities for transforming files

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 DESCRIPTION

This module provides some "scripts" for operating on data files. All
of the scripts read from one or more sources and write to one or more
sources. 

=head2 Calling conventions

All of the scripts conform to a standard calling convention that
allows us to be flexible in terms of how we specify the source files
and destination files. In particular, the first argument should always
be the source(s) and the second argument should always be the
destination(s). No constraints are made on the rest of the arguments.

  foo IN, OUT, ARGS

IN can be:

=over 4

=item * A file handle opened for reading.

=item * The name of a file to be opened for reading.

=item * undef, in which case *ARGV will be used. This allows scripts to
read from either STDIN or the files listed on the command line. Please
see L<perlopentut/Filters>.

=item * An array reference whose elements are one of the above types.

=back

OUT can be:

=over 4

=item * A file handle opened for writing.

=item * The name of a file to be opened for writing.

=item * undef, in which case STDOUT will be used.

=item * An array reference whose elements are one of the above types.

=back

ARGS can be a list of other arguments.

Suppose we have a script "foo" that reads from one file and writes to
another file. We could call this as:

  # Read from STDIN, write to STDOUT
  foo();

  # Read from "in.txt", write to "out.txt"
  foo("in.txt", "out.txt");

  # Read from $in, write to $out
  open my $in, "<", "in.txt";
  open my $out, ">", "out.txt";
  foo($in, $out);

=head2 Utility functions

These are some functions you can use to provide a consistent
command-line interface.

=over 4

=cut

use strict;
use warnings;
use autodie;

use subs qw(report _open_in _open_out _open_in_and_out);

use Getopt::Long;
use Pod::Usage;
use Log::Log4perl qw(:easy);

use Exporter 'import';
our %EXPORT_TAGS = 
  (scripts => [qw(
                   modify_fa_to_have_seq_on_one_line
                   modify_fasta_header_for_genome_seq_database
                   sort_genome_fa_by_chr
                   sort_gene_fa_by_chr
                   make_master_file_of_genes
                   fix_geneinfofile_for_neg_introns
                   sort_geneinfofile
                   make_ids_unique4geneinfofile
                   get_master_list_of_exons_from_geneinfofile
                   sort_gene_info
                   make_fasta_files_for_master_list_of_genes
                )]);

our @EXPORT_OK = qw(get_options
                    show_usage);
Exporter::export_ok_tags('scripts');

use RUM::ChrCmp qw(cmpChrs sort_by_chromosome);

=item get_options OPTIONS

Delegates to GetOptions, providing the given OPTIONS hash along with
some defaults that handle --help or -h options by printing out a
verbose usage message based on the running program's Pod.

=cut

sub get_options {
  my %options = @_;
  $options{"help|h"} ||= sub {
    pod2usage { -verbose => 2 }};
  return GetOptions(%options);
}

=item show_usage

Print a usage message based on the running script's Pod and exit.

=cut

sub show_usage {
  pod2usage { 
    -message => "Please see perldoc $0 for more information",
    -verbose => 1 };
}


=back

=head2 Scripts

These are the file processing scripts provided by this module.

=over 4

=item modify_fa_to_have_seq_on_one_line IN, OUT

Modify a fasta file to have the sequence all on one line. Reads from
IN and writes to OUT

=cut
sub modify_fa_to_have_seq_on_one_line {

  my ($in, $out) = _open_in_and_out(@_);

  my $flag = 0;
  while(defined(my $line = <$in>)) {
    # TODO: Using ^ anchor seems to save 15%; 61 to 53 seconds for cow
    if($line =~ />/) {
      if($flag == 0) {
        print $out $line;
        $flag = 1;
      } else {
        print $out "\n$line";
      }
    } else {
      chomp($line);
      $line = uc $line;
      print $out $line;
    }
  }
  print $out "\n";
}

=item modify_fasta_header_for_genome_seq_database IN, OUT

Transform each line in IN and write to OUT, changing any
fasta header lines that look like:

    >hg19_ct_UserTrack_3545_+ range=chrUn_gl000248:1-39786 ...

to look like:

    >chrUn_gl000248

=cut
sub modify_fasta_header_for_genome_seq_database {
  my ($in, $out) = _open_in_and_out(@_);
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

=item sort_genome_fa_by_chr IN, OUT

Expects an input file containing FASTA data, where adjacent sequence
lines are all concatenated together in a long line. Sorts the entries
in the file by chromosome.

=cut

sub sort_genome_fa_by_chr {
  my ($in, $out) = _open_in_and_out(@_);

  my %hash;
  report "Reading in genome";
  while (defined (my $line = <$in>)) {
    chomp($line);
    $line =~ /^>(.*)$/;
    my $chr = $1;
    $line = <$in>;
    chomp($line);
    $hash{$chr} = $line;
  }

  report "Sorting chromosomes";
  my @chromosomes = sort_by_chromosome keys %hash;
  
  report "Printing output";
  foreach my $chr (@chromosomes) {
    print $out ">$chr\n$hash{$chr}\n";
  }
}

=item sort_gene_fa_by_chr IN, OUT

Sort a gene FASTA file by chromosome, then start and end position,
then gene name (I think). Reads from IN and writes to OUT.

=cut
sub sort_gene_fa_by_chr {
  my ($in, $out) = _open_in_and_out(@_);

  my %hash;
  my %seq;

  while (defined (my $line = <$in>)) {
    chomp($line);
    $line =~ /^>(.*):([^:]+):(\d+)-(\d+)_.$/ or die "Expected header line, got $line";
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
  
  foreach my $chr (sort_by_chromosome keys %hash) {

    # TODO: Document this?
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

=item read_files_file FILES_FILE

Read entries from the gene_info_file and return them as a list.

=cut

sub read_files_file {
  my ($filesfile) = @_;

  my @files;
  while(defined (my $file = <$filesfile>)) {
    chomp($file);
    push @files, $file;
  }
  return @files;
}

=item make_master_file_of_genes FILES_FILE

Reads in one or more files containing gene info and merges them
together. For records that exist in both files, we merge the records
together and append the names used in both files.

=cut

sub make_master_file_of_genes {
  my ($filesfile, $outfile) = _open_in_and_out(@_);

  my $total = 0;

  my %geneshash;

  my @files = read_files_file($filesfile);

  for my $file (@files) {
    report "processing $file";
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
    report "$cnt lines in file\n";
    $total += $cnt;
  }
  report "TOTAL: $total\n";
  
  foreach my $geneinfo (keys %geneshash) {
    print $outfile "$geneinfo\t$geneshash{$geneinfo}\n";
  }
  
}



=item fix_geneinfofile_for_neg_introns IN, OUT, STARTS_COL, ENDS_COL, EXON_COUNT_COL

Takes a UCSC gene annotation file (IN) and outputs a file that removes
introns of zero or negative length.  You'd think there shouldn't be
such introns but for some annotation sets there are.

STARTS_COL is the column with the exon starts, ENDS_COL is the
column with the exon ends.  These are counted starting from zero.
EXON_COUNT_COL is the column that has the number of exons, also
counted starting from zero.  If there is no such column, set this to
-1.

=cut

sub fix_geneinfofile_for_neg_introns {
  my ($infile, $outfile, $starts_col, $ends_col, $exon_count_col) = _open_in_and_out(@_);

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

=item sort_geneinfofile IN, OUT

Sorts an annotated gene file first by chromosome, then by start exons,
then by end exons.

=cut

sub sort_geneinfofile {
  my ($infile, $outfile) = _open_in_and_out(@_);
  my (%start, %end, %chr);
  while (defined (my $line = <$infile>)) {
    chomp($line);
    my @a = split(/\t/,$line);
    $start{$line} = $a[2];
    $end{$line} = $a[3];
    $chr{$line} = $a[0];
  }

  foreach my $line (sort {
    $chr{$a}   cmp $chr{$b} || 
    $start{$a} <=> $start{$b} ||
    $end{$a}   <=> $end{$b}
  } keys %start) {
    print $outfile "$line\n";
  }
}

=item make_ids_unique4geneinfofile IN, OUT

TODO: Document me.

=cut

sub make_ids_unique4geneinfofile {
  my ($in, $out) = _open_in_and_out(@_);
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


=item get_master_list_of_exons_from_geneinfofile IN, OUT

Read in the gene info file from IN and print out one exon per line to
OUT.

=cut

sub get_master_list_of_exons_from_geneinfofile {
  my ($in, $out) = _open_in_and_out(@_);

  my %EXONS;
  my $_;

  while (defined (my $line = <$in>)) {
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
    print $out "$_\n";
  }
}

################################################################################
#
# Everything between here and the next #### line has to do with
# make_fasta_files_for_master_list_of_genes. This could probably use a
# bit of refactoring.


=item make_fasta_files_for_master_list_of_genes GENOME_FASTA_IN, EXON_IN, GENE_IN, GENE_INFO_OUT, GENE_FASTA_OUT

TODO: Describe me.

=cut

sub make_fasta_files_for_master_list_of_genes {
  report "In make fasta files";
  my ($ins, $outs) = _open_in_and_out(@_);

  report "Opened stuff";
  my ($genome_fasta, $exon_in, $gene_in) = @$ins;
  my ($final_gene_info, $final_gene_fasta) = @$outs;

  # Note: fasta file $ARGV[0] must have seq all on one line

  my %chromosomes_in_genome;
  my %chromosomes_from_exons;

  while (defined (my $line = <$genome_fasta>)) {
    
    # Read a header line
    chomp($line);
    $line =~ />(.*)/;
    my $chr = $1;
    report "processing $chr\n";
    $chromosomes_in_genome{$chr}++;

    # Read a sequence line
    $line = <$genome_fasta>;
    chomp($line);
    my $seq = $line;

    # Get the exons for this chromosome / sequence
    my $exons = get_exons($exon_in, $chr, $seq, \%chromosomes_from_exons);
    report "done with exons for $chr; starting genes\n";
  
    # Get the genes for this chromosome / sequence
    print_genes($gene_in, $final_gene_fasta, $chr, $seq, $exons);
    report "done with genes for $chr\n";
  }
  
  remove_genes_with_missing_sequence($gene_in,
                                     $final_gene_info,
                                     \%chromosomes_from_exons, \%chromosomes_in_genome);
}

=item remove_genes_with_missing_sequence GENE_INFO_IN, FINAL_GENE_INFO, FROM_EXONS, IN_GENOME

TODO: document me

=cut

sub remove_genes_with_missing_sequence {

  my ($gene_info_in, $final_gene_info, $from_exons, $in_genome) = @_;

  my $_;
  my @missing = grep { $in_genome->{$_} + 0 == 0 } keys %$from_exons;

  seek $gene_info_in, 0, 0;
  my $pattern = join("|", map { "($_)" } @missing);
  my $regex = qr/$pattern/;
  report "I am missing these genes: @missing";
  while (defined (my $line = <$gene_info_in>)) {
    unless (@missing and /$regex/) {
      print $final_gene_info $line;
    }
  }
}

=item get_exons EXON_IN_FILE, CHROMOSOME, SEQUENCE, CHROMOSOMES_HASH

Read the chromosome names and exon positions from EXON_IN_FILE and
return a hash mapping "<chromosome-name>:<start>-<end>" to appropriate
substring of SEQUENCE, where chromosome-name eq CHROMOSOME. Populate
keys of CHROMOSOMES_HASH as the set of all chromosomes seen in
EXON_IN_FILE.

=cut

sub get_exons {
  my ($exon_in_file, $chr, $seq, $chromosomes_hash) = @_;
  my $_;
  my %exons;

  while (<$exon_in_file>) {
    chomp;
    # Find the chromosome name, start, and end points
    my ($CHR, $START, $END) = /(.*):(\d+)-(\d+)/g;
    $chromosomes_hash->{$CHR}++;
    if($CHR eq $chr) {
      my $EXONSEQ = substr($seq,$START-1,$END-$START+1);
      $exons{$_} = $EXONSEQ;
    }
  }

  return \%exons;
}

=item print_genes GENE_IN_FILE, OUT, CHR, SEQ, EXONS

Read genes from GENE_IN_FILE and write to OUT.

TODO: More.

=cut

sub print_genes () {
  my ($gene_in_file, $out, $chr, $seq, $exons) = @_;

  while(defined (my $line2 = <$gene_in_file>)) {
    chomp($line2);

    # TODO: Split the line into fields and assign the fields to vars
    # right away.

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
      print $out ">$a[7]:$CHR:$a[2]-$a[3]_$a[1]\n";

      my $SEQ;
      if($a[1] eq '-') {
        $SEQ = &reversecomplement($GENESEQ);
      } else {
        $SEQ = $GENESEQ;
      }
      print $out "$SEQ\n";
    }
  }

}

=item reversecomplement SEQUENCE

Return the reverse complement of SEQUENCE.

=cut

sub reversecomplement {

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

################################################################################


=item sort_gene_info IN, OUT

Sorts a gene info file.

=cut
sub sort_gene_info {
  my ($in, $out) = _open_in_and_out(@_);
  my %hash;
  while (defined (my $line = <$in>)) {
    chomp($line);
    my @a = split(/\t/,$line);
    my $chr = $a[0];
    my $start = $a[2];
    my $end = $a[3];
    my $name = $a[7];
    $hash{$chr}{$line}[0] = $start;
    $hash{$chr}{$line}[1] = $end;
    $hash{$chr}{$line}[2] = $name;
  }
  
  foreach my $chr (sort {cmpChrs($a,$b)} keys %hash) {
    foreach my $line (sort {$hash{$chr}{$a}[0]<=>$hash{$chr}{$b}[0] || ($hash{$chr}{$a}[0]==$hash{$chr}{$b}[0] && $hash{$chr}{$a}[1]<=>$hash{$chr}{$b}[1]) || ($hash{$chr}{$a}[0]==$hash{$chr}{$b}[0] && $hash{$chr}{$a}[1]==$hash{$chr}{$b}[1] && $hash{$chr}{$a}[2] cmp $hash{$chr}{$b}[2])} keys %{$hash{$chr}}) {
      chomp($line);
      if($line =~ /\S/) {
        print $out $line;
        print $out "\n";
      }
    }
  }
}

=back

=head2 Private-ish subs

=over 4

=item _open_in IN

Attempt to open IN for reading. If it's already an open filehandle,
just return it. If it's a filename, open that file. If it's undef,
return *ARGV. If it's an array reference, open each element of the
array.

=cut

sub _open_in {
  my ($in) = @_;
  if (ref($in) and ref($in) =~ /^ARRAY/) {
    my @in = @$in;
    my @result;
    for my $file (@$in) {
      push @result, _open_in($file);
    }
    return \@result;
  }
  elsif (ref($in) =~ /GLOB/) {
    return $in;
  } elsif (defined $in) {
    open my $from, "<", $in or die "Can't open $in for reading: $!";
    return $from;
  } else {
    return *ARGV;
  }
}


=item _open_out OUT

Attempt to open OUT for writing. If it's already an open filehandle,
just return it. If it's a filename, open that file. If it's undef,
return *STDOUT. If it's an array reference, open each element of the
array.q

=cut

sub _open_out {
  my ($out) = @_;
  if (ref($out) =~ /^ARRAY/) {
    my @out = @$out;
    my @result;
    for my $file (@$out) {
      push @result, _open_out($file);
    }
    return \@result;
  }
  elsif (ref($out) =~ /GLOB/) {
    return $out;
  } elsif (defined $out) {
    open my $to, ">", $out or die "Can't open $out for writing: $!";
    return $to;
  } else {
    return *STDOUT;
  }
}

=item open_ins_and_outs IN, OUT

=cut

sub _open_in_and_out {
  my ($in, $out, @args) = @_;
  return (_open_in($in), _open_out($out), @args);
}

=item report MSG

Log the given message at the info level with indentation.

=cut

sub report {
  INFO "  @_";
}


=back

=head1 AUTHOR

Written by Gregory R. Grant, University of Pennsylvania, 2010

=cut


1;
