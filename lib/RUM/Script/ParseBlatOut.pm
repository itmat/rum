package RUM::Script::ParseBlatOut;

use autodie;
no warnings;

use Carp;

use RUM::BlatIO;
use RUM::Common qw(getave addJunctionsToSeq);
use RUM::Logging;
use RUM::Usage;
use List::Util qw(sum);

use base 'RUM::Script::Base';

# Given a filehandle, skip over all rows that appear to be header
# rows. After I return, the filehandle will be positioned at the first
# data row.
sub skip_headers {
    my ($fh) = @_;
    my $blatio = RUM::BlatIO->new(-fh => $fh);
}

sub is_blat_file_sorted {
    use strict;
    my ($self) = @_;

    my $blat_io = RUM::BlatIO->new(-fh => $self->{blatfile_fh})->peekable;
    my $last = $blat_io->next_val;;

    $self->logger->info("Checking to see if blat file $self->{blatfile} is sorted");
    my $count = 0;
    while (my $next = $blat_io->next_val) {
        
        if ($last->order > $next->order 
            || ( $last->is_mate($next) && $last->is_reverse && $next->is_forward)) {
            return;
        }
        $last = $next;
    }
    $self->logger->debug("Blat file $self->{blatfile} is sorted");
    seek $self->{blatfile_fh}, 0, 0;
    return 1;
}

sub ensure_blat_file_sorted {
    use strict;
    my ($self) = @_;

    if ($self->is_blat_file_sorted) {
        $self->logger->info("The blat file is already sorted");
        $self->{blatfile_sorted} = $self->{blatfile};
        warn "Blat file sorted is $self->{blatfile_sorted}\n";
        return;
    }
        
    $self->logger->warn("The blat file is not sorted properly, I'm sorting it now.  This could indicate an error");

    my $temp1  = File::Temp->new(UNLINK => 0);
    my $temp2  = File::Temp->new(UNLINK => 0);
    my $sorted = File::Temp->new(UNLINK => 0);
    my $temp2_filename = $temp2->filename;
    close $temp2;

    $self->{blatfile_sorted} = $sorted->filename;
    $self->logger->debug("Opening blat file $self->{blatfile}");
    open my $unsorted_fh, '<', $self->{blatfile};

    my $blat_iter = RUM::BlatIO->new(-fh => $unsorted_fh);
    
    $self->logger->debug("Copying headers to $sorted");
    for my $line (@{ $blat_iter->header_lines }) {
        print $sorted "$line\n";
    }

    while (my $rec = $blat_iter->next_val) {
        my $line = $rec->raw;
        my $order = $rec->order;
        my $type = $rec->is_forward ? 'a' : 'b';
        print $temp1 "$order\t$type\t$line\n";
    }

    close($temp1);

    open my $sort_output, '-|', "sort -T . -n $temp1";

    while (my $line = <$sort_output>) {
        chomp($line);
        $line =~ s/^(\d+)\t(.)\t//;
        print $sorted "$line\n";
    }

    close $sorted;

    my $old_size = -s $self->{blatfile};
    my $new_size = -s $self->{blatfile_sorted};

    if ($old_size != $new_size) {
        my $diff = $old_size - $new_size;
        my $msg = <<"EOF";

I tried to sort the blat file but the sorted file is not the same size
as the original. The unsorted file's size is $old_size and the sorted
file's size is $new_size (difference of $diff)

EOF
        system "cp $self->{blatfile} old";
        system "cp $self->{blatfile_sorted} new";
        die $msg;
    } else {
        $self->logger->info("The blat file is now sorted properly");
    }
}

$| = 1;
# blat run on forward/reverse reads separately, reported in order
# first make hash 'blathits' which is all alignments of the read that we would accept (indexed by t=0,1 for forward/reverse)
# then make array 'read_mapping_to_genome_blatoutput' which has all things that are within 5 bases of the longest alignment in 'blathits' (also indexed by t=0,1)
# then find things that we would keep if only the forward or reverse map, put them in 'one_dir_only_candidate' (also indexed by t=0,1)
# then go through array 'read_mapping_to_genome_blatoutput' to find things that are consistent mappers, put in array 'consistent_mappers'
# then go through 'consistent_mappers' and if a substantial overlap between all members then report the overlap to file of unique mappers blatU
# otherwise report to file of non unique mappers blatNU

# Blat should be run with the following parameters for maximum sensitivity:
# -ooc=11.ooc -minScore=M -minIdentity=93 -stepSize=5 -repMatch=2253
# where M = $match_length_cutoff - 12;
# Blat should be run with the following parameters for speed:
# -ooc=11.ooc -minScore=M -minIdentity=93

sub open_files {
    my ($self) = @_;
    
    for my $key (qw(blatfile seqfile mdustfile)) {
        open my $fh, '<', $self->{$key};
        $self->{"${key}_fh"} = $fh;
    }

    for my $key (qw(unique_out nu_out)) {
        open my $fh, '>', $self->{$key};
        $self->{"${key}_fh"} = $fh;
    }
    
}


sub parse_command_line {

    my ($self) = @_;

    $self->get_options(
        "reads-in=s"            => \($self->{seqfile}),
        "blat-in=s"             => \($self->{blatfile}),
        "mdust-in=s"            => \($self->{mdustfile}),
        "unique-out=s"          => \($self->{unique_out}),
        "non-unique-out=s"      => \($self->{nu_out}),
        "max-pair-dist=s"       => \($self->{max_pair_dist} = 500000),
        "max-insertions=s"      => \($self->{max_insertions} = 1),
        "match-length-cutoff=s" => \($self->{match_length_cutoff} = 0),
        "dna"                   => \(my $dna));
    
    # Check command-line args

    $self->{seqfile} or RUM::Usage->bad(
        "Please provide a file of unmapped reads with --reads-in");
    $self->{blatfile} or RUM::Usage->bad(
        "Please provide the file produced by blat with --blat-in");
    $self->{mdustfile} or RUM::Usage->bad(
        "Please provide the file produced by mdust with --mdust-in");
    $self->{unique_out} or RUM::Usage->bad(
        "Specify an output file for unique mappers with --unique-out");
    $self->{unique_out} or RUM::Usage->bad(
        "Specify an output file for non-unique mappers with --non-unique-out");
    $self->{max_insertions} =~ /^\d+$/ or RUM::Usage->bad(
        "If you provide --num-insertions-allowed, it must be an integer");
    $self->{match_length_cutoff} =~ /^\d+$/ or RUM::Usage->bad(
        "If you provide --match-length-cutoff, it must be an integer");

    $self->{num_blocks_allowed} = $dna ? 1 : 1000;
}

sub main {
    my $self = __PACKAGE__->new;

    $self->parse_command_line;
    $self->open_files;
    $self->ensure_blat_file_sorted;
    $self->run;
}

sub run {
    my ($self) = @_;

    open my $blat_hits, '<', $self->{blatfile_sorted};
    my $seq_fh    = $self->{seqfile_fh};
    my $mdust_fh  = $self->{mdustfile_fh};
    my $unique_fh = $self->{unique_out_fh};
    my $nu_fh     = $self->{nu_out_fh};

    my $blat_iter = RUM::BlatIO->new(-fh => $blat_hits);

    # Get the first and last sequence number and determine if the
    # reads are paired end.
    $head  = `head -1 $self->{seqfile}`;
    $head2 = `head -3 $self->{seqfile}`;

    $paired_end = $head2 =~ /seq.\d+b/;

    $head =~ /seq.(\d+)/;
    $first_seq_num = $1;
    $tail = `tail -1 $self->{blatfile_sorted}`;
    my $last_seq_num = $blat_iter->parse_aln($tail)->order;

    if ($self->{max_insertions} > 1 && $paired_end) {
        die "For paired end data, you cannot set -num_insertions_allowed to be greater than 1.";
    }

    my $aln;

    # NOTE: insertions instead are indicated in the final output file with the "+" notation
    for ($seq_count=$first_seq_num; $seq_count<=$last_seq_num; $seq_count++) {
        if ($seq_count == $first_seq_num) {

            $aln = $blat_iter->next_val;

            $readlength = $aln->q_size;
            if ($readlength < 80) {
                $min_size_intersection_allowed = 35;
                if ($self->{match_length_cutoff} == 0) {
                    $self->{match_length_cutoff} = 35;
                }
            } else {
                $min_size_intersection_allowed = 45;
                if ($self->{match_length_cutoff} == 0) {
                    $self->{match_length_cutoff} = 50;
                }
            }
            if ($min_size_intersection_allowed >= .8 * $readlength) {
                $min_size_intersection_allowed = int(.6 * $readlength);
                $self->{match_length_cutoff}   = int(.6 * $readlength);
            }
            $seqname = $aln->readid;
            $seqnum = $seqname;
            $seqnum =~ s/[^\d]//g;
            $seqa_temp = <$seq_fh>;
            chomp($seqa_temp);
            $seqa_temp =~ s/[^ACGTNab]$//;
            warn "Seqa temp si $seqa_temp\n";
            $mdust_temp = <$mdust_fh>;
            chomp($mdust_temp);
            $mdust_temp =~ s/[^ACGTNab]$//;
        }
        $seqa_temp =~ /seq.(\d+)/;
        $seq_count = $1; # this way we skip over things that aren't in <seq file>
        $seqa_temp = <$seq_fh>;
        chomp($seqa_temp);
        $seqa_temp =~ s/[^ACGTNab]$//;
        $seqa = "";
        while (!($seqa_temp =~ /^>/)) {
            $seqa_temp =~ s/[^A-Z]//gs;
            $seqa = $seqa . $seqa_temp;
            $seqa_temp = <$seq_fh>;
            chomp($seqa_temp);
            $seqa_temp =~ s/[^ACGTNab]$//;
            if ($seqa_temp eq '') {
                last;
            }
        }
        if ($paired_end) {
            $seqb_temp = <$seq_fh>;
            chomp($seqb_temp);
            $seqb_temp =~ s/[^ACGTNab]$//;
            $seqb = "";
            $seqb_temp =~ s/[^A-Z]//gs;
            while (!($seqb_temp =~ /^>/)) {
                $seqb = $seqb . $seqb_temp;
                $seqb_temp = <$seq_fh>;
                chomp($seqb_temp);
                $seqb_temp =~ s/[^ACGTNab]$//;
                if ($seqb_temp eq '') {
                    last;
                }
            }
            $seqa_temp = $seqb_temp;
        }

        $mdust_temp = <$mdust_fh>;
        chomp($mdust_temp);
        $mdust_temp =~ s/[^ACGTNab]$//;
        $dust_output = "";
        while (!($mdust_temp =~ /^>/)) {
            $dust_output = $dust_output . $mdust_temp;
            $mdust_temp = <$mdust_fh>;
            chomp($mdust_temp);
            $mdust_temp =~ s/[^ACGTNab]$//;
            if ($mdust_temp eq '') {
                last;
            }
        }
        $sn = $aln->as_forward->readid;
        $Ncount{$sn} = ($dust_output =~ tr/N//);
        $cutoff{$sn} = $self->{match_length_cutoff} + $Ncount{$sn};
        if ($cutoff{$sn} > $aln->q_size - 2) {
            $cutoff{$sn} = $aln->q_size - 2;
        }
        if ($paired_end) {
            $mdust_temp = <$mdust_fh>;
            chomp($mdust_temp);
            $mdust_temp =~ s/[^ACGTNab]$//;
            $dust_output = "";
            while (!($mdust_temp =~ /^>/)) {
                $dust_output = $dust_output . $mdust_temp;
                $mdust_temp = <$mdust_fh>;
                chomp($mdust_temp);
                $mdust_temp =~ s/[^ACGTNab]$//;
                if ($mdust_temp eq '') {
                    last;
                }
            }
            $sn = $aln->as_reverse->readid;
            $Ncount{$sn} = ($dust_output =~ tr/N//);
            $cutoff{$sn} = $self->{match_length_cutoff} + $Ncount{$sn};
            if ($cutoff{$sn} > $aln->q_size - 2) {
                $cutoff{$sn} = $aln->q_size - 2;
            }
        }

        while (defined($seqnum) && $seqnum == $seq_count) {
            $LENGTH = sum(@{ $aln->block_sizes });
            $SCORE = $LENGTH - $aln->mismatch; # This is the number of matches minus the number of mismatches, ignoring N's and gaps
            if ($SCORE > $cutoff{$seqname}) { # so match is at least cutoff long (and this cutoff was set to be longer if there are a lot of N's (bad reads or low complexity masked by dust)
                #	    if($aln->q_start <= 1) {   # so match starts at position zero or one in the query (allow '1' because first base can tend to be an N or low quality)
                if (1 == 1) { # trying this with no condition to see if it helps... (it did!)
                    if ($aln->q_gap_count <= $self->{max_insertions}) { # then the aligment has at most $self->{max_insertions} gaps (default = 1) in the query, allowing for insertion(s) in the sample, throw out this alignment otherwise (we typipcally don't believe more than one separate insertions in such a short span).
                        if ($Ncount{$aln->readid} <= ($aln->q_size / 2) || $aln->block_count <= 3) { # IF SEQ IS MORE THAN 50% LOW COMPLEXITY, DON'T ALLOW MORE THAN 3 BLOCKS, OTHERWISE GIVING IT TOO MUCH OPPORTUNITY TO MATCH BY CHANCE.  
                            if ($aln->block_count <= $self->{num_blocks_allowed}) { # NEVER ALLOW MORE THAN $self->{num_blocks_allowed} blocks, which is set to 1 for dna and 1000 (the equiv of infinity) for rnaseq
                                # at this point we know it's a prefix match starting at pos 0 or 1 and with at most one gap in the query, and if low comlexity then not too fragemented...
                                $gap_flag = 0;
                                if ($aln->q_gap_count == 1) { # there's a gap in the query, be stricter about allowing it
                                    if ($aln->mismatch > 2) { # ONLY 2 MISMATCHES
                                        $gap_flag = 1;
                                    }
                                    if ($aln->q_end < .85 * $aln->q_size) { # LONGER LENGTH MATCH (at least 85% length of read)
                                        $gap_flag = 1;
                                    }
                                    if ($aln->t_gap_count > 1) { # at most one gap in the target
                                        $gap_flag = 1;
                                    }
                                    @A = @{ $aln->block_sizes };
                                    @B = @{ $aln->t_starts };
                                    for ($k=0;$k<@A-1;$k++) { # any gap in the target must be at least 32 bases
                                        if (($B[$k+1]-$A[$k]-$B[$k]<32) && ($B[$k+1]-$A[$k]-$B[$k]>0)) {
                                            $gap_flag = 1;
                                        }
                                    }
                                    if ($aln->q_gap_bases > 3) { # gap in the query can be at most 3 bases
                                        $gap_flag = 1;
                                    }
                                    @qs = @{ $aln->q_starts };
                                    @bs = @{ $aln->block_sizes };
				
                                    for ($h=0; $h<@qs-1; $h++) { # gap at least 8 bases from the end of a block
                                        if ($qs[$h]+$bs[$h] < $qs[$h+1]) {
                                            if ($bs[$h] < 8 || $bs[$h+1] < 8) {
                                                $gap_flag = 1;
                                            }
                                        }
                                    }
                                    if ($aln->q_gap_count + $aln->t_gap_count >= @qs) { # this makes sure gap in query and target not in same place
                                        $gap_flag = 1;
                                    }
                                }
                                if ($gap_flag == 0) { # IF GOT TO HERE THEN READ PASSED ALL CRITERIA FOR A MATCH
                                    
                                    push @{ $blathits{$seqname} ||= [] }, [
                                        $SCORE,
                                        $aln->strand,
                                        $aln->t_name,
                                        $aln->block_sizes_str,
                                        $aln->t_starts_str,
                                        $aln->mismatch,
                                        $aln->q_starts_str
                                    ];

                                    $N = @{$blathits{$seqname}};
                                    if ($maxlength{$seqname}+0 < $aln->q_end) {
                                        $maxlength{$seqname} = $aln->q_end;
                                    }
                                    if ($aln->q_gap_count == 1) { # then query has a gap, write this to the insertions file I
                                        $gapsize = $aln->q_gap_bases;
                                        @blocksizes = @{ $aln->block_sizes };
                                        @qStarts    = @{ $aln->q_starts };
                                        @tStarts    = @{ $aln->t_starts };
                                        $n = @blocksizes;
                                        for ($block=0; $block < $n-1; $block++) {
                                            if ($blocksizes[$block] + $qStarts[$block] < $qStarts[$block+1]) {
                                                $insertion_target_coord = $blocksizes[$block] + $tStarts[$block];
                                                $temp = $aln->is_forward ? $seqa : $aln->is_reverse ? $seqb : '';

                                                if ($aln->strand eq "+") {
                                                    @s = split(//,$temp);
                                                } else {
                                                    @s2 = split(//,$temp);
                                                    $n2 = @s2-1;
                                                    $TMP = "";
                                                    for ($i=$n2; $i>=0; $i--) {
                                                        $flag = 0;
                                                        if ($s2[$i] eq 'A') {
                                                            $s[$n2 - $i] =  "T";
                                                            $flag = 1;
                                                            $TMP = $TMP . "T";
                                                        }
                                                        if ($s2[$i] eq 'T') {
                                                            $s[$n2 - $i] =  "A";
                                                            $flag = 1;
                                                            $TMP = $TMP . "A";
                                                        }
                                                        if ($s2[$i] eq 'G') {
                                                            $s[$n2 - $i] =  "C";
                                                            $flag = 1;
                                                            $TMP = $TMP . "C";
                                                        }
                                                        if ($s2[$i] eq 'C') {
                                                            $s[$n2 - $i] =  "G";
                                                            $flag = 1;
                                                            $TMP = $TMP . "G";
                                                        }
                                                        if ($flag == 0) {
                                                            $s[$n2 - $i] =  $s2[$i];
                                                        }
                                                    }
                                                }
                                                $insertion = "";
                                                for ($c=0; $c<$aln->q_gap_bases; $c++) {
                                                    $insertion = $insertion . "$s[$c + $qStarts[$block] + $blocksizes[$block]]";
                                                }
                                                $inscoord_temp = $insertion_target_coord + 1;
                                                $aln->t_name =~ /chr(.*):/;
                                                $chr = $1;
                                                $insertion = "chr" . $chr . ":" . $insertion_target_coord . ":" . $insertion . ":" . $inscoord_temp . "\n";
                                                $blathits{$seqname}[$cnt{$seqname}][7] = $insertion;
                                                $block = $n;
                                            }
                                        }
                                    }
                                    $cnt{$seqname}++; # this is the number of hits to this seq satisfying all criteria
                                }
                            }
                        }
                    }
                }
            }

            $aln = $blat_iter->next_val;

            $seqname = $aln ? $aln->readid : '';
            $seqnum = $seqname;
            $seqnum =~ s/[^\d]//g;
            if ($seqnum == $seq_count) {
                $readlength = $aln->q_size;
                if ($readlength < 80) {
                    $min_size_intersection_allowed = 35;
                    if ($self->{match_length_cutoff} == 0) {
                        $self->{match_length_cutoff} = 35;
                    }
                } else {
                    $min_size_intersection_allowed = 45;
                    if ($self->{match_length_cutoff} == 0) {
                        $self->{match_length_cutoff} = 50;
                    }
                }
                if ($min_size_intersection_allowed >= .8 * $readlength) {
                    $min_size_intersection_allowed = int(.6 * $readlength);
                    $self->{match_length_cutoff} = int(.6 * $readlength);
                }
            }
        }

        
        
        $sname[0] = "seq." . $seq_count . "a";
        $sname[1] = "seq." . $seq_count . "b";

        for ($t=0; $t<2; $t++) { # $t=0 for the 'a' (forward) reads, $t=1 for the 'b' (reverse) reads
            $cnt2=0;
            $N = @{$blathits{$sname[$t]}};
            for ($i1=0; $i1<$N; $i1++) {
                if ($blathits{$sname[$t]}[$i1][0] >= $maxlength{$sname[$t]} - 10) {
                    $chr = $blathits{$sname[$t]}[$i1][2]; # Should have the span, but the 'if' below allows it to not
                    if ($chr =~ /:(\d+)/) {
                        $start = $1;
                        $chr =~ s/:.*//;
                    } else {
                        $start = 1;
                    }
                    @a0 = split(/,/,$blathits{$sname[$t]}[$i1][4]);
                    @b  = split(/,/,$blathits{$sname[$t]}[$i1][3]);
                    @qs = split(/,/,$blathits{$sname[$t]}[$i1][6]);
                    $l = $start + $a0[0];
                    $e = $l + $b[0] - 1;
                    $loc = "$chr\t$l-$e";
                    for ($j=1; $j<@a0; $j++) {
                        $l = $start + $a0[$j];
                        $e = $l + $b[$j] - 1;
                        $loc = $loc . ", $l-$e";
                    }
                    # loc is correct, wether the query has a gap or not
                    # but loc might have spans with no space between them if a gap in the query
                    # the following will fix that:
                    $loc2 = $loc;
                    $loc2 =~ s/.*\t//;
                    @L = split(/, /,$loc2);
                    $fixedloc = "";
                    $LL = @L;
                    for ($j=0; $j<$LL; $j++) {
                        @x = split(/-/,$L[$j]);
                        @y = split(/-/,$L[$j+1]);
                        if ($x[1] == ($y[0]-1)) {
                            $fixedloc = $fixedloc . "$x[0]-$y[1], ";
                            $j++;
                        } else {
                            $fixedloc = $fixedloc . "$x[0]-$x[1], ";
                        }
                    }
                    $loc =~ s/\t.*//;
                    $loc = $loc . "\t$fixedloc";
                    $loc =~ s/, $//;
                    $read_mapping_to_genome_blatoutput[$t][$cnt2] = "$sname[$t]\t$loc\t$blathits{$sname[$t]}[$i1][0]\t$blathits{$sname[$t]}[$i1][1]\t$blathits{$sname[$t]}[$i1][2]\t$blathits{$sname[$t]}[$i1][3]\t$blathits{$sname[$t]}[$i1][4]\t$blathits{$sname[$t]}[$i1][5]\t$blathits{$sname[$t]}[$i1][6]\t$blathits{$sname[$t]}[$i1][7]\t$i1";

                    # 0: sname
                    # 1: chr
                    # 2: spans (note chr and spans are combined in $loc with a tab between them)
                    # 3: length of the prefix
                    # 4: strand
                    # 5: name of the target seq
                    # 6: block sizes
                    # 7: t-starts
                    # 8: num mismatches
                    # 9: q-starts
                    # 10: the number of the (kept) blat hit, starting counting at 0

                    $cnt2++;
                }
            }
        }

        for ($t=0; $t<2; $t++) { # $t=0 for the 'a' (forward) reads, $t=1 for the 'b' (reverse) reads
            $max_length = 0;
            $secondmax_length = 0;
            $N = @{$read_mapping_to_genome_blatoutput[$t]};
            $maxkey = "";
            $secondmaxkey = "";
            $maxkey_nummismatch = 0;
            $secondmaxkey_nummismatch = 0;
            for ($c=0; $c<$N; $c++) {
                $key = $read_mapping_to_genome_blatoutput[$t][$c];
                @a2 = split(/\t/,$key);
                if ($a2[3] > $max_length) {
                    $max_length = $a2[3]; # note: you might think index should be a 2, but $loc has a tab in it
                    $maxkey_nummismatch = $a2[8];
                    $maxkey = $key;
                }
            }
            # make the array 'read_mapping_to_genome_coords' which has things in 'read_mapping_to_genome_blatoutput'
            # that are within five bases of the longest, mapped to genomic coords
            $c2=0;
            for ($c=0; $c<$N; $c++) {
                $key = $read_mapping_to_genome_blatoutput[$t][$c];
                @a4 = split(/\t/,$key);
                if ($a4[3] > $max_length - 2 && $a4[8] <= $maxkey_nummismatch + 2) {
                    # might want to change $max_length - 2 to  $max_length - n for n>2 or even n=1,
                    # should do some rigorous benchmarking to figure this out
                    if ($sname[$t] =~ /a/) {
                        $seq = getsequence($a4[6], $a4[9], $a4[4], $seqa);
                    } else {
                        $seq = getsequence($a4[6], $a4[9], $a4[4], $seqb);
                    }
                    $STRAND = $a4[4];
                    if ($t==1) {
                        if ($STRAND eq "-") {
                            $STRAND = "+";
                        } else {
                            $STRAND = "-";
                        }
                    }

                    $read_mapping_to_genome_coords[$t][$c2] = "$a4[0]\t$a4[1]\t$a4[2]\t$seq\t$STRAND";
                    $read_mapping_to_genome_pairing_candidate[$t][$c2] = $read_mapping_to_genome_blatoutput[$t][$c];
                    $c2++;
                }
            }
            for ($c=0; $c<$N; $c++) {
                $key = $read_mapping_to_genome_blatoutput[$t][$c];
                if ($key ne $maxkey) {
                    @a3 = split(/\t/,$key);
                    if ($a3[3] > $secondmax_length) {
                        $secondmax_length = $a3[3];
                        $secondmaxkey_nummismatch = $a2[8];
                        $secondmaxkey = $key;
                    }
                }
            }

            # NOTE: The following keeps track of things that could be reported as unique matches of forward/reverse
            # reads in the case that the paired read does not map, a case that would be missed by the above, 
            # basically if the longest read is not more than 5 bases longer than the second longest but is at 
            # least two longer and has fewer mismatches, then we keep it as the best candidate

            @a5 = split(/\t/,$secondmaxkey);
            if ($secondmax_length < $max_length) {
                @a6 = split(/\t/,$maxkey);
                $STRAND = $a6[4];
                if ($t==1) {
                    if ($STRAND eq "-") {
                        $STRAND = "+";
                    } else {
                        $STRAND = "-";
                    }
                }
                if ($sname[$t] =~ /a/) {
                    $seq = getsequence($a6[6], $a6[9], $a6[4], $seqa);
                } else {
                    $seq = getsequence($a6[6], $a6[9], $a6[4], $seqb);
                }
                $one_dir_only_candidate[$t] = "$a6[0]\t$a6[1]\t$a6[2]\t$seq\t$STRAND";
            }
        }

        $numa = @{$read_mapping_to_genome_coords[0]} + 0;
        $numb = @{$read_mapping_to_genome_coords[1]} + 0;

        if ($numa == 1 && $numb == 0) { # unique forward match, no reverse
            print $unique_fh "$read_mapping_to_genome_coords[0][0]\n";
        }
        if ($numa > 1 && $numb == 0) {
            $unique = 0;
            if ($one_dir_only_candidate[0] =~ /\S/) {
                print $unique_fh "$one_dir_only_candidate[0]\n";
                $unique = 1;
            }
            undef @spans;
            undef %CHRS;
            if ($unique == 0) {
                $nchrs = 0;
                $STRAND = "-";
                for ($i=0; $i<$numa; $i++) {
                    @B1 = split(/\t/, $read_mapping_to_genome_coords[0][$i]);
                    $spans[$i] = $B1[2];
                    if ($i==0) {
                        $seq_temp = $B1[3];
                    }
                    if ($B1[4] eq "+") {
                        $STRAND = "+";
                    }
                    $CHRS{$B1[1]}++;
                }
                $nchrs = 0;
                foreach $ky (keys %CHRS) {
                    $nchrs++;
                    $CHR = $ky;
                }
                $str = intersect(\@spans, $seq_temp);
                if ($str ne "0\t" && $nchrs == 1) {
                    $str =~ s/^(\d+)\t/$CHR\t/;
                    $size = $1;
                    if ($size >= $min_size_intersection_allowed) {
                        @ss = split(/\t/,$str);
                        $seq_new = addJunctionsToSeq($ss[2], $ss[1]);
                        print $unique_fh "seq.$seq_count";
                        print $unique_fh "a\t$ss[0]\t$ss[1]\t$seq_new\t$STRAND\n";
                        $unique = 1;
                    }
                }
            }
            undef @B1;
            undef @ss;
            undef @spans;
            if ($unique == 0) {
                for ($i=0; $i<$numa; $i++) {
                    print $nu_fh "$read_mapping_to_genome_coords[0][$i]\n";
                }
            }
        }
        if ($numb == 1 && $numa == 0) { # unique reverse match, no forward
            print $unique_fh "$read_mapping_to_genome_coords[1][0]\n";
        }
        if ($numa == 0 && $numb > 1) {
            $unique = 0;
            if ($one_dir_only_candidate[1] =~ /\S/) {
                print $unique_fh "$one_dir_only_candidate[1]\n";
                $unique = 1;
            }
            undef @spans;
            undef %CHRS;
            if ($unique == 0) {
                $nchrs = 0;
                $STRAND = "-";
                for ($i=0; $i<$numb; $i++) {
                    @B1 = split(/\t/, $read_mapping_to_genome_coords[1][$i]);
                    $spans[$i] = $B1[2];
                    if ($i==0) {
                        $seq_temp = $B1[3];
                    }
                    if ($B1[4] eq "+") {
                        $STRAND = "+";
                    }
                    $CHRS{$B1[1]}++;
                }
                $nchrs = 0;
                foreach $ky (keys %CHRS) {
                    $nchrs++;
                    $CHR = $ky;
                }
                $str = intersect(\@spans, $seq_temp);
                if ($str ne "0\t" && $nchrs == 1) {
                    $str =~ s/^(\d+)\t/$CHR\t/;
                    $size = $1;
                    if ($size >= $min_size_intersection_allowed) {
                        @ss = split(/\t/,$str);
                        $seq_new = addJunctionsToSeq($ss[2], $ss[1]);
                        print $unique_fh "seq.$seq_count";
                        print $unique_fh "b\t$ss[0]\t$ss[1]\t$seq_new\t$STRAND\n";
                        $unique = 1;
                    }
                }
            }
            undef @B1;
            undef @ss;
            undef @spans;
            if ($unique == 0) {
                for ($i=0; $i<$numb; $i++) {
                    print $nu_fh "$read_mapping_to_genome_coords[1][$i]\n";
                }
            }
        }
        if ($numa > 0 && $numb > 0 && $numa * $numb < 1000000) { # this is one very big case within which we search
            # for consistent a/b mappers
            for ($i=0; $i<$numa; $i++) {
                @B1 = split(/\t/, $read_mapping_to_genome_pairing_candidate[0][$i]);
                $achr = $B1[1];
                @AR = split(/\t/,$read_mapping_to_genome_coords[0][$i]);
                $astrand = $AR[4];
                $astrand_hold = $astrand;
                $aseq = $AR[3];
                $aseq_hold = $aseq;
                $aspans = $B1[2];
                $aave = &getave($aspans);
                $aave_hold = $aave;
                $aspans_hold = $aspans;
                @aexons = split(/, /,$B1[2]);
                undef @astarts;
                undef @aends;
                undef @astarts_hold;
                undef @aends_hold;
                for ($e=0; $e<@aexons; $e++) {
                    @c = split(/-/,$aexons[$e]);
                    $astarts[$e] = $c[0];
                    $astarts_hold[$e] = $astarts[$e];
                    $aends[$e] = $c[1];
                    $aends_hold[$e] = $aends[$e];
                }
                $astart = $astarts[0];
                $astart_hold = $astart;
                $aend = $aends[$e-1];
                $aend_hold = $aend;
                for ($j=0; $j<$numb; $j++) {
                    $astart = $astart_hold;
                    $aend = $aend_hold;
                    $aspans = $aspans_hold;
                    $aave = $aave_hold;
                    $aseq = $aseq_hold;
                    undef @astarts;
                    undef @aends;
                    for ($e=0; $e<@aexons; $e++) {
                        $astarts[$e] = $astarts_hold[$e];
                        $aends[$e] = $aends_hold[$e];
                    }
                    @B1 = split(/\t/, $read_mapping_to_genome_pairing_candidate[1][$j]);
                    $bchr = $B1[1];
                    @BR = split(/\t/,$read_mapping_to_genome_coords[1][$j]);
                    $bstrand = $BR[4];
                    $bseq = $BR[3];
                    $bspans = $B1[2];
                    $bave = &getave($bspans);
                    @bexons = split(/, /,$B1[2]);
                    undef @bstarts;
                    undef @bends;
                    for ($e=0; $e<@bexons; $e++) {
                        @c = split(/-/,$bexons[$e]);
                        $bstarts[$e] = $c[0];
                        $bends[$e] = $c[1];
                    }
                    $bstart = $bstarts[0];
                    $bend = $bends[$e-1];
		
                    #		    print "----------------\n";
                    #		    print "$read_mapping_to_genome_coords[0][$i]\n";
                    #		    print "$read_mapping_to_genome_coords[1][$j]\n";
                    #		    print "aave = $aave\n";
                    #		    print "bave = $bave\n";
		
                    $proceedflag = 0;
                    if ($astrand eq "+" && $bstrand eq "+" && $aave <= $bave) {
                        $proceedflag = 1;
                    }
                    if ($astrand eq "-" && $bstrand eq "-" && $bave <= $aave) {
                        $proceedflag = 1;
                    }
                    if ($achr eq $bchr && $proceedflag == 1) {
                        $ostrand = $astrand; # "o" for "original"
                        if ($astrand eq "+" && $bstrand eq "+" && ($aend < $bstart-1) && ($bstart - $aend <= $self->{max_pair_dist})) {
                            $consistent_mappers{"$read_mapping_to_genome_coords[0][$i]\n$read_mapping_to_genome_coords[1][$j]"}++;
                        }
                        if ($astrand eq "-" && $bstrand eq "-" && ($bend < $astart-1) && ($astart - $bend <= $self->{max_pair_dist})) {
                            $consistent_mappers{"$read_mapping_to_genome_coords[0][$i]\n$read_mapping_to_genome_coords[1][$j]"}++;
                        }
                        $swaphack = "false";
                        if (($astrand eq "-") && ($bstrand eq "-") && ($bend >= $astart - 1) && ($astart >= $bstart) && ($aend >= $bend)) {
                            # this is a hack to switch the a and b reads so the following if can take care of both cases
                            $swaphack = "true";
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
                            $num_exons_merged = @astarts + @bstarts - 1;
                            undef @mergedstarts;
                            undef @mergedends;
                            $H=0;
                            for ($e=0; $e<@astarts; $e++) {
                                $mergedstarts[$H] = @astarts[$e];
                                $H++;
                            }
                            for ($e=1; $e<@bstarts; $e++) {
                                $mergedstarts[$H] = @bstarts[$e];
                                $H++;
                            }
                            $H=0;
                            for ($e=0; $e<@aends-1; $e++) {
                                $mergedends[$H] = @aends[$e];
                                $H++;
                            }
                            for ($e=0; $e<@bends; $e++) {
                                $mergedends[$H] = @bends[$e];
                                $H++;
                            }
                            $num_exons_merged = $H;
                            $merged_length = $mergedends[0]-$mergedstarts[0]+1;
                            $merged_spans = "$mergedstarts[0]-$mergedends[0]";
                            for ($e=1; $e<$num_exons_merged; $e++) {
                                $merged_length = $merged_length + $mergedends[$e]-$mergedstarts[$e]+1;
                                $merged_spans = $merged_spans . ", $mergedstarts[$e]-$mergedends[$e]";
                            }
                            $merged_seq = $aseq . $bseq;
                            $consistent_mappers{"seq.$seq_count\t$achr\t$merged_spans\t$merged_seq\t$ostrand"}++;
                        }
                        if (($astrand eq "+") && ($bstrand eq "+") && ($aend >= $bstart) && ($bstart >= $astart) && ($bend >= $aend)) {
                            $f = 0;
                            $consistent = 1;
                            $flag = 0;
                            while ($flag == 0 && $f < @astarts) { # this checks for a valid overlap
                                if ($bstart >= $astarts[$f] && $bstart <= $aends[$f] && $bends[0]>=$aends[$f]) {
                                    $first_overlap_exon = $f; # this index is relative to the a read
                                    $flag = 1;
                                } else {
                                    $f++;
                                }
                            }
                            if ($flag == 0) { # didn't find a valid overlap, so will check if removing
                                # the first base of the reverse read will help
                                $bstart++;
                                $bstarts[0]++;
                                $bseq =~ s/^(.)//;
                                $base_hold = $1;
                                $f = 0;
                                while ($flag == 0 && $f < @astarts) {
                                    if ($bstart >= $astarts[$f] && $bstart <= $aends[$f] && $bends[0]>=$aends[$f]) {
                                        $first_overlap_exon = $f; # this index is relative to the a read
                                        $flag = 1;
                                    } else {
                                        $f++;
                                    }
                                }
                                if ($flag == 0) {
                                    $bstart--;
                                    $bstarts[0]--;
                                    $bseq = $base_hold . $bseq;
                                }
                            }
                            if ($flag != 1) {
                                $consistent = 0;
                            }
                            $f = @bstarts-1;
                            while ($flag == 0 && $f >= 0) { # try the other direction
                                if ($aend >= $bstarts[$f] && $aend <= $bends[$f] && $aends[0]>=$bends[$f]) {
                                    $last_overlap_exon = $f; # this index is relative to the b read
                                    $flag = 1;
                                } else {
                                    $f--;
                                }
                            }
                            if ($flag == 0) { # didn't find a valid overlap, so will check if removing
                                # the last base of the forward read will help
                                $aend--;
                                $aends[@astarts-1]--;
                                $aseq =~ s/(.)$//;
                                $base_hold = $1;
                                $f = @bstarts-1;
                                while ($flag == 0 && $f >= 0) {
                                    if ($aend >= $bstarts[$f] && $aend <= $bends[$f] && $aends[0]>=$bends[$f]) {
                                        $last_overlap_exon = $f; # this index is relative to the b read
                                        $flag = 1;
                                    } else {
                                        $f--;
                                    }
                                }
                                if ($flag ==0) {
                                    $aend++;
                                    $aends[@astarts-1]++;
                                    $aseq = $aseq . $base_hold;
                                }
                            }
                            if ($flag != 1) {
                                $consistent = 0;
                            }
			
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
                                $NN = @astarts;
                                $alength=0;
                                for ($e=0; $e<@astarts; $e++) {
                                    $alength = $alength + $aends[$e] - $astarts[$e] + 1;
                                }
                                $MM = @bstarts;
                                $aseq =~ s/://g;
                                $bseq =~ s/://g;
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
                                # now gotta put back any insertions into the merged...
                                $aseq_temp = $aseq;
                                $aseq_temp =~ s/\+.*\+//g; # THIS IS ONLY GOING TO WORK IF THERE IS ONE INSERTION
                                # as is guaranteed, seach for "comment.1"
                                # This limitation should probably be fixed at some point...
                                @s1 = split(//,$aseq_temp);
                                $aseqlength = @s1;
                                $bseq_temp = $bseq;
                                $bseq_temp =~ /(\+.*\+)([^+]*)$/;
                                $ins = $1;
                                $bpostfix = $2;
                                $bseq_temp =~ s/(\+.*\+)//; # SAME COMMENT AS ABOVE
                                @s2 = split(//,$bseq_temp);
                                $bseqlength = @s2;
                                $merged_seq = $aseq;
                                for ($p=$aseqlength+$bseqlength-$merged_length; $p<@s2; $p++) {
                                    $merged_seq = $merged_seq . $s2[$p]
                                }
                                # the following if makes sure it's not done twice in the overlap
                                # because they can disagree there and cause havoc
                                $postfix_length = length($bpostfix);
                                if ($postfix_length <= $merged_length - $alength) {
                                    $str_temp = $ins . $bpostfix;
                                    $str_temp =~ s/\+/\\+/g;
                                    if (!($merged_seq =~ /$str_temp$/)) {
                                        $merged_seq =~ s/$bpostfix$/$ins$bpostfix/;
                                    }
                                }
                                $consistent_mappers{"seq.$seq_count\t$achr\t$merged_spans\t$merged_seq\t$ostrand"}++;
                            }
                            if ($swaphack eq "true") {
                                $astrand = "-";
                            }
                        }
                    }
                }
            }


            # OK, WE'VE COMPILED A LIST OF ALL CONSISTENT FORWARD/REVERSE PAIRS, WE NOW
            # COUNT THEM AND EVALUATE THEM

            $max_spans_length = 0;
            foreach $key (keys %consistent_mappers) {
                @K = split(/\t/,$key);
                @SS = split(/, /, $K[2]);
                $sl = 0;
                for ($i=0; $i<@SS; $i++) {
                    @SS2 = split(/-/,$SS[$i]);
                    $sl = $sl + $SS2[1] - $SS2[0] + 1;
                }
                if ($sl > $max_spans_length) {
                    $max_spans_length = $sl;
                }
            }

            $num_consistent_mappers=0;
            foreach $key (keys %consistent_mappers) {
                @K = split(/\t/,$key);
                @SS = split(/, /, $K[2]);
                $sl = 0;
                for ($i=0; $i<@SS; $i++) {
                    @SS2 = split(/-/,$SS[$i]);
                    $sl = $sl + $SS2[1] - $SS2[0] + 1;
                }
                if ($sl == $max_spans_length) {
                    $consistent_mappers2{$key}++;
                    $num_consistent_mappers++;
                }
            }
            if ($num_consistent_mappers == 1) {
                foreach $key (keys %consistent_mappers2) {
                    @A = split(/\n/,$key);
                    for ($n=0; $n<@A; $n++) {
                        @a = split(/\t/,$A[$n]);
                        $seq_new = addJunctionsToSeq($a[3], $a[2]);
                        if (@A == 2 && $n == 0) {
                            $outstring = "$a[0]\t$a[1]\t$a[2]\t$seq_new\t$a[4]\n";
                            print $unique_fh $outstring;
                        }
                        if (@A == 2 && $n == 1) {
                            $outstring = "$a[0]\t$a[1]\t$a[2]\t$seq_new\t$a[4]\n";
                            print $unique_fh $outstring;
                        }
                        if (@A == 1) {
                            print $unique_fh "$a[0]\t$a[1]\t$a[2]\t$seq_new\t$a[4]\n";
                        }
                    }
                }
            } else {
                $ccnt = 0;
                $num_absplit = 0;
                $num_absingle = 0;
                undef @spans1;
                undef @spans2;
                undef %CHRS;
                $STRAND = "-";
                foreach $key (keys %consistent_mappers2) {
                    @A = split(/\n/,$key);
                    @a = split(/\t/,$A[0]);
                    $CHRS{$a[1]}++;
                    $strnd[$ccnt] = $a[4];
                    if ($a[4] eq "+") {
                        $STRAND = "+";
                    }
                    if (@A == 1) {
                        $num_absingle++;
                        $spans1[$ccnt] = $a[2];
                        if ($ccnt == 0) {
                            $firstseq = $a[3];
                        }
                    }
                    if (@A == 2) {
                        $num_absplit++;
                        $spans1[$ccnt] = $a[2];
                        if ($ccnt == 0) {
                            $firstseq1 = $a[3];
                        }
                        @a = split(/\t/,$A[1]);
                        $spans2[$ccnt] = $a[2];
                        if ($ccnt == 0) {
                            $firstseq2 = $a[3];
                        }
                    }
                    $ccnt++;
                    $key_hold = $key;
                }
                $nchrs = 0;
                foreach $ky (keys %CHRS) {
                    $nchrs++;
                    $CHR = $ky;
                }
                $nointersection = 1;
                if ($num_absingle == 0 && $num_absplit > 0 && $nchrs == 1) {
                    $firstseq1 =~ s/://g;
                    $firstseq2 =~ s/://g;
                    $str1 = intersect(\@spans1, $firstseq1);
                    $str2 = intersect(\@spans2, $firstseq2);
                    if ($str1 ne "0\t" && $str2 eq "0\t") {
                        $str1 =~ s/^(\d+)\t/$CHR\t/;
                        $size1 = $1;
                        if ($size1 >= $min_size_intersection_allowed) {
                            @ss = split(/\t/,$str1);
                            $seq_new = addJunctionsToSeq($ss[2], $ss[1]);
                            print $unique_fh "seq.$seq_count";
                            print $unique_fh "a\t$ss[0]\t$ss[1]\t$seq_new\t$STRAND\n";
                            $nointersection = 0;
                        }
                    }
                    if ($str2 ne "0\t" && $str1 eq "0\t") {
                        $str2 =~ s/^(\d+)\t/$CHR\t/;
                        $size2 = $1;
                        if ($size2 >= $min_size_intersection_allowed) {
                            @ss = split(/\t/,$str2);
                            $seq_new = addJunctionsToSeq($ss[2], $ss[1]);
                            print $unique_fh "seq.$seq_count";
                            print $unique_fh "b\t$ss[0]\t$ss[1]\t$seq_new\t$STRAND\n";
                            $nointersection = 0;
                        }
                    }
                    if ($str1 ne "0\t" && $str2 ne "0\t") {
                        $str1 =~ s/^(\d+)\t/$CHR\t/;
                        $size1 = $1;
                        $str2 =~ s/^(\d+)\t/$CHR\t/;
                        $size2 = $1;
                        if ($size1 >= $min_size_intersection_allowed && $size2 < $min_size_intersection_allowed) {
                            @ss = split(/\t/,$str1);
                            $seq_new = addJunctionsToSeq($ss[2], $ss[1]);
                            print $unique_fh "seq.$seq_count";
                            print $unique_fh "a\t$ss[0]\t$ss[1]\t$seq_new\t$STRAND\n";
                            $nointersection = 0;
                        }
                        if ($size2 >= $min_size_intersection_allowed && $size1 < $min_size_intersection_allowed) {
                            @ss = split(/\t/,$str2);
                            $seq_new = addJunctionsToSeq($ss[2], $ss[1]);
                            print $unique_fh "seq.$seq_count";
                            print $unique_fh "b\t$ss[0]\t$ss[1]\t$seq_new\t$STRAND\n";
                            $nointersection = 0;
                        }
                        if ($size1 >= $min_size_intersection_allowed && $size2 >= $min_size_intersection_allowed) {
                            $str1 =~ /^[^\t]+\t(\d+)[^\t+]-(\d+)\t/;
                            $start1 = $1;
                            $end1 = $2;
                            $str2 =~ /^[^\t]+\t(\d+)[^\t+]-(\d+)\t/;
                            $start2 = $1;
                            $end2 = $2;
                            if ((($start2 - $end1 > 0) && ($start2 - $end1 < $self->{max_pair_dist})) || (($start1 - $end2 > 0) && ($start1 - $end2 < $self->{max_pair_dist}))) {
                                @ss = split(/\t/,$str1);
                                $seq_new = addJunctionsToSeq($ss[2], $ss[1]);
                                print $unique_fh "seq.$seq_count";
                                print $unique_fh "a\t$ss[0]\t$ss[1]\t$seq_new\t$STRAND\n";
                                @ss = split(/\t/,$str2);
                                $seq_new = addJunctionsToSeq($ss[2], $ss[1]);
                                print $unique_fh "seq.$seq_count";
                                print $unique_fh "b\t$ss[0]\t$ss[1]\t$seq_new\t$STRAND\n";
                                $nointersection = 0;
                            }
                        }
                    }
                }
                if ($num_absingle > 0 && $num_absplit == 0 && $nchrs == 1) {
                    $str = intersect(\@spans1, $firstseq);
                    if ($str ne "0\t") {
                        $str =~ s/^(\d+)\t/$CHR\t/;
                        $size = $1;
                        if ($size >= $min_size_intersection_allowed) {
                            @ss = split(/\t/,$str);
                            $seq_new = addJunctionsToSeq($ss[2], $ss[1]);
                            print $unique_fh "seq.$seq_count\t$ss[0]\t$ss[1]\t$seq_new\t$STRAND\n";
                            $nointersection = 0;
                        }
                    }
                }
                # NOTE: insertions in non-unique mappers are not being reported.
                if (($nointersection == 1) || ($nchrs > 1) || ($num_absingle > 0 && $num_absplit > 0)) {
                    foreach $key (keys %consistent_mappers2) {
                        @A = split(/\n/,$key);
                        for ($n=0; $n<@A; $n++) {
                            @a = split(/\t/,$A[$n]);
                            $seq_new = addJunctionsToSeq($a[3], $a[2]);
                            if (@A == 2 && $n == 0) {
                                print $nu_fh "$a[0]\t$a[1]\t$a[2]\t$seq_new\t$a[4]\n";
                            }
                            if (@A == 2 && $n == 1) {
                                print $nu_fh "$a[0]\t$a[1]\t$a[2]\t$seq_new\t$a[4]\n";
                            }
                            if (@A == 1) {
                                print $nu_fh "$a[0]\t$a[1]\t$a[2]\t$seq_new\t$a[4]\n";
                            }
                        }
                    }
                }
            }
        }

        undef %consistent_mappers;
        undef %consistent_mappers2;
        undef @read_mapping_to_genome_blatoutput;
        undef %maxlength;
        undef %blathits;
        undef %Ncount;
        undef %cnt;
        undef @one_dir_only_candidate;
        undef @read_mapping_to_genome_coords;
        undef @read_mapping_to_genome_pairing_candidate;
    }

    close($unique_fh);
    #close(INSERTIONFILE);
    
    # seq 12 in s_5 is an intersting marginal case for uniqueness...
    # seq 17 hits four exons, but finds only 3 with default BLAT params
    # seq.461 example with a ton of short hits

}


sub getsequence {
    ($blocksizes, $qstarts, $strand, $seq) = @_;
    chomp($seq);
    if ($strand eq "-") {
	@a_g = split(//,$seq);
	$n_g = @a_g;
	$revcomp = "";
	for ($i_g=$n_g-1; $i_g>=0; $i_g--) {
	    $flag_g = 0;
	    if ($a_g[$i_g] eq 'A') {
		$revcomp = $revcomp . "T";
		$flag_g = 1;
	    }
	    if ($a_g[$i_g] eq 'T') {
		$revcomp = $revcomp . "A";
		$flag_g = 1;
	    }
	    if ($a_g[$i_g] eq 'C') {
		$revcomp = $revcomp . "G";
		$flag_g = 1;
	    }
	    if ($a_g[$i_g] eq 'G') {
		$revcomp = $revcomp . "C";
		$flag_g = 1;
	    }
	    if ($flag_g == 0) {
		$revcomp = $revcomp . $a_g[$i_g];
	    }
	}
	$seq = $revcomp;
    }
    $blocksizes =~ s/,\s*$//;
    $qstarts =~ s/,\s*$//;
    @a_g = split(/,/,$blocksizes);
    @b_g = split(/,/,$qstarts);
    @s_g = split(//,$seq);
    $seq_out = "";
    for ($i_g=0; $i_g<@a_g; $i_g++) {
	for ($j_g=0; $j_g<$a_g[$i_g]; $j_g++) {
	    $seq_out = $seq_out . "$s_g[$b_g[$i_g]+$j_g]";
	}
	if ($i_g<@a_g-1) {
	    if ($a_g[$i_g]+$b_g[$i_g] == $b_g[$i_g+1]) {
		$seq_out = $seq_out . ":";
	    } else {
		$seq_out = $seq_out . "+";
		for ($k_g=0; $k_g<$b_g[$i_g+1]-$a_g[$i_g]-$b_g[$i_g]; $k_g++) {
		    $seq_out = $seq_out . $s_g[$b_g[$i_g]+$a_g[$i_g]+$k_g];
		}
		$seq_out = $seq_out . "+";
	    }
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
	@a_i = split(/, /,$spans[$s_i]);
	for ($i_i=0;$i_i<@a_i;$i_i++) {
	    @b_i = split(/-/,$a_i[$i_i]);
	    for ($j_i=$b_i[0];$j_i<=$b_i[1];$j_i++) {
		$chash{$j_i}++;
	    }
	}
    }
    $spanlength = 0;
    $flag_i = 0;
    $maxspanlength = 0; # going to report one contiguous span of the read, so will find the longest
    $maxspan_start = 0;
    $maxspan_end = 0;
    $prevkey = 0;
    for $key_i (sort {$a <=> $b} keys %chash) {
	if ($chash{$key_i} == $num_i) { # this location is contained in all sets of spans, so keep it
	    if ($flag_i == 0) {         # starts a new span
		$flag_i = 1;
		$span_start = $key_i;
	    }
	    $spanlength++;
	} else {
	    if ($flag_i == 1) { # ends a span, if one has been started
		$flag_i = 0;
		if ($spanlength > $maxspanlength) {
		    $maxspanlength = $spanlength;
		    $maxspan_start = $span_start;
		    $maxspan_end = $prevkey;
		}
		$spanlength = 0;
	    }
	}
	$prevkey = $key_i;
    }
    if ($flag_i == 1) {
	if ($spanlength > $maxspanlength) {
	    $maxspanlength = $spanlength;
	    $maxspan_start = $span_start;
	    $maxspan_end = $prevkey;
	}
    }
    if ($maxspanlength > 0) {
	@a_i = split(/, /,$spans[0]);
	@b_i = split(/-/,$a_i[0]);
	$i_i=0;
	until ($b_i[1] >= $maxspan_start) {
	    $i_i++;
	    @b_i = split(/-/,$a_i[$i_i]);
	}
	$prefix_size = $maxspan_start - $b_i[0]; # the size of the part removed from spans[0]
	for ($j_i=0; $j_i<$i_i; $j_i++) {
	    @b_i = split(/-/,$a_i[$j_i]);
	    $prefix_size = $prefix_size + $b_i[1] - $b_i[0] + 1;
	}
	$seq =~ s/://g;
	@s_i = split(//,$seq);
	$newseq = "";
	
	$ADD = 0;
	@INS_i = split(/\+/,$seq);
	$insertions_length_in_prefix=0;

	if (@INS_i > 0) {
	    $running_length_i = length($INS_i[0]);
	    $ind_i=0;
	    until ($running_length_i > $prefix_size) {
		$ind_i = $ind_i + 2;
		$running_length_i = $running_length_i + length($INS_i[$ind_i]);
	    }
	    for ($cnt_i=1; $cnt_i<$ind_i; $cnt_i=$cnt_i+2) {
		$insertions_length_in_prefix = $insertions_length_in_prefix + length($INS_i[$cnt_i]) + 2;
	    }
	}

	for ($i_i=$prefix_size+$insertions_length_in_prefix; $i_i<$prefix_size + $maxspanlength + $ADD + $insertions_length_in_prefix; $i_i++) {
	    # check here for odd number of + signs before $i_i=$prefix_size, otherwise
	    # get caught in an infinite loop at the until below.  In other words the
	    # prefix ended right in the middle of an insertion (pesky insertions).
	    if ($s_i[$i_i] eq "+") {
		$newseq = $newseq . $s_i[$i_i];
		$i_i++;
		$ADD++;
		until ($s_i[$i_i] eq "+") {
		    $newseq = $newseq . $s_i[$i_i];
		    $i_i++;
		    $ADD++;
		}
		$ADD++;
	    }
	    $newseq = $newseq . $s_i[$i_i];
	}

	$flag_i = 0;
	$i_i=0;
	@b_i = split(/-/,$a_i[0]);
	until ($b_i[1] >= $maxspan_start) {
	    $i_i++;
	    @b_i = split(/-/,$a_i[$i_i]);
	}
	$newspans = $maxspan_start;
	until ($b_i[1] >= $maxspan_end) {
	    $newspans = $newspans . "-$b_i[1]";
	    $i_i++;
	    @b_i = split(/-/,$a_i[$i_i]);
	    $newspans = $newspans . ", $b_i[0]";
	}
	$newspans = $newspans . "-$maxspan_end";
	$off = "";
	for ($i_i=0; $i_i<$prefix_size; $i_i++) {
	    $off = $off . " ";
	}
	return "$maxspanlength\t$newspans\t$newseq";
    } else {
	return "0\t";
    }
}

__END__

=head1 NAME

RUM::Script::ParseBlatOut - Parse output of blat

=head1 METHODS

=over 4

=item is_blat_file_sorted($blat_file)

Return 'true' if the given filename appears to be sorted by location,
otherwise 'false'.
