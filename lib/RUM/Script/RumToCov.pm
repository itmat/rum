package RUM::Script::RumToCov;

no warnings;
use RUM::Usage;
use RUM::Logging;
use Getopt::Long;
use RUM::RUMIO;

our $log = RUM::Logging->get_logger();

sub main {
    $timestart = time();

    undef %chromosomes_finished;

    GetOptions(
        "output|o=s" => \(my $outfile = undef),
        "stats=s"    => \(my $statsfile = undef),
        "name=s"     => \(my $name = undef),
        "help|h" => sub { RUM::Usage->help },
        "verbose|v" => sub { $log->more_logging(1) },
        "quiet|q"   => sub { $log->less_logging(1) });

    # option not implemented:
    #       -strand s : s=p to use just + strand reads, s=m to use just - strand.

    $outfile or RUM::Usage->bad(
        "Please specify an output file with -o or --output");

    my $infile = $ARGV[0] or RUM::Usage->bad(
        "Please provide an input file on the command line");

    $log->info("Making coverage plot $outfile...");

    $name ||= $infile . " Coverage";

    my $iter = RUM::RUMIO->new(-file => $infile)->peekable;
    open(OUTFILE, ">$outfile") 
        or die "Can't open $outfile for writing: $!";

    print OUTFILE "track type=bedGraph name=\"$name\" description=\"$name\" visibility=full color=255,0,0 priority=10\n";

    $flag = 0;

    &getStartEndandSpans_of_nextline();
    $current_chr = $chr;
    $current_loc = $start-1;
    $current_cov = 0;
    $first_span_on_chr = 1;
    $end_max = 0;
    $span_ended = 1;
    $prev_end = $end+2;

    if ($statsfile) {
        $footprint = 0;
    }
    while ($flag < 2) {

        if ($flag == 1) {
            $flag = 2;
        }
        if ($chr eq $current_chr) {
            @S = split(/, /, $spans);
            for ($i=0; $i<@S; $i++) {
                @b = split(/-/, $S[$i]);
                for ($j=$b[0]; $j<=$b[1]; $j++) {
                    $position_coverage{$j}++;
                }
            }
            if ($start > $current_loc) {
                if ($prev_end < $start) {
                    $M = $prev_end;
                } else {
                    $M = $start;
                }
                for ($j=$current_loc+1; $j<$M; $j++) {
                    if ($position_coverage{$j}+0 != $current_cov) { # span ends here
                        if ($current_cov > 0) {
                            $k=$j-1;
                            print OUTFILE "\t$k\t$current_cov\n"; # don't adjust the right point because half-open
                            if ($statsfile) {
                                $footprint = $footprint + $end_max - $span_start;
                            }
                            $span_ended = 1;
                        }
                        $current_cov = $position_coverage{$j}+0;
                        if ($current_cov > 0) { # start a new span
                            $k = $j-1; # so as to be half zero based
                            print OUTFILE "$chr\t$k";
                            $span_start = $k;
                            $span_ended = 0;
                        }
                    }
                    delete $position_coverage{$j};
                }
                $current_loc = $start - 1;
                if ($end+2 >= $prev_end) {
                    $prev_end = $end + 2;
                }
            }
            &getStartEndandSpans_of_nextline();
        } else {
            for ($j=$current_loc+1; $j<=$end_max; $j++) {
                if ($position_coverage{$j}+0 != $current_cov) { # span ends here
                    if ($current_cov > 0) {
                        $k=$j-1;
                        print OUTFILE "\t$k\t$current_cov\n"; # don't adjust the right point because half-open
                        $span_ended = 1;
                        if ($statsfile) {
                            $footprint = $footprint + $k - $span_start;
                        }
                    }
                    $current_cov = $position_coverage{$j}+0;
                    if ($current_cov > 0) { # start a new span
                        $k = $j-1; # so as to be half zero based
                        print OUTFILE "$chr_prev\t$k";
                        $span_start = $k;
                        $span_ended = 0;
                    }
                }
            }
            if ($span_ended == 0) {
                print OUTFILE "\t$end_max\t$current_cov\n"; # don't adjust the right point because half-open
                if ($statsfile) {
                    $footprint = $footprint + $k - $span_start;
                }
            }
            undef %position_coverage;
            $current_chr = $chr;
            $current_loc = $start-1;
            $current_cov = 0;
            $end_max = 0;
            $prev_end = $end+2;
        }
    }

    if ($statsfile) {
        open(STATS, ">$statsfile");
        print STATS "footprint for $infile : $footprint\n";
    }

    $timeend = time();
    $timelapse = $timeend - $timestart;
    if ($timelapse < 0) {
        $timelapse = 0;
    }
    my $elapsed;

    if ($timelapse < 60) {
        $elapsed = "$timelapse seconds";
    } else {
        $sec = $timelapse % 60;
        $min = int($timelapse / 60);
        $elapsed = "$min minute";
        $elapsed .= "s" if $min > 1;
        $elapsed .= ", $sec second";
        $elapsed .= "s" if $sec > 1;
    }
    $log->info("It took $elapsed to create the coverage file $outfile.");

    sub getStartEndandSpans_of_nextline () {
        my $aln = $iter->next_val;

        if ($end > $end_max) {
            $end_max = $end;
        }
        $chr_prev = $chr;
        $start_prev = $start;

        if (!$aln) {
            
            $flag ||= 1;
            for ($tryagain=0; $tryagain<10; $tryagain++) {
                $aln = $iter->next_val;

                if ($aln) {
                    $tryagain = 10;
                    $flag = 0;
                }
            }
            if ($flag) {
                $chr = "";
                return;
            }
        }

        $chr = $aln->chromosome;
        $start = $aln->start;
        $spans = RUM::RUMIO->format_locs($aln);

        if ($aln->is_forward) {

            $rev = $iter->peek;

            if ($rev && $aln->is_mate($rev)) {
                $iter->next_val;
                if ($aln->strand eq "+") {
                    $end = $rev->end;
                    $spans = $spans . ", " . RUM::RUMIO->format_locs($rev);
                } else {
                    $start = $rev->start;
                    $end = $aln->end;
                    $spans = RUM::RUMIO->format_locs($rev) . ", " . $spans;
                }
            } else {
                $end = $aln->end;
            }
        } else {
            $end = $aln->end;
        }
        if ($chr ne $chr_prev) {
            $chromosomes_finished{$chr_prev}++;
        }
        if (($chromosomes_finished{$chr}+0>0) ||
                ($chr eq $chr_prev && $start < $start_prev)) {
            die "It appears your file '$infile' is not sorted.  Use sort_RUM_by_location.pl to sort it.";
        }
    }

}
1;
