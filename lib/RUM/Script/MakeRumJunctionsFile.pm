package RUM::Script::MakeRumJunctionsFile;

no warnings;

use RUM::Logging;
use RUM::CommonProperties;

our $log = RUM::Logging->get_logger();

use base 'RUM::Script::Base';

sub summary {
    'Make RUM junctions file'
}

sub description {
    return <<'EOF';

This script finds the junctions in the RUM_Unique and RUM_NU files
and reports them to a junctions file that can be uploaded to the UCSC
browser.

In the high quality junctions, junctions in the annotation file are
colored blue, others are colored green.  Those with standard splice
signals (or those specified by -signal) are colored a shade lighter.
EOF
}

sub accepted_options {
    return (
        RUM::CommonProperties->unique_in->set_required,
        RUM::CommonProperties->non_unique_in->set_required,
        RUM::CommonProperties->genome->set_required,
        RUM::Property->new(
            opt => 'genes=s',
            desc => 'The RUM gene models file; omit there are no known gene
models'),
        RUM::Property->new(
            opt => 'all-rum-out=s',
            desc => 'The output file for all junctions in RUM format.',
            required => 1),
        RUM::Property->new(
            opt => 'all-bed-out=s',
            desc => 'The output file for all junctions in BED format.',
            required => 1),
        RUM::Property->new(
            opt => 'high-bed-out=s',
            desc => 'The output file for high-quality junctions in BED format.',
            required => 1),
        RUM::CommonProperties->faok,
        RUM::CommonProperties->strand,
        RUM::Property->new(
            opt => 'signal=s',
            desc => 'Use this alternate splice signal; wx is the donor and yz is the acceptor. Multiple may be specified, separated by commas without whitespace. If not specified, the standard signals will be used, with the canonical colored darker in the high quality junctions file.'),
        RUM::Property->new(
            opt => 'minintron=s',
            desc => 'The size of the smallest intron allowed. Must be > 0',
            default => 15,
            check => \&RUM::CommonProperties::check_int_gte_0
            ),
        RUM::Property->new(
            opt => 'overlap=s',
            desc => 'There must be at least this many bases spanning either side of a junction to qualify as high quality.',
            default => 8
        ));

}

sub run {

    my ($self) = @_;
    my $props = $self->properties;
    my $rumU = $props->get('unique_in');
    my $rumNU = $props->get('non_unique_in');
    my $genome_sequence = $props->get('genome');
    my $gene_annot = $props->get('genes');

    my $outfile1 = $props->get('all_rum_out');
    my $outfile2 = $props->get('all_bed_out');
    my $outfile3 = $props->get('high_bed_out');
    my $faok     = $props->get('faok');
    my $userstrand   = $props->get('strand');
    my $signal   = $props->get('signal');
    my $minintron = $props->get('minintron');
    my $allowable_overlap = $props->get('overlap');

    # Written by Gregory R. Grant
    # University of Pennsylvania, 2010

    # Splice Junctions:
    # ----------------
    # The Canonical:
    #  GTAG
    $donor[0] = "GT";
    $donor_rev[0] = "AC";
    $acceptor[0] = "AG";
    $acceptor_rev[0] = "CT";
    # Other Characterized:
    #  GCAG
    $donor[1] = "GC";
    $donor_rev[1] = "GC";
    $acceptor[1] = "AG";
    $acceptor_rev[1] = "CT";
    #  GCTG
    $donor[2] = "GC";
    $donor_rev[2] = "GC";
    $acceptor[2] = "TG";
    $acceptor_rev[2] = "CA";
    #  GCAA
    $donor[3] = "GC";
    $donor_rev[3] = "GC";
    $acceptor[3] = "AA";
    $acceptor_rev[3] = "TT";
    #  GCCG
    $donor[4] = "GC";
    $donor_rev[4] = "GC";
    $acceptor[4] = "CG";
    $acceptor_rev[4] = "CG";
    #  GTTG
    $donor[5] = "GT";
    $donor_rev[5] = "AC";
    $acceptor[5] = "TG";
    $acceptor_rev[5] = "CA";
    #  GTAA
    $donor[6] = "GT";
    $donor_rev[6] = "AC";
    $acceptor[6] = "AA";
    $acceptor_rev[6] = "TT";
    # U12-dependent:
    #  ATAC
    $donor[7] = "AT";
    $donor_rev[7] = "AT";
    $acceptor[7] = "AC";
    $acceptor_rev[7] = "GT";
    #  ATAA
    $donor[8] = "AT";
    $donor_rev[8] = "AT";
    $acceptor[8] = "AA";
    $acceptor_rev[8] = "TT";
    #  ATAG
    $donor[9] = "AT";
    $donor_rev[9] = "AT";
    $acceptor[9] = "AG";
    $acceptor_rev[9] = "CT";
    #  ATAT
    $donor[10] = "AT";
    $donor_rev[10] = "AT";
    $acceptor[10] = "AT";
    $acceptor_rev[10] = "AT";

    #  TAGA
    $donor[11] = "TA";
    $donor_rev[11] = "TA";
    $acceptor[11] = "GA";
    $acceptor_rev[11] = "TC";

    $|=1;

    # print "\nMaking junctions files...\n";

    $strand = "+"; # the default if unspecified, will basically ignore
                   # strand in this case
    $strandspecified = "false";

    my @argv = @ARGV;

    open OUTFILE1, '>', $outfile1;
    open OUTFILE2, '>', $outfile2;
    open OUTFILE3, '>', $outfile3;

    if ($userstrand) {
        $strandspecified = "true";
        $arg = $userstrand;
        if ($arg eq "p") {
            $strand = "+";
        } elsif ($arg eq "m") {
            $strand = "-";
        } else {
            RUM::Usage->bad("--strand must be either \"p\" or \"m\"");
        }
    }

    if ($signal) {

        @AR = split(/,/,$signal);
        undef @donor;
        undef @donor_rev;
        undef @acceptor;
        undef @acceptor_rev;
        for ($j=0; $j<@AR; $j++) {
            if ($AR[$j] =~ /^([ACGT][ACGT])([ACGT][ACGT])$/) {
                $donor[$j] = $1;
                $acceptor[$j] = $2;
                $donor_rev[$j] = reversesignal($donor[$j]);
                $acceptor_rev[$j] = reversesignal($acceptor[$j]);
            } else {
                die "\nError: in scritp make_RUM_junctions_file.pl: the -signal argument is misformatted, check signal $i: '$AR[$j]'\n\n";
            }
        }
        $optionrecognized = 1;
    }    

    $minintron =~ /^\d+$/ && $minintron > 0 or RUM::Usage->bad(
        "--minintron must be an integer greater than zero, ".
            "you gave '$minintron'");

    $allowable_overlap =~ /^\d+$/ && $allowable_overlap > 0 or RUM::Usage->bad(
        "--overlap must be an integer greater than zero, ".
            "you gave '$allowable_overlap'");

    if ($strandspecified eq 'true') {
        print OUTFILE1 "intron\tstrand\tscore\tknown\tstandard_splice_signal\tsignal_not_canonical\tambiguous\tlong_overlap_unique_reads\tshort_overlap_unique_reads\tlong_overlap_nu_reads\tshort_overlap_nu_reads\n";
        if ($strand eq "+") {
            print OUTFILE2 "track\tname=rum_junctions_pos-strand_all\tvisibility=3\tdescription=\"RUM junctions pos strand (all)\" itemRgb=\"On\"\n";
            print OUTFILE3 "track\tname=rum_junctions_pos-strand_hq\tvisibility=3\tdescription=\"RUM high quality junctions pos strand\" itemRgb=\"On\"\n";
        }
        if ($strand eq "-") {
            print OUTFILE2 "track\tname=rum_junctions_neg-strand_all\tvisibility=3\tdescription=\"RUM junctions neg strand (all)\" itemRgb=\"On\"\n";
            print OUTFILE3 "track\tname=rum_junctions_neg-strand_hq\tvisibility=3\tdescription=\"RUM high quality junctions neg strand\" itemRgb=\"On\"\n";
        }
    }
    if ($strandspecified eq 'false') {
        print OUTFILE1 "intron\tstrand\tscore\tknown\tstandard_splice_signal\tsignal_not_canonical\tambiguous\tlong_overlap_unique_reads\tshort_overlap_unique_reads\tlong_overlap_nu_reads\tshort_overlap_nu_reads\n";
        print OUTFILE2 "track\tname=rum_junctions_all\tvisibility=3\tdescription=\"RUM junctions (all)\" itemRgb=\"On\"\n";
        print OUTFILE3 "track\tname=rum_junctions_hq\tvisibility=3\tdescription=\"RUM high quality junctions\" itemRgb=\"On\"\n";
    }

    # read in known junctions to color them green in the hq track:

    if ($gene_annot ne "none") {
        open(INFILE, $gene_annot) or die "\nError: in script make_RUM_junctions_file.pl: cannot open file '$gene_annot' for reading\n\n";
        while ($line = <INFILE>) {
            @a = split(/\t/, $line);
            if ($strand eq "-" && $a[1] eq "+") {
                next;
            }
            if ($strand eq "+" && $a[1] eq "-" && $strandspecified eq 'true') {
                next;
            }
            $chr = $a[0];
            $a[5] =~ s/\s*,\s*$//;
            $a[6] =~ s/\s*,\s*$//;
            $a[5] =~ s/^\s*,\s*//;
            $a[6] =~ s/^\s*,\s*//;
            @starts = split(/\s*,\s*/,$a[5]);
            @ends = split(/\s*,\s*/,$a[6]);
            for ($i=0; $i<@starts-1; $i++) {
                $S = $ends[$i] + 1;
                $E = $starts[$i+1];
                $intron = $chr . ":" . $S . "-" . $E;
                $knownintron{$intron} = 1;
            }
        }
        close(INFILE);
    }

    if (!$faok) {
        print "Modifying genome fa file\n";
        $r = int(rand(1000));
        $f = "temp_" . $r . ".fa";
        `perl modify_fa_to_have_seq_on_one_line.pl $genome_sequence > $f`;
        open(GENOMESEQ, $f) or die "\nError: in script make_RUM_junctions_file.pl: cannot open file '$f' for reading\n\n";
    } else {
        open(GENOMESEQ, $genome_sequence) or die "\nError: in script make_RUM_junctions_file.pl: cannot open file '$genome_sequence' for reading\n\n";
    }

    # DEBUG
    # for($i=0; $i<@donor; $i++) {
    #     print "donor[$i] = $donor[$i]\n";
    #     print "donor_rev[$i] = $donor_rev[$i]\n";
    # }
    # for($i=0; $i<@acceptor; $i++) {
    #     print "acceptor[$i] = $acceptor[$i]\n";
    #     print "acceptor_rev[$i] = $acceptor_rev[$i]\n";
    # }
    # exit();
    # DEBUG

    $FLAG = 0;
    while ($FLAG == 0) {

        undef %CHR2SEQ;
        undef %allintrons;
        undef @amb;
        undef @badoverlapU;
        undef @goodoverlapU;
        undef @badoverlapNU;
        undef @goodoverlapNU;

        $sizeflag = 0;
        $totalsize = 0;
        while ($sizeflag == 0) {

            $line = <GENOMESEQ>;
            if ($line eq '') {
                $FLAG = 1;
                $sizeflag = 1;
            } else {
                chomp($line);
                $line =~ />(.*)/;
                $chr = $1;
                $chr =~ s/:[^:]*$//;
                $ref_seq = <GENOMESEQ>;
                chomp($ref_seq);
                $CHR2SEQ{$chr} = $ref_seq;
                $CHR2SIZE{$chr} = length($ref_seq);
                $totalsize = $totalsize + $CHR2SIZE{$chr};
                if ($totalsize > 1000000000) { # don't store more than 1 gb of sequence in memory at once...
                    $sizeflag = 1;
                }
            }
        }
        &getjunctions();
        &printjunctions();
    }
    close(GENOMESEQ);

    sub printjunctions () {

        foreach $intron (keys %allintrons) {
            $amb{$intron} = $amb{$intron} + 0;
            $badoverlapU{$intron} = $badoverlapU{$intron} + 0;
            $goodoverlapU{$intron} = $goodoverlapU{$intron} + 0;
            $badoverlapNU{$intron} = $badoverlapNU{$intron} + 0;
            $goodoverlapNU{$intron} = $goodoverlapNU{$intron} + 0;
            $knownintron{$intron} = $knownintron{$intron} + 0;

            # chromosome
            # start seg 1: 50 bases upstream from junction start
            # start seg 2: 50 bases upstream from junction end
            # score: goodoverlap_badoverlap
            # 50
            # +
            # start seg 1: 50 bases upstream from junction start (again)
            # start seg 2: 50 bases upstream from junction end (again)
            # 
            # Color:
            #    0,0,128 NAVY (for high quality)
            #    255,69,0 RED (for low quality)
            # 2
            # 50,50
            # 0, intron_length + 50
 
            $intron =~ /^(.*):(\d+)-(\d+)$/;
            $chr = $1;
            $start = $2 - 1;
            $end = $3;
            $end2 = $end + 50;
            $start2 = $start - 50;
            $ilen = $end - $start + 50;
            $LEN1 = 50;
            $LEN2 = 50;
            if ($start2 < 0) {
                $adjust = $start2;
                $start2 = 0;
                $LEN1 = $LEN1 + $adjust;
                $ilen = $ilen + $adjust;
            }
            if ($end2 >= $CHR2SIZE{$chr}) {
                $adjust = $end2 - $CHR2SIZE{$chr} + 1;
                $end2 = $end2 - $adjust;
                $LEN2 = $LEN2 - $adjust;
            }
            if ($goodsplicesignal{$intron} > 0) {
                $goodsplicesignal{$intron} = 1;
            }
            $known_noncanonical_signal{$intron} = $known_noncanonical_signal{$intron} + 0;
            $STRAND = $intronstrand{$intron};
            if (!($STRAND =~ /\S/)) {
                $STRAND = ".";
            }
            if ($goodoverlapU{$intron} > 0 && $goodsplicesignal{$intron} == 1) {
                $goodsplicesignal{$intron} = $goodsplicesignal{$intron} + 0;
                $N = $goodoverlapU{$intron} + $goodsplicesignal{$intron} - 1;
                if ($strandspecified eq 'true') {
                    print OUTFILE1 "$intron\t$strand\t$N\t$knownintron{$intron}\t$goodsplicesignal{$intron}\t$known_noncanonical_signal{$intron}\t$amb{$intron}\t$goodoverlapU{$intron}\t$badoverlapU{$intron}\t$goodoverlapNU{$intron}\t$badoverlapNU{$intron}\n";
                    print OUTFILE2 "$chr\t$start2\t$end2\t$N\t$N\t$strand\t$start2\t$end2\t0,0,128\t2\t$LEN1,$LEN2\t0,$ilen\n";
                } else {
                    print OUTFILE1 "$intron\t$STRAND\t$N\t$knownintron{$intron}\t$goodsplicesignal{$intron}\t$known_noncanonical_signal{$intron}\t$amb{$intron}\t$goodoverlapU{$intron}\t$badoverlapU{$intron}\t$goodoverlapNU{$intron}\t$badoverlapNU{$intron}\n";
                    print OUTFILE2 "$chr\t$start2\t$end2\t$N\t$N\t$STRAND\t$start2\t$end2\t0,0,128\t2\t$LEN1,$LEN2\t0,$ilen\n";
                }
                if ($knownintron{$intron}==1) {
                    if ($known_noncanonical_signal{$intron}+0==1) {
                        print OUTFILE3 "$chr\t$start2\t$end2\t$N\t$N\t$STRAND\t$start2\t$end2\t24,116,205\t2\t$LEN1,$LEN2\t0,$ilen\n";
                    } else {
                        print OUTFILE3 "$chr\t$start2\t$end2\t$N\t$N\t$STRAND\t$start2\t$end2\t16,78,139\t2\t$LEN1,$LEN2\t0,$ilen\n";
                    }
                } else {
                    if ($known_noncanonical_signal{$intron}+0==1) {
                        print OUTFILE3 "$chr\t$start2\t$end2\t$N\t$N\t$STRAND\t$start2\t$end2\t0,255,127\t2\t$LEN1,$LEN2\t0,$ilen\n";
                    } else {
                        print OUTFILE3 "$chr\t$start2\t$end2\t$N\t$N\t$STRAND\t$start2\t$end2\t0,205,102\t2\t$LEN1,$LEN2\t0,$ilen\n";
                    }
                }
            } else {
                if ($strandspecified eq 'true') {
                    $goodsplicesignal{$intron} = $goodsplicesignal{$intron} + 0;
                    print OUTFILE1 "$intron\t$strand\t0\t$knownintron{$intron}\t$goodsplicesignal{$intron}\t$known_noncanonical_signal{$intron}\t$amb{$intron}\t$goodoverlapU{$intron}\t$badoverlapU{$intron}\t$goodoverlapNU{$intron}\t$badoverlapNU{$intron}\n";
                } else {
                    $goodsplicesignal{$intron} = $goodsplicesignal{$intron} + 0;
                    print OUTFILE1 "$intron\t$STRAND\t0\t$knownintron{$intron}\t$goodsplicesignal{$intron}\t$known_noncanonical_signal{$intron}\t$amb{$intron}\t$goodoverlapU{$intron}\t$badoverlapU{$intron}\t$goodoverlapNU{$intron}\t$badoverlapNU{$intron}\n";
                }
                $NN = $goodoverlapU{$intron} + $goodoverlapNU{$intron} + $badoverlapU{$intron} + $badoverlapNU{$intron};
                print OUTFILE2 "$chr\t$start2\t$end2\t$NN\t$NN\t$STRAND\t$start2\t$end2\t255,69,0\t2\t$LEN1,$LEN2\t0,$ilen\n";
            }
        }
    }

    # chr2    181747872       181748112       0       0       +       181747872       181748112       255,69,0    50,50    0,190
    # 181748087


    sub getjunctions () {
        undef %allintrons;
        undef %goodsplicesignal;
        undef %amb;
        undef %badoverlapU;
        undef %badoverlapNU;
        undef %goodoverlapU;
        undef %goodoverlapNU;
            
        open(INFILE, $rumU) or die "\nError: in script make_RUM_junctions_file.pl: cannot open file '$rumU' for reading\n\n";
        #    print "please wait...\n";
        while ($line = <INFILE>) {

            if (!($line =~ /, /)) {
                next;
            }
            chomp($line);
            @a = split(/\t/,$line);
            if ($strand eq "-" && $a[3] eq "+") {
                next;
            }
            if ($strand eq "+" && $a[3] eq "-" && $strandspecified eq 'true') {
                next;
            }
            $chr = $a[1];
            if (!(defined $CHR2SEQ{$chr})) {
                next;
            }
            $seq = $a[4];
            while ($seq =~ /^([^+]*)\+/) { # removing the insertions
                $pref = $1;
                $seq =~ s/^$pref\+[^+]+\+/$pref/;
            }
            @SPANS = split(/, /,$a[2]);
            @SEQ = split(/:/, $seq);
            for ($i=0; $i<@SPANS-1; $i++) {
                @c1 = split(/-/,$SPANS[$i]);
                @c2 = split(/-/,$SPANS[$i+1]);
                $elen1 = $c1[1] - $c1[0] + 1;
                $elen2 = $c2[1] - $c2[0] + 1;
                $ilen = $c2[0] - $c1[1] - 1;
                $istart = $c1[1]+1;
                $iend = $c2[0]-1;
                $intron = $chr . ":" . $istart . "-" . $iend;
                $altintron = "";
                if ($ilen >= $minintron) {
                    $allintrons{$intron} = 1;
                    if (!(defined $amb{$intron}) || !($goodsplicesignal{$intron})) {
                        $SEQ[$i] =~ /(.)$/;
                        $leftexon_lastbase = $1;
                        $SEQ[$i+1] =~ /^(.)/;
                        $rightexon_firstbase = $1;
                        $intron_firstbase = substr($CHR2SEQ{$chr}, $istart-1, 1);
                        $intron_lastbase = substr($CHR2SEQ{$chr}, $iend-1, 1);
                        $splice_signal_upstream = substr($CHR2SEQ{$chr}, $istart-1, 2);
                        $splice_signal_downstream = substr($CHR2SEQ{$chr}, $iend-2, 2);
                        $goodsplicesignal{$intron} = $goodsplicesignal{$intron} + 0;
                        for ($sig=0; $sig<@donor; $sig++) {
                            if (($splice_signal_upstream eq $donor[$sig] && $splice_signal_downstream eq $acceptor[$sig]) || ($splice_signal_upstream eq $acceptor_rev[$sig] && $splice_signal_downstream eq $donor_rev[$sig])) {
                                $goodsplicesignal{$intron} = $goodsplicesignal{$intron} + 1;
                                if ($sig>0) {
                                    $known_noncanonical_signal{$intron} = 1;
                                }
                                if (($splice_signal_upstream eq $donor[$sig] && $splice_signal_downstream eq $acceptor[$sig])) {
                                    $intronstrand{$intron} = "+";
                                } else {
                                    $intronstrand{$intron} = "-";
                                }
                            } else {
                                $goodsplicesignal{$intron} = $goodsplicesignal{$intron} + 0;
                            }
                        }
                        if ($leftexon_lastbase eq $intron_lastbase) {
                            $istart_alt = $istart-1;
                            $iend_alt = $iend-1;
                            $altintron = $chr . ":" . $istart_alt . "-" . $iend_alt;
                            $amb{$intron}=1; # amb for ambiguous
                            $amb{$altintron}=1;
                            $allintrons{$altintron} = 1;
                        }
                        if ($rightexon_firstbase eq $intron_firstbase) {
                            $istart_alt = $istart+1;
                            $iend_alt = $iend+1;
                            $altintron = $chr . ":" . $istart_alt . "-" . $iend_alt;
                            $amb{$intron}=1; # amb for ambiguous
                            $amb{$altintron}=1;
                            $allintrons{$altintron} = 1;
                        }
                    }
                    if ($elen1 < $allowable_overlap || $elen2 < $allowable_overlap) {
                        $badoverlapU{$intron}++;
                        if ($altintron =~ /\S/) {
                            $badoverlapU{$altintron}++;			    
                        }
                    } else {
                        $goodoverlapU{$intron}++;
                        if ($altintron =~ /\S/) {
                            $goodoverlapU{$altintron}++;			    
                        }
                    }
                }
            }
        }

        close(INFILE);
        #    print STDERR "finished Unique\n";
        #    print "please wait some more...\n";
        open(INFILE, $rumNU) or die "\nError: in script make_RUM_junctions_file.pl: cannot open file '$rumNU' for reading\n\n";
        while ($line = <INFILE>) {

            if (!($line =~ /, /)) {
                next;
            }
            chomp($line);
            @a = split(/\t/,$line);
            if ($strand eq "-" && $a[3] eq "+") {
                next;
            }
            if ($strand eq "+" && $a[3] eq "-" && $strandspecified eq 'true') {
                next;
            }
            if (!(defined $CHR2SEQ{$a[1]})) {
                next;
            }
            $seq = $a[4];
            while ($seq =~ /^([^+]*)\+/) { # removing the insertions
                $pref = $1;
                $seq =~ s/^$pref\+[^+]+\+/$pref/;
            }
            $chr = $a[1];
            @SPANS = split(/, /,$a[2]);
            @SEQ = split(/:/, $seq);
            for ($i=0; $i<@SPANS-1; $i++) {
                @c1 = split(/-/,$SPANS[$i]);
                @c2 = split(/-/,$SPANS[$i+1]);
                $elen1 = $c1[1] - $c1[0] + 1;
                $elen2 = $c2[1] - $c2[0] + 1;
                $ilen = $c2[0] - $c1[1] - 1;
                $istart = $c1[1]+1;
                $iend = $c2[0]-1;
                $altintron="";
                if ($ilen >= $minintron) {
                    $intron = $chr . ":" . $istart . "-" . $iend;
                    $allintrons{$intron} = 1;
                    if (!(defined $amb{$intron})) {
                        $SEQ[$i] =~ /(.)$/;
                        $leftexon_lastbase = $1;
                        $SEQ[$i+1] =~ /^(.)/;
                        $rightexon_firstbase = $1;
                        $intron_firstbase = substr($CHR2SEQ{$chr}, $istart-1, 1);
                        $intron_lastbase = substr($CHR2SEQ{$chr}, $iend-1, 1);
                        $splice_signal_upstream = substr($CHR2SEQ{$chr}, $istart-1, 2);
                        $splice_signal_downstream = substr($CHR2SEQ{$chr}, $iend-2, 2);
                        $goodsplicesignal{$intron} = $goodsplicesignal{$intron} + 0;
                        for ($sig=0; $sig<@donor; $sig++) {
                            if (($splice_signal_upstream eq $donor[$sig] && $splice_signal_downstream eq $acceptor[$sig]) || ($splice_signal_upstream eq $acceptor_rev[$sig] && $splice_signal_downstream eq $donor_rev[$sig])) {
                                $goodsplicesignal{$intron} = $goodsplicesignal{$intron} + 1;
                                if ($sig>0) {
                                    $known_noncanonical_signal{$intron} = 1;
                                }
                                if (($splice_signal_upstream eq $donor[$sig] && $splice_signal_downstream eq $acceptor[$sig])) {
                                    $intronstrand{$intron} = "+";
                                } else {
                                    $intronstrand{$intron} = "-";
                                }
                            } else {
                                $goodsplicesignal{$intron} = $goodsplicesignal{$intron} + 0;
                            }
                        }
                        if ($leftexon_lastbase eq $intron_lastbase) {
                            $istart_alt = $istart-1;
                            $iend_alt = $iend-1;
                            $altintron = $chr . ":" . $istart_alt . "-" . $iend_alt;
                            $amb{$intron}=1; # amb for ambiguous
                            $amb{$altintron}=1;
                            $allintrons{$intron} = 1;
                        }
                        if ($rightexon_firstbase eq $intron_firstbase) {
                            $istart_alt = $istart+1;
                            $iend_alt = $iend+1;
                            $altintron = $chr . ":" . $istart_alt . "-" . $iend_alt;
                            $amb{$intron}=1; # amb for ambiguous
                            $amb{$altintron}=1;
                            $allintrons{$intron} = 1;
                        }
                    }
                    if ($elen1 < $allowable_overlap || $elen2 < $allowable_overlap) {
                        $badoverlapNU{$intron}++;
                        if ($altintron =~ /\S/) {
                            $badoverlapNU{$altintron}++;			    
                        }
                    } else {
                        $goodoverlapNU{$intron}++;
                        if ($altintron =~ /\S/) {
                            $goodoverlapNU{$altintron}++;			    
                        }
                    }
                }
            }
        }

        close(INFILE);
    }




}

1;
