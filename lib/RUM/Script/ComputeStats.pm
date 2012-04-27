package RUM::Script::ComputeStats;

use strict;
use warnings;

use Carp;
use Getopt::Long;

use RUM::Usage;
use RUM::Logging;
use RUM::Common;

our $log = RUM::Logging->get_logger;

sub _read_footprint {
    my ($filename) = @_;
    open my $in, "<", $filename or croak
        "Can't open footprint file $filename: $!";
    local $_ = <$in>;
    chomp;
    /(\d+)$/ and return $1;
}


sub main {

    GetOptions(
        "help|h"    => sub { RUM::Usage->help },
        "verbose|v" => sub { $log->more_logging(1) },
        "quiet|q"   => sub { $log->less_logging(1) },
        "u-footprint=s" => \(my $uf_filename),
        "nu-footprint=s" => \(my $nuf_filename),
        "genome-size=s" => \(my $genome_size));


    my $usage = RUM::Usage->new;
    $uf_filename or $usage->bad(
        "Please provide the unique footprint filename "
            . "with --u-footprint");

    $nuf_filename or $usage->bad(
        "Please provide the non-unique footprint filename "
            . "with --nu-footprint");

    $genome_size or $usage->bad(
        "Please provide the genome size with --genome-size");

    my $mapping_stats = shift @ARGV or $usage->bad(
        "Please provide the mapping stats input file ".
            "as the last command line argument");

    $usage->check;

    my $uf   = _read_footprint($uf_filename);
    my $nuf  = _read_footprint($nuf_filename);
    my $UF   = RUM::Common->format_large_int($uf);
    my $NUF  = RUM::Common->format_large_int($nuf);
    my $UFp  = int($uf / $genome_size * 10000) / 100;
    my $NUFp = int($nuf / $genome_size * 10000) / 100;

    my $gs4 = RUM::Common->format_large_int($genome_size);

    my @lines = (
        "genome size: $gs4",
        "number of bases covered by unique mappers: $UF ($UFp%)",
        "number of bases covered by non-unique mappers: $NUF ($NUFp%)");
    
    $log->info("$_\n") for @lines;
    
    open my $in, "<", $mapping_stats or croak "Can't read from $mapping_stats: $!";
    my $newfile = "";
    while (local $_ = <$in>) {
        chomp;
        next if /chr_name/;
        if(/RUM_Unique reads per chromosome/) {
            for my $line (@lines) {
                print "$line\n";
            }
        }
        print "$_\n";
    }
}

1;
