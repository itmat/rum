package RUM::Action::Version;

use strict;
use warnings;

use base 'RUM::Base';

sub run {
    my ($class) = @_;
    print("RUM version $RUM::Pipeline::VERSION, released $RUM::Pipeline::RELEASE_DATE");
}

1;
