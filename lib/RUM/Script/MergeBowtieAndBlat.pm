package RUM::Script::MergeBowtieAndBlat;

no warnings;
use autodie;

use List::Util qw(max);
use Data::Dumper;
use RUM::Usage;
use RUM::Logging;
use RUM::Common qw(addJunctionsToSeq spansTotalLength min_overlap_for_read_length);
use RUM::BowtieIO;
use RUM::RUMIO;
use RUM::Mapper;
use Getopt::Long;

our $log = RUM::Logging->get_logger();

$|=1;

# These are used by both main and joinifpossible. It would be nice to
# refactor in some way so that they don't need to be global variables.
my ($astem, $a_insertion, $aseq_p, $apost);
my ($bstem, $b_insertion, $bseq_p, $bpost);
my $dflag;

sub longest_read {
    use strict;
    my ($iter) = @_;
    my $count = 0;
    my $readlength = 0;
    while (my $aln = $iter->next_val) {
        my $length = 0;
        my $locs = $aln->locs;
        
        $count++;
        for my $span ( @{ $locs } ) {
            my ($start, $end) = @{ $span };
            $length += $end - $start + 1;
        }
        if ($length > $readlength) {
            $readlength = $length;
            $count = 0;
        }
        if ($count > 50000) { 
            # it checked 50,000 lines without finding anything
            # larger than the last time readlength was
            # changed, so it's most certainly found the max.
            # Went through this to avoid the user having to
            # input the readlength.
            last;
        }
    }    
    return $readlength;
}

sub blat_nu_iter_for_readid {
    my ($filename, $readid) = @_;
    open my $fh, '-|', "grep $readid $filename";
    return RUM::BowtieIO->new(-fh => $fh, strand_last => 1);
}

sub main {

    GetOptions(
        "bowtie-unique-in=s"     => \(my $bowtie_unique_in),
        "blat-unique-in=s"       => \(my $blat_unique_in),
        "bowtie-non-unique-in=s" => \(my $bowtie_non_unique_in),
        "blat-non-unique-in=s"   => \(my $blat_non_unique_in),
        "unique-out=s"           => \(my $unique_out),
        "non-unique-out=s"       => \(my $non_unique_out),
        "single"                 => \(my $single),
        "paired"                 => \(my $paired),
        "max-pair-dist=s"        => \(my $max_distance_between_paired_reads = 500000),
        "read-length=s"          => \(my $readlength = 0),
        "min-overlap"            => \(my $user_min_overlap),
        "help|h"                 => sub { RUM::Usage->help },
        "verbose|v"              => sub { $log->more_logging(1) },
        "quiet|q"                => sub { $log->less_logging(1) }
    );

    # Input files
    $bowtie_unique_in or RUM::Usage->bad(
        "Please provide unique bowtie mappers with --bowtie-unique-in");
    $blat_unique_in or RUM::Usage->bad(
        "Please provide unique blat mappers with --blat-unique-in");
    $bowtie_non_unique_in or RUM::Usage->bad(
        "Please provide non-unique bowtie mappers with --bowtie-non-unique-in");
    $blat_non_unique_in or RUM::Usage->bad(
        "Please provide non-unique blat mappers with --blat-non-unique-in");

    # Output files
    $unique_out or RUM::Usage->bad(
        "Please specify output file for unique mappers with --unique-out");
    $non_unique_out or RUM::Usage->bad(
        "Please specify output file for non-unique mappers with --non-unique-out");
    
    ($single xor $paired) or RUM::Usage->bad(
        "Please specify exactly one of --single or --paired");

    if (defined($user_min_overlap)) {
        if (!($user_min_overlap =~ /^\d+$/) || $user_min_overlap < 5) {
            RUM::Usage->bad(
                "If you provide --min-overlap it must be an integer > 4");
        }
    }
    else {
        $user_min_overlap = 0;
    }

    # get readlength from bowtie unique/nu, if both empty then get max
    # in blat unique/nu

    if ($readlength == 0) {
        my @files = ($bowtie_unique_in,
                     $bowtie_non_unique_in,
                     $blat_unique_in,
                     $blat_non_unique_in);
        my @iters   = map { RUM::BowtieIO->new(-file => $_) } @files;
        my @lengths = map { longest_read($_) } @iters;
        $readlength = max(@lengths);
    }
    
    if ($readlength == 0) { # Couldn't determine the read length so going to fall back
        # on the strategy used for variable length reads.
        $readlength = "v";
    }
    if ($readlength ne "v") {
        $min_overlap = min_overlap_for_read_length($readlength);
    }
    if ($user_min_overlap > 0) {
        $min_overlap = $user_min_overlap;
    }

    my (%blat_ambiguous_mappers_a, %blat_ambiguous_mappers_b);

    {
        my $blat_nu_iter = RUM::BowtieIO->new(-file => $blat_non_unique_in);
        $log->info("Reading blat non-unique mappers");
        while (my $aln = $blat_nu_iter->next_val) {
            $id = $aln->order;
            if ($aln->contains_forward) {
                $blat_ambiguous_mappers_a{$id}++;
            }
            if ($aln->contains_reverse) {
                $blat_ambiguous_mappers_b{$id}++;
            }
        }
    };

    open my $outfile2, ">>", $blat_non_unique_in;
    my $nu_io = RUM::RUMIO->new(-fh => $outfile2, strand_last => 1);

    # The only things we're going to add to BlatNU.chunk are the reads
    # that are single direction only mappers in BowtieUnique that are
    # also single direction only mappers in BlatNU, but the two
    # mappings disagree.  Also, do not write these to RUM_Unique.

    {
        my $bowtie_nu_iter = RUM::BowtieIO->new(-file => $bowtie_non_unique_in);
        while (my $aln = $bowtie_nu_iter->next_val) {
            $bowtie_ambiguous_mappers{$aln->order}++;
        }
    };

    my $bowtie_unique_iter = RUM::BowtieIO->new(-file => $bowtie_unique_in,
                                                strand_last => 1);
    my $blat_unique_in     = RUM::BowtieIO->new(-file => $blat_unique_in,
                                                strand_last => 1);
    open my $outfile1, ">", $unique_out;
    my $unique_io = RUM::RUMIO->new(-fh => $outfile1,
                                    strand_last => 1);

    $max_distance_between_paired_reads = 500000;
    $num_lines_at_once = 10000;
    $linecount = 0;
    $FLAG = 1;
    $FLAG2 = 1;
    my $aln_prev = $blat_unique_in->next_val;
    my $line_prev = $aln_prev ? $aln_prev->raw : undef;
    chomp($line_prev);
    $last_id = 10**14;
    while ($FLAG == 1 || $FLAG2 == 1) {

        my (%bowtie_mappers_for, %blat_mappers_for, %allids);

        $linecount = 0;
        # get the bowtie output into hash1 for a bunch of ids
        while ($linecount < $num_lines_at_once) {

            my $aln = $bowtie_unique_iter->next_val;
            my $line = $aln ? $aln->raw : undef;

            if (!$aln) {
                $FLAG = 0;
                $linecount = $num_lines_at_once;
            } else {
                chomp($line);
                $id = $aln->order;
                $last_id = $id;
                $allids{$id}++;
                push @{ $bowtie_mappers_for{$id} }, $aln;

                if ($paired) {
                    # this makes sure we have read in both a and b reads, this approach might cause a problem
                    # if no, or very few, b reads mapped at all.
                    if ( (($linecount == ($num_lines_at_once - 1)) && !$aln->is_forward) ||
                         ($linecount < ($num_lines_at_once - 1)) ) {
                        $linecount++;
                    }
                } else {
                    if ( ($linecount == ($num_lines_at_once - 1)) || ($linecount < ($num_lines_at_once - 1)) ) {
                        $linecount++;
                    }
                }
            }
        }
        $line = $line_prev;
        $prev_id = $id;
        $id      = $aln_prev->order;
        if ($prev_id eq $id) {
            $FLAG3++;
            if ($FLAG3 > 1) {
                $FLAG2=0;
            }
        }
        my $blat_aln = RUM::BowtieIO->new(-fh => 1,
                                          strand_last => 1)->parse_aln($line);
        
        # now get the blat output for this bunch of ids, that goes in hash2
        while ($id && $id <= $last_id && $FLAG3 <= 1) {
            $allids{$id}++;
            push @{ $blat_mappers_for{$id} }, $blat_aln;
            $blat_aln = $blat_unique_in->next_val;

            if ($blat_aln) {
                $id = $blat_aln->order;
            } else {
                $FLAG2 = 0;
                $FLAG3 = 2;
            }
        }

        if ($FLAG2 == 1) {
            $line_prev = $blat_aln->raw;
        }
        if ($FLAG2 == 0) {
            $line_prev = "";
        }

        # now parse for this bunch of ids:

      ID: foreach $id (sort {$a <=> $b} keys %allids) {

            next ID if $bowtie_ambiguous_mappers{$id};
            next ID if $blat_ambiguous_mappers_a{$id} && $blat_ambiguous_mappers_b{$id};

            my $bowtie = RUM::Mapper->new(alignments => $bowtie_mappers_for{$id});
            my $blat   = RUM::Mapper->new(alignments => $blat_mappers_for{$id});

            if ( $blat_ambiguous_mappers_a{$id} && $bowtie->single_reverse ) {
                # ambiguous forward in in BlatNU, single reverse in
                # BowtieUnique.  See if there is a consistent pairing
                # so we can keep the pair, otherwise this read is
                # considered unmappable (not to be confused with
                # ambiguous)

                my $blat_nu_iter = blat_nu_iter_for_readid(
                    $blat_non_unique_in, $bowtie->single->as_forward->readid);
                $numjoined=0;

                while (my $aln = $blat_nu_iter->next_val) {
                    my @joined;
                    # check the strand
                    if ($bowtie->single->strand eq '-') {
                        # this is not backwards, line1 is the reverse read
                        @joined = joinifpossible($bowtie->single, $aln,
                                                 $max_distance_between_paired_reads);
                    } else {
                        @joined = joinifpossible($aln, $bowtie->single, $max_distance_between_paired_reads);
                    }
                    if (@joined) {
                        $numjoined++;
                        @joinedsave = @joined;
                    }
                }
                if ($numjoined == 1) { # if numjoined > 1 should probably intersect them to see if there's a 
                    # salvagable intersection
                    $unique_io->write_alns(\@joinedsave);
                }
                $remove_from_BlatNU{$id}++;
                next ID;
            }
            if ($blat_ambiguous_mappers_b{$id} && $bowtie->single_forward) {
                # ambiguous reverse in in BlatNU, single forward in BowtieUnique.  See if there is
                # a consistent pairing so we can keep the pair, otherwise this read is considered unmappable
                # (not to be confused with ambiguous)
                $numjoined=0;
                my @joined;
                my $blat_nu_iter = blat_nu_iter_for_readid(
                    $blat_non_unique_in, $bowtie->single->as_reverse->readid);
                while (my $aln = $blat_nu_iter->next_val) {
                    if ($bowtie->single->strand eq '-') {
                        @joined = joinifpossible($aln, $bowtie->single, $max_distance_between_paired_reads);
                    } else {
                        @joined = joinifpossible($bowtie->single, $aln, $max_distance_between_paired_reads);
                    }
                    if ($joined =~ /\S/) {
                        $numjoined++;
                        @joinedsave = @joined;
                    }
                }
                if ($numjoined == 1) { # if numjoined > 1 should probably intersect them to see if there's a 
                    # salvagable intersection
                    $unique_io->write_alns(\@joinedsave);
                }
                $remove_from_BlatNU{$id}++;
                next ID;
            }

            # Kept for debugging
            #	print "hash1{$id}[0]=$hash1{$id}[0]\n";
            #	print "hash2{$id}[0]=$hash2{$id}[0]\n";

            # These can have values -1, 0, 1, 2
            # All combinations possible except (0,0), so 15 total:
            # case -1: both forward and reverse reads mapped, consistently, and overlapped so were joined
            # case  0: neither read mapped
            # case  1: only one of the forward or reverse mapped
            # case  2: both forward and reverse reads mapped, consistently, but did not overlap so were not joined

            # THREE CASES:

            # Cases 0, 1, 2, 3
            if ( $bowtie->is_empty ) {
                $unique_io->write_alns($blat);
            }

            elsif ($bowtie->single) {
                if ($blat->is_empty) {
                    # this is a one-direction only mapper in
                    # BowtieUnique and nothing in BlatUnique, so must
                    # check it's not in BlatNU
                    if ( (!$blat_ambiguous_mappers_a{$id} && $bowtie->single_forward) ||
                         (!$blat_ambiguous_mappers_b{$id} && $bowtie->single_reverse)) {
                        $unique_io->write_alns($bowtie);
                    }
                }

                elsif ($blat->single) {
                    handle_both_single($bowtie, $blat, $unique_io, $nu_io,
                                       $readlength, $user_min_overlap,
                                       $max_distance_between_paired_reads);
                }
                elsif ($blat->unjoined) {
                    $unique_io->write_alns($blat);
                }     
                elsif ($blat->joined) {
                    $unique_io->write_alns($blat);
                }
            }
            
            elsif ($bowtie->unjoined) {
                if ($blat->is_empty) {
                    $unique_io->write_alns($bowtie);
                }
                elsif ($blat->single) {
                    $unique_io->write_alns($bowtie);
                }	
                if ($blat->unjoined) { # preference bowtie
                    $unique_io->write_alns($bowtie);
                }	
                if ($blat->joined) { # preference bowtie
                    $unique_io->write_alns($bowtie);
                }
            }

            elsif ($bowtie->joined) {
                if    ($blat->is_empty) {
                    $unique_io->write_alns($bowtie);
                }
                elsif ($blat->single) {
                    $unique_io->write_alns($bowtie);
                }
                elsif ($blat->unjoined) {
                    $unique_io->write_alns($bowtie);
                }
                elsif ($blat->joined) { 
                    # Prefer the bowtie mapping. This case should actually
                    # not happen because we should only send to blat those
                    # things which didn't have consistent bowtie maps.
                    $unique_io->write_alns($bowtie);
                }
            }
            
            # ALL FIFTEEN CASES DONE
        }
    }

    close($outfile2);

    # now need to remove the stuff in %remove_from_BlatNU from BlatNU

    my $blat_nu = RUM::RUMIO->new(
        -file => $blat_non_unique_in,
        strand_last => 1);

    open my $rum_nu, '>', $non_unique_out;
    while (my $aln = $blat_nu->next_val) {
        if ( ! $remove_from_BlatNU{$aln->order} ) {
            print $rum_nu $aln->raw . "\n";
        }
    }

    open $infile, '<', $bowtie_non_unique_in;
    # now append BowtieNU to get the full NU file
    while ($line = <$infile>) {
        print $rum_nu $line;
    }
}

sub joinifpossible () {
    use strict;
    my ($aln1, $aln2, $max_distance_between_paired_reads) = @_;
    my $LINE1 = $aln1->raw;
    my $LINE2 = $aln2->raw;
    my $aspans_p = RUM::RUMIO->format_locs($aln1);
    my $astart_p = $aln1->start;
    my $aend_p = $aln1->end;
    my $chra_p = $aln1->chromosome;
    my $aseq_p = $aln1->seq;
    my $astrand_p = $aln1->strand;
    my $seqnum_p = $aln1->readid_directionless;

    my @a_p = split(/\t/,$LINE2);
    my $bspans_p = RUM::RUMIO->format_locs($aln2);
    my $bstart_p = $aln2->start;
    my $bend_p = $aln2->end;
    my $chrb_p = $aln2->chromosome;
    my $bseq_p = $aln2->seq;
    my $bstrand_p = $aln2->strand;
    my @result;

    return if $astrand_p ne $bstrand_p;

    if (   ($chra_p eq $chrb_p)
        && ($astrand_p eq $bstrand_p)
        && ($aend_p < $bstart_p-1)
        && ($bstart_p - $aend_p < $max_distance_between_paired_reads)) {

	if ($aln1->is_forward) {
            push @result, $aln1, $aln2;
	} else {
            push @result, $aln2, $aln2;
	}
    }

    # if they overlap, can't merge properly if there's an insertion, so chop it out,
    # save it and put it back in before printing the next two if's do the chopping...
    $aseq_p =~ s/://g;
    if ($aseq_p =~ /\+/) {
	$aseq_p =~ /(.*)(\+.*\+)(.*)/; # Only going to work if there is at most one insertion, search on "comment.1"
	$astem = $1;
	$a_insertion = $2;
	$apost = $3;
	$aseq_p =~ s/\+.*\+//;
	if (!($a_insertion =~ /\S/)) {
	    push @result, "Something is wrong, here 1.07\n";
	}
    }
    $bseq_p =~ s/://g;
    if ($bseq_p =~ /\+/) {
	$bseq_p =~ /(.*)(\+.*\+)(.*)/; # Only going to work if there is at most one insertion, search on "comment.1"
	$bstem = $1;
	$b_insertion = $2;
	$bpost = $3;
	$bseq_p =~ s/\+.*\+//;
	if (!($b_insertion =~ /\S/)) {
	    push @result, "Something is wrong, here 1.21\n";
	}
    }
    $dflag = 0;
    if (($chra_p eq $chrb_p) && ($aend_p >= $bstart_p-1) && ($astart_p <= $bstart_p) && ($aend_p <= $bend_p) && ($astrand_p eq $bstrand_p)) {
	# they overlap
	my $spans_merged_p = merge($aspans_p,$bspans_p);
	my $merged_length = spansTotalLength($spans_merged_p);
	$aseq_p =~ s/://g;
	my $seq_merged_p = $aseq_p;
	my @s = split(//,$aseq_p);
	my $bsize = $merged_length - @s;
	$bseq_p =~ s/://g;
	@s = split(//,$bseq_p);
	my $add = "";
	for (my $i=@s-1; $i>=@s-$bsize; $i--) {
	    $add = $s[$i] . $add;
	}
	$seq_merged_p = $seq_merged_p . $add;
	if ($a_insertion =~ /\S/) { # put back the insertions, if any...
	    $seq_merged_p =~ s/^$astem/$astem$a_insertion/;
	}
	if ($b_insertion =~ /\S/) {
	    my $str_temp = $b_insertion;
	    $str_temp =~ s/\+/\\+/g;
	    if (!($seq_merged_p =~ /$str_temp$bpost$/)) {
		$seq_merged_p =~ s/$bpost$/$b_insertion$bpost/;
	    }
	}
	my $seq_p = addJunctionsToSeq($seq_merged_p, $spans_merged_p);

	push @result, RUM::Alignment->new(
            readid => $seqnum_p,
            chr    => $chra_p,
            locs   => RUM::RUMIO->parse_locs($spans_merged_p),
            seq    => $seq_p,
            strand => $astrand_p);

	$dflag = 1;
    }

    return @result;
}

sub merge  {
    my ($aspans2, $bspans2) = @_;
    use strict;
    my @astarts2;
    my @aends2;
    my @bstarts2;
    my @bends2;
    my $merged_spans;

    for my $span (split /, /, $aspans2) {
	my ($start, $end) = split /-/, $span;
	push @astarts2, $start;
	push @aends2,   $end;
    }

    for my $span (split /, /, $bspans2) {
	my ($start, $end) = split /-/, $span;
	push @bstarts2, $start;
	push @bends2,   $end;
    }

    if ($aends2[-1] + 1 < $bstarts2[0]) {
	$merged_spans = $aspans2 . ", " . $bspans2;
    }
    if ($aends2[-1] + 1 == $bstarts2[0]) {
	$aspans2 =~ s/-\d+$//;
	$bspans2 =~ s/^\d+-//;
	$merged_spans = $aspans2 . "-" . $bspans2;
    }
    if ($aends2[-1] + 1 > $bstarts2[0]) {
	$merged_spans = $aspans2;
	for (my $i=0; $i<@bstarts2; $i++) {
	    if ($aends2[-1] >= $bstarts2[$i] && ($aends2[-1] <= $bstarts2[$i+1] || $i == $#bstarts2)) {
		$merged_spans =~ s/-\d+$//;
		$merged_spans = $merged_spans . "-" . $bends2[$i];
		for (my $j=$i+1; $j<@bstarts2; $j++) {
		    $merged_spans = $merged_spans . ", $bstarts2[$j]-$bends2[$j]";
		}
	    }
	}
    }
    return $merged_spans;
}

sub intersect {
    use strict;
    my ($spans_ref, $seq) = @_;
    my @spans = @{$spans_ref};
    my $num_i = @spans;
    my %chash;
    for (my $s_i=0; $s_i<$num_i; $s_i++) {
	my @a_i = split(/, /,$spans[$s_i]);
	for (my $i_i=0;$i_i<@a_i;$i_i++) {
	    my @b_i = split(/-/,$a_i[$i_i]);
	    for (my $j_i=$b_i[0];$j_i<=$b_i[1];$j_i++) {
		$chash{$j_i}++;
	    }
	}
    }
    my $spanlength = 0;
    my $flag_i = 0;
    my $maxspanlength = 0;
    my $maxspan_start = 0;
    my $maxspan_end = 0;
    my $prevkey = 0;
    my $span_start;
    for my $key_i (sort {$a <=> $b} keys %chash) {
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
	my @a_i = split(/, /,$spans[0]);
	my @b_i = split(/-/,$a_i[0]);
	my $i_i=0;
	until ($b_i[1] >= $maxspan_start) {
	    $i_i++;
	    @b_i = split(/-/,$a_i[$i_i]);
	}
	my $prefix_size = $maxspan_start - $b_i[0]; # the size of the part removed from spans[0]
	for (my $j_i=0; $j_i<$i_i; $j_i++) {
	    @b_i = split(/-/,$a_i[$j_i]);
	    $prefix_size = $prefix_size + $b_i[1] - $b_i[0] + 1;
	}
	my @s_i = split(//,$seq);
	my $newseq = "";
	for ($i_i=$prefix_size; $i_i<$prefix_size + $maxspanlength; $i_i++) {
	    $newseq = $newseq . $s_i[$i_i];
	}
	$flag_i = 0;
	$i_i=0;
	@b_i = split(/-/,$a_i[0]);
	until ($b_i[1] >= $maxspan_start) {
	    $i_i++;
	    @b_i = split(/-/,$a_i[$i_i]);
	}
	my $newspans = $maxspan_start;
	until ($b_i[1] >= $maxspan_end) {
	    $newspans = $newspans . "-$b_i[1]";
	    $i_i++;
	    @b_i = split(/-/,$a_i[$i_i]);
	    $newspans = $newspans . ", $b_i[0]";
	}
	$newspans = $newspans . "-$maxspan_end";
	return ($maxspanlength, $newspans, $newseq);
    } else {
	return;
    }

}

sub handle_both_single {
    use strict;
    my ($bowtie, $blat, $unique_io, $nu_io, $readlength,
        $user_min_overlap, $max_distance_between_paired_reads) = @_;
    my $bowtie_single = $bowtie->single;
    my $blat_single   = $blat->single;
    if ($bowtie_single->same_direction($blat_single)) {
        # If single-end then this is the only case where $hash1{$id}[0] != 0 and $hash2{$id}[0] != 0
        
        my @a1 = split /\t/, $bowtie_single->raw;
        my @a2 = split /\t/, $blat_single->raw;
        my @spans = (RUM::RUMIO->format_locs($bowtie_single),
                     RUM::RUMIO->format_locs($blat_single));
        my $l1 = spansTotalLength($spans[0]);
        my $l2 = spansTotalLength($spans[1]);
        my $F=0;
        if ($l1 > $l2+3) {
            $unique_io->write_aln($bowtie_single);
            $F=1;
        }
        if ($l2 > $l1+3) {
            $unique_io->write_aln($blat_single); # preference blat
            $F=1;
        }
        my ($length_overlap, undef, undef) = intersect(\@spans, $bowtie_single->seq);
        
        if ( ! $F ) {
            my $min_overlap;
            if ($readlength eq "v") {
                my $readlength_temp = length($bowtie_single->seq);
                if (length($blat_single->seq) < $readlength_temp) {
                    $readlength_temp = length($blat_single->seq);
                }
                $min_overlap = min_overlap_for_read_length($readlength_temp);
            }
            if ($user_min_overlap > 0) {
                $min_overlap = $user_min_overlap;
            }
            
            if (($length_overlap > $min_overlap) && 
                ($bowtie_single->chromosome eq $blat_single->chromosome)) {
                # preference bowtie (so no worries about insertions)
                $unique_io->write_aln($bowtie_single);
            } else {
                # AMBIGUOUS, OUTPUT TO NU FILE
                if ($bowtie_single && $blat_single) {
                    $nu_io->write_alns([$bowtie_single,
                                        $blat_single]);
                }
            }
        }
    }
    if ($bowtie_single->opposite_direction($blat_single)) {
        # This is the tricky case where there's a unique
        # forward bowtie mapper and a unique reverse blat
        # mapper, or conversely.  Must check for
        # consistency.  This cannot be in BlatNU so don't
        # have to worry about that here.
        
        my $aspans  = RUM::RUMIO->format_locs($bowtie_single);
        my $astart  = $bowtie_single->start;
        my $aend    = $bowtie_single->end;
        my $chra    = $bowtie_single->chromosome;
        my $aseq    = $bowtie_single->seq;
        my $Astrand = $bowtie_single->strand;
        my $seqnum  = $bowtie_single->readid_directionless;
        
        my $bspans  = RUM::RUMIO->format_locs($blat_single);
        my $bstart  = $blat_single->start;
        my $bend    = $blat_single->end;
        my $chrb    = $blat_single->chromosome;
        my $bseq    = $blat_single->seq;
        my $Bstrand = $blat_single->strand;
        
        if ( ($bowtie_single->is_forward && $Astrand eq "+") || 
             ($bowtie_single->is_reverse && $Astrand eq '-')) {
            if ($bowtie_single->strand eq $blat_single->strand && 
                ($chra eq $chrb) && 
                ($aend < $bstart-1) && 
                ($bstart - $aend < $max_distance_between_paired_reads)) {
                if ($bowtie_single->is_forward) {
                    $unique_io->write_alns([$bowtie_single, $blat_single]);
                } else {
                    $unique_io->write_alns([$blat_single, $bowtie_single]);
                }
            }
        }
        if ( ($bowtie_single->is_forward && $Astrand eq "-") || 
             ($bowtie_single->is_reverse && $Astrand eq "+") ) {
            if (($Astrand eq $Bstrand) && 
                ($chra eq $chrb) && 
                ($bend < $astart-1) &&
                ($astart - $bend < $max_distance_between_paired_reads)) {
                if ($bowtie_single->is_forward) {
                    $unique_io->write_alns([$bowtie_single, $blat_single]);
                } else {
                    $unique_io->write_alns([$blat_single, $bowtie_single]);
                }
            }
        }
        # if they overlap, can't merge properly if there's
        # an insertion, so chop it out, save it and put it
        # back in before printing the next two if's do the
        # chopping...
        $aseq=~ s/://g;
        if ($aseq =~ /\+/) {
            $aseq =~ /(.*)(\+.*\+)(.*)/; # THIS IS ONLY GOING TO WORK IF THERE IS ONE INSERTION
            # as is guaranteed, seach for "comment.1" in parse_blat_out.pl
            # This limitation should probably be fixed at some point...
            $astem = $1;
            $a_insertion = $2;
            $apost = $3;
            $aseq =~ s/\+.*\+//;
            if (!($a_insertion =~ /\S/)) {
                print STDERR "ERROR: in script merge_Bowtie_and_Blat.pl: Something is wrong here, possible bug: code_id 0001\n";
            }
        }
        $bseq=~ s/://g;
        if ($bseq =~ /\+/) {
            $bseq =~ /(.*)(\+.*\+)(.*)/; # SAME COMMENT AS ABOVE
            $bstem = $1;
            $b_insertion = $2;
            $bpost = $3;
            $bseq =~ s/\+.*\+//;
            if (!($b_insertion =~ /\S/)) {
                print STDERR "ERROR: in script merge_Bowtie_and_Blat.pl: Something is wrong here, possible bug: code_id 0002\n";
            }
        }
        $dflag = 0;
        if ( ($bowtie_single->is_forward && $Astrand eq "+") || 
             ($bowtie_single->is_reverse && $Astrand eq "-") ) {
            if (($Astrand eq $Bstrand) && 
                ($chra eq $chrb) &&
                ($aend >= $bstart-1) && 
                ($astart <= $bstart) && 
                ($aend <= $bend)) {
                # they overlap
                my $spans_merged = merge($aspans,$bspans);
                my $merged_length = spansTotalLength($spans_merged);
                $aseq =~ s/://g;
                my $seq_merged = $aseq;
                my $bsize = $merged_length - length($aseq);
                $bseq =~ s/://g;
                my @s = split(//,$bseq);
                my $add = "";
                for (my $i=@s-1; $i>=@s-$bsize; $i--) {
                    $add = $s[$i] . $add;
                }
                $seq_merged = $seq_merged . $add;
                if ($a_insertion =~ /\S/) { # put back the insertions, if any...
                    $seq_merged =~ s/^$astem/$astem$a_insertion/;
                }
                if ($b_insertion =~ /\S/) {
                    my $str_temp = $b_insertion;
                    $str_temp =~ s/\+/\\+/g;
                    if (!($seq_merged =~ /$str_temp$bpost$/)) {
                        $seq_merged =~ s/$bpost$/$b_insertion$bpost/;
                    }
                }
                my $seq_j = addJunctionsToSeq($seq_merged, $spans_merged);
                $unique_io->write_aln(RUM::Alignment->new(
                    readid => $seqnum,
                    chr    => $chra,
                    locs   => RUM::RUMIO->parse_locs($spans_merged),
                    seq    => $seq_j,
                    strand => $Astrand));
                $dflag = 1;
            }
        }
        if ( (($bowtie_single->is_forward) && ($Astrand eq "-")) || ((($bowtie_single->is_reverse) && ($Astrand eq "+"))) ) {
            if (($Astrand eq $Bstrand) && ($chra eq $chrb) && ($bend >= $astart-1) && ($bstart <= $astart) && ($bend <= $aend) && ($dflag == 0)) {
                # they overlap
                my $spans_merged = merge($bspans,$aspans);
                my $merged_length = spansTotalLength($spans_merged);
                $bseq =~ s/://g;
                my $seq_merged = $bseq;
                my @s = split(//,$bseq);
                my $asize = $merged_length - @s;
                my $aseq =~ s/://g;
                @s = split(//,$aseq);
                my $add = "";
                for (my $i=@s-1; $i>=@s-$asize; $i--) {
                    $add = $s[$i] . $add;
                }
                my $seq_merged = $seq_merged . $add;
                if ($a_insertion =~ /\S/) { # put back the insertions, if any...
                    $seq_merged =~ s/$apost$/$a_insertion$apost/;
                }
                
                if ($b_insertion =~ /\S/) {
                    my $str_temp = $b_insertion;
                    $str_temp =~ s/\+/\\+/g;
                    if (!($seq_merged =~ /^$bstem$str_temp/)) {
                        $seq_merged =~ s/^$bstem/$bstem$b_insertion/;
                    }
                }
                my $seq_j = addJunctionsToSeq($seq_merged, $spans_merged);
                my $aln = RUM::Alignment->new(
                    readid => $seqnum,
                    chr => $chra,
                    locs => RUM::RUMIO->parse_locs($spans_merged),
                    seq => $seq_j,
                    strand => $Astrand);
                $unique_io->write_aln($aln);
            }
        }
    }
}

1;

