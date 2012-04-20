package RUM::Action::Version;

=head1 NAME

RUM::Action::Status - Print status of job

=head1 METHODS

=over 4

=item run

Print the version and release date of rum.

=back

=cut

use strict;
use warnings;

use base 'RUM::Base';

sub run {
    my ($class) = @_;
    print("RUM version $RUM::Pipeline::VERSION, released $RUM::Pipeline::RELEASE_DATE");
}

1;
