package RUM::Action::Help;

use strict;
use warnings;

use base 'RUM::Base';

sub run {
    my ($class) = @_;

    if (@ARGV) {
        if ($ARGV[0] eq 'config') {
            print($RUM::ConfigFile::DOC);
        }
    }
    else {
        RUM::Usage->help;
    }
}

1;
