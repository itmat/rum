package RUM::Index;

use strict;
use warnings;

use FindBin qw($Bin);
use Exporter 'import';
use Pod::Usage;
use Log::Log4perl qw(:easy);
use RUM::ChrCmp qw(cmpChrs sort_by_chromosome);

Log::Log4perl->easy_init($INFO);

our @EXPORT_OK = qw(fix_geneinfofile_for_neg_introns
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

  open my $infile, $infile_name or die "Can't open $ARGV[0]: $!";
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
  close($infile);

  foreach my $line (sort {
    $chr{$a} cmp $chr{$b} || $start{$a}<=>$start{$b} || $end{$a}<=>$end{$b}} keys %start) {
    print $outfile "$line\n";
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
