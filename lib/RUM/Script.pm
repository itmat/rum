package RUM::Script;

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use Log::Log4perl qw(:easy);

use Exporter 'import';
our %EXPORT_TAGS = 
  (scripts => [qw(modify_fa_to_have_seq_on_one_line)]);
our @EXPORT_OK = qw(get_options
                    show_usage);
Exporter::export_ok_tags('scripts');

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

sub _open_in {
  my ($in) = @_;
  if (ref($in) and ref($in) =~ /^ARRAY/) {
    INFO "Recurring on @$in\n";
    return [map &_open_in, @$in];
  }
  elsif (ref $in) {
    return $in;
  } elsif (defined $in) {
    open my $from, "<", $in or die "Can't open $in for reading: $!";
    return $from;
  } else {
    return *ARGV;
  }
}

=item _open_out OUT

If OUT is already a ref assume it's a writable file handle, otherwise
if it's defined try to open it, otherwise set it to STDOUT.

=cut

sub _open_out {
  my ($out) = @_;
  if (ref($out) =~ /^ARRAY/) {
    return map &_open_out, @$out;
  }
  elsif (ref $out) {
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

sub open_in_and_out {
  my ($in, $out) = @_;
  return (_open_in($in), _open_out($out));
}

=item modify_fa_to_have_seq_on_one_line IN, OUT

Modify a fasta file to have the sequence all on one line. Reads from
IN and writes to OUT

=cut
sub modify_fa_to_have_seq_on_one_line {

  my ($in, $out) = open_in_and_out(@_);

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

1;
