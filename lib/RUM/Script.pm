package RUM::Script;

use strict;
no warnings;

use RUM::Common qw(reversecomplement);
use RUM::Logging;

our $log = RUM::Logging->get_logger();

=pod

=head1 NAME

RUM::Script - Common utilities for command-line programs

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


use subs qw(_open_in _open_out _open_in_and_out);
use Carp;
use Getopt::Long;
use Pod::Usage;

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

use RUM::Sort qw(cmpChrs by_chromosome);

=item get_options OPTIONS

Delegates to GetOptions, providing the given OPTIONS hash along with
some defaults that handle --help or -h options by printing out a
verbose usage message based on the running program's Pod.

=cut

sub get_options {
    shift if ($_[0] eq __PACKAGE__);
    my %options = @_;
    $options{"help|h"} ||= sub {
        pod2usage { -verbose => 2 }};
    return GetOptions(%options);
}

=item show_usage

Print a usage message based on the running script's Pod and exit.

=cut

sub show_usage {
  return pod2usage { 
    -message => "Please run $0 -h for more information\n",
    -verbose => 1 };
}

=back

=head2 Scripts

These are the file processing scripts provided by this module.

=over 4

=item modify_fa_to_have_seq_on_one_line IN, OUT

Modify a fasta file to have the sequence all on one line. Reads from
IN and writes to OUT

TODO: Perhaps we should provide an abstraction on top of the fasta
file format, so we don't need to have the sequence all on one line. It
would be easy to write a fasta parser, or we could use BioPerl.

=cut

sub modify_fa_to_have_seq_on_one_line {
  my @args = @_;

  my ($in, $out) = _open_in_and_out(@args);

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
  my @args = @_;
  my ($in, $out) = _open_in_and_out(@args);
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

TODO: We are currently storing the whole FASTA file in memory while we
sort it. This can take up a lot of space. Instead of sorting the fasta
file, we could do one of the following:

=over 4

=item *

Store the sequences in some file-backed structure like a tied hash
keyed on chromosome name.

=item *

Create an index into the fasta file, so we know the start location of
each chromosome.

=item *

Use BioPerl's Bio::Index::Fasta package, which provides an indexed
view into fasta files.

=back

=cut

sub sort_genome_fa_by_chr {
  my @args = @_;
  my ($in, $out) = _open_in_and_out(@args);
  
  my %hash;
  $log->debug("Reading in genome");
  while (defined (my $line = <$in>)) {
    chomp($line);
    $line =~ /^>(.*)$/ or croak "Expected header line, got $line";
    my $chr = $1;
    $line = <$in>;
    chomp($line);
    $hash{$chr} = $line;
  }

  $log->debug("Sorting chromosomes");
  my @chromosomes = sort by_chromosome keys %hash;
  
  $log->debug("Printing output");
  foreach my $chr (@chromosomes) {
    print $out ">$chr\n$hash{$chr}\n";
  }
}

=item sort_gene_fa_by_chr IN, OUT

Sort a gene FASTA file by chromosome, then start and end position,
then gene name (I think). Reads from IN and writes to OUT.

=cut
sub sort_gene_fa_by_chr {
  my @args = @_;
  my ($in, $out) = _open_in_and_out(@args);
  $log->info("Sorting gene fasta by chr");

  my %hash;
  my %seq;

  while (defined (my $line = <$in>)) {
    chomp($line);
    my ($name, $chr, $start, $end) = $line =~ /^>(.*):([^:]+):(\d+)-(\d+)_.$/ 
      or croak "Expected header line, got $line";

    $hash{$chr}{$line}[0] = $start;
    $hash{$chr}{$line}[1] = $end;
    $hash{$chr}{$line}[2] = $name;
    my $SEQ = <$in>;
    chomp($SEQ);
    $seq{$line} = $SEQ;
  }
  
  foreach my $chr (sort by_chromosome keys %hash) {

    foreach my $line (sort {
      $hash{$chr}{$a}[0] <=> $hash{$chr}{$b}[0] || 
      $hash{$chr}{$a}[1] <=> $hash{$chr}{$b}[1] || 
      $hash{$chr}{$a}[2] cmp $hash{$chr}{$b}[2]
    } keys %{$hash{$chr}}) {
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

=item make_master_file_of_genes INS, OUT, TYPES

Reads from one or more files containing gene info and merges them
together. For records that exist in both files, we merge the records
together and append the names used in both files.

INS must be a reference to an array of gene info files.

We write a single merged table to OUT.

TYPES must be a reference to an array with the same length as INS;
each element should be a string that can describes type type of the
corresponding file in INS.

For example:

  _make_master_file_of_genes_impl(["refseq.txt", "ensemble.txt"],
                                  "merged.txt",
                                  ["refseq", "ensembl"]);

=cut

sub _make_master_file_of_genes_impl {
  my @args = @_;
  my ($ins, $out, $types) = _open_in_and_out(@args);
  my @ins = @$ins;
  my @types = @$types;
  my %geneshash;
  my $total;
  while (my $in = shift(@ins)) {
    my $type = shift @types;
    my $line = <$in>;
    chomp($line);
    my @header = split(/\t/,$line);
    my $n = @header;

    my ($namecol, $chromcol, $strandcol, $exonStartscol, $exonEndscol);

    # TODO: Maybe use a standard tab file parser?
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
    while(defined (my $line = <$in>)) {
      chomp($line);
      
      # Skip comments
      next if($line =~ /^#/);

      my @a = split(/\t/,$line);
      $a[$namecol] =~ s/\(/-/g;
      $a[$namecol] =~ s/\)/-/g;
      $a[$exonStartscol] =~ /^(\d+)/ 
        or croak "Expected a number in the exon starts col. Bad input is '$line' on line $.";
      my $txStart = $1;
      $a[$exonEndscol] =~ /(\d+),?$/
        or croak "Expected a number in the exon ends col";
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
    $log->debug("$cnt lines in file");
    $total += $cnt;
  }
  $log->debug("TOTAL: $total\n");
  
  foreach my $geneinfo (keys %geneshash) {
    print $out "$geneinfo\t$geneshash{$geneinfo}\n";
  }  
}

=item make_master_file_of_genes FILES_FILE, OUT

Reads in one or more files containing gene info and merges them
together. For records that exist in both files, we merge the records
together and append the names used in both files.

FILES_FILE should be a file that contains a list of filenames, each of
which is a gene info file with five columns: name, chromosome, strand,
exon starts, and exon ends.

Writes a single merged table to OUT.

=cut


sub make_master_file_of_genes {
  my @args = @_;
  my ($filesfile, $out) = _open_in_and_out(@args);

  my @ins = read_files_file($filesfile);
  my @types = map {
    (/(.*).txt$/ and $1) 
      or croak "Files listed in gene_info_file should end with .txt";
  } @ins;

  return _make_master_file_of_genes_impl(\@ins, $out, \@types);  
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
  my @args = @_;
  my ($in, $out, $starts_col, $ends_col, $exon_count_col) = 
    _open_in_and_out(@args);

  while (defined (my $line = <$in>)) {

    chomp($line);
    my @row = split(/\t/, $line);
    my $starts = $row[$starts_col];
    my $ends = $row[$ends_col];

    # Make sure the starts, ends, and exon_counts columns are
    # populated
    if(!($starts =~ /\S/)) {
      croak "ERROR: the 'starts' column has empty entries\n";
    }
    if(!($ends =~ /\S/)) {
      croak "ERROR: the 'ends' column has empty entries\n";
    }
    if(!(($row[$exon_count_col]||"") =~ /\S/)) {
      croak "ERROR: the 'exon counts' column has empty entries\n";
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
      my $realstart    = $E[$i-1] + 1;
      my $realend      = $S[$i];
      my $length       = $realend - $realstart + 1;
      if($length > 0) {
        $start_string = $start_string . $S[$i] . ",";
        $end_string = $end_string . $E[$i-1] . ",";
      }
      else {
        #           print $out "$line\n";
        if($exon_count_col >= 0) {
          $row[$exon_count_col]--;
        }
      }
    }

    $end_string = $end_string . $E[$N-1] . ",";;
    $row[$starts_col] = $start_string;
    $row[$ends_col] = $end_string;

    print $out join("\t", @row) . "\n";
  }
  
}

=item sort_geneinfofile IN, OUT

Sorts an annotated gene file first by chromosome, then by start exons,
then by end exons.

=cut

sub sort_geneinfofile {
  my @args = @_;
  my ($infile, $outfile) = _open_in_and_out(@args);
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
  my @args = @_;
  my ($in, $out) = _open_in_and_out(@args);
  my (%idcount, %typecount);

  while (defined (my $line = <$in>)) {
    chomp($line);
    my @a = split(/\t/,$line);
    my @b = split(/::::/,$a[7]);
    
    # Count the number of rows with the current id and type
    for(my $i=0; $i<@b; $i++) {
      $b[$i] =~ /(.*)\(([^\)]+)\)$/ or croak "Invalid gene name $b[$i]";
      my $id = $1;
      my $type = $2;
      $id =~ s/.*://;
      $id =~ s/\(.*//;
      $idcount{$type}{$id}++;
      $typecount{$id}{$type}++;
    }
  }
  
  # Rewind to the front of the file; we need to make a second pass
  # through it.
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
      $b[$i] =~ /(.*)\(([^\)]+)\)$/ or croak "Invalid gene name $b[$i]";
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
OUT. IN must have the chromosome name in the 0th column and the start
and end points in the 5th and 6th column (starting column numbering at
0).

Increments the start position before printing the exon line.

TODO: Rather than create a temp file containing this master list of
exons, I think it would be better to read it into a data structure and
keep it in memory. It's not very big compared to the other files that
we're keeping in memory anyway. If it does turn out to be too large,
we can easily convert it to a tied hash.

=cut

sub get_master_list_of_exons_from_geneinfofile {
  my @args = @_;
  my ($in, $out) = _open_in_and_out(@args);
  my %EXONS;

  while (defined (my $line = <$in>)) {
    chomp($line);

    # Fields 5 and 6 are exon starts and ends. Trim leading and
    # trailing whitespace and commas, and split on comma.
    my @a = split(/\t/,$line);
    $a[5]=~ s/\s*,\s*$//;
    $a[5]=~ s/^\s*,\s*//;
    $a[6]=~ s/\s*,\s*$//;
    $a[6]=~ s/^\s*,\s*//;
    my @S = split(/,/,$a[5]);
    my @E = split(/,/,$a[6]);
    my $N = @S;

    # For each of the start and end points, add a line like
    # "$chr:$start-$end".
    for (my $e=0; $e<@S; $e++) {
      $S[$e]++;
      my $exon = "$a[0]:$S[$e]-$E[$e]";
      $EXONS{$exon}++;
    }
  }

  for my $key (keys %EXONS) {
    print $out "$key\n";
  }
}

################################################################################
#
# Everything between here and the next #### line has to do with
# make_fasta_files_for_master_list_of_genes. This could probably use a
# bit of refactoring.


=item make_fasta_files_for_master_list_of_genes GENOME_FASTA_IN, EXON_IN, GENE_IN, GENE_INFO_OUT, GENE_FASTA_OUT

=over 4

=item GENOME_FASTA_IN

 must be a fasta file that contains an entry for each chromosome.

=item EXON_IN 

must be a file produced by get_master_list_of_exons_from_geneinfofile;
each line should be formatted like "<chromosome>:<start>-<end>".

=item GENE_IN

must be a tab-delimited file containing the chromosome, strand, gene
start, gene end, ?, exon starts, exon ends, and id fields (in order).

=item GENE_INFO_OUT

We write a gene info file here 

=back

=cut

sub make_fasta_files_for_master_list_of_genes {
  my @args = @_;
  my ($ins, $outs) = _open_in_and_out(@args);

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
    $log->debug("processing $chr\n");
    $chromosomes_in_genome{$chr}++;

    # Read a sequence line
    $line = <$genome_fasta>;
    chomp($line);

    # Get the exons for this chromosome / sequence
    seek $exon_in, 0, 0;
    my $exons = get_exons($exon_in, $chr, $line, \%chromosomes_from_exons);
    $log->debug("Got " . scalar(keys(%$exons)) . " exons for $chr; starting genes\n");

    # Get the genes for this chromosome / sequence
    seek $gene_in, 0, 0;
    print_genes($gene_in, $final_gene_fasta, $chr, $exons);
    $log->debug("done with genes for $chr\n");
  }
  
  my @chromosomes_from_exons = keys %chromosomes_from_exons;
  remove_genes_with_missing_sequence($gene_in,
                                     $final_gene_info,
                                     \@chromosomes_from_exons, \%chromosomes_in_genome);
}

=item remove_genes_with_missing_sequence GENE_INFO_IN, FINAL_GENE_INFO, FROM_EXONS, IN_GENOME

TODO: document me

=cut

sub remove_genes_with_missing_sequence {

  my ($gene_info_in, $final_gene_info, $from_exons, $in_genome) = @_;

  local $_;
  my @missing = grep { not exists $in_genome->{$_} } @$from_exons;

  seek $gene_info_in, 0, 0;
  my $pattern = join("|", map("($_)", @missing));
  my $regex = qr/$pattern/;
  $log->debug("I am missing these genes: @missing, pattern is $pattern\n");
  while (defined($_ = <$gene_info_in>)) {
    print $final_gene_info $_ unless @missing && /$regex/;
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
  local $_;
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

=item print_genes GENE_IN_FILE, OUT, CHR, EXONS

Read genes from GENE_IN_FILE and write to OUT.

EXONS must be a hash mapping "<chromosome-name>:<start>-<end>" to a
sequence.

TODO: More.

=cut

sub print_genes {
  my ($gene_in_file, $out, $chr, $exons) = @_;

  while(defined (my $line2 = <$gene_in_file>)) {
    chomp($line2);

    my ($CHR, $strand, $gene_start, $gene_end, undef, $starts, $ends, $id) 
      = split(/\t/,$line2);

    # Trim trailing commas from the exon starts and ends and split
    # them
    $starts =~ s/\s*,\s*$//;
    $ends =~ s/\s*,\s*$//;
    my @STARTS = split(/,/,$starts);
    my @ENDS = split(/,/,$ends);

    if ($CHR eq $chr) {

      # Concatenate together all the exons for this gene.
      my $GENESEQ = "";
      for(my $i=0; $i<@STARTS; $i++) {
        my $s = $STARTS[$i] + 1;  # add one because of the pesky zero based ucsc coords
        my $e = $ENDS[$i];  # don't add one to the end, because of the pesky half-open based ucsc coords
        my $ex = "$CHR:$s-$e";
        my $exon_seq = $exons->{$ex};
        if ($exon_seq and $exon_seq =~ /\S/) {
          $GENESEQ = $GENESEQ . $exons->{$ex};
        }
        else {
          croak "ERROR: exon for $ex not found.\n$line2\ni=$i\n";
        }
      }

      # Print the header, using only the first one of the gene
      # ids. TODO: why only the first id for this gene?
      $id =~ s/::::.*//;
      $id =~ s/\([^\(]+$//;
      print $out ">$id:$CHR:${gene_start}-${gene_end}_$strand\n";

      my $SEQ;
      if($strand eq '-') {
        $SEQ = &reversecomplement($GENESEQ);
      } else {
        $SEQ = $GENESEQ;
      }
      print $out "$SEQ\n";
    }
  }

}

################################################################################


=item sort_gene_info IN, OUT

Sorts a gene info file.

=cut
sub sort_gene_info {
  my @args = @_;
  my ($in, $out) = _open_in_and_out(@args);
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
  
  foreach my $chr (sort cmpChrs keys %hash) {
    foreach my $line (sort {
      $hash{$chr}{$a}[0] <=> $hash{$chr}{$b}[0] || 
      $hash{$chr}{$a}[1] <=> $hash{$chr}{$b}[1] || 
      $hash{$chr}{$a}[2] cmp $hash{$chr}{$b}[2]
    } keys %{$hash{$chr}}) {
      chomp($line);
      if($line =~ /\S/) {
        print $out $line . "\n";
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
  if (ref($in) =~ /^ARRAY/) {
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
    open my $from, "<", $in or croak "Can't open $in for reading: $!";
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
    open my $to, ">", $out or croak "Can't open $out for writing: $!";
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


=item run_with_logging($script)

Call the main() method on the script with the given name, wrapping the
call in logging messages that indicate when the script is starting and
stopping. For example:

  RUM::Script->run_with_logging("RUM::Script:MergeSortedRumFiles")

Will print a message indicating that the script is starting, then call
RUM::Script::MergeSortedRumFiles->main(), then log a message saying
that the script has finished.

If we catch an error while the main method is running, we log the
message.

=cut

sub run_with_logging {
    my ($class, $script) = @_;
    my @parts = split /\:\:/, $script;
    my $path = join("/", @parts) . ".pm";

    my $cmd =  "$0 @ARGV";
    my $log = RUM::Logging->get_logger("RUM.ScriptRunner");

    require $path;
    eval {
	$script->main();
    };
    if ($@) {
      if (ref($@) && ref($@) =~ /RUM::UsageErrors/) {
	my $errors = $@;
	pod2usage({
		   -verbose => 1,
		   -exitval => "NOEXIT"
		  });
	my $msg = "Usage errors:\n\n";
	for my $error ($errors->errors) {
	  chomp $error;
	  $msg .= "  * $error\n";
	}
	die $msg;
      }
      else {
	die $@;
      }
    }
}

=item import_scripts_with_logging

Import all the script methods into the current package, wrapping them
in code that prints out a message before and after the script runs.

=cut


sub import_scripts_with_logging {
  my @names = @{$RUM::Script::EXPORT_TAGS{scripts}};
  for my $name (@names) {
    no strict "refs";
    my $long_name = "RUM::Script::$name";
    my $new_name  = "main::$name";
    *{$new_name} = sub {
      my @args = @_;
      warn "START $name @args";
      &$long_name(@args);
      warn "END $name @args";
    };
  }
}


=back

=head1 AUTHOR

Mike DeLaurentis (delaurentis@gmail.com)

=head1 COPYRIGHT

Copyright 2012 University of Pennsylvania

=cut

1;
