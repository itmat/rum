package RUM::Script::ComputeStats;

use strict;
use warnings;

use Carp;
use Getopt::Long;

use RUM::Logging;
use RUM::Common;
use RUM::CommandLineParser;
use RUM::CommonProperties;

use base 'RUM::Script::Base';

our $log = RUM::Logging->get_logger;

sub _read_footprint {
    my ($filename) = @_;
    open my $in, "<", $filename or croak
        "Can't open footprint file $filename: $!";
    local $_ = <$in>;
    chomp;
    /(\d+)$/ and return $1;
}


sub summary {
    return "Compute final mapping stats";
}

sub command_line_parser {
    my $parser = RUM::CommandLineParser->new;
    $parser->add_prop(
        opt => 'u-footprint=s',
        desc => 'File containing number of bases covered by unique mappers, produced by rum2cov.pl',
        required => 1);
    $parser->add_prop(
        opt => 'nu-footprint=s',
        desc => 'File containing number of bases covered by non-unique mappers, produced by rum2cov.pl',
        required => 1);
    $parser->add_prop(RUM::CommonProperties->genome_size);
    $parser->add_prop(
        opt => 'mapping_stats',
        desc => 'Mapping stats input file',
        positional => 1,
        required => 1);
    return $parser;
}

sub run {
    my ($self) = @_;

    my $props = $self->properties;
    my $uf   = _read_footprint($props->get('u_footprint'));
    my $nuf  = _read_footprint($props->get('nu_footprint'));
    my $genome_size = $props->get('genome_size');
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
    
    open my $in, "<", $props->get('mapping_stats');
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
