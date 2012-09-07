package RUM::Action::Version;


use strict;
use warnings;

use base 'RUM::Base';

use RUM::Pipeline;

sub run {
    my ($class) = @_;
    print("RUM version $RUM::Pipeline::VERSION, released $RUM::Pipeline::RELEASE_DATE\n");
}

1;

__END__

=head1 NAME

RUM::Action::Version - Print RUM version number and release date

=head1 METHODS

=over 4

=item run

Print the version number.

=item accepted_options

Returns the map of options accepted by this action.

=cut

=back
