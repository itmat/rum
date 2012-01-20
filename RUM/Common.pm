package RUM::Common;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(modify_fa_to_have_seq_on_one_line);

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

  $flag = 0;
  while($line = <$infile>) {
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


return 1;
