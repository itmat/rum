package RUM::Script::MergeGuAndTu;

no warnings;

use Carp;
use Data::Dumper;
use RUM::Usage;
use RUM::RUMIO;
use RUM::Common qw(min_overlap_for_read_length
                   min_overlap_for_seqs);
use RUM::Mapper;
use List::Util qw(min max first);

use base 'RUM::Script::Base';

$|=1;

sub overlap_length {
    my ($spans, $seq) = @_;
    my $str = intersect($spans, $seq);
    $str =~ /^(\d+)/;
    return $1;
}

sub unique_iter {
    my ($fh, $source) = @_;
    my $iter = RUM::BowtieIO->new(-fh => $fh, strand_last => 1);
    return $iter->group_by(
        sub { 
            my ($x, $y) = @_;
            return RUM::Identifiable::is_mate($x, $y),
        },
        sub { 
            my $alns = shift;
            RUM::Mapper->new(alignments => $alns,
                             source => $source) 
          }
    )->peekable;
}


sub parse_command_line {
    my ($self) = @_;

    $self->{max_pair_dist} = 500000;
    $self->get_options(
        "gu-in=s"             => \$self->{gu_in},
        "tu-in=s"             => \$self->{tu_in},
        "gnu-in=s"            => \$self->{gnu_in},
        "tnu-in=s"            => \$self->{tnu_in},
        "bowtie-unique-out=s" => \$self->{bowtie_unique_out},
        "cnu-out=s"           => \$self->{cnu_out},
        "paired"              => \$self->{paired},
        "single"              => \(my $single),
        "max-pair-dist=s"     => \$self->{max_pair_dist},
        "read-length=s"       => \$self->{read_length},
        "min-overlap=s"       => \$self->{user_min_overlap});

    $self->{gu_in} or RUM::Usage->bad(
        "Please specify a genome unique input file with --gu");
    $self->{tu_in} or RUM::Usage->bad(
        "Please specify a transcriptome unique input file with --tu");
    $self->{gnu_in} or RUM::Usage->bad(
        "Please specify a genome non-unique input file with --gnu");
    $self->{tnu_in} or RUM::Usage->bad(
        "Please specify a transcriptome non-unique input file with --tnu");
    $self->{bowtie_unique_out} or RUM::Usage->bad(
        "Please specify the bowtie-unique output file with --bowtie-unique");
    $self->{cnu_out} or RUM::Usage->bad(
        "Please specify the cnu output file with --cnu");
    ($self->{paired} xor $single) or RUM::Usage->bad(
        "Please specify exactly one type with either --single or --paired");
    
    if ($self->{read_length}) {
        if ($self->{read_length} =~ /^\d+$/) {
            if ($self->{read_length} < 5) {
                RUM::Usage->bad("--read-length cannot be that small, ".
                                    "must be at least 5, or 'v'");
            }
        }

        elsif ($self->{read_length} ne 'v') {
            RUM::Usage->bad("--read-length must be an integer > 4, or 'v'");
        }
    }

    if ($self->{user_min_overlap}) {
        unless ($self->{user_min_overlap} =~ /^\d+$/ && $self->{user_min_overlap} >= 5) {
            RUM::Usage->bad("--min-overlap must be an integer > 4");
        }
    }

    for my $in_name (qw(gu tu gnu tnu)) {
        open my $fh, '<', $self->{"${in_name}_in"};
        $self->{"${in_name}_in_fh"} = $fh;
    }

    for my $out_name (qw(bowtie_unique cnu)) {
        open my $fh, '>', $self->{"${out_name}_out"};
        $self->{"${out_name}_out_fh"} = $fh;
    }

}

sub main {

    my $self = __PACKAGE__->new;
    $self->parse_command_line;
    $self->run;
}

sub determine_read_length_from_input {
    use strict;
    my ($self) = @_;
    my @keys = qw(gu_in_fh
                  tu_in_fh 
                  gnu_in_fh
                  tnu_in_fh);
    my @fhs   = map { $self->{$_} } @keys;
    my @iters = map { RUM::BowtieIO->new(
        -fh => $_, strand_last => 1) } @fhs;

    my @lengths = map { $_->longest_read } @iters;

    for my $fh (@fhs) {
        seek $fh, 0, 0;
    }
    return max(@lengths);
}

sub run {
    my ($self) = @_;

    $self->{read_length} ||= $self->determine_read_length_from_input;

    if (!$self->{read_length}) { # Couldn't determine the read length so going to fall back
        # on the strategy used for variable length reads.
        $self->{read_length} = "v";
    }

    if ($self->{read_length} ne "v") {
        $min_overlap  = min_overlap_for_read_length($self->{read_length});
        $min_overlap1 = $min_overlap;
        $min_overlap2 = $min_overlap;
    }
    if ($self->{user_min_overlap} > 0) {
        $min_overlap  = $self->{user_min_overlap};
        $min_overlap1 = $self->{user_min_overlap};
        $min_overlap2 = $self->{user_min_overlap};
    }

    {
        my $gnu_in_fh = $self->{gnu_in_fh};
        
        while ($line = <$gnu_in_fh>) {
            $line =~ /^seq.(\d+)/;
            $self->{ambiguous_mappers}->{$1}++;
        }
    }
    
    {
        my $tnu_in_fh = $self->{tnu_in_fh};
        while ($line = <$tnu_in_fh>) {
            $line =~ /^seq.(\d+)/;
            $self->{ambiguous_mappers}->{$1}++;
        }
    }
    
    my $gu_in_fh             = $self->{gu_in_fh};
    my $tu_in_fh             = $self->{tu_in_fh};
    my $bowtie_unique_out_fh = $self->{bowtie_unique_out_fh};
    my $cnu_out_fh           = $self->{cnu_out_fh};

    my $gu_iter =  unique_iter($gu_in_fh, 'gu');
    my $tu_iter =  unique_iter($tu_in_fh, 'tu');

    my $unique_io = RUM::RUMIO->new(-fh => $bowtie_unique_out_fh, strand_last => 1);
    my $cnu_io    = RUM::RUMIO->new(-fh => $cnu_out_fh, strand_last => 1);

    my $unique_iter = $gu_iter->merge(
        \&RUM::Mapper::cmp_read_ids, $tu_iter, sub { shift });

  READ: while (my $mappers = $unique_iter->next_val) {

        if (ref($mappers) !~ /^ARRAY/) {
            $mappers = [ $mappers ];
        }
        my $id = $mappers->[0]->alignments->[0]->order;

        next READ if $self->{ambiguous_mappers}->{$id};
        {
            my $gu = first { $_->source eq 'gu' } @{ $mappers };
            my $tu = first { $_->source eq 'tu' } @{ $mappers };
            
            $gu ||= RUM::Mapper->new();
            $tu ||= RUM::Mapper->new();

            # MUST DO 15 CASES IN TOTAL:
            # THREE CASES:
            if ($gu->is_empty) {
                $unique_io->write_alns($tu);
            }
            # THREE CASES
            if ($tu->is_empty) {
                $unique_io->write_alns($gu);
            }
            # ONE CASE
            if ($gu->joined && $tu->joined) {

                my @spans = (RUM::RUMIO->format_locs($gu->joined),
                             RUM::RUMIO->format_locs($tu->joined));

                my $length_overlap = overlap_length(\@spans, $gu->joined->seq);

                if ($self->enough_overlap($length_overlap, $gu->joined->seq, $tu->joined->seq) &&
                    ($gu->joined->chromosome eq $tu->joined->chromosome)) {
                    $unique_io->write_alns($tu);
                } else {
                    $cnu_io->write_alns($gu);
                    $cnu_io->write_alns($tu);
                }
            }
            # ONE CASE
            if ($gu->single && $tu->single) {

                # genome mapper and transcriptome mapper, and both single read mapping
                # If single-end then this is the only case where $hash1{$id}[0] > 0 and $hash2{$id}[0] > 0
                if (($gu->single_forward && $tu->single_forward) || 
                    ($gu->single_reverse && $tu->single_reverse)) {
                    # both forward mappers, or both reverse mappers

                    my @spans = (RUM::RUMIO->format_locs($gu->single),
                                 RUM::RUMIO->format_locs($tu->single));

                    my $length_overlap = overlap_length(\@spans, $gu->single->seq);

                    if ($self->enough_overlap($length_overlap, $gu->single->seq, $tu->single->seq) 
                        && ($gu->single->chromosome eq $tu->single->chromosome)) {
                        # preference TU
                        $unique_io->write_alns($tu);
                    } else {
                        if (!$self->{paired}) {
                            $cnu_io->write_alns($gu);
                            $cnu_io->write_alns($tu);
                        }
                    }
                }
                if (($gu->single_forward && $tu->single_reverse) || 
                    ($gu->single_reverse && $tu->single_forward)) {

                    # one forward and one reverse

                    $aspans = RUM::RUMIO->format_locs($gu->single);
                    $astart = $gu->single->start;
                    $aend = $gu->single->end;
                    $chra = $gu->single->chromosome;
                    $aseq = $gu->single->seq;
                    $seqnum = $gu->single->readid;
                    $astrand = $gu->single->strand;
                    $seqnum = $gu->single->readid_directionless;

                    if ($gu->single_forward) {
                        if ($astrand eq "+") {
                            $forward_strand = "+";
                        }
                        if ($astrand eq "-") {
                            $forward_strand = "-";
                        }
                    } else {
                        if ($bstrand eq "+") {
                            $forward_strand = "+";
                        }
                        if ($bstrand eq "-") {
                            $forward_strand = "-";
                        }
                    }

                    $bspans = RUM::RUMIO->format_locs($tu->single);
                    $bstart = $tu->single->start;
                    $bend = $tu->single->end;
                    $chrb = $tu->single->chromosome;
                    $bseq = $tu->single->seq;
                    $bstrand = $tu->single->strand;
                    if ($tu->single_forward) {
                        if ($bstrand eq "+") {
                            $forward_strand = "+";
                        }
                        if ($bstrand eq "-") {
                            $forward_strand = "-";
                        }
                    } else {
                        if ($astrand eq "+") {
                            $forward_strand = "+";
                        }
                        if ($astrand eq "-") {
                            $forward_strand = "-";
                        }
                    }

                    # the next two if's take care of the case that there is no overlap, one read lies entirely downstream of the other
		
                    if ((($astrand eq "+" && $bstrand eq "+" && $gu->single_forward && $tu->single_reverse) || ($astrand eq "-" && $bstrand eq "-" && $gu->single_reverse && $tu->single_forward)) && ($chra eq $chrb) && ($aend < $bstart-1) && ($bstart - $aend < $self->{max_pair_dist})) {
                        if ($gu->single_forward) {
                            $unique_io->write_alns([$gu->single, $tu->single]);
                        } else {
                            $unique_io->write_alns([$tu->single, $gu->single]);
                        }
                    }
                    if ((($astrand eq "-" && $bstrand eq "-" && $gu->single_forward && $tu->single_reverse) || ($astrand eq "+" && $bstrand eq "+" && $gu->single_reverse && $tu->single_forward)) && ($chra eq $chrb) && ($bend < $astart-1) && ($astart - $bend < $self->{max_pair_dist})) {
                        if ($gu->single_forward) {
                            $unique_io->write_alns([$gu->single, $tu->single]);
                        } else {
                            $unique_io->write_alns([$tu->single, $gu->single]);
                        }
                    }
                    $Eflag =0;

                    if (($astrand eq $bstrand) && ($chra eq $chrb) && (($aend >= $bstart-1) && ($astart <= $bstart)) || (($bend >= $astart-1) && ($bstart <= $astart))) {
                                            
                        $aseq2 = $aseq;
                        $aseq2 =~ s/://g;
                        $bseq2 = $bseq;
                        $bseq2 =~ s/://g;

                        if ($gu->single_forward && $astrand eq "+" || $gu->single_reverse && $astrand eq "-") {
                            ($merged_spans, $merged_seq) = merge($aspans, $bspans, $aseq2, $bseq2);
                        } else {
                            ($merged_spans, $merged_seq) = merge($bspans, $aspans, $bseq2, $aseq2);
                        }

                        if (! $merged_spans) {
                            @AS = split(/-/,$aspans);
                            $AS[0]++;

                            $aspans_temp = join '-', @AS;
                            $aseq2_temp = $aseq2;
                            $aseq2_temp =~ s/^.//;

                            if ($gu->single_forward && $astrand eq "+" || $gu->single_reverse && $astrand eq "-") {
                                ($merged_spans, $merged_seq) = merge($aspans_temp, $bspans, $aseq2_temp, $bseq2);
                            } else {
                                ($merged_spans, $merged_seq) = merge($bspans, $aspans_temp, $bseq2, $aseq2_temp);
                            }
                        }

                        if (! $merged_spans) {
                            $AS[0]++;
                            $aspans_temp = join '-', @AS;
                            $aseq2_temp =~ s/^.//;
                            if ($gu->single_forward && $astrand eq "+" || $gu->single_reverse && $astrand eq "-") {
                                ($merged_spans, $merged_seq) = merge($aspans_temp, $bspans, $aseq2_temp, $bseq2);
                            } else {
                                ($merged_spans, $merged_seq) = merge($bspans, $aspans_temp, $bseq2, $aseq2_temp);
                            }
                        }
                        if (! $merged_spans) {
                            $AS[0]++;
                            $aspans_temp = join '-', @AS;
                            $aseq2_temp =~ s/^.//;
                            if ($gu->single_forward && $astrand eq "+" || $gu->single_reverse && $astrand eq "-") {
                                ($merged_spans, $merged_seq) = merge($aspans_temp, $bspans, $aseq2_temp, $bseq2);
                            } else {
                                ($merged_spans, $merged_seq) = merge($bspans, $aspans_temp, $bseq2, $aseq2_temp);
                            }
                        }
                        if (! $merged_spans) {
                            @AS = split(/-/,$aspans);
                            $AS[-1]--;
                            $aspans_temp = join '-', @AS;
                            $aseq2_temp = $aseq2;
                            $aseq2_temp =~ s/.$//;
                            if ($gu->single_forward && $astrand eq "+" || $gu->single_reverse && $astrand eq "-") {
                                ($merged_spans, $merged_seq) = merge($aspans_temp, $bspans, $aseq2_temp, $bseq2);
                            } else {
                                ($merged_spans, $merged_seq) = merge($bspans, $aspans_temp, $bseq2, $aseq2_temp);
                            }
                        }
                        if (! $merged_spans) {
                            $AS[-1]--;
                            $aspans_temp = join '-', @AS;
                            $aseq2_temp =~ s/.$//;
                            if ($gu->single_forward && $astrand eq "+" || $gu->single_reverse && $astrand eq "-") {
                                ($merged_spans, $merged_seq) = merge($aspans_temp, $bspans, $aseq2_temp, $bseq2);
                            } else {
                                ($merged_spans, $merged_seq) = merge($bspans, $aspans_temp, $bseq2, $aseq2_temp);
                            }
                        }
                        if (! $merged_spans) {
                            $AS[-1]--;
                            $aspans_temp = join '-', @AS;
                            $aseq2_temp =~ s/.$//;
                            if ($gu->single_forward && $astrand eq "+" || $gu->single_reverse && $astrand eq "-") {
                                ($merged_spans, $merged_seq) = merge($aspans_temp, $bspans, $aseq2_temp, $bseq2);
                            } else {
                                ($merged_spans, $merged_seq) = merge($bspans, $aspans_temp, $bseq2, $aseq2_temp);
                            }
                        }
                        
                        if (! $merged_spans) {
                            @Fspans = split(/, /,$aspans);
                            @T = split(/-/, $Fspans[0]);
                            $aspans3 = $aspans;
                            $aseq3 = $aseq;
                            $bseq3 = $bseq;
                            $aseq3 =~ s/://g;
                            $bseq3 =~ s/://g;

                            # If the first span is 5 bases or fewer,
                            # remove it and trim the sequence
                            # accordingly, then try to merge the
                            # spans.
                            if ($T[1] - $T[0] <= 5) {
                                $aspans3 =~ s/^(\d+)-(\d+), //;
                                $length_diff = $2 - $1 + 1;
                                for ($i1=0; $i1<$length_diff; $i1++) {
                                    $aseq3 =~ s/^.//;
                                }
                            }
                            if ($gu->single_forward && $astrand eq "+" || $gu->single_reverse && $astrand eq "-") {
                                ($merged_spans, $merged_seq) = merge($aspans3, $bspans, $aseq3, $bseq3);
                            } else {
                                ($merged_spans, $merged_seq) = merge($bspans, $aspans3, $bseq3, $aseq3);
                            }

                            # Now try the same with the last span
                            if (! $merged_spans) {
                                @T = split(/-/, $Fspans[@Fspans-1]);
                                $aspans4 = $aspans;
                                $aseq4 = $aseq;
                                $bseq4 = $bseq;
                                $aseq4 =~ s/://g;
                                $bseq4 =~ s/://g;
                                if ($T[1] - $T[0] <= 5) {
                                    $aspans4 =~ s/, (\d+)-(\d+)$//;
                                    $length_diff = $2 - $1 + 1;
                                    for ($i1=0; $i1<$length_diff; $i1++) {
                                        $aseq4 =~ s/.$//;
                                    }
                                }
                                if ($gu->single_forward && $astrand eq "+" || $gu->single_reverse && $astrand eq "-") {
                                    ($merged_spans, $merged_seq) = merge($aspans4, $bspans, $aseq4, $bseq4);
                                } else {
                                    ($merged_spans, $merged_seq) = merge($bspans, $aspans4, $bseq4, $aseq4);
                                }
                            }
                        }

                        
                        if (! $merged_spans) {
                            @Rspans = split(/, /,$bspans);
                            @T = split(/-/, $Rspans[0]);
                            $bspans3 = $bspans;
                            $aseq3 = $aseq;
                            $bseq3 = $bseq;
                            $aseq3 =~ s/://g;
                            $bseq3 =~ s/://g;
                            if ($T[1] - $T[0] <= 5) {
                                $bspans3 =~ s/^(\d+)-(\d+), //;
                                $length_diff = $2 - $1 + 1;
                                for ($i1=0; $i1<$length_diff; $i1++) {
                                    $bseq3 =~ s/^.//;
                                }
                            }
                            if ($gu->single_forward && $astrand eq "+" || $gu->single_reverse && $astrand eq "-") {
                                ($merged_spans, $merged_seq) = merge($aspans, $bspans3, $aseq3, $bseq3);
                            } else {
                                ($merged_spans, $merged_seq) = merge($bspans3, $aspans, $bseq3, $aseq3);
                            }
                            if (! $merged_spans) {
                                @T = split(/-/, $Rspans[@Rspans-1]);
                                $bspans4 = $bspans;
                                $aseq4 = $aseq;
                                $bseq4 = $bseq;
                                $aseq4 =~ s/://g;
                                $bseq4 =~ s/://g;
                                if ($T[1] - $T[0] <= 5) {
                                    $bspans4 =~ s/, (\d+)-(\d+)$//;
                                    $length_diff = $2 - $1 + 1;
                                    for ($i1=0; $i1<$length_diff; $i1++) {
                                        $bseq4 =~ s/.$//;
                                    }
                                }
                                if ($gu->single_forward && $astrand eq "+" || $gu->single_reverse && $astrand eq "-") {
                                    ($merged_spans, $merged_seq) = merge($aspans, $bspans4, $aseq4, $bseq4);
                                } else {
                                    ($merged_spans, $merged_seq) = merge($bspans4, $aspans, $bseq4, $aseq4);
                                }
                            }
                        }
                        $seq_j = addJunctionsToSeq($merged_seq, $merged_spans);

                        if ($seq_j =~ /\S/ && $merged_spans =~ /^\d+.*-.*\d+$/) {
                            print $bowtie_unique_out_fh "$seqnum\t$chra\t$merged_spans\t$seq_j\t$astrand\n";
                        }
                        $Eflag =1;
                    }
                }
            }
            # ONE CASE
            if ($gu->unjoined && $tu->unjoined) {
                my @spansa;
                my @spansb;
                my @gu = @{ $gu->unjoined };
                my @tu = @{ $tu->unjoined };

                $chr1 = $gu[0]->chromosome;
                $chr2 = $tu[0]->chromosome;

                $spansa[0] = RUM::RUMIO->format_locs($gu[0]);
                $spansb[0] = RUM::RUMIO->format_locs($gu[1]);
                $seqa = $gu[0]->seq;
                $seqb = $gu[1]->seq;
                
                $spansa[1] = RUM::RUMIO->format_locs($tu[0]);
                $spansb[1] = RUM::RUMIO->format_locs($tu[1]);

                $min_overlap1 = $self->min_overlap($seqa, $tu[0]->seq);
                $min_overlap2 = $self->min_overlap($seqb, $tu[1]->seq);

                my $length_overlap1 = overlap_length(\@spansa, $seqa);
                my $length_overlap2 = overlap_length(\@spansb, $seqb);

                if (($length_overlap1 > $min_overlap1) && 
                    ($length_overlap2 > $min_overlap2) && 
                    ($chr1 eq $chr2)) {
                    $unique_io->write_alns($tu);
                } else {
                    $cnu_io->write_alns($gu);
                    $cnu_io->write_alns($tu);
                }
            }	
            # NINE CASES DONE
            # ONE CASE
            if ($gu->joined && $tu->unjoined) {
                $cnu_io->write_alns($gu);
                $cnu_io->write_alns($tu);
            }
            # ONE CASE
            if ($gu->unjoined && $tu->joined) {
                my @gu = @{ $gu->unjoined };

                my $seq  = $gu[0]->seq;
                my $chr1 = $gu[0]->chromosome;
                my $chr2 = $tu->joined->chromosome;
                
                my @spans = (RUM::RUMIO->format_locs($gu[0]),
                             RUM::RUMIO->format_locs($tu->joined));

                if ($chr1 eq $chr2) {

                    $min_overlap1 = $self->min_overlap_for_seqs($seq, $tu->joined->seq);

                    my $overlap1 = overlap_length(\@spans, $seq);

                    if ($self->{read_length} eq "v") {
                        $min_overlap2 = min_overlap_for_seqs($seq, $gu[1]->seq);
                    }
                    if ($self->{user_min_overlap} > 0) {
                        $min_overlap2 = $self->{user_min_overlap};
                    }
                    $spans[0] = RUM::RUMIO->format_locs($gu[1]);
                    my $overlap2 = overlap_length(\@spans, $seq);
                }

                if ($overlap1 >= $min_overlap1 && $overlap2 >= $min_overlap2) {
                    $unique_io->write_alns($tu);
                } else {
                    $cnu_io->write_alns($gu);
                    $cnu_io->write_alns($tu);
                }
            }
            # ELEVEN CASES DONE
            if ($gu->joined && $tu->single) {
                $unique_io->write_alns($gu);
            }
            if ($gu->single && $tu->joined) {
                $unique_io->write_alns($tu);
            }
            if ($gu->single && $tu->unjoined) {
                $unique_io->write_alns($tu);
            }	
            if ($gu->unjoined && $tu->single) {
                $unique_io->write_alns($gu);
            }	
            # ALL FIFTEEN CASES DONE
        }
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
        $maxspanlength = 0;
        $maxspan_start = 0;
        $maxspan_end = 0;
        $prevkey = 0;
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
            @s_i = split(//,$seq);
            $newseq = "";
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
            return "0";
        }
    }

    sub addJunctionsToSeq () {
        ($seq_in, $spans_in) = @_;
        @s1 = split(//,$seq_in);
        @b1 = split(/, /,$spans_in);
        $seq_out = "";
        $place = 0;
        for ($j1=0; $j1<@b1; $j1++) {
            @c1 = split(/-/,$b1[$j1]);
            $len1 = $c1[1] - $c1[0] + 1;
            if ($seq_out =~ /\S/) {
                $seq_out = $seq_out . ":";
            }
            for ($k1=0; $k1<$len1; $k1++) {
                $seq_out = $seq_out . $s1[$place];
                $place++;
            }
        }
        return $seq_out;
    }

}

sub merge {
   
    use strict;
    my ($upstreamspans, $downstreamspans, $seq1, $seq2) = @_;

    my %HASH;
    my @Uarray;
    my @Darray;

    my @Ustarts;
    my @Dstarts;
    my @Uends;
    my @Dends;
    my @T;
    
    my @Upstreamspans = split(/, /,$upstreamspans);
    my @Downstreamspans = split(/, /,$downstreamspans);
    my $num_u = @Upstreamspans;
    my $num_d = @Downstreamspans;
    for (my $i1=0; $i1<$num_u; $i1++) {
        @T = split(/-/, $Upstreamspans[$i1]);
        $Ustarts[$i1] = $T[0];
        $Uends[$i1] = $T[1];
    }
    for (my $i1=0; $i1<$num_d; $i1++) {
        @T = split(/-/, $Downstreamspans[$i1]);
        $Dstarts[$i1] = $T[0];
        $Dends[$i1] = $T[1];
    }
    
    # the last few bases of the upstream read might be misaligned downstream of the entire
    # downstream read, the following chops them off and tries again
    
    if ($num_u > 1 && ($Uends[$num_u-1]-$Ustarts[$num_u-1]) <= 5) {
        if ($Dends[$num_d-1] < $Uends[$num_u-1]) {
            $upstreamspans =~ s/, (\d+)-(\d+)$//;
            my $length_diff = $2 - $1 + 1;
            for (my $i1=0; $i1<$length_diff; $i1++) {
                $seq1 =~ s/.$//;
            }
            return merge($upstreamspans, $downstreamspans, $seq1, $seq2);
        }
    }
    # similarly, the first few bases of the downstream read might be misaligned upstream of the entire
    # upstream read, the following chops them off and tries again
    
    if ($num_u > 1 && ($Dends[0]-$Dstarts[0]) <= 5) {
        if ($Dstarts[0] < $Ustarts[0]) {
            $downstreamspans =~ s/^(\d+)-(\d+), //;
            my $length_diff = $2 - $1 + 1;
            for (my $i1=0; $i1<$length_diff; $i1++) {
                $seq2 =~ s/^.//;
            }
            return merge($upstreamspans, $downstreamspans, $seq1, $seq2);
        }
    }

    # next two if statements take care of the case where they do not overlap
    
    if ($Uends[$num_u-1] == $Dstarts[0]-1) {
        $upstreamspans =~ s/-\d+$//;
        $downstreamspans =~ s/^\d+-//;
        my $seq = $seq1 . $seq2;
        my $merged = $upstreamspans . "-" . $downstreamspans;
        return ($merged, $seq);
    }
    if ($Uends[$num_u-1] < $Dstarts[0]-1) {
        my $seq = $seq1 . $seq2;
        my $merged = $upstreamspans . ", " . $downstreamspans;
        return ($merged, $seq);
    }

    # now going to do a bunch of checks that these reads coords are consistent with 
    # them really being overlapping
    
    # the following merges the upstream starts and ends into one array
    for (my $i1=0; $i1<$num_u; $i1++) {
        $Uarray[2*$i1] = $Ustarts[$i1];
        $Uarray[2*$i1+1] = $Uends[$i1];
    }
    # the following merges the downstream starts and ends into one array
    for (my $i1=0; $i1<$num_d; $i1++) {
        $Darray[2*$i1] = $Dstarts[$i1];
        $Darray[2*$i1+1] = $Dends[$i1];
    }
    my $Flength = 0;
    my $Rlength = 0;
    for (my $i1=0; $i1<@Uarray; $i1=$i1+2) {
        $Flength = $Flength + $Uarray[$i1+1] - $Uarray[$i1] + 1;
    }
    for (my $i1=0; $i1<@Darray; $i1=$i1+2) {
        $Rlength = $Rlength + $Darray[$i1+1] - $Darray[$i1] + 1;
    }
    my $i1=0;
    my $flag1 = 0;
    # try to find a upstream span that contains the start of the downstream read
    until ($i1>=@Uarray || ($Uarray[$i1] <= $Darray[0] && $Darray[0] <= $Uarray[$i1+1])) {
        $i1 = $i1+2;
    } 
    if ($i1>=@Uarray) {     # didn't find one...
        $flag1 = 1;
    }
    my $Fhold = $Uarray[$i1];
    # the following checks the spans in the overlap have the same starts and ends
    for (my $j1=$i1+1; $j1<@Uarray-1; $j1++) {
        if ($Uarray[$j1] != $Darray[$j1-$i1]) {
            $flag1 = 1;
        } 
    }
    my $Rhold = $Darray[@Uarray-1-$i1];
    # make sure the end of the upstream ends in a span of the downstream   
    if (!($Uarray[@Uarray-1] >= $Darray[@Uarray-$i1-2] && $Uarray[@Uarray-1] <= $Darray[@Uarray-$i1-1])) {
        $flag1 = 1;
    }
    my $merged="";
    $Darray[0] = $Fhold;
    $Uarray[@Uarray-1] = $Rhold;
    if ($flag1 == 0) { # everything is kosher, going to proceed to merge
        for ($i1=0; $i1<@Uarray-1; $i1=$i1+2) {
            $HASH{"$Uarray[$i1]-$Uarray[$i1+1]"}++;
        }
        for ($i1=0; $i1<@Darray-1; $i1=$i1+2) {
            $HASH{"$Darray[$i1]-$Darray[$i1+1]"}++;
        }
        my $merged_length=0;
        foreach my $key_i (sort {$a<=>$b} keys %HASH) {
            $merged = $merged . ", $key_i";
            my @A = split(/-/,$key_i);
            $merged_length = $merged_length + $A[1] - $A[0] + 1;
        }
        my $suffix_length = $merged_length - $Flength;
        my $offset = $Rlength - $suffix_length;
        my $suffix = substr($seq2, $offset, $merged_length);
        $merged =~ s/\s*,\s*$//;
        $merged =~ s/^\s*,\s*//;
        my $merged_seq = $seq1 . $suffix;
        return ($merged, $merged_seq);
    }

    return;
    
}

sub enough_overlap {
    my ($self, $overlap, $seq1, $seq2) = @_;
    
    my $threshold = 
      $self->{user_min_overlap}   ? $self->{user_min_overlap} 
    : $self->{read_length} ne 'v' ? $self->{min_overlap} 
    :                               min_overlap_for_seqs($seq1, $seq2);
    
    return $overlap > $self->min_overlap($seq1, $seq2);
}

sub min_overlap {
    my ($self, $seq1, $seq2) = @_;
    if ($self->{user_min_overlap}) {
        return $self->{user_min_overlap};
    }
    elsif ($self->{read_length} ne 'v') {
        return min_overlap_for_read_length($self->{read_length});
    }
    else {
        return min_overlap_for_seqs($seq1, $seq2);
    }
}
