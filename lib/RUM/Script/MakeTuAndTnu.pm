package RUM::Script::MakeTuAndTnu;

use autodie;
no warnings;

use RUM::Logging;
use RUM::Usage;
use RUM::BowtieIO;
use RUM::RUMIO;
use Getopt::Long;

$|=1;

our $log = RUM::Logging->get_logger();

sub read_annot_file {
    my ($annot_fh) = @_;
    $log->info("Reading gene annotation file");
    while ($line = <$annot_fh>) {
        chomp($line);
        @a = split(/\t/,$line);
        @ids = split(/::::/,$a[7]);
        for ($i=0;$i<@ids;$i++) {
            $ids[$i] =~ s/\([^\(]+$//;
            $geneID2coords{$ids[$i]} = $line;
        }
    }
    return %geneID2coords;
    
}

sub mapping_to_aln {
    my $mapping = shift;
    my $readid = shift || "junk";
    my ($chr, $locs, $strand, $seq) =  split /\t/, $mapping;
    return RUM::Alignment->new(
        readid => $readid,
        chr => $chr,
        locs => RUM::RUMIO->parse_locs($locs),
        seq => $seq,
        strand => $strand);
}

sub write_mapping_with_new_id_and_junctions {
    my ($io, $mapping, $readid) = @_;
    my ($chr, $locs, $strand, $seq) =  split /\t/, $mapping;
    my $aln =  mapping_to_aln($mapping, $readid);
    write_aln_with_junctions($io, $aln);
}

sub write_aln_with_junctions {
    my ($io, $aln) = @_;
    $io->write_aln(
        $aln->copy(seq => newAddJunctionsToSeq($aln)));    
}

sub main {

    GetOptions(
        "bowtie-output=s" => \(my $bowtie_output),
        "genes=s"         => \(my $gene_annot_file),
        "unique=s"        => \(my $unique_out),
        "non-unique=s"    => \(my $non_unique_out),
        "single"          => \(my $single),
        "paired"          => \(my $paired),
        "max-pair-dist=s" => \(my $max_distance_between_paired_reads = 500000),
        "help|h"    => sub { RUM::Usage->help },
        "verbose|v" => sub { $log->more_logging(1) },
        "quiet|q"   => sub { $log->less_logging(1) });
        
    $bowtie_output or RUM::Usage->bad(
        "Please specify the bowtie output file to read with --bowtie-output");

    $gene_annot_file or RUM::Usage->bad(
        "Please specify the gene annotation file with --genes");

    $unique_out or RUM::Usage->bad(
        "Please specify file to write unique mappers with --unique");

    $non_unique_out or RUM::Usage->bad(
        "Please specify file to write non-unique mappers with --non-unique");

    ($single xor $paired) or RUM::Usage->bad(
        "Please specify exactly one type with either --single or --paired");

    $paired_end = $paired ? "true" : "false";

    open my $infile,    "<", $bowtie_output;
    open my $annot_fh,  "<", $gene_annot_file;
    open my $unique_fh, ">", $unique_out;
    open my $nu_fh,     ">", $non_unique_out;

    my $unique_io = RUM::RUMIO->new(-fh => $unique_fh,
                                    strand_last => 1);
    my $nu_io = RUM::RUMIO->new(-fh => $nu_fh,
                                strand_last => 1);
    my $iter = RUM::BowtieIO->new(-fh => $infile);
    my %geneID2coords = read_annot_file($annot_fh);

    $log->info("Parsing bowtie output");

    # line of Y looks like this:
    # seq.1308a       -       mm9_NM_153168:chr9:123276058-123371782_+        3181    TAACTGTCTTGTGGCGGCCAAGCGTTCATAGCGACGTCTCTTTTTGATCCTTCGATGTCTGCTCTTCCTATCATTGTGAAGCAGAATTCACCAAGCGTTGGATTGTTC

    $linecnt = 0;
    $seqnum = -1;

    $firstflag_a = 1;
    $firstflag_b = 1;

    while (1) {
        my $aln = $iter->next_val;
        $linecnt++;
        $seqnum_prev = $seqnum || 0;
        $seqnum = $aln ? $aln->order : undef;

        $type = $aln && $aln->is_forward ? 'a'
              : $aln && $aln->is_reverse ? 'b' 
              :                            '' ;

        if ($seqnum != $seqnum_prev && $seqnum_prev >= 0) {
            $firstflag_a = 1;
            $firstflag_b = 1;
            my %consistent_mappers;
            # NOTE: the following three if's cover all cases we care about, because if numa > 1 and numb = 0, then that's
            # not really ambiguous, blat might resolve it

            if (@a_read_mapping_to_genome == 1 && ! @b_read_mapping_to_genome) { # unique forward match, no reverse, or single_end
                write_mapping_with_new_id_and_junctions($unique_io, $a_read_mapping_to_genome[0], "seq.${seqnum_prev}a");
            }
            if (@b_read_mapping_to_genome == 1 && ! @a_read_mapping_to_genome) { # unique reverse match, no forward
                write_mapping_with_new_id_and_junctions($unique_io, $b_read_mapping_to_genome[0], "seq.${seqnum_prev}b");
            }
            if ($paired_end eq "false") { # write ambiguous mapper to NU file since there's no chance a later step
                # will resolve this read, like it might if it was paired end
		# BUT: first check for siginficant overlap, if so report the overlap to the "Unique" file,
                #  otherwise report all alignments to the "NU" file
                my @spans_t;
                my %CHRS;
                if (@a_read_mapping_to_genome > 1) {
                    my $strand;
                
                    for my $str (@a_read_mapping_to_genome) {
                        my $aln = mapping_to_aln($str);
                        $strand = $aln->strand;
                        push @spans_t, RUM::RUMIO->format_locs($aln);
                        $CHRS{$aln->chromosome}++;
                        $seq_temp = $aln->seq;
                    }
                    $nchrs = 0;
                    foreach $ky (keys %CHRS) {
                        $nchrs++;
                        $CHR = $ky;
                    }
                    $str = intersect(\@spans_t, $seq_temp);
                    $uflag = 1;
                    if ((!$str) || $nchrs > 1) {
                        $uflag = 0;
                    } else { # significant overlap, report to "Unique" file, if it's long enough
                        @ss = split(/\t/,$str);
                        if ($ss[0] >= $min_overlap_a) {
                            $seq_new = addJunctionsToSeq($ss[2], $ss[1]);
                            print $unique_fh "seq.$seqnum_prev";
                            print $unique_fh "a\t$CHR\t$ss[1]\t$seq_new\t$strand\n";
                        } else {
                            $uflag = 0;
                        }
                    }
                    if ($uflag == 0) { # no significant overlap, report to "NU" file
                        for my $str (@a_read_mapping_to_genome) {
                            write_mapping_with_new_id_and_junctions($nu_io, $str, "seq.${seqnum_prev}a");
                        }
                    }
                }
                undef @spans_t;
            }

            if (@a_read_mapping_to_genome &&
                @b_read_mapping_to_genome &&
                scalar(@a_read_mapping_to_genome) * scalar(@b_read_mapping_to_genome) < 1000000) {
                for ($i=0; $i<@a_read_mapping_to_genome; $i++) {
                    @B1 = split(/\t/, $a_read_mapping_to_genome[$i]);
                    $achr = $B1[0];
                    $astrand = $B1[2];
                    $astrand_hold = $astrand;

                    $aseq = $B1[3];
                    $aseq_hold = $aseq;
                    @aexons = split(/, /,$B1[1]);
                    undef @astarts;
                    undef @aends;
                    for ($e=0; $e<@aexons; $e++) {
                        @c = split(/-/,$aexons[$e]);
                        $astarts[$e] = $c[0];
                        $astarts_hold[$e] = $c[0];
                        $aends[$e] = $c[1];
                        $aends_hold[$e] = $c[1];
                    }
                    $astart = $astarts[0];
                    $astart_hold = $astart;
                    $aend = $aends[$e-1];
                    $aend_hold = $aend;
                    for ($j=0; $j<@b_read_mapping_to_genome; $j++) {
                        $astrand = $astrand_hold;
                        $astart = $astart_hold;
                        $aend = $aend_hold;
                        $aseq = $aseq_hold;
                        undef @astarts;
                        undef @aends;
                        for ($e=0; $e<@aexons; $e++) {
                            $astarts[$e] = $astarts_hold[$e];
                            $aends[$e] = $aends_hold[$e];			
                        }
                        undef @bstarts;
                        undef @bends;
                        @B2 = split(/\t/, $b_read_mapping_to_genome[$j]);
                        $bseq = $B2[3];
                        $bchr = $B2[0];
                        $bstrand = $B2[2];
                        @bexons = split(/, /,$B2[1]);
                        for ($e=0; $e<@bexons; $e++) {
                            @c = split(/-/,$bexons[$e]);
                            $bstarts[$e] = $c[0];
                            $bends[$e] = $c[1];
                        }
                        $bstart = $bstarts[0];
                        $bend = $bends[$e-1];

                        if ($achr eq $bchr && $astrand eq $bstrand) {
                            if ($astrand eq "+" && $bstrand eq "+" && ($aend < $bstart-1) && ($bstart - $aend <= $max_distance_between_paired_reads)) {
                                $consistent_mappers{"$a_read_mapping_to_genome[$i]\n$b_read_mapping_to_genome[$j]"}++;
                            }
                            if ($astrand eq "-" && $bstrand eq "-" && ($bend < $astart-1) && ($astart - $bend <= $max_distance_between_paired_reads)) {
                                $consistent_mappers{"$a_read_mapping_to_genome[$i]\n$b_read_mapping_to_genome[$j]"}++;
                            }
                            $swapped = "false";
                            if (($astrand eq "-") && ($bstrand eq "-") && ($bend >= $astart - 1) && ($astart >= $bstart) && ($aend >= $bend)) {
                                # this is a hack to switch the a and b reads so the following if can take care of both cases
                                $swapped = "true";
                                $astrand = "+";
                                $bstrand = "+";
                                $cstart = $astart;
                                $astart = $bstart;
                                $bstart = $cstart;
                                $cend = $aend;
                                $aend = $bend;
                                $bend = $cend;
                                @cstarts = @astarts;
                                @astarts = @bstarts;
                                @bstarts = @cstarts;
                                @cends = @aends;
                                @aends = @bends;
                                @bends = @cends;
                                $cseq = $aseq;
                                $aseq = $bseq;
                                $bseq = $cseq;
                            }
                            if (($astrand eq "+") && ($bstrand eq "+") && ($aend == $bstart-1)) {

                                @mergedstarts = ( @astarts,                 @bstarts[1..$#bstarts] );
                                @mergedends   = ( @aends[0 .. $#aends - 1], @bends                 );

                                $num_exons_merged = @mergedends;
                                $merged_length = $mergedends[0]-$mergedstarts[0]+1;
                                $merged_spans = "$mergedstarts[0]-$mergedends[0]";
                                for ($e=1; $e<$num_exons_merged; $e++) {
                                    $merged_length = $merged_length + $mergedends[$e]-$mergedstarts[$e]+1;
                                    $merged_spans = $merged_spans . ", $mergedstarts[$e]-$mergedends[$e]";
                                }
                                $merged_seq = $aseq . $bseq;
                                if ($swapped eq "false") {
                                    $consistent_mappers{"$achr\t$merged_spans\t+\t$merged_seq"}++;
                                } else {
                                    $consistent_mappers{"$achr\t$merged_spans\t-\t$merged_seq"}++;
                                }
                            }
                            if (($astrand eq "+") && ($bstrand eq "+") && ($aend >= $bstart) && ($bstart >= $astart) && ($bend >= $aend)) {
                                $f = 0;
                                $consistent = 1;
                                $flag = 0;
                                while ($flag == 0 && $f < @astarts) {
                                    if ($bstart >= $astarts[$f] && $bstart <= $aends[$f]) {
                                        $first_overlap_exon = $f; # this index is relative to the a read
                                        $flag = 1;
                                    } else {
                                        $f++;
                                    }
                                }
                                $f = @bstarts-1;
                                if ($flag != 1) {
                                    $consistent = 0;
                                }
                                $flag = 0;
                                while ($flag == 0 && $f >= 0) {
                                    if ($aend >= $bstarts[$f] && $aend <= $bends[$f]) {
                                        $last_overlap_exon = $f; # this index is relative to the b read
                                        $flag = 1;
                                    } else {
                                        $f--;
                                    }
                                }
                                if ($flag != 1) {
                                    $consistent = 0;
                                }
			    
                                $overlap = 0;
                                if ($first_overlap_exon < @astarts-1 || $last_overlap_exon > 0) {
                                    if ($bends[0] != $aends[$first_overlap_exon]) {
                                        $consistent = 0;
                                    }
                                    if ($astarts[@astarts-1] != $bstarts[$last_overlap_exon]) {
                                        $consistent = 0;
                                    }
                                    $b_exon_counter = 1;
                                    for ($e=$first_overlap_exon+1; $e < @astarts-1; $e++) {
                                        if ($astarts[$e] != $bstarts[$b_exon_counter] || $aends[$e] != $bends[$b_exon_counter]) {
                                            $consistent = 0;
                                        }
                                        $b_exon_counter++;
                                    }
                                }
                                if ($consistent == 1) {
                                    $num_exons_merged = @astarts + @bstarts - $last_overlap_exon - 1;
                                    undef @mergedstarts;
                                    undef @mergedends;
                                    for ($e=0; $e<@astarts; $e++) {
                                        $mergedstarts[$e] = @astarts[$e];
                                    }
                                    for ($e=0; $e<@astarts-1; $e++) {
                                        $mergedends[$e] = @aends[$e];
                                    }
                                    $mergedends[@astarts-1] = $bends[$last_overlap_exon];
                                    $E = @astarts-1;
                                    for ($e=$last_overlap_exon+1; $e<@bstarts; $e++) {
                                        $E++;
                                        $mergedstarts[$E] = $bstarts[$e];
                                        $mergedends[$E] = $bends[$e];
                                    }
                                    $num_exons_merged = $E+1;
                                    $merged_length = $mergedends[0]-$mergedstarts[0]+1;
                                    $merged_spans = "$mergedstarts[0]-$mergedends[0]";
                                    for ($e=1; $e<$num_exons_merged; $e++) {
                                        $merged_length = $merged_length + $mergedends[$e]-$mergedstarts[$e]+1;
                                        $merged_spans = $merged_spans . ", $mergedstarts[$e]-$mergedends[$e]";
                                    }
                                    @s1 = split(//,$aseq);
                                    $aseqlength = @s1;
                                    @s2 = split(//,$bseq);
                                    $bseqlength = @s2;
                                    $merged_seq = $aseq;
                                    for ($p=$aseqlength+$bseqlength-$merged_length; $p<@s2; $p++) {
                                        $merged_seq = $merged_seq . $s2[$p]
                                    }
                                    if ($swapped eq "false") {
                                        $consistent_mappers{"$achr\t$merged_spans\t+\t$merged_seq"}++;
                                    } else {
                                        $consistent_mappers{"$achr\t$merged_spans\t-\t$merged_seq"}++;
                                    }
                                }
                            }
                        }
                    }
                }

                if (keys(%consistent_mappers) == 1) {
                    foreach $key (keys %consistent_mappers) {

                        my @mappers = split /\n/, $key;
                        my @directions = qw(a b);

                        for my $mapper (@mappers) {
                            my $direction = @mappers == 1 ? "" : shift(@directions);
                            my $readid = "seq.${seqnum_prev}$direction";
                            write_mapping_with_new_id_and_junctions($unique_io, $mapper, $readid);
                        }
                    }
                } else {
                    $ccnt = 0;
                    $num_absplit = 0;
                    $num_absingle = 0;
                    undef @spans1;
                    undef @spans2;
                    my %CHRS;
                    undef %STRANDhash;
                    $numstrands = 0;
                    foreach $key (keys %consistent_mappers) {
                        @A = split(/\n/,$key);
                        $CHRS{$a[0]}++;
                        if (@A == 1) {
                            $num_absingle++;
                            @a = split(/\t/,$A[0]);
                            $spans1[$ccnt] = $a[1];
                            $STRANDhash{$a[2]}++;
                            if ($ccnt == 0) {
                                $firstseq = $a[3];
                            }
                        }
                        if (@A == 2) {
                            $num_absplit++;
                            @a = split(/\t/,$A[0]);
                            $spans1[$ccnt] = $a[1];
                            $STRANDhash{$a[2]}++;
                            if ($ccnt == 0) {
                                $firstseq1 = $a[3];
                            }
                            @a = split(/\t/,$A[1]);
                            $spans2[$ccnt] = $a[1];
                            if ($ccnt == 0) {
                                $firstseq2 = $a[3];
                            }
                        }
                        $ccnt++;
                    }
                    foreach $strandkey (keys %STRANDhash) {
                        $numstrands++;
                        $STRAND = $strandkey;
                    }
                    $nchrs = 0;
                    foreach $ky (keys %CHRS) {
                        $nchrs++;
                        $CHR = $ky;
                    }
                    $nointersection = 0;
                    if ($num_absingle == 0 && $num_absplit > 0 && $nchrs == 1 && $numstrands == 1) {
                        $str1 = intersect(\@spans1, $firstseq1);
                        $str2 = intersect(\@spans2, $firstseq2);
                        if ($str1 && $str2) {
                            $str1 =~ s/^(\d+)\t/$CHR\t/;
                            $size1 = $1;
                            $str2 =~ s/^(\d+)\t/$CHR\t/;
                            $size2 = $1;
                            if ($size1 >= $min_overlap_a && $size2 >= $min_overlap_b) {
                                $str1 =~ /^[^\t]+\t(\d+)[^\t+]-(\d+)\t/;
                                $start1 = $1;
                                $end1 = $2;
                                $str2 =~ /^[^\t]+\t(\d+)[^\t+]-(\d+)\t/;
                                $start2 = $1;
                                $end2 = $2;
                                if ((($start2 - $end1 > 0) && ($start2 - $end1 < $max_distance_between_paired_reads)) || 
                                    (($start1 - $end2 > 0) && ($start1 - $end2 < $max_distance_between_paired_reads))) {
                                    @ss = split(/\t/,$str1);
                                    $seq_new = addJunctionsToSeq($ss[2], $ss[1]);
                                    print $unique_fh "seq.$seqnum_prev";
                                    print $unique_fh "a\t$ss[0]\t$ss[1]\t$seq_new\t$STRAND\n";

                                    @ss = split(/\t/,$str2);
                                    $seq_new = addJunctionsToSeq($ss[2], $ss[1]);
                                    print $unique_fh "seq.$seqnum_prev";
                                    print $unique_fh "b\t$ss[0]\t$ss[1]\t$seq_new\t$STRAND\n";
                                } else {
                                    $nointersection = 1;
                                }
                            } else {
                                $nointersection = 1;
                            }
                        } else {
                            $nointersection = 1;
                        }
                    }
                    if ($num_absingle > 0 && $num_absplit == 0 && $nchrs == 1 && $numstrands == 1) {
                        $str = intersect(\@spans1, $firstseq);
                        if ($str) {
                            $str =~ s/^(\d+)\t/$CHR\t/;
                            $size = $1;
                            if ($size >= $min_overlap_a && $size >= $min_overlap_b) {
                                @ss = split(/\t/,$str);
                                $seq_new = addJunctionsToSeq($ss[2], $ss[1]);
                                print $unique_fh "seq.$seqnum_prev\t$ss[0]\t$ss[1]\t$seq_new\t$STRAND\n";
                            } else {
                                $nointersection = 1;
                            }
                        } else {
                            $nointersection = 1;
                        }
                    }
                    if (($nointersection == 1) || ($nchrs > 1) || ($num_absingle > 0 && $num_absplit > 0) || ($numstrands > 1)) {
                        for my $key (keys %consistent_mappers) {

                            my @mappers = split /\n/, $key;
                            my @directions = qw(a b);

                            for my $mapper (@mappers) {
                                my $direction = @mappers == 1 ? "" : shift(@directions);
                                my $readid = "seq.${seqnum_prev}$direction";
                                write_mapping_with_new_id_and_junctions($nu_io, $mapper, $readid);
                            }
                        }
                    }
                }
            }
            # add something here so that if all consistent mappers agree on some stretch of
            # exons, then those exons will still get reported
            undef @a_read_mapping_to_genome;
            undef @b_read_mapping_to_genome;
            $min_overlap_a=0;
            $min_overlap_b=0;
        }
        last if ! $aln;
        @a = split /\t/, $aln->raw;
    
        if ($aln->is_forward) {
            if ($firstflag_a == 1) {
                $readlength_a = length($aln->seq);
                if ($readlength_a < 80) {
                    $min_overlap_a = 35;
                } else {
                    $min_overlap_a = 45;
                }
                if ($min_overlap_a >= .8 * $readlength_a) {
                    $min_overlap_a = int(.6 * $readlength_a);
                }
                $firstflag_a = 0;
            }
        }
        if ($aln->is_reverse) {
            if ($firstflag_b == 1) {
                $readlength_b = length($aln->seq);
                if ($readlength_b < 80) {
                    $min_overlap_b = 35;
                } else {
                    $min_overlap_b = 45;
                }
                if ($min_overlap_b >= .8 * $readlength_b) {
                    $min_overlap_b = int(.6 * $readlength_b);
                }
                $firstflag_b = 0;
            }
        }

        $qstrand = $a[1];
        $displacement = $a[3];
        # $a[2] looks like this: uc002bea.2:chr15:78885397-78913322_-
        #       or like this: PF08_tmp1:rRNA:Pf3D7_08:1285649-1288826_+
        $a[2] =~ /^(.*):([^:]+):[^:]+(.)$/;

        $geneid = $1;
        $chr = $2;
        $tstrand = $3;
        $seq = $a[4];
        @sq = split(//,$seq);
        $seq_length = @sq;

        $target = $geneID2coords{$geneid};
        @a = split(/\t/,$target);
        @starts = split(/,/,$a[5]);
        @ends = split(/,/,$a[6]);

        $numexons = $a[4];
        $j=@sq-1;
        while (($sq[$j] eq "N") && ($j >= 0)) {
            $j--;
            $seq_length--;
        }
        $j=0;
        while (($sq[$j] eq "N") && ($j < @sq)) {
            $j++;
            $displacement++;
            $seq_length--;
        }
        $seq =~ s/^N+//;
        $seq =~ s/N+$//;
        @sq = split(//,$seq);
        if ($tstrand eq "-") {
            $gene_length = 0;
            for ($k=0; $k<@starts; $k++) {
                $gene_length = $gene_length + $ends[$k] - $starts[$k];
            }
            $displacement = $gene_length - $displacement - $seq_length;
            $revcomp = "";
            for ($i=@sq-1; $i>=0; $i--) {
                $flag = 0;
                if ($sq[$i] eq 'A') {
                    $revcomp = $revcomp . "T";
                    $flag = 1;
                }
                if ($sq[$i] eq 'T') {
                    $revcomp = $revcomp . "A";
                    $flag = 1;
                }
                if ($sq[$i] eq 'C') {
                    $revcomp = $revcomp . "G";
                    $flag = 1;
                }
                if ($sq[$i] eq 'G') {
                    $revcomp = $revcomp . "C";
                    $flag = 1;
                }
                if ($flag == 0) {
                    $revcomp = $revcomp . $sq[$i];
                }
            }
            $seq = $revcomp;
        }
        $i=0;
        $s[0] = 0;
        while ($s[$i] <= $displacement) {
            $i++;
            $s[$i] = $s[$i-1] + $ends[$i-1] - $starts[$i-1];
            if ($i > 100000) {
                die "Something is wrong, probably with the gene annotation file: $ARGV[1].  Are you sure it is zero-based, half-open?  Script make_TU_and_TNU is exiting due to this error.";
            }
        }
        $readstart[0] = $starts[$i-1] + $displacement - $s[$i-1] + 1;
        $cnt=0;
        while ($s[$i] < $displacement+$seq_length) {
            $readsend[$cnt] = $ends[$i-1];
            $i++;
            $s[$i] = $s[$i-1] + $ends[$i-1] - $starts[$i-1];
            $cnt++;
            $readstart[$cnt] = $starts[$i-1] + 1;
            if ($i > 100000) {
                die "Something is wrong, probably with the gene annotation file: $ARGV[1].  Are you sure it is zero-based, half-open?  Script make_TU_and_TNU is exiting due to this error.";
            }
        }
        $readsend[$cnt] = $starts[$i-1] + $displacement + $seq_length - $s[$i-1];
        $output = "";
        $output = $output .  "$chr\t";
        $output = $output .  "$readstart[0]-$readsend[0]";
        for ($i=1; $i<$cnt+1; $i++) {
            $output = $output . ", $readstart[$i]-$readsend[$i]";
        }

        my $new_strand;

        if ($qstrand eq $tstrand) {
            $new_strand = $aln->is_forward ? '+' : '-';
        } else {
            $new_strand = $aln->is_forward ? '-' : '+';
        }
        $output .= "\t$new_strand\t$seq";

        my $aln_out = RUM::Alignment->new(
            chr => $chr,
            locs => [ map { [ $readstart[$_], $readsend[$_] ] } (0 .. $#readstart) ],
            strand => $new_strand,
            seq => $seq,
            readid => "junk",
            raw => $output
        );

        if ($aln->is_forward) {
            if ( ! grep { $_ eq $output } @a_read_mapping_to_genome) {
                push @a_read_mapping_to_genome, $output;
            }
        }
        if ($aln->is_reverse) {
            if ( ! grep { $_ eq $output } @b_read_mapping_to_genome ) {
                push @b_read_mapping_to_genome, $output;
            }
        }
    }

    sub newAddJunctionsToSeq {
        my ($aln) = @_;
        addJunctionsToSeq($aln->seq, 
                          RUM::RUMIO->format_locs($aln));
    }

    sub addJunctionsToSeq () {
        ($seq, $spans) = @_;
        @s_j = split(//,$seq);
        @b_j = split(/, /,$spans);
        $seq_out = "";
        $place_j = 0;
        for ($j_j=0; $j_j<@b_j; $j_j++) {
            @c_j = split(/-/,$b_j[$j_j]);
            $len_j = $c_j[1] - $c_j[0] + 1;
            if ($seq_out =~ /\S/) {
                $seq_out = $seq_out . ":";
            }
            for ($k_j=0; $k_j<$len_j; $k_j++) {
                $seq_out = $seq_out . $s_j[$place_j];
                $place_j++;
            }
        }
        return $seq_out;
    }

    sub intersect () {
        ($spans_ref, $seq) = @_;
        @spans = @{$spans_ref};
        $num_i = @spans;
        undef %chash;
        for ($s_i=0; $s_i<$num_i; $s_i++) {
            @a2 = split(/, /,$spans[$s_i]);
            for ($i_i=0;$i_i<@a2;$i_i++) {
                @b_i = split(/-/,$a2[$i_i]);
                for ($j_i=$b_i[0];$j_i<=$b_i[1];$j_i++) {
                    $chash{$j_i}++;
                }
            }
        }
        $spanlength = 0;
        $flag_i = 0;
        $maxspanlength = 0;
        $maxspan_start = 0;
        $maxspan_end = 0;
        $prevkey_i = 0;
        for $key_i (sort {$a <=> $b} keys %chash) {
            if ($chash{$key_i} == $num_i) {
                if ($flag_i == 0) {
                    $flag_i = 1;
                    $span_start = $key_i;
                }
                $spanlength++;
            } else {
                if ($flag_i == 1) {
                    $flag_i = 0;
                    if ($spanlength > $maxspanlength) {
                        $maxspanlength = $spanlength;
                        $maxspan_start = $span_start;
                        $maxspan_end = $prevkey_i;
                    }
                    $spanlength = 0;
                }
            }
            $prevkey_i = $key_i;
        }
        if ($flag_i == 1) {
            if ($spanlength > $maxspanlength) {
                $maxspanlength = $spanlength;
                $maxspan_start = $span_start;
                $maxspan_end = $prevkey_i;
            }
        }
        if ($maxspanlength > 0) {
            @a2 = split(/, /,$spans[0]);
            @b_i = split(/-/,$a2[0]);
            $i_i=0;
            until ($b_i[1] >= $maxspan_start) {
                $i_i++;
                @b_i = split(/-/,$a2[$i_i]);
            }
            $prefix_size = $maxspan_start - $b_i[0]; # the size of the part removed from spans[0]
            for ($j_i=0; $j_i<$i_i; $j_i++) {
                @b_i = split(/-/,$a2[$j_i]);
                $prefix_size = $prefix_size + $b_i[1] - $b_i[0] + 1;
            }
            @s_i = split(//,$seq);
            $newseq = "";
            for ($i_i=$prefix_size; $i_i<$prefix_size + $maxspanlength; $i_i++) {
                $newseq = $newseq . $s_i[$i_i];
            }
            $flag_i = 0;
            $i_i=0;
            @b_i = split(/-/,$a2[0]);
            until ($b_i[1] >= $maxspan_start) {
                $i_i++;
                @b_i = split(/-/,$a2[$i_i]);
            }
            $newspans = $maxspan_start;
            until ($b_i[1] >= $maxspan_end) {
                $newspans = $newspans . "-$b_i[1]";
                $i_i++;
                @b_i = split(/-/,$a2[$i_i]);
                $newspans = $newspans . ", $b_i[0]";
            }
            $newspans = $newspans . "-$maxspan_end";
            $off = "";
            for ($i_i=0; $i_i<$prefix_size; $i_i++) {
                $off = $off . " ";
            }
            return "$maxspanlength\t$newspans\t$newseq";
        } else {
            return;
        }
    }
}
