package RUM::Common;

use strict;
use warnings;

=head1 FUNCTIONS

=over 4

=item getave

TODO: Document me

=cut 

sub getave () {
    my ($spans_x) = @_;

    my @SS3 = split(/, /, $spans_x);
    my $spanave = 0;
    my $spanlen = 0;
    for(my $ss3=0; $ss3 < @SS3; $ss3++) {
	my @SS4 = split(/-/, $SS3[$ss3]);
	$spanave = $spanave + $SS4[1]*($SS4[1]+1)/2 - $SS4[0]*($SS4[0]-1)/2;
	$spanlen = $spanlen + $SS4[1] - $SS4[0] + 1;
    }
    $spanave = $spanave / $spanlen;

    return $spanave;
}

1;
