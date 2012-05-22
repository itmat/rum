package RUM::Script::MergeSamHeaders;

use strict;
no warnings;
use Carp;
use RUM::Sort qw(by_chromosome);

use Getopt::Long;
use RUM::Usage;
use RUM::Logging;

our $log = RUM::Logging->get_logger();

sub main {

    GetOptions(
        "name=s"    => \(my $name = "unknown"),
        "help|h"    => sub { RUM::Usage->help },
        "quiet|q"   => sub { $log->less_logging(1) },
        "verbose|v" => sub { $log->more_logging(1) });

    local $_;
    my %header;
    for my $filename (@ARGV) {
        open my $in, "<", $filename;
        while (defined($_ = <$in>)) {
            chomp;
            /SN:([^\s]+)\s/ or croak "Bad SAM header $_";
            $header{$1}=$_;
        }
    }
    for (sort by_chromosome keys %header) {
        print "$header{$_}\n";
    }

    print join("\t", '@RG', "ID:$name", "SM:$name"), "\n";
}


1;
