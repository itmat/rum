package RUM::Index;

use strict;
use warnings;

use FindBin qw($Bin);
use Exporter 'import';
use Pod::Usage;
use Log::Log4perl qw(:easy);
use RUM::ChrCmp qw(cmpChrs);

Log::Log4perl->easy_init($INFO);

our @EXPORT_OK = qw(modify_fa_to_have_seq_on_one_line
                    modify_fasta_header_for_genome_seq_database
                    sort_genome_fa_by_chr
                    fix_geneinfofile_for_neg_introns
                    transform_input
                    run_bowtie run_subscript
                    make_master_file_of_genes);

=pod

=head1 NAME

RUM::Common - Common utilities for RUM.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

  use RUM::Common qw(transform_input ...)

  # Run one of the file transformer functions on STDIN and STDOUT
  modify_fasta_header_for_genome_seq_database(*STDIN, *STDOUT)

  # or on a file listed on the command line
  modify_fasta_header_for_genome_seq_database($ARGV[0], *STDOUT)
  
  # or let transform_input do it for you. This will handle any errors
  # encountered while opening the input file, including displaying
  # usage information if the user didn't supply an input file.
  transform_input(\&modify_fasta_header_for_genome_seq_database)

=head1 DESCRIPTION

Provides some common utilities for creating indexes for RUM.

=cut

our %TRANSFORM_NAMES;

=head2 Subroutines

=over 4

=cut

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

# Populate %TRANSFORM_NAMES so that each key is a code ref and the
# corresponding value is the name of that function. This way we can
# print the name of a function given a reference to it.

{ 
  no strict "refs";
  for my $name (@EXPORT_OK) {
    my $long_name = "RUM::Index::$name";
    my $code = \&$long_name;
    $TRANSFORM_NAMES{$code} = $name;
  }
}


=item transform_input($infile_name, $function)

Opens the file identified by $ARGV[0] and applies $function to it
and the *STDOUT filehandle. $function should be a function that takes
two filehandles, reads from the first, and writes to the second.

This is just a convenience method so that scripts that want to
transform a file listed on the command line and write the transformed
output don't have to deal with opening files.

=cut
sub transform_input {
  my ($function, @args) = @_;

  die "Argument to transform_input must be a CODE reference: $function" 
    unless ref($function) =~ /^CODE/;
    
  my $function_name = $TRANSFORM_NAMES{$function};

  my ($infile_name) = @ARGV;

  pod2usage() unless @ARGV >= 1;
  open my ($infile), $infile_name;
  INFO "Running $function_name on $infile_name";
  my $start = time();
  $function->($infile, *STDOUT, @args);
  my $stop = time();
  my $elapsed = $stop - $start;
  INFO "Done in $elapsed seconds.";
}

=item run_bowtie(@args)

Runs bowtie-build with the following arguments. Checks the return
status and dies if it's non-zero.

=cut
sub run_bowtie {
  my @cmd = ("bowtie-build", @_);
  print "Running @cmd\n";
  system @cmd;
  $? == 0 or die "Bowtie failed: $!";
}

=item run_subscript($script, @args)

Runs perl on the given script with the given args. Checks the return
status and dies if it's non-zero.

=cut
sub run_subscript {
  my ($subscript, @args) = @_;
  my $cmd = "perl $Bin/$subscript @args";
  INFO "Running $cmd";
  system $cmd;
  my $stop = time();
  $? == 0 or die "Subscript failed: $!";
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
  my @chromosomes = sort { cmpChrs($a, $b) } keys %hash;
  
  INFO "Printing output";
  foreach my $chr (@chromosomes) {
    print $outfile ">$chr\n$hash{$chr}\n";
  }
}

sub _read_files_file {
  my ($filesfilename) = @_;
  open(my $filesfile, "<", $filesfilename);
  my @files;
  while(defined (my $file = <$filesfile>)) {
    INFO "processing $file";
    chomp($file);
    push @files, $file;
  }
  close $filesfile;
  return @files;
}

=item make_master_file_of_genes($filesfilename)

Reads in one or more files containing gene info and merges them
together. For records that exist in both files, we merge the records
together and append the names used in both files.

=cut

sub make_master_file_of_genes {
  my ($filesfilename) = @_;
  my $total = 0;

  open(my $filesfile, "<", $filesfilename);

  my %geneshash;

  my @files = _read_files_file($filesfilename);

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
    close($infile);
    INFO "$cnt lines in file\n";
    $total += $cnt;
  }
  close($filesfile);
  print STDERR "TOTAL: $total\n";
  
  foreach my $geneinfo (keys %geneshash) {
    print "$geneinfo\t$geneshash{$geneinfo}\n";
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
  print "I am here\n";
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

=back

=head1 AUTHORS

=over 4

=item Gregory R. Grant

=item Mike DeLaurentis

=item University of Pennsylvania, 2010

=back

=cut
return 1;
