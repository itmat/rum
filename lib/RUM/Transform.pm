package RUM::Transform;

use strict;
use warnings;
use autodie;

use Exporter 'import';
use Getopt::Long;
use Log::Log4perl qw(:easy);
use Pod::Usage;
use RUM::Transform::Fasta;
use RUM::Transform::GeneInfo;
our @EXPORT_OK = qw(with_timing
                    transform_file
                    get_options 
                    show_usage);

Log::Log4perl->easy_init($INFO);

=pod

=head1 NAME

RUM::Transform - Common utilities for transforming files.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

  use RUM::Transform qw(with_timing
                        transform_file
                        show_usage
                        get_options);

  # Wrap some task with logging messages that indicate when it
  # started, when it stopped, and the elapsed seconds.
  with_timing "doing some task", sub {
    ...
  }

  # Apply a transformation function to STDIN or the files listed in
  # @ARGV and print the results to STDOUT.
  transform_file \&sort_genome_by_chromosome;

  # Apply a transformation function to a particular named file and
  # print results to STDOUT.
  transform_file  \&sort_genome_by_chromosome, "bos-taurus.fa";

  # Apply a transformation function to a particular named file and
  # print results to a named file.
  transform_file  \&sort_genome_by_chromosome, "bos-taurus.fa", "sorted.fa";

  # Apply a transformation to open filehandles
  open my $in, "bos-taurus.fa";
  open my $out, "bos-taurus.fa";
  transform_file  \&sort_genome_by_chromosome, $in, $out;

  # Exit, showing a usage message based on the Pod in the current
  # script.
  show_usage();

  # Get options via Getopt::Long, with --help and -h handled by
  # default.
  get_options(...);

=head1 DESCRIPTION

=head2 Subroutines

=over 4

=cut

our %TRANSFORMER_NAMES;

for my $package (qw(RUM::Transform::Fasta
                    RUM::Transform::GeneInfo)) {
  my $export_name = "${package}::EXPORT_OK";
  no strict "refs";
  for my $name (@$export_name) {
    my $longname = "${package}::${name}";
    my $coderef = \&$longname;
    $TRANSFORMER_NAMES{$coderef} = $name;
  }
}

=item with_timing MSG, CODE

MSG should be a message string and $code should be a CODE ref. Logs a
start message, then runs CODE->(), then logs a stop message
indicating how long CODE->() took.

=cut

sub with_timing {
  my ($msg, $code) = @_;
  INFO "Starting $msg";
  my $start = time();
  $code->();
  my $elapsed = time() - $start;
  INFO "Done $msg in $elapsed seconds";
  return $elapsed;
}

=item transform_file FUNCTION

=item transform_file FUNCTION, IN

=item transform_file FUNCTION, IN, OUT

=item transform_file FUNCTION, IN, OUT, ARGS

Opens the files identified by IN and OUT in a sensible way
and then calls FUNCTION, passing in the opened input file, output
./file, and any extra ARGS that were supplied.

FUNCTION should be a reference to a subroutine that takes two open
filehandles as its first two arguments, reading from the first one and
writing to the second one. It may also take additional args.

IN should either be a file handle opened for reading, a string
naming a file, or undef. If it's already a file handle, we just pass
it to FUNCTION. If it's a filename, we open it. If it's undef, we'll
use *ARGV, which will read from all the files listed in @ARGV or from
STDIN if @ARGV is empty.

OUT should either be a file handle opened for writing, a string
naming a file, or undef. If it's already a file handle, we just pass
it to FUNCTION. If it's a filename, we open it. If it's undef, we use
*STDOUT.

Any extra args will be passed on to the function.

=cut

sub transform_file {
  my ($function, $in, $out, @args) = @_;

  my ($from, $to);

  # If $in is already a ref assume it's a readable file handle,
  # otherwise if it's defined try to open it, otherwise just set it so
  # that it will read from either the files listed in @ARGV or STDIN
  if (ref $in) {
    $from = $in;
  } elsif (defined $in) {
    open $from, "<", $in or die "Can't open $in for reading: $!";
  } else {
    $from = *ARGV;
  }

  # If $out is already a ref assume it's a writable file handle,
  # otherwise if it's defined try to open it, otherwise set it to
  # STDOUT.
  if (ref $out) {
    $to = $out;
  } elsif (defined $out) {
    open $to, ">", $out or die "Can't open $out for writing: $!";
  } else {
    $to = *STDOUT;
  }

  # Get names for IN, OUT, and FUNCTION so we can log a message
  $in = "ARGV" unless $in;
  $out = "STDOUT" unless $out;
  my $name = $TRANSFORMER_NAMES{$function} || "unknown function";

  with_timing "Transforming $in to $out with $name", sub {
    $function->($from, $to, @args);
  };
}

=item show_usage

Print a usage message based on the running script's Pod and exit.

=cut

sub show_usage {
  pod2usage { 
    -message => "Please see perldoc $0 for more information",
    -verbose => 1 };
}

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

=back

=cut

1;
