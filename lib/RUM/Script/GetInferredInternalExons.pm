package RUM::Script::GetInferredInternalExons;

no warnings;
use RUM::Usage;
use RUM::Logging;
use Getopt::Long;
use RUM::CoverageMap;
use RUM::Common qw(roman Roman arabic isroman);
use RUM::Sort qw(cmpChrs by_chromosome);

our $log = RUM::Logging->get_logger();

sub main {

    GetOptions(
        "junctions=s" => \(my $junctionsinfile),
        "coverage=s"  => \(my $covinfile),
        "genes=s"     => \(my $annotfile),
        "bed=s"       => \(my $bedfile),
        "rum=s"       => \(my $rumoutfile),
        "min-score=s" => \(my $minscore = 1),
        "max-exon=s"  => \(my $maxexon = 500),
        "help|h"      => sub { RUM::Usage->help },
        "verbose|v"   => sub { $log->more_logging(1) },
        "quiet|q"     => sub { $log->less_logging(1) });

    $junctionsinfile or RUM::Usage->bad(
        "Please provide a junctions input file with --junctions");

    $covinfile or RUM::Usage->bad(
        "Please provide a coverage file with --coverage");

    $annotfile or RUM::Usage->bad(
        "Please provide an annotation file with --genes");

    my %debughash;              # xxx get rid of this later...

    my $min_intron = 35;
    my @junctions_file;

    my %count_coverage_in_span_cache;
    my %ave_coverage_in_span_cache;
    my @inferredTranscript;
    my $firstchr = "true";

    open(INFILE, $annotfile) or die "Can't open $annotfile for reading: $!";

    # read in the transcript models

    my %ANNOTATEDTRANSCRIPT;
    my %EXON_temp;
    my %INTRON_temp;
    my %cnt;
    my @A;
    my @B;
    my %tcnt;
    my %ecnt;
    my %icnt;
    my %FIRSTEXONS;
    my %LASTEXONS;
    my %JUNCTIONS_ANNOT;

    while (my $line = <INFILE>) {
        chomp($line);
        my @a = split(/\t/,$line);

        $a[5] =~ s/\s*,\s*$//;
        $a[6] =~ s/\s*,\s*$//;
        my $chr = $a[0];
        $tcnt{$chr}=$tcnt{$chr}+0;
        $ANNOTATEDTRANSCRIPT{$chr}[$tcnt{$chr}]{strand} = $a[1];
        $ANNOTATEDTRANSCRIPT{$chr}[$tcnt{$chr}]{num} = $a[4];
        $ANNOTATEDTRANSCRIPT{$chr}[$tcnt{$chr}]{start} = $a[2]+1; # add one to convert to one-based coords
        $ANNOTATEDTRANSCRIPT{$chr}[$tcnt{$chr}]{end} = $a[3];
        my @s = split(/,/,$a[5]);
        my @e = split(/,/,$a[6]);
        my @c;
        my $transcript_length=0;

        # xxx populate %FIRSTEXONS and %LASTEXONS in the following loop

        for (my $i=0; $i<@s; $i++) {
            $ANNOTATEDTRANSCRIPT{$chr}[$tcnt{$chr}]{coords}[2*$i]=$s[$i]+1; # add one to convert to one-based coords
            $ANNOTATEDTRANSCRIPT{$chr}[$tcnt{$chr}]{coords}[2*$i+1]=$e[$i];
            my $S = $s[$i]+1;
            my $E = $chr . ":" . $S . "-" . $e[$i];
            $transcript_length = $transcript_length + $e[$i] - $S + 1;
            $EXON_temp{$chr}{$E}{start} = $S;
            $EXON_temp{$chr}{$E}{end} = $e[$i];
            if ($i == 0) {
                $FIRSTEXONS{$chr}{$E}  = $S;
            } elsif ($i == @s-1) {
                $LASTEXONS{$chr}{$E}  = $S;
            }

            if ($i < @s-1) {
                my $s2 = $e[$i]+1;
                my $e2 = $s[$i+1];
                my $E = $chr . ":" . $s2 . "-" . $e2;
                $INTRON_temp{$chr}{$E}{start} = $s2;
                $INTRON_temp{$chr}{$E}{end} = $e2;
                $s2 = $e[$i];
                $e2 = $s[$i+1]+1;
                $E = $chr . ":" . $s2 . "-" . $e2;
                $JUNCTIONS_ANNOT{$E} = 1;
            }
        }
        $ANNOTATEDTRANSCRIPT{$chr}[$tcnt{$chr}]{length} = $transcript_length;
        $ANNOTATEDTRANSCRIPT{$chr}[$tcnt{$chr}]{id} = $a[7];
        $tcnt{$chr}++;
    }
    close(INFILE);

    #foreach my $key (keys %JUNCTIONS_ANNOT) {
    #    print "$key\n";
    #}

    open(INFILE, $junctionsinfile) 
        or die "Can't open $junctionsinfile for reading: $!";
    my $junctions_ref = &filter_junctions_file();
    my @ARR = @{$junctions_ref};
    my %junctions = %{$ARR[0]};
    my %junctions_scores = %{$ARR[1]};
    close(INFILE);

    #foreach my $chr (keys %junctions) {
    #    my $N = @{$junctions{$chr}};
    #    for(my $i=0; $i<$N; $i++) {
    #	print "junctions{$chr}[$i] = $junctions{$chr}[$i]\n";
    #    }
    #}

    my %ANNOTATEDEXON; # this guy is a highly structured hash mapping chr to
    # an ordered list of exons feature details
    my %ANNOTATEDEXONS;    # this guy is a simple hash with keys=exons
    foreach my $chr (sort by_chromosome keys %EXON_temp) {
        $ecnt{$chr} = 0;
        foreach my $exon (sort {$EXON_temp{$chr}{$a}{start} <=> $EXON_temp{$chr}{$b}{start}} keys %{$EXON_temp{$chr}}) {
            $ANNOTATEDEXON{$chr}[$ecnt{$chr}]{start} = $EXON_temp{$chr}{$exon}{start};
            $ANNOTATEDEXON{$chr}[$ecnt{$chr}]{end} = $EXON_temp{$chr}{$exon}{end};
            $ANNOTATEDEXON{$chr}[$ecnt{$chr}]{exon} = $exon;
            my $s = $EXON_temp{$chr}{$exon}{start};
            my $e = $EXON_temp{$chr}{$exon}{end};
            my $exon = "$chr:$s-$e";
            $ANNOTATEDEXONS{$exon}=1;
            $ecnt{$chr}++;
        }
    }

    my %INTRON;
    foreach my $chr (sort by_chromosome keys %INTRON_temp) {
        $icnt{$chr} = 0;
        foreach my $intron (sort {$INTRON_temp{$chr}{$a}{start} <=> $INTRON_temp{$chr}{$b}{start}} keys %{$INTRON_temp{$chr}}) {
            $INTRON{$chr}[$icnt{$chr}]{start} = $INTRON_temp{$chr}{$intron}{start};
            $INTRON{$chr}[$icnt{$chr}]{end} = $INTRON_temp{$chr}{$intron}{end};
            $INTRON{$chr}[$icnt{$chr}]{intron} = $intron;
            $icnt{$chr}++;
        }
    }
    open(COVFILE, $covinfile) or die "Error: cannot open '$covinfile' for reading\n\n";
    my $coverage = RUM::CoverageMap->new(*COVFILE);

    my $line = <INFILE>;
    chomp($line);
    my @a = split(/\t/,$line);
    my $chr = $a[0];
    my %prev_exon_start;
    my $count;
    my %junction_score;
    my %working_chr;
    my %coverage;

    # Going to change everything into one-based (inclusive) coordinates, then will change back
    # to print.  Did this to keep from going crazy.

    my %working_on;

    my $cnt = 0;
    my %junctionstarts;
    my %junctionends;
    my @junction_starts;
    my @junction_ends;
    my %coverage;
    my %exonstart2ends;
    my %exonend2starts;
    my %putative_exons;
    my %startloc2exons;
    my %endloc2exons;
    my %adjacent;
    my @putative_exon_array;
    my %associated;
    my %firstexonendloc2startlocs;
    my %lastexonstartloc2endlocs;
    my @putative_start_exons_ends;
    my %exonend2adj_downstream_exons;
    my %exonstart2adj_upstream_exons;
    my %annotatedfirstexonendloc2startlocs;
    my %annotatedlastexonstartloc2endlocs;
    my @putative_upstream_exons_ends;
    my @putative_downstream_exons_starts;
    my %junctionstarts2ends;
    my %junctionends2starts;
    my %cov;
    my %cache;
    my %fraglengths;
    my %initial_exons;
    my %terminal_exons;
    my $fraglength_mean;
    my $fraglength_sd;
    my %JUNCTIONS_START_SCORES;
    my %JUNCTIONS_END_SCORES;

    # going to step through the chromosomes in sorted order

    if ($bedfile) {
        open(BEDFILE, ">$bedfile");
        print BEDFILE "track\tname=\"Inferred Internal Exons\"  description=\"Inferred Internal Exons\"   visibility=3    itemRgb=\"On\"\n";
    }
    if ($rumoutfile) {
        open(RUMFILE, ">$rumoutfile");
    }

    foreach my $chr (sort by_chromosome keys %junctions) {

        #    print STDERR "working on chromosome '$chr'\n";

        undef %coverage;
        undef %exonstart2ends;
        undef %exonend2starts;
        undef %junctionstarts;
        undef %junctionends;
        undef @junction_starts;
        undef @junction_ends;
        undef %putative_exons;
        undef %JUNCTIONS_START_SCORES;
        undef %JUNCTIONS_END_SCORES;
        undef %startloc2exons;
        undef %endloc2exons;
        undef %adjacent;
        undef @putative_exon_array;
        undef %associated;
        undef %annotatedfirstexonendloc2startlocs;
        undef %annotatedlastexonstartloc2endlocs;
        undef @putative_upstream_exons_ends;
        undef @putative_downstream_exons_starts;
        undef %exonend2adj_downstream_exons;
        undef %exonstart2adj_upstream_exons;
        undef %junctionstarts2ends;
        undef %junctionends2starts;
        undef %cov;
        undef %initial_exons;
        undef %terminal_exons;
        undef %fraglengths;

        # Read in the coverage for this chromosome
        $coverage->read_chromosome($chr);

        my $N = @{$junctions{$chr}};
        for (my $k=0; $k<$N; $k++) {
            $line = $junctions{$chr}[$k];
            my $score = $junctions_scores{$chr}[$k];
            @a = split(/\t/,$line);
            my $score = $a[3];
            my $blocksizes = $a[10];
            $blocksizes =~ s/\s*,\s*$//;
            my @B = split(/,/,$blocksizes);
            my $offsets = $a[11];
            $offsets =~ s/\s*,\s*$//;
            my @O = split(/,/,$offsets);
            $junctionstarts{$a[1] + $B[0]} = 1;
            $junctionends{$a[1] + $O[1] + 1} = 1; # added one to change to one-based
            push(@{$junctionstarts2ends{$a[1] + $B[0]}}, $a[1] + $O[1] + 1);
            push(@{$junctionends2starts{$a[1] + $O[1] + 1}}, $a[1] + $B[0]);
            my $x = $a[1] + $B[0];
            my $y = $a[1] + $O[1] + 1;
            my $J = "$chr:$x-$y";
            if (!(defined $JUNCTIONS_START_SCORES{$x})) {
                $JUNCTIONS_START_SCORES{$x} = $score;
            } else {
                if ($JUNCTIONS_START_SCORES{$x} < $score) {
                    $JUNCTIONS_START_SCORES{$x} = $score;
                }
            }
            if (!(defined $JUNCTIONS_END_SCORES{$x})) {
                $JUNCTIONS_END_SCORES{$y} = $score;
            } else {
                if ($JUNCTIONS_END_SCORES{$y} < $score) {
                    $JUNCTIONS_END_SCORES{$y} = $score;
                }
            }
        }

        my $C=0;
        foreach my $s (sort {$a<=>$b} keys %junctionstarts) {
            $junction_starts[$C] = $s;
            $C++;
        }
        $C=0;
        foreach my $s (sort {$a<=>$b} keys %junctionends) {
            $junction_ends[$C] = $s;
            $C++;
        }
        my $start_index = 0;

        for (my $je=0; $je<@junction_ends; $je++) {
            my $flag = 0;
            my $js = $start_index;
            #	if($js % 1000 == 0 && $js>0) {
            #	    print STDERR "finished $js\n";
            #	}
            while ($flag == 0) {
                if ($start_index >= @junction_starts || $js >= @junction_starts) {
                    $flag = 1;
                    next;
                }
                if ($junction_starts[$js] <= $junction_ends[$je]) {
                    $start_index++;
                }
                if ($junction_starts[$js] > $junction_ends[$je] + $maxexon - 1) {
                    $flag = 1;
                    next;
                }
                if ($junction_ends[$je] < $junction_starts[$js] && $junction_starts[$js] <= $junction_ends[$je] + $maxexon) {
                    my $cov_yes = 0;
                    my $annot_yes = 0;
		
                    # 1) see if there is coverage across span $junction_ends[$je] to $junction_starts[$js]
                    my $N = $coverage->count_coverage_in_span($junction_ends[$je], $junction_starts[$js], 1);
                    if ($N == 0) {
                        $cov_yes = 1;
                    } else {
                        if ($JUNCTIONS_END_SCORES{$junction_ends[$je]} < 10 && $JUNCTIONS_START_SCORES{$junction_starts[$js]} < 10) {
                            $cov_yes=1;
                        }
                    }
		
                    # 2) see if the span $junction_ends[$je] to $junction_starts[$js] is annotated as an exon
		
                    my $exon = "$chr:$junction_ends[$je]-$junction_starts[$js]";
                    if ($ANNOTATEDEXONS{$exon} + 0 == 1) {
                        $annot_yes = 1;
                    }
		
                    # 3) if 1 *or* 2 are 'yes' then call this an exon
                    if ($cov_yes == 1 || $annot_yes == 1) {
                        my $exon = "$chr:$junction_ends[$je]-$junction_starts[$js]";
                        $putative_exons{$exon}=$junction_ends[$je];
                        push(@{$exonstart2ends{$junction_ends[$je]}}, $junction_starts[$js]);
                        push(@{$exonend2starts{$junction_starts[$js]}}, $junction_ends[$je]);
                    }
                }		
                $js++;
            }
        }

        # use %exonstart2ends and %exonend2starts to remove exons that span two exons:
        # in other words remove '2' in cases like the below, where 'x' represents exon:
        # 1) ---xxxxxx--------xxxxxx----
        # 2) ---xxxxxxxxxxxxxxxxxxxx----

        foreach my $exon (sort {cmpExons($a,$b)} keys %putative_exons) {
            $exon =~ /^.*:(\d+)-(\d+)$/;
            my $S = $1;
            my $E = $2;
            if (defined $exonstart2ends{$S} && defined $exonend2starts{$E}) {
                my $N1 = @{$exonstart2ends{$S}};
                my $N2 = @{$exonend2starts{$E}};
                for (my $i=0; $i<$N1; $i++) {
                    for (my $j=0; $j<$N2; $j++) {
                        if ($exonstart2ends{$S}[$i] + $min_intron <= $exonend2starts{$E}[$j]) {
                            delete $putative_exons{$exon};
                        }
                    }
                }	    
            }
        }

        foreach my $exon (sort {$putative_exons{$a}<=>$putative_exons{$b}} keys %putative_exons) {
            if ($ANNOTATEDEXONS{$exon} + 0 == 1) {
                print "$exon\tannotated\n";
            } else {
                print "$exon\tnovel\n";
            }
            my $chr;
            my $start;
            my $end;
            if ($rumoutfile || $bedfile) {
                $exon =~ /^(.*):(\d+)-(\d+)/;
                $chr = $1;
                $start = $2 - 1;
                $end = $3;
            }
            if ($rumoutfile) {
                if ($ANNOTATEDEXONS{$exon} + 0 == 0) {
                    print RUMFILE "$chr\t+\t$start\t$end\t1\t$start,\t$end,\t$exon\n";
                }	    
            }
            if ($bedfile) {
                if ($ANNOTATEDEXONS{$exon} + 0 == 1) {
                    print BEDFILE "$chr\t$start\t$end\t.\t0\t.\t$start\t$end\t16,78,139\n";
                } else {
                    print BEDFILE "$chr\t$start\t$end\t.\t0\t.\t$start\t$end\t0,205,102\n";
                }
            }
        }
    }


#    This doesn't seem to be used at all
#    
#    sub  attach () {
#         my ($exonlist_ref) = @_;
#         my @exonlist = @{$exonlist_ref};
#         my $lastexon = $exonlist[@exonlist-1];
#         my @returnarray;
#         my $N2;
#         if (defined $adjacent{$lastexon}) {
#             $N2 = @{$adjacent{$lastexon}};
#         } else {
#             $N2 = 0;
#         }
#         if (defined $terminal_exons{$lastexon} || $N2 == 0) {
#             my $N1 = @returnarray;
#             push(@{$returnarray[$N1]}, @exonlist);
#         }
#         for (my $i=0; $i<$N2; $i++) {
#             my $y = $adjacent{$lastexon}[$i];
#         }
#         for (my $i=0; $i<$N2; $i++) {
#             my $exon = $adjacent{$lastexon}[$i];
#             my @exonlist2 = @exonlist;
#             push(@exonlist2, $exon);
#             my $temp_ref = &attach(\@exonlist2);
#             my @temp = @{$temp_ref};
#             my $M = @returnarray;
#             for (my $i=0; $i<@temp; $i++) {
#                 for (my $j=0; $j<@{$temp[$i]}; $j++) {
#                     $returnarray[$M+$i][$j] = $temp[$i][$j];
#                 }
#             }
#         }
#         return \@returnarray;
#     }

#    This doesn't seem to be used at all
#
#    sub  ave_coverage_in_span () {
#         # This will return the average depth over bases in the span
#         my ($start, $end, $coverage_cutoff) = @_;
#         my $tmp = $start . ":" . $end . ":" . $coverage_cutoff;
#         my $sum = 0;
#         if (defined $ave_coverage_in_span_cache{$tmp}) {
#             return $ave_coverage_in_span_cache{$tmp};
#         }
#         for (my $i=$start; $i<=$end; $i++) {
#             $sum = $sum + $coverage{$i};
#         }
#         my $ave = $sum / ($end - $start + 1);
#         $ave_coverage_in_span_cache{$tmp}=$ave;
#         return $ave;
#     }

    # Initial filtering to remove low scoring stuff that does not seem
    # like it should be part of a transcript:
    #
    # Score <= 2, unknown, overlaps with something with score >= 20,
    # unless it is a perfect alternate splice form without being
    # ridiculously long.
    # (might want to play with 20 to get whatever works best)

    sub filter_junctions_file () {
        my %junction_num;
        my %kept_junctions;
        my %kept_junctions_scores;
        my $scorefilter = 3;
        my $scorefilter_max = 20;
        my %junctions_file;
        my %starts;
        my %ends;
        while (my $line = <INFILE>) {
            chomp($line);
            my @a = split(/\t/,$line);

            my $start_1 = $a[1] + 50;
            my $end_1 = $a[2] - 49;
            my $loc_1 = $a[0] . ":" . $start_1 . "-" . $end_1;

            if (($a[4] < $minscore) && (!($JUNCTIONS_ANNOT{$loc_1} == 1))) {
                next;
            }
            $junction_num{$a[0]}=$junction_num{$a[0]}+0;
            $junctions_file{$a[0]}[$junction_num{$a[0]}][0] = $a[1];
            $junctions_file{$a[0]}[$junction_num{$a[0]}][1] = $a[2];
            $junctions_file{$a[0]}[$junction_num{$a[0]}][2] = $a[4];
            $junctions_file{$a[0]}[$junction_num{$a[0]}][3] = $line;
            if ($a[4] >= $scorefilter) {
                $starts{$a[0]}{$a[1]}=1;
                $ends{$a[0]}{$a[2]}=1;
            }
            $junction_num{$a[0]}++;
        }
        #    foreach my $chr (keys %junction_num) {
        #	foreach my $start (sort {$a<=>$b} keys %{$starts{$chr}}) {
        #	    print "starts{$chr}{$start}=$starts{$chr}{$start}\n";
        #	}
        #    }
        foreach my $chr (keys %junction_num) {
            my $start = 0;
            my $kept_counter=0;
            for (my $i=0; $i<$junction_num{$chr}; $i++) {
                #	    print "junctions_file{$chr}[$i][2]=$junctions_file{$chr}[$i][2]\n";
                #	    print "$junctions_file{$chr}[$i][3]\n";
                #	    print "junctions_file{$chr}[$i][0]=$junctions_file{$chr}[$i][0]\n";
                #	    print "junctions_file{$chr}[$i][0]=$junctions_file{$chr}[$i][0]\n";

                my $line = $junctions_file{$chr}[$i][3];
                my @a = split(/\t/,$line);
                my $start_1 = $a[1] + 50;
                my $end_1 = $a[2] - 49;
                my $loc_1 = $a[0] . ":" . $start_1 . "-" . $end_1;

                if ($junctions_file{$chr}[$i][2] > $scorefilter) {
                    $kept_junctions{$chr}[$kept_counter] = $junctions_file{$chr}[$i][3];
                    $kept_junctions_scores{$chr}[$kept_counter] = $junctions_file{$chr}[$i][2];
                    $kept_counter++;
                } elsif ($starts{$chr}{$junctions_file{$chr}[$i][0]}+0==1 &&
                             $ends{$chr}{$junctions_file{$chr}[$i][1]}+0==1) {
                    $kept_junctions{$chr}[$kept_counter] = $junctions_file{$chr}[$i][3];
                    $kept_junctions_scores{$chr}[$kept_counter] = $junctions_file{$chr}[$i][2];
                    $kept_counter++;
                } elsif ($JUNCTIONS_ANNOT{$loc_1} == 1) {
                    $kept_junctions{$chr}[$kept_counter] = $junctions_file{$chr}[$i][3];
                    $kept_junctions_scores{$chr}[$kept_counter] = $junctions_file{$chr}[$i][2];
                    $kept_counter++;		
                } else {
                    my $flag = 0;
                    for (my $j=$start; $j<$junction_num{$chr}; $j++) {
                        if ($junctions_file{$chr}[$j][2] >= $scorefilter_max &&
                                $junctions_file{$chr}[$j][0] <= $junctions_file{$chr}[$i][1] &&
                                    $junctions_file{$chr}[$j][1] >= $junctions_file{$chr}[$i][0]) {
                            $flag = 1;
                        }
                        if ($junctions_file{$chr}[$i][1] < $junctions_file{$chr}[$j][0]) {
                            # we've checked everything that can overlap, set $j to jump out of loop
                            $j = $junction_num{$chr};
                        }
                    }
                    if ($flag == 0) {
                        $kept_junctions{$chr}[$kept_counter] = $junctions_file{$chr}[$i][3];
                        $kept_junctions_scores{$chr}[$kept_counter] = $junctions_file{$chr}[$i][2];
                        $kept_counter++;
                    }
                    while ($junctions_file{$chr}[$start][1] < $junctions_file{$chr}[$i][0] && $start < $junction_num{$chr}) {
                        $start++;
                    }		    
                }
            }
        }
        my @ARRAY;
        $ARRAY[0] = \%kept_junctions;
        $ARRAY[1] = \%kept_junctions_scores;
        return \@ARRAY;
    }

    sub cmpExons () {
        my $exon1 = $a;
        my $exon2 = $b;

        $exon1 =~ /^(.*):(\d+)-(\d+)$/;
        my $c1 = $1;
        my $s1 = $2;
        my $e1 = $3;
        $exon2 =~ /^(.*):(\d+)-(\d+)$/;
        my $c2 = $1;
        my $s2 = $2;
        my $e2 = $3;

        if ($c1 ne $c2) {
            if (&cmpChrs2($c1,$c2) == 1) {
                return 1;
            }
            if (&cmpChrs2($c1,$c2) == -1) {
                return -1;
            }
        } else {
            if ($s1 < $s2) {
                return -1;
            }
            if ($s1 > $s2) {
                return 1;
            }
            if ($s1 == $s2) {
                if ($e1 < $e2) {
                    return -1;
                }
                if ($e1 > $e2) {
                    return 1;
                }
            }
        }
        return 1;
    }

    sub cmpChrs2 () {
        my ($c1, $c2) = @_;
        my %temphash;
        $temphash{$c1}=1;
        $temphash{$c2}=1;
        foreach my $tempkey (sort {cmpChrs($a,$b)} keys %temphash) {
            if ($tempkey eq $c1) {
                return 1;
            } else {
                return -1;
            }
        }
    }

}

1;
