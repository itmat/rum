package RUM::Index;
use strict;
use warnings;
use Pod::Usage;
use Log::Log4perl qw(:easy);

use RUM::ChrCmp qw(cmpChrs);

Log::Log4perl->easy_init($INFO);

use FindBin qw($Bin);
use Exporter 'import';
our @EXPORT_OK = qw(modify_fa_to_have_seq_on_one_line
                    modify_fasta_header_for_genome_seq_database
                    sort_genome_fa_by_chr
                    transform_input
                    %transforms
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

Transform each line on $infile and write to $outfile, changing any fasta header lines that look like:

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

my %transforms = 
  (
   modify_fasta_header_for_genome_seq_database => \&modify_fasta_header_for_genome_seq_database,
   modify_fa_to_have_seq_on_one_line => \&modify_fa_to_have_seq_on_one_line,
   sort_genome_fa_by_chr => \&sort_genome_fa_by_chr
);


=item transform_input($infile_name, $function)

Opens the file identified by $ARGV[0] and applies $function to it
and the *STDOUT filehandle. $function should be a function that takes
two filehandles, reads from the first, and writes to the second.

This is just a convenience method so that scripts that want to
transform a file listed on the command line and write the transformed
output don't have to deal with opening files.

=cut
sub transform_input {
  my $function_name = shift;
  my $function = $transforms{$function_name} 
    or die "No transform called $function_name";
  my ($infile_name) = @ARGV;

  pod2usage() unless @ARGV == 1;
  open my ($infile), $infile_name;
  INFO "Running $function_name on $infile_name";
  my $start = time();
  $function->($infile, *STDOUT);
  my $stop = time();
  my $elapsed = $stop - $start;
  INFO "Done in $elapsed seconds.";
}

sub run_bowtie {
  my @cmd = ("bowtie-build", @_);
  print "Running @cmd\n";
  system @cmd;
  $? == 0 or die "Bowtie failed: $!";
}

sub run_subscript {
  my ($subscript, @args) = @_;
  my $cmd = "perl $Bin/$subscript @args";
  INFO "Running $cmd";
  system $cmd;
  my $stop = time();
  $? == 0 or die "Subscript failed: $!";
}

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
  my @chromosomes = sort cmpChrs keys %hash;
  
  INFO "Printing output";
  foreach my $chr (@chromosomes) {
    print $outfile ">$chr\n$hash{$chr}\n";
  }
}

sub read_files_file {
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

sub make_master_file_of_genes {
  my ($filesfilename) = @_;
  my $TOTAL = 0;

  open(my $filesfile, "<", $filesfilename);

  my %geneshash;

  my @files = read_files_file($filesfilename);

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

    my $CNT=0;
    while(defined (my $line = <$infile>)) {
      chomp($line);
      
      # Skip comments
      next if $line =~ /^#/;

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
      $CNT++;
    }
    close($infile);
    INFO "$CNT lines in file\n";
    $TOTAL = $TOTAL + $CNT;
  }
  close($filesfile);
  print STDERR "TOTAL: $TOTAL\n";
  
  foreach my $geneinfo (keys %geneshash) {
    print "$geneinfo\t$geneshash{$geneinfo}\n";
  }
  
}

=back

=head1 AUTHORS

=over

=item Gregory R. Grant

=item Mike DeLaurentis

=item University of Pennsylvania, 2010

=back

=cut
return 1;
