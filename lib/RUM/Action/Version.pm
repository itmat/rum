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
