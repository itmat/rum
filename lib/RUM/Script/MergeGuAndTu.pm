package RUM::Script::MergeGuAndTu;

no warnings;

use Carp;
use RUM::Usage;
use RUM::Common qw(min_overlap_for_read_length
                   min_overlap_for_seqs);
use List::Util qw(min max);

use base 'RUM::Script::Base';

$|=1;

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
    my @fhs = map { $self->{$_} } @keys;
    my @iters   = map { RUM::BowtieIO->new(
        -fh => $_, strand_last => 1) } @fhs;

    my @lengths = map { $_->longest_read } @iters;

    for my $fh (@fhs) {
        seek $fh, 0, 0;
    }
    warn "my lengths are @lengths\n";
    return max(@lengths);
}

sub run {
    my ($self) = @_;

    $self->{read_length} ||= $self->determine_read_length_from_input;
    warn "Read length is $self->{read_length}\n";
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

    $num_lines_at_once = 10000;
    $linecount = 0;
    $FLAG = 1;
    $line_prev = <$tu_in_fh>;
    chomp($line_prev);
    while ($FLAG == 1) {
        undef %hash1;
        undef %hash2;
        undef %allids;
        $linecount = 0;
        until ($linecount == $num_lines_at_once) {
            $line=<$gu_in_fh>;
            if (!($line =~ /\S/)) {
                $FLAG = 0;
                $linecount = $num_lines_at_once;
            } else {
                chomp($line);
                @a = split(/\t/,$line);
                $a[0] =~ /seq.(\d+)/;
                $id = $1;
                $last_id = $id;
                $allids{$id}++;
                if ($a[0] =~ /a$/ || $a[0] =~ /b$/) {
                    $hash1{$id}[0]++;
                    $hash1{$id}[$hash1{$id}[0]]=$line;
                } else {
                    $hash1{$id}[0]=-1;
                    $hash1{$id}[1]=$line;
                }
                if ($self->{paired}) {
                    # this makes sure we have read in both a and b reads, this approach might cause a problem
                    # for paired end data if no, or very few, b reads mapped at all.
                    if ( (($linecount == ($num_lines_at_once - 1)) && !($a[0] =~ /a$/)) || ($linecount < ($num_lines_at_once - 1)) ) {
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
        @a = split(/\t/,$line);
        $a[0] =~ /seq.(\d+)/;
        $prev_id = $id;
        $id = $1;
        if ($prev_id eq $id) {
            $FLAG2 = 0;
        }
        $FLAG2 = 1;
        until ($id > $last_id || $FLAG2 == 0) {
            $allids{$id}++;
            if ($a[0] =~ /a$/ || $a[0] =~ /b$/) {
                $hash2{$id}[0]++;
                $hash2{$id}[$hash2{$id}[0]]=$line;
            } else {
                $hash2{$id}[0]=-1;
                $hash2{$id}[1]=$line;
            }
            $line=<$tu_in_fh>;
            chomp($line);
            if (!($line =~ /\S/)) {
                $FLAG2 = 0;
            } else {
                @a = split(/\t/,$line);
                $a[0] =~ /seq.(\d+)/;
                $id = $1;
            }
        }
        if ($FLAG2 == 1) {
            $line_prev = $line;
        }
        foreach $id (sort {$a <=> $b} keys %allids) {
            next if $self->{ambiguous_mappers}->{$id};

            $hash1{$id}[0] = $hash1{$id}[0] + 0;
            $hash2{$id}[0] = $hash2{$id}[0] + 0;

            # MUST DO 15 CASES IN TOTAL:
            # THREE CASES:
            if ($hash1{$id}[0] == 0) {
                # no genome mapper, so there must be a transcriptome mapper
                if ($hash2{$id}[0] == -1) {
                    print $bowtie_unique_out_fh "$hash2{$id}[1]\n";
                } else {
                    for ($i=0; $i<$hash2{$id}[0]; $i++) {
                        print $bowtie_unique_out_fh "$hash2{$id}[$i+1]\n";
                    }
                }
            }
            # THREE CASES
            if ($hash2{$id}[0] == 0) {
                # no transcriptome mapper, so there must be a genome mapper
                if ($hash1{$id}[0] == -1) {
                    print $bowtie_unique_out_fh "$hash1{$id}[1]\n";
                } else {
                    for ($i=0; $i<$hash1{$id}[0]; $i++) {
                        print $bowtie_unique_out_fh "$hash1{$id}[$i+1]\n";
                    }
                }
            }
            # ONE CASE
            if ($hash1{$id}[0] == -1 && $hash2{$id}[0] == -1) {
                # genome mapper and transcriptome mapper, and both joined
                undef @spans;
                @a1 = split(/\t/,$hash1{$id}[1]);
                @a2 = split(/\t/,$hash2{$id}[1]);
                $spans[0] = $a1[2];
                $spans[1] = $a2[2];
                $str = intersect(\@spans, $a1[3]);
                $str =~ /^(\d+)/;
                $length_overlap = $1;

                if ($self->enough_overlap($length_overlap, $a1[3], $a2[3]) &&
                    ($a1[1] eq $a2[1])) {
                    print $bowtie_unique_out_fh "$hash2{$id}[1]\n";
                } else {
                    print $cnu_out_fh "$hash1{$id}[1]\n";
                    print $cnu_out_fh "$hash2{$id}[1]\n";
                }
            }
            # ONE CASE
            if ($hash1{$id}[0] == 1 && $hash2{$id}[0] == 1) {
                # genome mapper and transcriptome mapper, and both single read mapping
                # If single-end then this is the only case where $hash1{$id}[0] > 0 and $hash2{$id}[0] > 0
                if ((($hash1{$id}[1] =~ /seq.\d+a/) && ($hash2{$id}[1] =~ /seq.\d+a/)) || (($hash1{$id}[1] =~ /seq.\d+b/) && ($hash2{$id}[1] =~ /seq.\d+b/))) {
                    # both forward mappers, or both reverse mappers
                    undef @spans;
                    @a1 = split(/\t/,$hash1{$id}[1]);
                    @a2 = split(/\t/,$hash2{$id}[1]);
                    $spans[0] = $a1[2];
                    $spans[1] = $a2[2];
                    $str = intersect(\@spans, $a1[3]);
                    $str =~ /^(\d+)/;
                    $length_overlap = $1;

                    if ($self->enough_overlap($length_overlap, $a1[3], $a2[3]) 
                        && ($a1[1] eq $a2[1])) {
                        # preference TU
                        print $bowtie_unique_out_fh "$hash2{$id}[1]\n";
                    } else {
                        if (!$self->{paired}) {
                            print $cnu_out_fh "$hash1{$id}[1]\n";			
                            print $cnu_out_fh "$hash2{$id}[1]\n";			
                        }
                    }
                }
                if ((($hash1{$id}[1] =~ /seq.\d+a/) && ($hash2{$id}[1] =~ /seq.\d+b/)) || (($hash1{$id}[1] =~ /seq.\d+b/) && ($hash2{$id}[1] =~ /seq.\d+a/))) {
                    # one forward and one reverse
                    @a = split(/\t/,$hash1{$id}[1]);
                    $aspans = $a[2];
                    $a[2] =~ /^(\d+)[^\d]/;
                    $astart = $1;
                    $a[2] =~ /[^\d](\d+)$/;
                    $aend = $1;
                    $chra = $a[1];
                    $aseq = $a[3];
                    $seqnum = $a[0];
                    $atype = "";
                    if ($seqnum =~ s/a$//) {
                        $atype = "forward";
                    }
                    if ($seqnum =~ s/b$//) {
                        $atype = "reverse";
                    }
                    $astrand = $a[4];
                    if ($atype eq "forward") {
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

                    @a = split(/\t/,$hash2{$id}[1]);
                    $btype = "";
                    if ($a[0] =~ /a$/) {
                        $btype = "forward";
                    }
                    if ($a[0] =~ /b$/) {
                        $btype = "reverse";
                    }

                    $bspans = $a[2];
                    $a[2] =~ /^(\d+)[^\d]/;
                    $bstart = $1;
                    $a[2] =~ /[^\d](\d+)$/;
                    $bend = $1;
                    $chrb = $a[1];
                    $bseq = $a[3];
                    $bstrand = $a[4];
                    if ($btype eq "forward") {
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
		
                    if ((($astrand eq "+" && $bstrand eq "+" && $atype eq "forward" && $btype eq "reverse") || ($astrand eq "-" && $bstrand eq "-" && $atype eq "reverse" && $btype eq "forward")) && ($chra eq $chrb) && ($aend < $bstart-1) && ($bstart - $aend < $self->{max_pair_dist})) {
                        if ($hash1{$id}[1] =~ /a\t/) {
                            print $bowtie_unique_out_fh "$hash1{$id}[1]\n$hash2{$id}[1]\n";
                        } else {
                            print $bowtie_unique_out_fh "$hash2{$id}[1]\n$hash1{$id}[1]\n";
                        }
                    }
                    if ((($astrand eq "-" && $bstrand eq "-" && $atype eq "forward" && $btype eq "reverse") || ($astrand eq "+" && $bstrand eq "+" && $atype eq "reverse" && $btype eq "forward")) && ($chra eq $chrb) && ($bend < $astart-1) && ($astart - $bend < $self->{max_pair_dist})) {
                        if ($hash1{$id}[1] =~ /a\t/) {
                            print $bowtie_unique_out_fh "$hash1{$id}[1]\n$hash2{$id}[1]\n";
                        } else {
                            print $bowtie_unique_out_fh "$hash2{$id}[1]\n$hash1{$id}[1]\n";
                        }
                    }
                    $Eflag =0;

                    if (($astrand eq $bstrand) && ($chra eq $chrb) && (($aend >= $bstart-1) && ($astart <= $bstart)) || (($bend >= $astart-1) && ($bstart <= $astart))) {

                        $aseq2 = $aseq;
                        $aseq2 =~ s/://g;
                        $bseq2 = $bseq;
                        $bseq2 =~ s/://g;
                        if ($atype eq "forward" && $astrand eq "+" || $atype eq "reverse" && $astrand eq "-") {
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

                            if ($atype eq "forward" && $astrand eq "+" || $atype eq "reverse" && $astrand eq "-") {
                                ($merged_spans, $merged_seq) = merge($aspans_temp, $bspans, $aseq2_temp, $bseq2);
                            } else {
                                ($merged_spans, $merged_seq) = merge($bspans, $aspans_temp, $bseq2, $aseq2_temp);
                            }
                        }
                        if (! $merged_spans) {
                            $AS[0]++;
                            $aspans_temp = join '-', @AS;
                            $aseq2_temp =~ s/^.//;
                            if ($atype eq "forward" && $astrand eq "+" || $atype eq "reverse" && $astrand eq "-") {
                                ($merged_spans, $merged_seq) = merge($aspans_temp, $bspans, $aseq2_temp, $bseq2);
                            } else {
                                ($merged_spans, $merged_seq) = merge($bspans, $aspans_temp, $bseq2, $aseq2_temp);
                            }
                        }
                        if (! $merged_spans) {
                            $AS[0]++;
                            $aspans_temp = join '-', @AS;
                            $aseq2_temp =~ s/^.//;
                            if ($atype eq "forward" && $astrand eq "+" || $atype eq "reverse" && $astrand eq "-") {
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
                            if ($atype eq "forward" && $astrand eq "+" || $atype eq "reverse" && $astrand eq "-") {
                                ($merged_spans, $merged_seq) = merge($aspans_temp, $bspans, $aseq2_temp, $bseq2);
                            } else {
                                ($merged_spans, $merged_seq) = merge($bspans, $aspans_temp, $bseq2, $aseq2_temp);
                            }
                        }
                        if (! $merged_spans) {
                            $AS[-1]--;
                            $aspans_temp = join '-', @AS;
                            $aseq2_temp =~ s/.$//;
                            if ($atype eq "forward" && $astrand eq "+" || $atype eq "reverse" && $astrand eq "-") {
                                ($merged_spans, $merged_seq) = merge($aspans_temp, $bspans, $aseq2_temp, $bseq2);
                            } else {
                                ($merged_spans, $merged_seq) = merge($bspans, $aspans_temp, $bseq2, $aseq2_temp);
                            }
                        }
                        if (! $merged_spans) {
                            $AS[-1]--;
                            $aspans_temp = join '-', @AS;
                            $aseq2_temp =~ s/.$//;
                            if ($atype eq "forward" && $astrand eq "+" || $atype eq "reverse" && $astrand eq "-") {
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
                            if ($atype eq "forward" && $astrand eq "+" || $atype eq "reverse" && $astrand eq "-") {
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
                                if ($atype eq "forward" && $astrand eq "+" || $atype eq "reverse" && $astrand eq "-") {
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
                            if ($atype eq "forward" && $astrand eq "+" || $atype eq "reverse" && $astrand eq "-") {
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
                                if ($atype eq "forward" && $astrand eq "+" || $atype eq "reverse" && $astrand eq "-") {
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
            if ($hash1{$id}[0] == 2 && $hash2{$id}[0] == 2) {
                undef @spansa;
                undef @spansb;
                @a = split(/\t/,$hash1{$id}[1]);
                $chr1 = $a[1];
                $spansa[0] = $a[2];
                $seqa = $a[3];
                @a = split(/\t/,$hash1{$id}[2]);
                $spansb[0] = $a[2];
                $seqb = $a[3];
                @a = split(/\t/,$hash2{$id}[1]);
                $chr2 = $a[1];
                $spansa[1] = $a[2];

                $min_overlap1 = $self->min_overlap($seqa, $a[3]);

                @a = split(/\t/,$hash2{$id}[2]);
                $spansb[1] = $a[2];

                $min_overlap2 = $self->min_overlap($seqb, $a[3]);

                $str = intersect(\@spansa, $seqa);
                $str =~ /^(\d+)/;
                $length_overlap1 = $1;
                $str = intersect(\@spansb, $seqb);
                $str =~ /^(\d+)/;
                $length_overlap2 = $1;
                if (($length_overlap1 > $min_overlap1) && 
                    ($length_overlap2 > $min_overlap2) && 
                    ($chr1 eq $chr2)) {
                    print $bowtie_unique_out_fh "$hash2{$id}[1]\n";
                    print $bowtie_unique_out_fh "$hash2{$id}[2]\n";
                } else {
                    print $cnu_out_fh "$hash1{$id}[1]\n";
                    print $cnu_out_fh "$hash1{$id}[2]\n";
                    print $cnu_out_fh "$hash2{$id}[1]\n";
                    print $cnu_out_fh "$hash2{$id}[2]\n";
                }
            }	
            # NINE CASES DONE
            # ONE CASE
            if ($hash1{$id}[0] == -1 && $hash2{$id}[0] == 2) {
                print $cnu_out_fh "$hash1{$id}[1]\n";
                print $cnu_out_fh "$hash2{$id}[1]\n";
                print $cnu_out_fh "$hash2{$id}[2]\n";
            }
            # ONE CASE
            if ($hash1{$id}[0] == 2 && $hash2{$id}[0] == -1) {
                undef @spans;
                @a = split(/\t/,$hash1{$id}[1]);
                $chr1 = $a[1];
                $spans[0] = $a[2];
                $seq = $a[3];
                @a = split(/\t/,$hash2{$id}[1]);
                $chr2 = $a[1];
                $spans[1] = $a[2];
                if ($chr1 eq $chr2) {

                    $min_overlap1 = $self->min_overlap($seq, $a[3]);

                    $str = intersect(\@spans, $seq);
                    $str =~ /^(\d+)/;
                    $overlap1 = $1;
                    @a = split(/\t/,$hash1{$id}[2]);
                    if ($self->{read_length} eq "v") {
                        $min_overlap2 = min_overlap_for_seqs($seq, $a[3]);
                    }
                    if ($self->{user_min_overlap} > 0) {
                        $min_overlap2 = $self->{user_min_overlap};
                    }
                    $spans[0] = $a[2];
                    $str = intersect(\@spans, $seq);
                    $str =~ /^(\d+)/;
                    $overlap2 = $1;
                }
                if ($overlap1 >= $min_overlap1 && $overlap2 >= $min_overlap2) {
                    print $bowtie_unique_out_fh "$hash2{$id}[1]\n";
                } else {
                    print $cnu_out_fh "$hash1{$id}[1]\n";
                    print $cnu_out_fh "$hash1{$id}[2]\n";
                    print $cnu_out_fh "$hash2{$id}[1]\n";
                }
            }
            # ELEVEN CASES DONE
            if ($hash1{$id}[0] == -1 && $hash2{$id}[0] == 1) {
                print $bowtie_unique_out_fh "$hash1{$id}[1]\n";
            }
            if ($hash1{$id}[0] == 1 && $hash2{$id}[0] == -1) {
                print $bowtie_unique_out_fh "$hash2{$id}[1]\n";
            }
            if ($hash1{$id}[0] == 1 && $hash2{$id}[0] == 2) {
                print $bowtie_unique_out_fh "$hash2{$id}[1]\n";
                print $bowtie_unique_out_fh "$hash2{$id}[2]\n";
            }	
            if ($hash1{$id}[0] == 2 && $hash2{$id}[0] == 1) {
                print $bowtie_unique_out_fh "$hash1{$id}[1]\n";
                print $bowtie_unique_out_fh "$hash1{$id}[2]\n";
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
    warn "Getting threshold for $seq1, $seq2\n";
    if ($self->{user_min_overlap}) {
        carp "Using threshold from user of $self->{user_min_overlap}\n";
        return $self->{user_min_overlap};
    }
    elsif ($self->{read_length} ne 'v') {
        carp "Using calculated threshold of $self->{min_overlap}\n";
        return min_overlap_for_read_length($self->{read_length});
    }
    else {
        carp "Using custom threshold of " . min_overlap_for_seqs($seq1, $seq2);
        return min_overlap_for_seqs($seq1, $seq2);
    }
}
