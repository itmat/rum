package RUM::Script::MergeSamHeaders;

use strict;
no warnings;
use Carp;
use RUM::Sort qw(by_chromosome);

sub main {
    local $_;
    my %header;
    while (defined($_ = <ARGV>)) {
        chomp;
        /SN:([^\s]+)\s/ or croak "Bad SAM header $_";
        $header{$1}=$_;
    }
    for (sort by_chromosome keys %header) {
        print "$header{$_}\n";
    }
}


1;
