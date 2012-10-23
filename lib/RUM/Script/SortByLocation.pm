package RUM::Script::SortByLocation;

use strict;
use warnings;
use autodie;

use RUM::UsageErrors;
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


    my $errors = RUM::UsageErrors->new;

    my ($infile) = shift(@ARGV) or $errors->add(
        "Please provide an input file");

    if ($location_col) {
        $location_col > 0 or $errors->add(
            "Location column must be a positive integer");
        $location_col--;
    }

    elsif ($chromosome_col && $start_col && $end_col) {
        $chromosome_col > 0 or $errors->add(
            "Chromosome column must be a positive integer");
        $start_col > 0 or $errors->add(
            "Start column must be a positive integer");
        $end_col > 0 or $errors->add(
            "End column must be a positive integer");
        $chromosome_col--;
        $start_col--;
        $end_col--;
    }
    else {
        $errors->add("Specify either --location or --chromosome, ".
                            "--start, and --end");
    }

    if (!$outfile) {
      $errors->add("Specify an output file with -o or --output");
    }

    $skip >= 0 or $errors->add("--skip must be an integer");

    $errors->check;

    open my $in,  "<", $infile;
    open my $out, ">", $outfile;

    for (my $i=0; $i<$skip; $i++) {
        my $line = <$in>;
        print $out $line;
    }

    my %hash;

    while (defined(my $line = <$in>)) {
        chomp($line);
        my @a = split /\t/, $line;
        my ($chr, $start, $end);
        if (defined($location_col)) {
            my $loc = $a[$location_col];
            $loc   =~ /^(.*):(\d+)-(\d+)/;
            $chr   = $1;
            $start = $2;
            $end   = $3;
        }
        else {
            $chr   = $a[$chromosome_col];
            $start = $a[$start_col];
            $end   = $a[$end_col];
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
