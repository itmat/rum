package RUM::Script::RumToCov;

no warnings;
use autodie;
use RUM::Usage;
use RUM::Logging;
use RUM::CoverageMap;
use Getopt::Long;
use Data::Dumper;
our $log = RUM::Logging->get_logger();

sub main {

    GetOptions(
        "output|o=s" => \(my $outfile = undef),
        "stats=s"    => \(my $statsfile = undef),
        "name=s"     => \(my $name = undef),
        "help|h" => sub { RUM::Usage->help },
        "verbose|v" => sub { $log->more_logging(1) },
        "quiet|q"   => sub { $log->less_logging(1) });


    $outfile or RUM::Usage->bad(
        "Please specify an output file with -o or --output");

    my $infile = $ARGV[0] or RUM::Usage->bad(
        "Please provide an input file on the command line");

    $log->info("Making coverage plot $outfile...");

    $name ||= $infile . " Coverage";

    open $in_fh,  '<', $infile;
    open $out_fh, '>', $outfile;

    print $out_fh qq{track type=bedGraph name="$name" description="$name" visibility=full color=255,0,0 priority=10\n};

    my $footprint = 0;
    
    my $covmap = RUM::CoverageMap->new();

    my @spans;
    while (1) {

        my ($chr, $spans) = next_chr_and_span($in_fh);
        my @spans = @{ $spans };

        if ($chr ne $current_chr) {
            my $purged = $covmap->purge_spans($cutoff);
            for my $rec (@{ $purged }) {
                my ($start, $end, $cov) = @{ $rec };
                if ($cov) {
                    print $out_fh join("\t", $current_chr, $start, $end, $cov), "\n";
                    $footprint += $end - $start;
                }
            }
        }

        $covmap->add_spans(\@spans);

        $current_chr = $chr;

        last unless $chr;
    }

    if ($statsfile) {
        open my $stats_out, '>', $statsfile;
        print $stats_out "footprint for $infile : $footprint\n";
    }
}
1;

sub next_chr_and_span  {
    my ($in_fh) = @_;
    
    my $line = <$in_fh>;

    return unless defined $line;
    
    chomp($line);
    
    my ($readid, $chr, $spans, $strand) = split /\t/,$line;

    if ($readid =~ /^seq.(\d+)a/) {
        $seqnum1 = $1;

        $line2 = <$in_fh>;
        chomp($line2);

        my ($b_readid, undef, $b_spans) = split(/\t/,$line2);

        if ($b_readid eq "seq.${seqnum1}b") {
            if ($strand eq '+') {
                $spans = $spans . ", " . $b_spans;
            } else {
                $spans = $b_spans . ", " . $spans;
            }
        } else {
            # reset the file handle so the last line read will be read again
            seek $in_fh, -(1 + length($line2)), 1;
        }
    }

    my @spans;

    for my $span (split /, /, $spans) {
        my ($start, $end) = split /-/, $span;
        push @spans, [ int($start - 1), int($end), 1 ];
    }

    return ($chr, \@spans);
}

# 8:30 to 4:30
