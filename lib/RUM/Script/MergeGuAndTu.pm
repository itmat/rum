package RUM::Script::MergeGuAndTu;

use strict;
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

sub overlap_length {

    my (@alns) = @_;
    my @spans = map { $_->locs } @alns;
    my %chash;
    for my $spans (@spans) {
        for my $span (@{ $spans }) {
            my ($start, $end) = @{ $span };
            for my $j ($start .. $end) {
                $chash{$j}++;
            }
        }
    }
    my $spanlength = 0;
    my $in_overlap_region = 0;
    my $maxspanlength = 0;
    
    for my $key_i (sort {$a <=> $b} keys %chash) {
        if ($chash{$key_i} == @spans) {
            if ( ! $in_overlap_region) {
                $in_overlap_region = 1;
            }
            $spanlength++;
        } else {
            if ($in_overlap_region) {
                $in_overlap_region = 0;
                if ($spanlength > $maxspanlength) {
                    $maxspanlength = $spanlength;
                }
                $spanlength = 0;
            }
        }
    }
    if ($in_overlap_region) {
        if ($spanlength > $maxspanlength) {
            $maxspanlength = $spanlength;
        }
    }
    return $maxspanlength;
}

sub unique_iter {
    my ($fh, $source) = @_;
    my $iter = RUM::BowtieIO->new(-fh => $fh, strand_last => 1);
    return $iter->to_mapper_iter($source);
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
    my $min_overlap;
    if ($self->{read_length} ne "v") {
        $min_overlap  = min_overlap_for_read_length($self->{read_length});
    }
    if ($self->{user_min_overlap} > 0) {
        $min_overlap  = $self->{user_min_overlap};
    }

    {
        my $gnu_in_fh = $self->{gnu_in_fh};
        
        while (my $line = <$gnu_in_fh>) {
            $line =~ /^seq.(\d+)/;
            $self->{ambiguous_mappers}->{$1}++;
        }
    }
    
    {
        my $tnu_in_fh = $self->{tnu_in_fh};
        while (my $line = <$tnu_in_fh>) {
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

                if ($self->enough_overlap($gu->joined, $tu->joined)) {
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

                    if ($self->enough_overlap($gu->single, $tu->single)) {
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

                    my $aspans  = RUM::RUMIO->format_locs($gu->single);
                    my $astart  = $gu->single->start;
                    my $aend    = $gu->single->end;
                    my $chra    = $gu->single->chromosome;
                    my $aseq    = $gu->single->seq;
                    my $seqnum  = $gu->single->readid;
                    my $astrand = $gu->single->strand;
                    my $seqnum  = $gu->single->readid_directionless;

                    my $forward_strand;

                    my $bspans  = RUM::RUMIO->format_locs($tu->single);
                    my $bstart  = $tu->single->start;
                    my $bend    = $tu->single->end;
                    my $chrb    = $tu->single->chromosome;
                    my $bseq    = $tu->single->seq;
                    my $bstrand = $tu->single->strand;

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

                    if (($astrand eq $bstrand) && ($chra eq $chrb) && (($aend >= $bstart-1) && ($astart <= $bstart)) || (($bend >= $astart-1) && ($bstart <= $astart))) {
                        my ($merged_spans, $merged_seq);
                        my $aseq2 = $aseq;
                        $aseq2 =~ s/://g;
                        my $bseq2 = $bseq;
                        $bseq2 =~ s/://g;

                        if ($gu->single_forward && $astrand eq "+" || $gu->single_reverse && $astrand eq "-") {
                            ($merged_spans, $merged_seq) = merge($aspans, $bspans, $aseq2, $bseq2);
                        } else {
                            ($merged_spans, $merged_seq) = merge($bspans, $aspans, $bseq2, $aseq2);
                        }
                        my (@AS, $aseq2_temp);
                        if (! $merged_spans) {
                            @AS = split(/-/,$aspans);
                            $AS[0]++;

                            my $aspans_temp = join '-', @AS;
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
                            my $aspans_temp = join '-', @AS;
                            $aseq2_temp =~ s/^.//;
                            if ($gu->single_forward && $astrand eq "+" || $gu->single_reverse && $astrand eq "-") {
                                ($merged_spans, $merged_seq) = merge($aspans_temp, $bspans, $aseq2_temp, $bseq2);
                            } else {
                                ($merged_spans, $merged_seq) = merge($bspans, $aspans_temp, $bseq2, $aseq2_temp);
                            }
                        }
                        if (! $merged_spans) {
                            $AS[0]++;
                            my $aspans_temp = join '-', @AS;
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
                            my $aspans_temp = join '-', @AS;
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
                            my $aspans_temp = join '-', @AS;
                            $aseq2_temp =~ s/.$//;
                            if ($gu->single_forward && $astrand eq "+" || $gu->single_reverse && $astrand eq "-") {
                                ($merged_spans, $merged_seq) = merge($aspans_temp, $bspans, $aseq2_temp, $bseq2);
                            } else {
                                ($merged_spans, $merged_seq) = merge($bspans, $aspans_temp, $bseq2, $aseq2_temp);
                            }
                        }
                        if (! $merged_spans) {
                            $AS[-1]--;
                            my $aspans_temp = join '-', @AS;
                            $aseq2_temp =~ s/.$//;
                            if ($gu->single_forward && $astrand eq "+" || $gu->single_reverse && $astrand eq "-") {
                                ($merged_spans, $merged_seq) = merge($aspans_temp, $bspans, $aseq2_temp, $bseq2);
                            } else {
                                ($merged_spans, $merged_seq) = merge($bspans, $aspans_temp, $bseq2, $aseq2_temp);
                            }
                        }
                        
                        if (! $merged_spans) {
                            my @Fspans = split(/, /,$aspans);
                            my @T = split(/-/, $Fspans[0]);
                            my $aspans3 = $aspans;
                            my $aseq3 = $aseq;
                            my $bseq3 = $bseq;
                            $aseq3 =~ s/://g;
                            $bseq3 =~ s/://g;

                            # If the first span is 5 bases or fewer,
                            # remove it and trim the sequence
                            # accordingly, then try to merge the
                            # spans.
                            if ($T[1] - $T[0] <= 5) {
                                $aspans3 =~ s/^(\d+)-(\d+), //;
                                my $length_diff = $2 - $1 + 1;
                                for (my $i1=0; $i1<$length_diff; $i1++) {
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
                                my $aspans4 = $aspans;
                                my $aseq4 = $aseq;
                                my $bseq4 = $bseq;
                                $aseq4 =~ s/://g;
                                $bseq4 =~ s/://g;
                                if ($T[1] - $T[0] <= 5) {
                                    $aspans4 =~ s/, (\d+)-(\d+)$//;
                                    my $length_diff = $2 - $1 + 1;
                                    for (my $i1=0; $i1<$length_diff; $i1++) {
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
                            my @Rspans = split(/, /,$bspans);
                            my @T = split(/-/, $Rspans[0]);
                            my $bspans3 = $bspans;
                            my $aseq3 = $aseq;
                            my $bseq3 = $bseq;
                            $aseq3 =~ s/://g;
                            $bseq3 =~ s/://g;
                            if ($T[1] - $T[0] <= 5) {
                                $bspans3 =~ s/^(\d+)-(\d+), //;
                                my $length_diff = $2 - $1 + 1;
                                for (my $i1=0; $i1<$length_diff; $i1++) {
                                    $bseq3 =~ s/^.//;
                                }
                            }
                            if ($gu->single_forward && $astrand eq "+" || $gu->single_reverse && $astrand eq "-") {
                                ($merged_spans, $merged_seq) = merge($aspans, $bspans3, $aseq3, $bseq3);
                            } else {
                                ($merged_spans, $merged_seq) = merge($bspans3, $aspans, $bseq3, $aseq3);
                            }
                            if (! $merged_spans) {
                                my @T = split(/-/, $Rspans[@Rspans-1]);
                                my $bspans4 = $bspans;
                                my $aseq4 = $aseq;
                                my $bseq4 = $bseq;
                                $aseq4 =~ s/://g;
                                $bseq4 =~ s/://g;
                                if ($T[1] - $T[0] <= 5) {
                                    $bspans4 =~ s/, (\d+)-(\d+)$//;
                                    my $length_diff = $2 - $1 + 1;
                                    for (my $i1=0; $i1<$length_diff; $i1++) {
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
                        my $seq_j = addJunctionsToSeq($merged_seq, $merged_spans);

                        if ($seq_j =~ /\S/ && $merged_spans =~ /^\d+.*-.*\d+$/) {
                            $unique_io->write_aln(
                                RUM::Alignment->new(
                                    readid => $seqnum,
                                    chr => $chra,
                                    locs => RUM::RUMIO->parse_locs($merged_spans),
                                    seq => $seq_j,
                                    strand => $astrand));
                        }
                    }
                }
            }
            # ONE CASE
            if ($gu->unjoined && $tu->unjoined) {
                my @gu = @{ $gu->unjoined };
                my @tu = @{ $tu->unjoined };

                if ($self->enough_overlap($gu[0], $tu[0]) &&
                    $self->enough_overlap($gu[1], $tu[1])) {
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

                if ($self->enough_overlap($gu[0], $tu->joined) &&
                    $self->enough_overlap($gu[1], $tu->joined)) {
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
}


sub addJunctionsToSeq {
    use strict;
    my ($seq_in, $spans_in) = @_;
    my @s1 = split(//,$seq_in);
    my @b1 = split(/, /,$spans_in);
    my $seq_out = "";
    my $place = 0;
    for (my $j1=0; $j1<@b1; $j1++) {
        my @c1 = split(/-/,$b1[$j1]);
        my $len1 = $c1[1] - $c1[0] + 1;
        if ($seq_out =~ /\S/) {
            $seq_out = $seq_out . ":";
        }
        for (my $k1=0; $k1<$len1; $k1++) {
            $seq_out = $seq_out . $s1[$place];
            $place++;
        }
    }
    return $seq_out;
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

sub enough_overlap {
    my ($self, $x, $y) = @_;

    return if $x->chromosome ne $y->chromosome;

    my $overlap = overlap_length($x, $y);

    my $seq1 = $x->seq;
    my $seq2 = $y->seq;

    my $threshold = 
      $self->{user_min_overlap}   ? $self->{user_min_overlap} 
    : $self->{read_length} ne 'v' ? $self->{min_overlap} 
    :                               min_overlap_for_seqs($seq1, $seq2);
    
    return $overlap > $self->min_overlap($seq1, $seq2);

}

1;
