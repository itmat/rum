package RUM::Common;
use strict;
use warnings;
use Pod::Usage;

use Exporter 'import';
our @EXPORT_OK = qw(modify_fa_to_have_seq_on_one_line transform_input);

=pod

=head1 RUM::Common

Common utilities for RUM.

=head2 Subs

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

=item transform_input($infile_name, $function)

Opens the file identified by $ARGV[0] and applies $function to it
and the *STDOUT filehandle. $function should be a function that takes
two filehandles, reads from the first, and writes to the second.

This is just a convenience method so that scripts that want to
transform a file listed on the command line and write the transformed
output don't have to deal with opening files.

=cut
sub transform_input {
  my $function = shift;
  my ($infile_name) = @ARGV;
  pod2usage() unless @ARGV == 1;
  open my ($infile), $infile_name;
  $function->($infile, *STDOUT);
}

=pod

=back

=cut
return 1;
