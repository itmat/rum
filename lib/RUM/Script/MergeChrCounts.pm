package RUM::Script::MergeChrCounts;

no warnings;
use RUM::Usage;
use RUM::Logging;
use Getopt::Long;
use RUM::Sort qw(by_chromosome);
our $log = RUM::Logging->get_logger();

use strict;

sub main {

    GetOptions(
        "output|o=s" => \(my $outfile),
        "help|h"    => sub { RUM::Usage->help },
        "verbose|v" => sub { $log->more_logging(1) },
        "quiet|q"   => sub { $log->less_logging(1) },
        "chunk-ids-file=s" => \(my $chunk_ids_file));

    $outfile or RUM::Usage->bad(
        "Please specify an output file with --output or -o");
    
    my @file = @ARGV;
    
    @file > 0 or RUM::Usage->bad(
        "Please list the input files on the command line");
    
    my %chunk_ids_mapping;

    if ($chunk_ids_file && -e $chunk_ids_file) {
        $log->info("Loading chunk id file");
        open(INFILE, $chunk_ids_file) 
            or die "Can't open $chunk_ids_file for reading: $!";
        while (defined(my $line = <INFILE>)) {
            chomp($line);
            my @a = split(/\t/,$line);
            if ($a[0] ne "chr_name") {
                $chunk_ids_mapping{$a[0]} = $a[1];
            }
        }
        close(INFILE);
    }
    open(OUTFILE, ">>", $outfile) or die "Can't open $outfile for appending";
    
    for (my $i=0; $i<@file; $i++) {
        my $j = $i+1;
        if ($chunk_ids_file =~ /\S/ && $chunk_ids_mapping{$j} =~ /\S/) {
            $file[$i] =~ s/(\d|\.)+$//;
            $file[$i] = $file[$i] . ".$j." . $chunk_ids_mapping{$j};
        }
    }

    my %chrcnt;
    for my $filename (@file) {
        open(INFILE, $filename) or die "Can't open $filename for reading: $!";
        local $_ = <INFILE>;
        $_ = <INFILE>;
        $_ = <INFILE>;
        $_ = <INFILE>;
        while (defined ($_ = <INFILE>)) {
            chomp;
            my @a1 = split /\t/;
            $chrcnt{$a1[0]} = $chrcnt{$a1[0]} + $a1[1];
        }
        close(INFILE);
    }
    
    for my $chr (sort by_chromosome keys %chrcnt) {
        my $cnt = $chrcnt{$chr};
        print OUTFILE "$chr\t$cnt\n";
    }
    
    
}

    1;
