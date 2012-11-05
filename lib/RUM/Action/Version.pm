package RUM::Action::Version;

use strict;
use warnings;

use base 'RUM::Script::Base';

use RUM::Pipeline;

sub accepted_options { }

sub summary { 'Show the version number of RUM' }

sub run {
    my ($self) = @_;
    print("RUM version $RUM::Pipeline::VERSION, released $RUM::Pipeline::RELEASE_DATE\n");
}

1;
