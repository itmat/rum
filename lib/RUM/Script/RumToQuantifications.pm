package RUM::Script::RumToQuantifications;

use strict;
use autodie;
no warnings;

use RUM::Usage;
use RUM::Common qw(roman Roman isroman arabic);
use RUM::Sort qw(cmpChrs);
use RUM::Script::QuantifyExons;
use RUM::RUMIO;

use base 'RUM::Script::Base';

my $sepout = "false";
my $posonly;
my $countsonly;
my $anti;
my $infofile;

my %TRANSCRIPT;
my %EXON_temp;
my %INTRON_temp;
my %cnt;
my %tcnt;
my %ecnt;
my %icnt;
my %NUREADS;
my $UREADS=0;
my %EXON;
my %INTRON;


my %strand_for_user_strand = (
    p => '+',
    m => '-',
    '' => undef);

sub main {

    my $self = __PACKAGE__->new;

    my $outfile2;
    
    my $annotfile;
    my $U_readsfile;
    my $NU_readsfile;
    my $outfile1;

    undef %TRANSCRIPT;
    undef %EXON_temp;
    undef %INTRON_temp;
    undef %cnt;
    undef %tcnt;
    undef %ecnt;
    undef %icnt;
    undef %NUREADS;
    undef $UREADS;
    undef %EXON;
    undef %INTRON;
    
    $annotfile = "";
    $U_readsfile = "";
    $NU_readsfile = "";
    $outfile1 = "";

    $sepout = "false";
    undef $posonly;
    undef $countsonly;
    undef $anti;

    $self->get_options(
        "genes-in=s"      => \$annotfile,
        "unique-in=s"     => \$U_readsfile,
        "non-unique-in=s" => \$NU_readsfile,
        "output|o=s"      => \$outfile1,
        "sepout=s"        => \$outfile2,
        "strand=s"        => \(my $strand),
        "posonly"         => \$posonly,
        "countsonly"      => \$countsonly,
        "anti"            => \$anti,
        "info=s"          => \$infofile);

    $annotfile or RUM::Usage->bad(
        "Please provide a gene annotation file with --genes-in");
    $U_readsfile or RUM::Usage->bad(
        "Please provide a sorted file of unique mappers with --unique-in");
    $NU_readsfile or RUM::Usage->bad(
        "Please provide a sorted file of non-unique mappers with ".
            "--non-unique-in");
    $outfile1 or RUM::Usage->bad(
        "Please specify an output file with --output or -o");

    if ($outfile2) {
        $sepout = "true";
    }


    if ($strand) {
        $strand = $strand_for_user_strand{$strand} or RUM::Usage->bad(
            "--strand must be either 'p' or 'm', not '$strand'");
    }

    # read in the info file, if given

    my %INFO;
    if ($infofile) {
        open INFILE, "<", $infofile;
        while (my $line = <INFILE>) {
            chomp($line);
            my @a = split(/\t/,$line);
            $INFO{$a[0]} = $a[1];
        }
        close(INFILE);
    }

    # read in the transcript models

    open INFILE, "<", $annotfile;
    while (my $line = <INFILE>) {
        chomp($line);
        my @a = split(/\t/,$line);

        my $STRAND = $a[1];
        next if $strand && $strand ne $STRAND;

        $a[5] =~ s/\s*,\s*$//;
        $a[6] =~ s/\s*,\s*$//;
        my $chr = $a[0];
        $tcnt{$chr}=$tcnt{$chr}+0;
        $TRANSCRIPT{$chr}[$tcnt{$chr}]{strand} = $a[1];
        $TRANSCRIPT{$chr}[$tcnt{$chr}]{num} = $a[4];
        $TRANSCRIPT{$chr}[$tcnt{$chr}]{start} = $a[2]+1; # add one to convert to one-based coords
        $TRANSCRIPT{$chr}[$tcnt{$chr}]{end} = $a[3];
        my @s = split(/,/,$a[5]);
        my @e = split(/,/,$a[6]);
        my @c;
        my $transcript_length=0;
        for (my $i=0; $i<@s; $i++) {
            $TRANSCRIPT{$chr}[$tcnt{$chr}]{coords}[2*$i]=$s[$i]+1; # add one to convert to one-based coords
            $TRANSCRIPT{$chr}[$tcnt{$chr}]{coords}[2*$i+1]=$e[$i];
            my $S = $s[$i]+1;
            my $E = $chr . ":" . $S . "-" . $e[$i];
            $transcript_length = $transcript_length + $e[$i] - $S + 1;
            $EXON_temp{$chr}{$E}{start} = $S;
            $EXON_temp{$chr}{$E}{end} = $e[$i];
            if ($i < @s-1) {
                my $s2 = $e[$i]+1;
                my $e2 = $s[$i+1];
                my $E = $chr . ":" . $s2 . "-" . $e2;
                $INTRON_temp{$chr}{$E}{start} = $s2;
                $INTRON_temp{$chr}{$E}{end} = $e2;
            }
        }
        $TRANSCRIPT{$chr}[$tcnt{$chr}]{length} = $transcript_length;
        $TRANSCRIPT{$chr}[$tcnt{$chr}]{id} = $a[7];
        $tcnt{$chr}++;
    }
    close(INFILE);

    foreach my $chr (sort {cmpChrs($a,$b)} keys %EXON_temp) {
        $ecnt{$chr} = 0;
        foreach my $exon (sort {$EXON_temp{$chr}{$a}{start} <=> $EXON_temp{$chr}{$b}{start}} keys %{$EXON_temp{$chr}}) {
            $EXON{$chr}[$ecnt{$chr}]{start} = $EXON_temp{$chr}{$exon}{start};
            $EXON{$chr}[$ecnt{$chr}]{end} = $EXON_temp{$chr}{$exon}{end};
            $EXON{$chr}[$ecnt{$chr}]{exon} = $exon;
            $ecnt{$chr}++;
        }
    }

    foreach my $chr (sort {cmpChrs($a,$b)} keys %INTRON_temp) {
        $icnt{$chr} = 0;
        foreach my $intron (sort {$INTRON_temp{$chr}{$a}{start} <=> $INTRON_temp{$chr}{$b}{start}} keys %{$INTRON_temp{$chr}}) {
            $INTRON{$chr}[$icnt{$chr}]{start} = $INTRON_temp{$chr}{$intron}{start};
            $INTRON{$chr}[$icnt{$chr}]{end} = $INTRON_temp{$chr}{$intron}{end};
            $INTRON{$chr}[$icnt{$chr}]{intron} = $intron;
            $icnt{$chr}++;
        }
    }

    &_readfile($U_readsfile, "Ucount", $strand);
    &_readfile($NU_readsfile, "NUcount", $strand);

    my %EXONhash;
    foreach my $chr (sort {cmpChrs($a,$b)} keys %EXON) {
        for (my $i=0; $i<$ecnt{$chr}; $i++) {
            my $x1 = $EXON{$chr}[$i]{Ucount}+0;
            my $x2 = $EXON{$chr}[$i]{NUcount}+0;
            my $y = $EXON{$chr}[$i]{id};
            my $s = $EXON{$chr}[$i]{start};
            my $e = $EXON{$chr}[$i]{end};
            my $exon = $chr . ":" . $EXON{$chr}[$i]{start} . "-" . $EXON{$chr}[$i]{end};
            $EXONhash{$exon}{u} = $x1;
            $EXONhash{$exon}{nu} = $x2;
        }
    }
    my %INTRONhash;
    foreach my $chr (sort {cmpChrs($a,$b)} keys %INTRON) {
        for (my $i=0; $i<$icnt{$chr}; $i++) {
            my $x1 = $INTRON{$chr}[$i]{Ucount}+0;
            my $x2 = $INTRON{$chr}[$i]{NUcount}+0;
            my $y = $INTRON{$chr}[$i]{id};
            my $s = $INTRON{$chr}[$i]{start};
            my $e = $INTRON{$chr}[$i]{end};
            my $intron = $chr . ":" . $INTRON{$chr}[$i]{start} . "-" . $INTRON{$chr}[$i]{end};
            $INTRONhash{$intron}{u} = $x1;
            $INTRONhash{$intron}{nu} = $x2;
        }
    }

    open OUTFILE1, ">", $outfile1;
    if ($sepout eq "true") {
        open OUTFILE2, ">", $outfile2;
    }

    my $num_reads = $UREADS;
    $num_reads = $num_reads + (scalar keys %NUREADS);

    my $nr = $num_reads / 1000000;
    if ($countsonly) {
        print OUTFILE1 "num_reads = $num_reads\n";
    }
    foreach my $chr (sort {cmpChrs($a,$b)} keys %TRANSCRIPT) {
        for (my $i=0; $i<$tcnt{$chr}; $i++) {
            my $x1 = $TRANSCRIPT{$chr}[$i]{Ucount}+0;
            my $x2 = $TRANSCRIPT{$chr}[$i]{NUcount}+0;
            my $y = $TRANSCRIPT{$chr}[$i]{id};
            my $s = $TRANSCRIPT{$chr}[$i]{start};
            my $e = $TRANSCRIPT{$chr}[$i]{end};
            my $st = $TRANSCRIPT{$chr}[$i]{strand};
            my $z = $x1 + $x2;
            my $nl = $TRANSCRIPT{$chr}[$i]{length} / 1000;
            my $n1;
            my $n2;
            if ($nl == 0 || $nr == 0) {
                $n1=0;
                $n2=0;
            } else {
                $n1 = int($x1 / $nl / $nr * 10000) / 10000;
                $n2 = int($z / $nl / $nr * 10000) / 10000;
            }
            if ((!$posonly) || $z > 0) {
                if (!$countsonly) {
                    print OUTFILE1 "--------------------------------------------------------------------\n";
                    if ($sepout eq "true") {
                        print OUTFILE2 "--------------------------------------------------------------------\n";
                    }
                }
                my $tlen = $TRANSCRIPT{$chr}[$i]{length};
                if (!$countsonly) {
                    if ($sepout eq "true") {
                        print OUTFILE1 "$y\t$st\n";
                        print OUTFILE1 "      Type\tLocation           \tCount\tAve_Cnt\tRPKM\tLength\n";
                        print OUTFILE2 "$y\t$st\n";
                        print OUTFILE2 "      Type\tLocation           \tCount\tAve_Cnt\tRPKM\tLength\n";
                        my $x3;
                        if ($nl == 0) {
                            $x3=0;
                        } else {
                            $x3 = int($x1 / $nl * 10000) / 10000;
                        }
                        print OUTFILE1 "transcript\t$chr:$s-$e\t$x1\t$x3\t$n1\t$tlen\t$y\n";

                        if ($nl == 0) {
                            $x3=0;
                        } else {
                            $x3 = int($z / $nl * 10000) / 10000;
                        }
                        print OUTFILE2 "transcript\t$chr:$s-$e\t$z\t$x3\t$n2\t$tlen\t$y\n";
                    } else {
                        print OUTFILE1 "$y\t$st\n";
                        print OUTFILE1 "      Type\tLocation           \tmin\tmax\tLength\n";
                        print OUTFILE1 "transcript\t$chr:$s-$e\t$n1\t$n2\t$tlen";
                        my $info = "";
                        if ($infofile) {
                            my @b = split(/:::/,$y);
                            for (my $k=0; $k<@b; $k++) {
                                $b[$k] =~ s/\(.*//;
                                $info = $INFO{$b[$k]};
                                if ($info =~ /\S/) {
                                    $k=@b;
                                }
                            }
                            print OUTFILE1 "\t$info";
                        }
                        print OUTFILE1 "\n";
                    }
                } else {
                    print OUTFILE1 "transcript\t$chr:$s-$e\t$x1\t$x2\t$tlen\t$st\t$y";
                    my $info = "";
                    if ($infofile) {
                        my @b = split(/:::/,$y);
                        for (my $k=0; $k<@b; $k++) {
                            $b[$k] =~ s/\(.*//;
                            $info = $INFO{$b[$k]};
                            if ($info =~ /\S/) {
                                $k=@b;
                            }
                        }
                        print OUTFILE1 "\t$info";
                    }
                    print OUTFILE1 "\n";
                }
                my $N = @{$TRANSCRIPT{$chr}[$i]{coords}};
                if ($st eq '+') {
                    for (my $j=0; $j<$N; $j=$j+2) {
                        my $s = $TRANSCRIPT{$chr}[$i]{coords}[$j];
                        my $e = $TRANSCRIPT{$chr}[$i]{coords}[$j+1];
                        my $exon = $chr . ":" . $s . "-" . $e;
                        my $elen = $e - $s + 1;
                        my $nl = $elen / 1000;
                        my $x1 = $EXONhash{$exon}{u};
                        my $x2 = $EXONhash{$exon}{nu};
                        my $z = $x1 + $x2;
                        my $n1;
                        my $n2;
                        if ($nl==0 || $nr==0) {
                            $n1=0;
                            $n2=0;
                        } else {
                            $n1 = int($x1 / $nl / $nr * 10000) / 10000;
                            $n2 = int($z / $nl / $nr * 10000) / 10000;
                        }
                        my $en = $j/2+1;
                        if (!$countsonly) {
                            if ($sepout eq "true") {
                                my $x3;
                                if ($nl == 0) {
                                    $x3 = 0;
                                } else {
                                    $x3 = int($x1 / $nl * 10000) / 10000;
                                }
                                print OUTFILE1 "  exon $en\t$chr:$s-$e\t$x1\t$x3\t$n1\t$elen\n";
                                if ($nl == 0) {
                                    $x3=0;
                                } else {
                                    $x3 = int($z / $nl * 10000) / 10000;
                                }
                                print OUTFILE2 "  exon $en\t$chr:$s-$e\t$z\t$x3\t$n2\t$elen\n";
                            } else {
                                print OUTFILE1 "  exon $en\t$chr:$s-$e\t$n1\t$n2\t$elen\n";
                            }
                        } else {
                            print OUTFILE1 "exon\t$chr:$s-$e\t$x1\t$x2\t$elen\n";
                        }
                        if ($j<$N-2) {
                            my $s = $TRANSCRIPT{$chr}[$i]{coords}[$j+1]+1;
                            my $e = $TRANSCRIPT{$chr}[$i]{coords}[$j+2]-1;
                            my $intron = $chr . ":" . $s . "-" . $e;
                            my $ilen = $e - $s + 1;
                            my $nl = $ilen / 1000;
                            my $x1 = $INTRONhash{$intron}{u};
                            my $x2 = $INTRONhash{$intron}{nu};
                            my $z = $x1 + $x2;
                            my $n1;
                            my $n2;
                            if ($nl==0 || $nr==0) {
                                $n1=0;
                                $n2=0;
                            } else {
                                $n1 = int($x1 / $nl / $nr * 10000) / 10000;
                                $n2 = int($z / $nl / $nr * 10000) / 10000;
                            }
                            my $en = $j/2+1;
                            if (!$countsonly) {
                                if ($sepout eq "true") {
                                    my $x3;
                                    if ($nl==0) {
                                        $x3=0;
                                    } else {
                                        $x3 = int($x1 / $nl * 10000) / 10000;
                                    }
                                    print OUTFILE1 "intron $en\t$chr:$s-$e\t$x1\t$x3\t$n1\t$ilen\n";
                                    if ($nl==0) {
                                        $x3=0;
                                    } else {
                                        $x3 = int($z / $nl * 10000) / 10000;
                                    }
                                    print OUTFILE2 "intron $en\t$chr:$s-$e\t$z\t$x3\t$n2\t$ilen\n";
                                } else {
                                    print OUTFILE1 "intron $en\t$chr:$s-$e\t$n1\t$n2\t$ilen\n";
                                }
                            } else {
                                print OUTFILE1 "intron\t$chr:$s-$e\t$x1\t$x2\t$ilen\n";
                            }
                        }
                    }
                } else {
                    for (my $j=0; $j<$N; $j=$j+2) {
                        my $s = $TRANSCRIPT{$chr}[$i]{coords}[($N-1)-($j+1)];
                        my $e = $TRANSCRIPT{$chr}[$i]{coords}[($N-1)-($j)];
                        my $exon = $chr . ":" . $s . "-" . $e;
                        my $x1 = $EXONhash{$exon}{u};
                        my $x2 = $EXONhash{$exon}{nu};
                        my $z = $x1 + $x2;
                        my $en = $j/2+1;
                        my $elen = $e - $s + 1;
                        my $nl = $elen / 1000;
                        my $n1;
                        my $n2;
                        if ($nl==0 || $nr==0) {
                            $n1 = 0;
                            $n2 = 0;
                        } else {
                            $n1 = int($x1 / $nl / $nr * 10000) / 10000;
                            $n2 = int($z / $nl / $nr * 10000) / 10000;
                        }
                        if (!$countsonly) {
                            if ($sepout eq "true") {
                                my $x3;
                                if ($nl==0) {
                                    $x3=0;
                                } else {
                                    $x3 = int($x1 / $nl * 10000) / 10000;
                                }
                                print OUTFILE1 "  exon $en\t$chr:$s-$e\t$x1\t$x3\t$n1\t$elen\n";
                                if ($nl == 0) {
                                    $x3=0;
                                } else {
                                    $x3 = int($z / $nl * 10000) / 10000;
                                }
                                print OUTFILE2 "  exon $en\t$chr:$s-$e\t$z\t$x3\t$n2\t$elen\n";
                            } else {
                                print OUTFILE1 "  exon $en\t$chr:$s-$e\t$n1\t$n2\t$elen\n";
                            }
                        } else {
                            print OUTFILE1 "exon\t$chr:$s-$e\t$x1\t$x2\t$elen\n";
                        }
                        if ($j<$N-2) {
                            my $s = $TRANSCRIPT{$chr}[$i]{coords}[($N-1)-($j+2)]+1;
                            my $e = $TRANSCRIPT{$chr}[$i]{coords}[($N-1)-($j+1)]-1;
                            my $intron = $chr . ":" . $s . "-" . $e;
                            my $ilen = $e - $s + 1;
                            my $nl = $ilen / 1000;
                            my $x1 = $INTRONhash{$intron}{u};
                            my $x2 = $INTRONhash{$intron}{nu};
                            my $z = $x1 + $x2;
                            my $n1;
                            my $n2;
                            if ($nl == 0 || $nr == 0) {
                                $n1 = 0;
                                $n2 = 0;
                            } else {
                                $n1 = int($x1 / $nl / $nr * 10000) / 10000;
                                $n2 = int($z / $nl / $nr * 10000) / 10000;
                            }
                            my $en = $j/2+1;
                            if (!$countsonly) {
                                if ($sepout eq "true") {
                                    my $x3;
                                    if ($nl == 0) {
                                        $x3 = 0;
                                    } else {
                                        $x3 = int($x1 / $nl * 10000) / 10000;
                                    }
                                    print OUTFILE1 "intron $en\t$chr:$s-$e\t$x1\t$x3\t$n1\t$ilen\n";
                                    if ($nl == 0) {
                                        $x3 = 0;
                                    } else {
                                        $x3 = int($z / $nl * 10000) / 10000;
                                    }
                                    print OUTFILE2 "intron $en\t$chr:$s-$e\t$z\t$x3\t$n2\t$ilen\n";
                                } else {
                                    print OUTFILE1 "intron $en\t$chr:$s-$e\t$n1\t$n2\t$ilen\n";
                                }
                            } else {
                                print OUTFILE1 "intron\t$chr:$s-$e\t$x1\t$x2\t$ilen\n";
                            }
                        }
                    }
                }
            }
        }
    }
}


sub _readfile {
    my ($filename, $type, $strand) = @_;
    my $iter = RUM::RUMIO->new(-file => $filename)->peekable;

    my %indexstart_t = map { ($_ => 0) } keys %TRANSCRIPT;
    my %indexstart_e = map { ($_ => 0) } keys %TRANSCRIPT;
    my %indexstart_i = map { ($_ => 0) } keys %TRANSCRIPT;

    while (my $aln = $iter->next_val) {

	my $CHR     = $aln->chromosome;
        my $STRAND  = $aln->strand;

	if ($type eq "NUcount") {
	    $NUREADS{$aln->order}=1;
	} else {
	    $UREADS++;
	}
	if ($strand) {
            next if $strand eq $STRAND &&  $anti;
            next if $strand ne $STRAND && !$anti;
	}

        my ($start, $end, @spans);
        
        if ($aln->is_mate($iter->peek)) {
            
            my $next_aln = $iter->next_val;
            
            if ($aln->strand eq "+") {
                ($start, $end) = ($aln->start, $next_aln->end);
                @spans = (@{ $aln->locs }, 
                          @{ $next_aln->locs });
            } else {
                ($start, $end) = ($next_aln->start, $aln->end);
                @spans = (@{ $next_aln->locs }, 
                          @{ $aln->locs });
            }
        } else {
            ($start, $end) = ($aln->start, $aln->end);
            @spans = @{ $aln->locs };
        }
        my @flattened_spans = map { @$_ } @spans;

	while ($TRANSCRIPT{$CHR}[$indexstart_t{$CHR}]{end} < $start && $indexstart_t{$CHR} <= $tcnt{$CHR}) {
	    $indexstart_t{$CHR}++;	
	}
	while ($EXON{$CHR}[$indexstart_e{$CHR}]{end} < $start && $indexstart_e{$CHR} <= $ecnt{$CHR}) {
	    $indexstart_e{$CHR}++;	
	}
	while ($INTRON{$CHR}[$indexstart_i{$CHR}]{end} < $start && $indexstart_i{$CHR} <= $icnt{$CHR}) {
	    $indexstart_i{$CHR}++;	
	}
	my $i = $indexstart_t{$CHR};
	my $flag = 0;
	while ($flag == 0) {
	    $tcnt{$CHR} = $tcnt{$CHR}+0;
	    last if $end < $TRANSCRIPT{$CHR}[$i]{start} || $i >= $tcnt{$CHR};
	    if (RUM::Script::QuantifyExons::do_they_overlap($TRANSCRIPT{$CHR}[$i]{coords}, \@flattened_spans)) {
		$TRANSCRIPT{$CHR}[$i]{$type}++;
	    }
	    $i++;
	}
	$i = $indexstart_e{$CHR};
	$flag = 0;
	while ($flag == 0) {
	    $ecnt{$CHR} = $ecnt{$CHR}+0;
	    last if $end < $EXON{$CHR}[$i]{start} || $i >= $ecnt{$CHR};
	    if (RUM::Script::QuantifyExons::do_they_overlap([$EXON{$CHR}[$i]{start}, $EXON{$CHR}[$i]{end}], \@flattened_spans)) {
		$EXON{$CHR}[$i]{$type}++;
	    }
	    $i++;
	}
	$i = $indexstart_i{$CHR};
	$flag = 0;
	while ($flag == 0) {
	    $icnt{$CHR} = $icnt{$CHR}+0;
	    last if $end < $INTRON{$CHR}[$i]{start} || $i >= $icnt{$CHR};
	    if (RUM::Script::QuantifyExons::do_they_overlap([$INTRON{$CHR}[$i]{start}, $INTRON{$CHR}[$i]{end}], \@flattened_spans)) {
		$INTRON{$CHR}[$i]{$type}++;
	    }
	    $i++;
	}
    }
}

1;

__END__

=head1 NAME

RUM::Script::RumToQuantifications - Convert a RUM file to a quantifications file

=head1 METHODS

=over 4

=item RUM::Script::RumToQuantifications->main

Run the script.

=back

=head1 AUTHORS

Gregory Grant (ggrant@grant.org)

Mike DeLaurentis (delaurentis@gmail.com)

=head1 COPYRIGHT

Copyright 2012, University of Pennsylvania


