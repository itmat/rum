package RUM::Common;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(getave);

=head1 FUNCTIONS

=over 4

=item getave

TODO: Document me

=cut 

sub getave {
    my ($spans_x) = @_;

    my @spans = split(/, /, $spans_x);
    my $ave = 0;
    my $len = 0;
    for my $span (@spans) {
	my ($start, $end) = split(/-/, $span);
	$ave = $ave + $end*($end+1)/2 - $start*($start-1)/2;
	$len = $len + $end - $start + 1;
    }
    $ave = $ave / $len;

    return $ave;
}

1;
