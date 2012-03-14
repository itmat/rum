package RUM::Script::SortByLocation;

use strict;
no warnings;

use RUM::Usage;
use RUM::Logging;
use Getopt::Long;
use RUM::Sort qw(cmpChrs);



our $log = RUM::Logging->get_logger();

sub main {

    GetOptions(
        "output|o=s"   => \(my $outfile),
        "location=s"   => \(my $location_col),
        "chromosome=s" => \(my $chromosome_col),
        "start=s"      => \(my $start_col),
        "end=s"        => \(my $end_col),
        "skip=s"       => \(my $skip = 0),
        "help|h"    => sub { RUM::Usage->help },
        "verbose|v" => sub { $log->more_logging(1) },
        "quiet|q"   => sub { $log->less_logging(1) });

    my ($infile) = shift(@ARGV) or RUM::Usage->bad(
        "Please provide an input file");

    if ($location_col) {
        $location_col > 0 or RUM::Usage->bad(
            "Location column must be a positive integer");
        $location_col--;
    }

    elsif ($chromosome_col && $start_col && $end_col) {
        $chromosome_col > 0 or RUM::Usage->bad(
            "Chromosome column must be a positive integer");
        $start_col > 0 or RUM::Usage->bad(
            "Start column must be a positive integer");
        $end_col > 0 or RUM::Usage->bad(
            "End column must be a positive integer");
        $chromosome_col--;
        $start_col--;
        $end_col--;
    }
    else {
        RUM::Usage->bad("Please specify either --location or --chromsome, ".
                            "--start, and --end");
    }

    $skip >= 0 or RUM::Usage->bad("--skip must be an integer");

    open my $in, "<", $infile or die "Can't open $infile for reading: $!";
    open my $out, ">", $outfile or die "Can't open $outfile for writing: $!";

    for (my $i=0; $i<$skip; $i++) {
        my $line = <$in>;
        print $out $line;
    }

    my %hash;

    while (defined(my $line = <$in>)) {
        chomp($line);
        my @a = split(/\t/,$line);
        my ($chr, $start, $end);
        if ($location_col) {
            my $loc = $a[$location_col];
            $loc =~ /^(.*):(\d+)-(\d+)/;
            $chr = $1;
            $start = $2;
            $end = $3;
        }
        else {
            $chr = $a[$chromosome_col];
            $start = $a[$start_col];
            $end = $a[$end_col];
        }
        $hash{$chr}{$line}[0] = $start;
        $hash{$chr}{$line}[1] = $end;
    }
    close($in);

    for my $chr (sort {cmpChrs($a,$b)} keys %hash) {
        for my $line (sort {
            $hash{$chr}{$a}[0]<=>$hash{$chr}{$b}[0] ||
                $hash{$chr}{$a}[1]<=>$hash{$chr}{$b}[1]
            } keys %{$hash{$chr}}) {
            chomp($line);
            if ($line =~ /\S/) {
                print $out "$line\n";
            }
        }
    }
}

1;
