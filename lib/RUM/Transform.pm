package RUM::Transform;

use strict;
use warnings;

use Exporter 'import';
use Getopt::Long;
use Log::Log4perl qw(:easy);
our @EXPORT_OK = qw(transform_file require_argv get_options);

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


=item with_timing($msg, $code)

$msg should be a message string and $code should be a CODE ref. Logs a
start message, then runs $code->(), then logs a stop message
indicating how long $code->() took.

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


=item transform_file($function, [$in, [$out, [@args]]])

Opens the files identified by $in and $out in a sensible way
and then calls $function, passing in the opened input file, output
file, and any extra @args that were supplied.

$function should be a reference to a subroutine that takes two open
filehandles as its first two arguments, reading from the first one and
writing to the second one. It may also take additional args.

$in should either be a file handle opened for reading, a string
naming a file, or undef. If it's already a file handle, we just pass
it to $function. If it's a filename, we open it. If it's undef, we'll
use *ARGV, which will read from all the files listed in @ARGV or from
STDIN if @ARGV is empty.

$out should either be a file handle opened for writing, a string
naming a file, or undef. If it's already a file handle, we just pass
it to $function. If it's a filename, we open it. If it's undef, we use
*STDOUT.

Any extra args will be passed on to the function.

=cut

sub transform_file {
  my ($function, $in, $out, @args) = @_;

  my ($from, $to);

  if (ref $in) {
    $from = $in;
  } elsif (defined $in) {
    open $from, "<", $in or die "Can't open $in for reading: $!";
  } else {
    $from = *ARGV;
  }

  if (ref $out) {
    $to = $out;
  } elsif (defined $out) {
    open $to, ">", $out or die "Can't open $out for writing: $!";
  } else {
    $to = *STDOUT;
  }

  with_timing "Transforming $in to $out with $function", sub {
    $function->($from, $to, @args);
  };
}

=item show_usage()

Print a usage message based on the running script's Pod and exit.

=cut

sub show_usage {
  pod2usage { 
    -message => "Please see perldoc $0 for more information",
    -verbose => 1 };
}

=item get_options(%options)

Delegates to GetOptions, providing the given %options hash along with
some defaults that handle --help or -h options by printing out a
verbose usage message based on the running program's Pod.

=item
sub get_options {
  my %options = @_;
  $options{"help|h"} ||= sub {
    pod2usage { -verbose => 2 }};
  return GetOptions(%options);
}

=back

=cut
