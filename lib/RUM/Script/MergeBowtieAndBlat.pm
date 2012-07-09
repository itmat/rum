package RUM::Script::MergeBowtieAndBlat;

no warnings;
use autodie;

use List::Util qw(max);

use RUM::Usage;
use RUM::Logging;
use RUM::Common qw(addJunctionsToSeq spansTotalLength);
use RUM::BowtieIO;
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
        if ($readlength < 80) {
            $min_overlap = 35;
        } else {
            $min_overlap = 45;
        }
        if ($min_overlap >= .8 * $readlength) {
            $min_overlap = int(.6 * $readlength);
        }
    }
    if ($user_min_overlap > 0) {
        $min_overlap = $user_min_overlap;
    }

    my (%blat_ambiguous_mappers_a,
        %blat_ambiguous_mappers_b);

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

    open OUTFILE2, ">>", $blat_non_unique_in;

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

        my (%bowtie_mappers_for, %blat_mappers_for);

        undef %hash1;
        undef %hash2;
        my %allids;
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
                if ($aln->is_forward || $aln->is_reverse) {
                    $hash1{$id}[ 0 ]++;
                    $hash1{$id}[ $hash1{$id}[0] ] = $line;
                    push @{ $bowtie_mappers_for{$id} }, $aln;
                } else {
                    $hash1{$id}[0] = -1;
                    $hash1{$id}[1] = $line;
                    push @{ $bowtie_mappers_for{$id} }, $aln;
                }
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
        @a = split /\t/, $line;
        $prev_id = $id;
        $id      = $aln_prev->order;
        if ($prev_id eq $id) {
            $FLAG3++;
            if ($FLAG3 > 1) {
                $FLAG2=0;
            }
        }
        my $blat_aln = RUM::BowtieIO->new(-fh => 1)->parse_aln($line);

        # now get the blat output for this bunch of ids, that goes in hash2
        while ($id && $id <= $last_id && $FLAG3 <= 1) {
            $allids{$id}++;
            if ($blat_aln->is_forward || $blat_aln->is_reverse) {
                $hash2{$id}[0]++;
                $hash2{$id}[ $hash2{$id}[0] ] = $blat_aln->raw;
                push @{ $blat_mappers_for{$id} }, $blat_aln;
            } else {
                $hash2{$id}[0] = -1;
                $hash2{$id}[1] = $blat_aln->raw;
                push @{ $blat_mappers_for{$id} }, $blat_aln;
            }
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

            my @bowtie = @{ $bowtie_mappers_for{$id} || [] };
            my @blat   = @{   $blat_mappers_for{$id} || [] };

            next ID if $bowtie_ambiguous_mappers{$id};
            next ID if $blat_ambiguous_mappers_a{$id} && $blat_ambiguous_mappers_b{$id};

            $hash1{$id}[0] ||= 0;
            $hash2{$id}[0] ||= 0;

            my @bowtie_mapper = @{ $hash1{$id} };
            my @blat_mapper   = @{ $hash2{$id} };

            my $bowtie_joined_mapper = $bowtie_mapper[0] == -1 ? $bowtie_mapper[1] : undef;
            my $blat_joined_mapper   =   $blat_mapper[0] == -1 ?   $blat_mapper[1] : undef;

            my $bowtie_single_mapper = $bowtie_mapper[0] == 1 ? @bowtie[0]->raw : undef;
            my $blat_single_mapper   =   $blat_mapper[0] == 1 ? $blat_mapper[1] : undef;

            my (@blat_pair, @bowtie_pair);

            if ($bowtie_mapper[0] == 2) {
                @bowtie_pair = @bowtie_mapper[1,2];
            }
            if ($blat_mapper[0] == 2) {
                @blat_pair = @blat_mapper[1,2];
            }

            my $bowtie_single_mapper_is_reverse = $bowtie_single_mapper && $hash1{$id}[1] =~ /seq.\d+b/;
            my $bowtie_single_mapper_is_forward = $bowtie_single_mapper && $hash1{$id}[1] =~ /seq.\d+a/;

            my $blat_single_mapper_is_reverse = $blat_single_mapper && $hash2{$id}[1] =~ /seq.\d+b/;
            my $blat_single_mapper_is_forward = $blat_single_mapper && $hash2{$id}[1] =~ /seq.\d+a/;
            
            my $bowtie_mapped = $hash1{$id}[0];
            my $blat_mapped = $hash2{$id}[0];

            if (($blat_ambiguous_mappers_a{$id}+0 > 0) && @bowtie == 1 && $bowtie[0]->is_reverse) {
                # ambiguous forward in in BlatNU, single reverse in BowtieUnique.  See if there is
                # a consistent pairing so we can keep the pair, otherwise this read is considered unmappable
                # (not to be confused with ambiguous)
                $line1 = $bowtie_single_mapper;
                $x = `grep ${id}a $blat_non_unique_in`;
                @a3 = split(/\n/,$x);
                $numjoined=0;

                for my $line2 (@a3) {
                    if ($bowtie[0]->strand eq '-') { # check the strand
                        $joined = joinifpossible($bowtie[0]->raw, $line2, $max_distance_between_paired_reads); # this is not backwards, line1 is the reverse read
                    } else {
                        $joined = joinifpossible($line2, $bowtie[0]->raw, $max_distance_between_paired_reads);
                    }
                    if ($joined =~ /\S/) {
                        $numjoined++;
                        $joinedsave = $joined;
                    }
                }
                if ($numjoined == 1) { # if numjoined > 1 should probably intersect them to see if there's a 
                    # salvagable intersection
                    print $outfile1 "$joinedsave";
                }
                $remove_from_BlatNU{$id}++;
                next;
            }
            if (($blat_ambiguous_mappers_b{$id}+0 > 0) && @bowtie == 1 && $bowtie[0]->is_forward) {
                # ambiguous reverse in in BlatNU, single forward in BowtieUnique.  See if there is
                # a consistent pairing so we can keep the pair, otherwise this read is considered unmappable
                # (not to be confused with ambiguous)

                $x = `grep ${id}b $blat_non_unique_in`;
                @a3 = split(/\n/,$x);
                $numjoined=0;
                for my $line2 (@a3) {
                    if ($bowtie_single_mapper =~ /-$/) {
                        $joined = joinifpossible($line2, $bowtie_single_mapper, $max_distance_between_paired_reads);
                    } else {
                        $joined = joinifpossible($bowtie_single_mapper, $line2, $max_distance_between_paired_reads);
                    }
                    if ($joined =~ /\S/) {
                        $numjoined++;
                        $joinedsave = $joined;
                    }
                }
                if ($numjoined == 1) { # if numjoined > 1 should probably intersect them to see if there's a 
                    # salvagable intersection
                    print $outfile1 "$joinedsave";
                }
                $remove_from_BlatNU{$id}++;
                next;
            }

            # Kept for debugging
            #	print "hash1{$id}[0]=$hash1{$id}[0]\n";
            #	print "hash2{$id}[0]=$hash2{$id}[0]\n";

            # %hash1 is bowtie
            # %hash2 is blat
            # These can have values -1, 0, 1, 2
            # All combinations possible except (0,0), so 15 total:
            # case -1: both forward and reverse reads mapped, consistently, and overlapped so were joined
            # case  0: neither read mapped
            # case  1: only one of the forward or reverse mapped
            # case  2: both forward and reverse reads mapped, consistently, but did not overlap so were not joined

            # THREE CASES:

            if ( ! $bowtie_mapped ) {

                # Sequence is joined in unique blat read
                if ($blat_joined_mapper) {
                    print $outfile1 "$blat_joined_mapper\n";
                } else {
                    for my $line (@blat_mapper[1..$#blat_mapper]) {
                        # don't need to check if this is in BlatNU since
                        # it can't be in both BlatNU and BlatUnique
                        print $outfile1 "$line\n";
                    }
                }
            }
            # THREE CASES:
            if ( ! $blat_mapped ) {
                if ($bowtie_joined_mapper) {
                    print $outfile1 "$bowtie_joined_mapper\n";
                }
                if (@bowtie_pair) {
                    for my $mapper (@bowtie) {
                        print $outfile1 $mapper->raw . "\n";
                    }
                }
                if ($bowtie_single_mapper) {
                    # this is a one-direction only mapper in
                    # BowtieUnique and nothing in BlatUnique, so must
                    # check it's not in BlatNU
                    if ( ! $blat_ambiguous_mappers_a{$id} && $bowtie_single_mapper_is_forward) {
                        print $outfile1 "$bowtie_single_mapper\n";
                    }
                    if ( ! $blat_ambiguous_mappers_b{$id} && $bowtie_single_mapper_is_reverse) {
                        print $outfile1 "$bowtie_single_mapper\n";
                    }
                }
            }
            # ONE CASE:
            if ($bowtie_joined_mapper && $blat_joined_mapper) { 
                # Prefer the bowtie mapping. This case should actually
                # not happen because we should only send to blat those
                # things which didn't have consistent bowtie maps.
                print $outfile1 "$bowtie_joined_mapper\n";
            }
            # ONE CASE:
            if ($bowtie_single_mapper && $blat_single_mapper) {
                if (($bowtie_single_mapper_is_forward && $blat_single_mapper_is_forward) ||
                    ($bowtie_single_mapper_is_reverse && $blat_single_mapper_is_reverse)) {
                    # If single-end then this is the only case where $hash1{$id}[0] != 0 and $hash2{$id}[0] != 0
                    undef @spans;
                    @a1 = split /\t/, $bowtie_single_mapper;
                    @a2 = split /\t/, $blat_single_mapper;
                    $spans[0] = $a1[2];
                    $spans[1] = $a2[2];
                    $l1 = spansTotalLength($spans[0]);
                    $l2 = spansTotalLength($spans[1]);
                    $F=0;
                    if ($l1 > $l2+3) {
                        print $outfile1 $bowtie[0]->raw . "\n"; # preference bowtie
                        $F=1;
                    }
                    if ($l2 > $l1+3) {
                        print $outfile1 "$blat_single_mapper\n"; # preference blat
                        $F=1;
                    }
                    $str = intersect(\@spans, $a1[3]);
                    $str =~ /^(\d+)/;
                    $length_overlap = $1;
                    if ($F == 0) {

                        if ($readlength eq "v") {
                            $readlength_temp = length($a1[3]);
                            if (length($a2[3]) < $readlength_temp) {
                                $readlength_temp = length($a2[3]);
                            }
                            if ($readlength_temp < 80) {
                                $min_overlap = 35;
                            } else {
                                $min_overlap = 45;
                            }
                            if ($min_overlap >= .8 * $readlength_temp) {
                                $min_overlap = int(.6 * $readlength_temp);
                            }
                        }
                        if ($user_min_overlap > 0) {
                            $min_overlap = $user_min_overlap;
                        }

                        if (($length_overlap > $min_overlap) && ($a1[1] eq $a2[1])) {
                            print $outfile1 "$bowtie_single_mapper\n"; # preference bowtie (so no worries about insertions)
                        } else {
                            # AMBIGUOUS, OUTPUT TO NU FILE
                            if (($bowtie_single_mapper =~ /\S/) && $blat_single_mapper =~ /\S/) {
                                print OUTFILE2 "$bowtie_single_mapper\n";
                                print OUTFILE2 "$blat_single_mapper\n";
                            }
                        }
                    }
                }
                if (($bowtie_single_mapper_is_forward && $blat_single_mapper_is_reverse) ||
                    ($bowtie_single_mapper_is_reverse && $blat_single_mapper_is_forward)) {
                    # This is the tricky case where there's a unique
                    # forward bowtie mapper and a unique reverse blat
                    # mapper, or conversely.  Must check for
                    # consistency.  This cannot be in BlatNU so don't
                    # have to worry about that here.
                    if ($bowtie_single_mapper_is_forward) {
                        $atype = "a";
                    } else {
                        $atype = "b";
                    }
                    @a = split(/\t/,$bowtie_single_mapper);
                    $aspans = $a[2];
                    $a[2] =~ /^(\d+)[^\d]/;
                    $astart = $1;
                    $a[2] =~ /[^\d](\d+)$/;
                    $aend = $1;
                    $chra = $a[1];
                    $aseq = $a[3];
                    $Astrand = $a[4];
                    $seqnum = $a[0];
                    $seqnum =~ s/a$//;
                    $seqnum =~ s/b$//;
                    @a = split /\t/, $blat_single_mapper;
                    $bspans = $a[2];
                    $a[2] =~ /^(\d+)[^\d]/;
                    $bstart = $1;
                    $a[2] =~ /[^\d](\d+)$/;
                    $bend = $1;
                    $chrb = $a[1];
                    $bseq = $a[3];
                    $Bstrand = $a[4];
                    if ( (($atype eq "a") && ($Astrand eq "+")) || ((($atype eq "b") && ($Astrand eq "-"))) ) {
                        if (($Astrand eq $Bstrand) && ($chra eq $chrb) && ($aend < $bstart-1) && ($bstart - $aend < $max_distance_between_paired_reads)) {
                            if ($bowtie_single_mapper_is_forward) {
                                print $outfile1 "$bowtie_single_mapper\n$blat_single_mapper\n";
                            } else {
                                print $outfile1 "$blat_single_mapper\n$bowtie_single_mapper\n";
                            }
                        }
                    }
                    if ( (($atype eq "a") && ($Astrand eq "-")) || ((($atype eq "b") && ($Astrand eq "+"))) ) {
                        if (($Astrand eq $Bstrand) && ($chra eq $chrb) && ($bend < $astart-1) && ($astart - $bend < $max_distance_between_paired_reads)) {
                            if ($bowtie_single_mapper_is_forward) {
                                print $outfile1 "$bowtie_single_mapper\n$blat_single_mapper\n";
                            } else {
                                print $outfile1 "$blat_single_mapper\n$bowtie_single_mapper\n";
                            }
                        }
                    }
                    # if they overlap, can't merge properly if there's an insertion, so chop it out,
                    # save it and put it back in before printing the next two if's do the chopping...
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
                    if ( (($atype eq "a") && ($Astrand eq "+")) || ((($atype eq "b") && ($Astrand eq "-"))) ) {
                        if (($Astrand eq $Bstrand) && ($chra eq $chrb) && ($aend >= $bstart-1) && ($astart <= $bstart) && ($aend <= $bend)) {
                            # they overlap
                            $spans_merged = merge($aspans,$bspans);
                            $merged_length = spansTotalLength($spans_merged);
                            $aseq =~ s/://g;
                            $seq_merged = $aseq;
                            @s = split(//,$aseq);
                            $bsize = $merged_length - @s;
                            $bseq =~ s/://g;
                            @s = split(//,$bseq);
                            $add = "";
                            for ($i=@s-1; $i>=@s-$bsize; $i--) {
                                $add = $s[$i] . $add;
                            }
                            $seq_merged = $seq_merged . $add;
                            if ($a_insertion =~ /\S/) { # put back the insertions, if any...
                                $seq_merged =~ s/^$astem/$astem$a_insertion/;
                            }
                            if ($b_insertion =~ /\S/) {
                                $str_temp = $b_insertion;
                                $str_temp =~ s/\+/\\+/g;
                                if (!($seq_merged =~ /$str_temp$bpost$/)) {
                                    $seq_merged =~ s/$bpost$/$b_insertion$bpost/;
                                }
                            }
                            $seq_j = addJunctionsToSeq($seq_merged, $spans_merged);
                            print $outfile1 "$seqnum\t$chra\t$spans_merged\t$seq_j\t$Astrand\n";
                            $dflag = 1;
                        }
                    }
                    if ( (($atype eq "a") && ($Astrand eq "-")) || ((($atype eq "b") && ($Astrand eq "+"))) ) {
                        if (($Astrand eq $Bstrand) && ($chra eq $chrb) && ($bend >= $astart-1) && ($bstart <= $astart) && ($bend <= $aend) && ($dflag == 0)) {
                            # they overlap
                            $spans_merged = merge($bspans,$aspans);
                            $merged_length = spansTotalLength($spans_merged);
                            $bseq =~ s/://g;
                            $seq_merged = $bseq;
                            @s = split(//,$bseq);
                            $asize = $merged_length - @s;
                            $aseq =~ s/://g;
                            @s = split(//,$aseq);
                            $add = "";
                            for ($i=@s-1; $i>=@s-$asize; $i--) {
                                $add = $s[$i] . $add;
                            }
                            $seq_merged = $seq_merged . $add;
                            if ($a_insertion =~ /\S/) { # put back the insertions, if any...
                                $seq_merged =~ s/$apost$/$a_insertion$apost/;
                            }

                            if ($b_insertion =~ /\S/) {
                                $str_temp = $b_insertion;
                                $str_temp =~ s/\+/\\+/g;
                                if (!($seq_merged =~ /^$bstem$str_temp/)) {
                                    $seq_merged =~ s/^$bstem/$bstem$b_insertion/;
                                }
                            }
                            $seq_j = addJunctionsToSeq($seq_merged, $spans_merged);
                            print $outfile1 "$seqnum\t$chra\t$spans_merged\t$seq_j\t$Astrand\n";
                        }
                    }
                }
            }
            # ONE CASE
            if (@bowtie_pair && @blat_pair == 2) { # preference bowtie
                print $outfile1 "$bowtie_pair[0]\n";
                print $outfile1 "$bowtie_pair[1]\n";
            }	
            # NINE CASES DONE
            # ONE CASE
            if ($bowtie_joined_mapper && @blat_pair == 2) { # preference bowtie
                print $outfile1 "$bowtie_joined_mapper\n";
            }
            # ONE CASE
            if (@bowtie_pair && $blat_joined_mapper) { # preference bowtie
                print $outfile1 "$bowtie_pair[0]\n";
                print $outfile1 "$bowtie_pair[1]\n";
            }
            # ELEVEN CASES DONE
            if ($bowtie_single_mapper && @blat_pair == 2) {
                print $outfile1 "$blat_pair[0]\n";
                print $outfile1 "$blat_pair[1]\n";
            }	
            if (@bowtie_pair && $blat_single_mapper) {
                print $outfile1 "$bowtie_pair[0]\n";
                print $outfile1 "$bowtie_pair[1]\n";
            }	
            if ($bowtie_joined_mapper && $blat_single_mapper) {
                print $outfile1 "$bowtie_joined_mapper\n";
            }
            if ($bowtie_single_mapper && $blat_joined_mapper) {
                print $outfile1 "$blat_joined_mapper\n";
            }
            # ALL FIFTEEN CASES DONE
        }
    }

    close($outfile1);
    close(OUTFILE2);

    # now need to remove the stuff in %remove_from_BlatNU from BlatNU
    $filename = $non_unique_out;
    open INFILE, '<', $blat_non_unique_in;
    open OUTFILE, '>', $filename;
    while ($line = <INFILE>) {
        $line =~ /seq.(\d+)/;
        if ($remove_from_BlatNU{$1}+0==0) {
            print OUTFILE $line;
        }
    }
    close(INFILE);
    open INFILE, '<', $bowtie_non_unique_in;
    # now append BowtieNU to get the full NU file
    while ($line = <INFILE>) {
        print OUTFILE $line;
    }
    close(INFILE);
    close(OUTFILE);

}

sub joinifpossible () {
    use strict;
    my ($LINE1, $LINE2, $max_distance_between_paired_reads) = @_;
    my @a_p = split(/\t/,$LINE1);
    my $aspans_p = $a_p[2];
    $a_p[2] =~ /^(\d+)[^\d]/;
    my $astart_p = $1;
    $a_p[2] =~ /[^\d](\d+)$/;
    my $aend_p = $1;
    my $chra_p = $a_p[1];
    my $aseq_p = $a_p[3];
    my $astrand_p = $a_p[4];
    my $seqnum_p = $a_p[0];
    $seqnum_p =~ s/a$//;
    $seqnum_p =~ s/b$//;
    my @a_p = split(/\t/,$LINE2);
    my $bspans_p = $a_p[2];
    $a_p[2] =~ /^(\d+)[^\d]/;
    my $bstart_p = $1;
    $a_p[2] =~ /[^\d](\d+)$/;
    my $bend_p = $1;
    my $chrb_p = $a_p[1];
    my $bseq_p = $a_p[3];
    my $bstrand_p = $a_p[4];
    my $returnstring = "";
    if ($astrand_p ne $bstrand_p) {
	return "";
    }

    if (   ($chra_p eq $chrb_p)
        && ($astrand_p eq $bstrand_p)
        && ($aend_p < $bstart_p-1)
        && ($bstart_p - $aend_p < $max_distance_between_paired_reads)) {

	if ($LINE1 =~ /a\t/) {
	    $returnstring = $returnstring . "$LINE1\n$LINE2\n";
	} else {
	    $returnstring = $returnstring . "$LINE2\n$LINE1\n";
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
	    $returnstring = $returnstring . "Something is wrong, here 1.07\n";
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
	    $returnstring = $returnstring . "Something is wrong, here 1.21\n";
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
	$returnstring = $returnstring . "$seqnum_p\t$chra_p\t$spans_merged_p\t$seq_p\t$astrand_p\n";
	$dflag = 1;
    }

    return $returnstring;
}

sub merge () {
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

sub intersect () {
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
	return "$maxspanlength\t$newspans\t$newseq";
    } else {
	return "0";
    }

}

1;

