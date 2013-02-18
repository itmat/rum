package RUM::Script::MakeRumJunctionsFile;

no warnings;
use RUM::Usage;
use RUM::Logging;
use Getopt::Long;

our $log = RUM::Logging->get_logger();

sub main {

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

    $strand = "+"; # the default if unspecified, will basically ignore
                   # strand in this case
    $strandspecified = "false";

    my @argv = @ARGV;

    GetOptions(
	"sam-in=s" => \(my $sam),
        "genome=s" => \(my $genome_sequence),
        "genes=s" => \(my $gene_annot),
        "all-rum-out=s" => \(my $outfile1),        
        "all-bed-out=s" => \(my $outfile2),
        "high-bed-out=s" => \(my $outfile3),
        "faok" => \(my $faok),
        "strand=s" => \(my $userstrand),
        "signal=s" => \(my $signal),
        "minintron=s" => \(my $minintron = 15),
        "overlap=s"   => \(my $allowable_overlap = 8),
        "sam-out=s" => \(my $samout),
        "help|h"    => sub { RUM::Usage->help },
        "verbose|v" => sub { $log->more_logging(1) },
        "quiet|q"   => sub { $log->less_logging(1) }
    );

    $sam or RUM::Usage->bad(
        "Please provide a sam file file with --sam-in");

    $genome_sequence or RUM::Usage->bad(
        "Please provide a genome fasta file with --genome");

    $gene_annot or RUM::Usage->bad(
        "Please provide a gene annotation file with --genes");

    $outfile1 or RUM::Usage->bad(
        "Please specify a RUM output file for all junctions ".
            "with --all-ru-out");
    $outfile2 or RUM::Usage->bad(
        "Please specify a bed output file for all junctions ".
            "with --all-bed-out");
    $outfile3 or RUM::Usage->bad(
        "Please specify a bed output file for high-quality junctions ".
            "with --high-bed-out");

    open(OUTFILE1, ">$outfile1") or die "\nError: in script make_RUM_junctions_file.pl: cannot open file '$outfile1' for writing\n\n";

    open(OUTFILE2, ">$outfile2") or die "\nError: in script make_RUM_junctions_file.pl: cannot open file '$outfile2' for writing\n\n";

    open(OUTFILE3, ">$outfile3") or die "\nError: in script make_RUM_junctions_file.pl: cannot open file '$outfile3' for writing\n\n";

    open(SAMOUT, ">$samout") or die "\nError: in script make_RUM_junctions_file.pl: cannot open file '$samout' for writing\n\n";

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
                if ($totalsize > 5000000000) { # don't store more than 1 gb of sequence in memory at once...
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

    sub getjunctions () {
        undef %allintrons;
        undef %goodsplicesignal;
        undef %amb;
        undef %badoverlapU;
        undef %badoverlapNU;
        undef %goodoverlapU;
        undef %goodoverlapNU;
            
        open(INFILE, $sam) or die "\nError: in script make_RUM_junctions_file.pl: cannot open file '$sam' for reading\n\n";
        while ($line = <INFILE>) {
	    $NU = "false";
            chomp($line);
            @a = split(/\t/,$line);
            $chr = $a[2];
            if (!($a[5] =~ /N/)) {
		print SAMOUT "$line\n";
                next;
            }
	    if($a[1] & 4) {
		print SAMOUT "$line\n";
 		next;
	    }
	    if($a[5] eq '*' || $a[5] eq '*') {
		print SAMOUT "$line\n";
 		next;
	    }
	    if($a[2] eq '.' || $a[2] eq '*') {
		print SAMOUT "$line\n";
 		next;
	    }
	    if($a[1] & 16) {
		$strand_thisread = "-";
	    } else {
		$strand_thisread = "+";
	    }
            if ($strand eq "-" && $strand_thisread eq "+") {
		print SAMOUT "$line\n";
                next;
            }
            if ($strand eq "+" && $strand_thisread eq "-" && $strandspecified eq 'true') {
		print SAMOUT "$line\n";
                next;
            }
            if (!(defined $CHR2SEQ{$chr})) {
		print SAMOUT "$line\n";
		if($undefined_chr{$chr}+0==0) {
		    $undefined_chr{$chr}=1;
		    print "Warning: chr '$chr' not in your genome sequence file.\n";
		}
                next;
            }
	    if($a[1] & 256) {
		$NU = "true";
	    }
	    if($line =~ /IH:i:(\d+)/) {
		if($1 > 1) {
		    $NU = "true";
		}
	    }
	    if($line =~ /XT:A:R/) {
		$NU = "true";
	    }
            $seq = $a[9];
            while ($seq =~ /^([^+]*)\+/) { # removing the insertions
                $pref = $1;
                $seq =~ s/^$pref\+[^+]+\+/$pref/;
            }
	    $cigarstring = $a[5];
	    $cigarlength = length($cigarstring);
	    $spans1 = cigar2spans($cigarstring, $a[3]);
	    undef @CIG;
	    undef @CIGTYPES;
	    undef @CIGTYPESALL;
	    @CIG=split(/[ND]/,$cigarstring);
	    @CIGTYPES=split(/[^ND]+/,$cigarstring);
	    @CIGTYPESALL=split(/\d+/,$cigarstring);
	    $newcigar = $CIG[0];  # the rest will be built up in the loop over SPANS below
	    undef %badN;
	    $Ncnt = -1;
	    $badflag = 0;
	    for($i=0; $i<@CIGTYPESALL; $i++) {  # I went through this rigmarole because I wanted to handle the
		                                # case where an N wasn't flanked by M's on both sides.  But in
		                                # the end it got too complicated so I just boot on any such reads.
		                                # But I left in these data structures in case anybody wants to 
		                                # revisit this later...
		if($CIGTYPESALL[$i] eq 'N') {
		    $Ncnt++;
		    if($i==0 || $i==@CIGTYPESALL-1) {
			$badN{$Ncnt}=1;
			$badflag = 1;
		    } elsif($CIGTYPESALL[$i-1] ne 'M' || $CIGTYPESALL[$i+1] ne 'M') {
			$badN{$Ncnt}=1;
			$badflag = 1;
		    }
		}
	    }
	    if($badflag == 1) {  # this is the place it just boots on reads where there's an N that's not flanked by M's on both sides.
		print SAMOUT "$line\n";
                next;
	    }
	    @SPANS = split(/, /,$spans1);
	    @SEQ = split(/:/, $seq);
	    undef @Elen;
	    undef @Elen1;
	    undef @Elen2;
	    for ($i=0; $i<@SPANS; $i++) {
		@c1 = split(/-/,$SPANS[$i]);
		$Elen[$i] = + $c1[1] - $c1[0] + 1;
		$SEQ[$i] = substr($CHR2SEQ{$chr}, $c1[0]-1, $c1[1]-$c1[0]+1);
	    }
            # now make @Elen1 which holds the length of alignment to the left of each junction
	    $Elen1[0] = $Elen[0];
	    for ($i=1; $i<@SPANS-1; $i++) {
		$Elen1[$i] = $Elen1[$i-1] + $Elen[$i];
	    }
            # now make @Elen2 which holds the length of alignment to the right of each junction
	    $Elen2[@SPANS-2] = $Elen[@SPANS-1];
	    for ($i=@SPANS-3; $i>=0; $i--) {
		$Elen2[$i] = $Elen2[$i+1] + $Elen[$i+1];
	    }
	    $Ncnt = -1;
	    for ($i=0; $i<@SPANS-1; $i++) {
		@c1 = split(/-/,$SPANS[$i]);
		@c2 = split(/-/,$SPANS[$i+1]);
		$elen1 = $Elen1[$i];
		$elen2 = $Elen2[$i];
		$ilen = $c2[0] - $c1[1] - 1;
		$istart = $c1[1]+1;
		$iend = $c2[0]-1;
		$intron = $chr . ":" . $istart . "-" . $iend;
		$altintron1 = "";
		$altintron2 = "";
		if ($CIGTYPES[$i+1] eq "N") {
		    $Ncnt++;
		}
		if ($CIGTYPES[$i+1] eq "N" && $badN{$Ncnt}+0==0) {
		    $allintrons{$intron} = 1;
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
			    $goodsplicesignal{$intron} = 1;
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
		    if($goodsplicesignal{$intron}+0 == 0) {
			if ($leftexon_lastbase eq $intron_lastbase) {
			    $istart_alt = $istart-1;
			    $iend_alt = $iend-1;
			    $altintron1 = $chr . ":" . $istart_alt . "-" . $iend_alt;
			    $allintrons{$altintron1} = 1;
			    $splice_signal_upstream = substr($CHR2SEQ{$chr}, $istart_alt-1, 2);
			    $splice_signal_downstream = substr($CHR2SEQ{$chr}, $iend_alt-2, 2);
			    for ($sig=0; $sig<@donor; $sig++) {
				if (($splice_signal_upstream eq $donor[$sig] && $splice_signal_downstream eq $acceptor[$sig]) || ($splice_signal_upstream eq $acceptor_rev[$sig] && $splice_signal_downstream eq $donor_rev[$sig])) {
				    $goodsplicesignal{$altintron1} = 1;
				    if ($sig>0) {
					$known_noncanonical_signal{$altintron1} = 1;
				    }
				    if (($splice_signal_upstream eq $donor[$sig] && $splice_signal_downstream eq $acceptor[$sig])) {
					$intronstrand{$altintron1} = "+";
				    } else {
					$intronstrand{$altintron1} = "-";
				    }
				}
			    }
			}
			if ($rightexon_firstbase eq $intron_firstbase) {
			    $istart_alt = $istart+1;
			    $iend_alt = $iend+1;
			    $altintron2 = $chr . ":" . $istart_alt . "-" . $iend_alt;
			    $allintrons{$altintron2} = 1;
			    $splice_signal_upstream = substr($CHR2SEQ{$chr}, $istart_alt-1, 2);
			    $splice_signal_downstream = substr($CHR2SEQ{$chr}, $iend_alt-2, 2);
			    for ($sig=0; $sig<@donor; $sig++) {
				if (($splice_signal_upstream eq $donor[$sig] && $splice_signal_downstream eq $acceptor[$sig]) || ($splice_signal_upstream eq $acceptor_rev[$sig] && $splice_signal_downstream eq $donor_rev[$sig])) {
				    $goodsplicesignal{$altintron2} = 1;
				    if ($sig>0) {
					$known_noncanonical_signal{$altintron2} = 1;
				    }
				    if (($splice_signal_upstream eq $donor[$sig] && $splice_signal_downstream eq $acceptor[$sig])) {
					$intronstrand{$altintron2} = "+";
				    } else {
					$intronstrand{$altintron2} = "-";
				    }
				}
			    }
			}
		    }
		    $flag = 0;
		    if($altintron1 =~ /\S/ && $goodsplicesignal{$altintron1}==1) {
			$newcigar =~ s/(\d+)M(\d+)$//;
			$len1 = $1 - 1;
			$len_t = length($len1);
			$len_t2 = length($len1);
			if($len_t2 != $len_t) {
			    $cigarlength--;
			}
			$X = $CIG[$i+1];
			$X =~ s/^(\d+)//;
			$len2 = $1 + 1;
			$len_t = length($len2);
			if(length($len2) != $len_t) {
			    $cigarlength++;
			}
			$newcigar = $newcigar . $len1 . "M" . $ilen . "N" . $len2 . $X;
			$flag = 1;
		    }
		    if($flag == 0 && $altintron2 =~ /\S/ && $goodsplicesignal{$altintron2}==1) {
			if(($altintron1 =~ /\S/ && $goodsplicesignal{$altintron1}+0==0) || $altintron1 eq '') {
			    $newcigar =~ s/(\d+)M(\d+)$//;
			    $len1 = $1 + 1;
			    $len_t = length($len1);
			    if(length($len1) != $len_t) {
				$cigarlength++;
			    }
			    $X = $CIG[$i+1];
			    $X =~ s/^(\d+)//;
			    $len2 = $1 - 1;
			    $len_t = length($len2);
			    if(length($len2) != $len_t) {
				$cigarlength--;
			    }
			    $newcigar = $newcigar . $len1 . "M" . $ilen . "N" . $len2 . $X;
			} else {
			    $newcigar = $newcigar . $CIG[$i+1];
			}
			$flag = 1;
		    }
		    if($flag == 0) {
			$newcigar = $newcigar . $CIGTYPES[$i+1] . $CIG[$i+1];
		    }
		    if($altintron1 =~ /\S/ && $goodsplicesignal{$altintron1}+0==0) {
			$amb{$intron}=1;
			$amb{$altintron1}=1
		    }
		    if($altintron2 =~ /\S/ && $goodsplicesignal{$altintron2}+0==0) {
			$amb{$intron}=1;
			$amb{$altintron2}=1
		    }
		    if($altintron1 =~ /\S/ && $altintron2 eq "") {
			if($goodsplicesignal{$altintron1} == 1) {
			    delete $allintrons{$intron};
			    $amb{$altintron1} = 0;
			}
		    }
		    if($altintron2 =~ /\S/ && $altintron1 eq "") {
			if($goodsplicesignal{$altintron2} == 1) {
			    delete $allintrons{$intron};
			    $amb{$altintron2} = 0;
			}
		    }
		    if($altintron1 =~ /\S/ && $altintron2 =~ /\S/) {
			if($goodsplicesignal{$altintron1}+0 == 1 && $goodsplicesignal{$altintron2}+0==0) {
			    delete $allintrons{$intron};
			    delete $allintrons{$altintron2};
			    $amb{$altintron1} = 0;
			}
			if($goodsplicesignal{$altintron1}+0 == 0 && $goodsplicesignal{$altintron2}+0==1) {
			    delete $allintrons{$intron};
			    delete $allintrons{$altintron1};
			    $amb{$altintron2} = 0;
			}
			if($goodsplicesignal{$altintron1}+0 == 1 && $goodsplicesignal{$altintron2}+0==1) {
			    if($known_noncanonical_signal{$altintron1}+0 == 1 && $known_noncanonical_signal{$altintron2}+0 == 0) {
				delete $allintrons{$intron};
				delete $allintrons{$altintron2};
				$amb{$altintron1} = 0;
			    }
			    if($known_noncanonical_signal{$altintron1}+0 == 0 && $known_noncanonical_signal{$altintron2}+0 == 1) {
				delete $allintrons{$intron};
				delete $allintrons{$altintron1};
				$amb{$altintron2} = 0;
			    }
			    if($known_noncanonical_signal{$altintron1}+0 == 1 && $known_noncanonical_signal{$altintron2}+0 == 1) {
				# In this case preference the one on the left. 
				# This is a rare case, maybe never even happens.
				delete $allintrons{$intron};
				delete $allintrons{$altintron2};
				$amb{$altintron1} = 0;
			    }
			}
		    }
		    if($NU eq "false") {
			if ($elen1 < $allowable_overlap || $elen2 < $allowable_overlap) {
			    $badoverlapU{$intron}++;
			    if ($altintron1 =~ /\S/) {
				$badoverlapU{$altintron1}++;
			    }
			    if ($altintron2 =~ /\S/) {
				$badoverlapU{$altintron2}++;
			    }
			} else {
			    $goodoverlapU{$intron}++;
			    if ($altintron1 =~ /\S/) {
				$goodoverlapU{$altintron1}++;
			    }
			    if ($altintron2 =~ /\S/) {
				$goodoverlapU{$altintron2}++;
			    }
			}
		    } else {
			if ($elen1 < $allowable_overlap || $elen2 < $allowable_overlap) {
			    $badoverlapNU{$intron}++;
			    if ($altintron1 =~ /\S/) {
				$badoverlapNU{$altintron1}++;
			    }
			    if ($altintron2 =~ /\S/) {
				$badoverlapNU{$altintron2}++;
			    }
			} else {
			    $goodoverlapNU{$intron}++;
			    if ($altintron1 =~ /\S/) {
				$goodoverlapNU{$altintron1}++;
			    }
			    if ($altintron2 =~ /\S/) {
				$goodoverlapNU{$altintron2}++;
			    }
			}
		    }
		} else {
		    $newcigar = $newcigar . $CIGTYPES[$i+1] . $CIG[$i+1];
		}
	    }
	    if(length($cigarstring) != $cigarlength) {
		print STDERR "Warning: an integrity check makes me think maybe the cigar string in fixed sam file got messed up.\nHere are the original and modified cigar strings.\nPlease take a look and make sure nothing seems strange:\n";
		print STDERR "  original: $cigarstring\n";
		print STDERR "  modified: $newcigar\n";
	    }
	    if($cigarstring eq $newcigar) {
		print SAMOUT "$line\n";
	    } else {
		@a2 = split(/\t/,$line);
		print SAMOUT "$a[0]\t$a[1]\t$a[2]\t$a[3]\t$a[4]\t$newcigar";
		for($i=6; $i<@a; $i++) {
		    print SAMOUT "\t$a[$i]";
		}
		print SAMOUT "\n";
	    }
	}
	close(INFILE);
	close(SAMOUT);
}



sub cigar2spans {
    ($matchstring, $start) = @_;
    $spans = "";
    $current_loc = $start;
    $offset = 0;
    while($matchstring =~ /^(\d+)([^\d])/) {
	$num = $1;
	$type = $2;
	if($type eq 'M') {
	    $E = $current_loc + $num - 1;
	    if($spans =~ /\S/) {
		$spans = $spans . ", " .  $current_loc . "-" . $E;
	    } else {
		$spans = $current_loc . "-" . $E;
	    }
	    $offset = $offset + $num;
	    $current_loc = $E;
	}
	if($type eq 'D' || $type eq 'N') {
	    $current_loc = $current_loc + $num + 1;
	}
	if($type eq 'S') {
	    if($matchstring =~ /^\d+S\d/) {
		for($i=0; $i<$num; $i++) {
		    $seq =~ s/^.//;
		}
	    } elsif($matchstring =~ /\d+S$/) {
		for($i=0; $i<$num; $i++) {
		    $seq =~ s/.$//;
		}
	    }
	}
	if($type eq 'I') {
	    $current_loc++;
	    substr($seq, $offset, 0, "+");
	    $offset = $offset  + $num + 1;
	    substr($seq, $offset, 0, "+");
	    $offset = $offset + 1;
	}
	$matchstring =~ s/^\d+[^\d]//;
    }
    $spans2 = "";
    while($spans2 ne $spans) {
	$spans2 = $spans;
	@b = split(/, /, $spans);
	for($i=0; $i<@b-1; $i++) {
	    @c1 = split(/-/, $b[$i]);
	    @c2 = split(/-/, $b[$i+1]);
	    if($c1[1] + 1 >= $c2[0]) {
		$str = "-$c1[1], $c2[0]";
		$spans =~ s/$str//;
	    }
	}
    }
    return $spans;

}
}
1;
