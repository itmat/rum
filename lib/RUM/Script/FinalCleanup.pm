package RUM::Script::FinalCleanup;

use warnings;

use Getopt::Long;
use File::Temp qw(tempfile);
use Data::Dumper;

use RUM::Usage;
use RUM::Logging;
use RUM::Common qw(roman Roman isroman arabic);
use RUM::Sort qw(cmpChrs);
use RUM::CommandLineParser;
use RUM::CommonProperties;
use base 'RUM::Script::Base';

our $log = RUM::Logging->get_logger();

sub summary {
    return 'Cleans up RUM_Unique and RUM_NU files';
}

sub description {
    return <<'EOF';
This script modifies the RUM_Unique and RUM_NU files to clean
up things like mismatches at the ends of alignments.
EOF
}

sub command_line_parser {
    my $parser = RUM::CommandLineParser->new;
    $parser->add_prop(RUM::CommonProperties->unique_in->set_required);
    $parser->add_prop(RUM::CommonProperties->non_unique_in->set_required);
    $parser->add_prop(RUM::CommonProperties->unique_out->set_required);
    $parser->add_prop(RUM::CommonProperties->non_unique_out->set_required);
    $parser->add_prop(RUM::CommonProperties->genome->set_required);
    $parser->add_prop(RUM::CommonProperties->match_length_cutoff);
    $parser->add_prop(RUM::CommonProperties->faok);
    $parser->add_prop(
        opt => 'sam-header-out=s',
        desc => 'Sam header output file',
        required => 1);
    return $parser;
}

sub run {
    my ($self) = @_;

    my $props = $self->properties;

    my (undef, $dir, undef) = File::Spec->splitpath($props->get('unique_out'));

    if (!$faok) {
        $log->info("Modifying genome fa file");

        my $fh = File::Temp->new(TEMPLATE => "_tmp_final_cleanup.XXXXXXXX",
                                 UNLINK => 1, 
                                 DIR => $dir);

        open(INFILE, $props->get('genome'));
        $flag = 0;
        while ($line = <INFILE>) {
            if ($line =~ />/) {
                if ($flag == 0) {
                    print $fh $line;
                    $flag = 1;
                } else {
                    print $fh "\n$line";
                }
            } else {
                chomp($line);
                print $fh $line;
            }
        }
        print $fh "\n";
        close($fh);
        close(INFILE);
        open(GENOMESEQ, "<", $fh->filename)
            or die "Can't open temp file ".$fh->filename." for reading: $!";
    } else {
        $log->info("Genome fa file does not need fixing");
        open(GENOMESEQ, $props->get('genome'));
    }
    
    # Truncate output files
    open(OUTFILE, '>', $props->get('unique_out'));
    close(OUTFILE);
    open(OUTFILE, '>', $props->get('non_unique_out'));
    close(OUTFILE);

    $FLAG = 0;

    $log->info("Cleaning mappers");
    while ($FLAG == 0) {
        undef %CHR2SEQ;
        $sizeflag = 0;
        $totalsize = 0;
        while ($sizeflag == 0) {
            $line = <GENOMESEQ>;
            if (!defined $line) {
                $FLAG = 1;
                $sizeflag = 1;
            } else {
                chomp($line);
                $line =~ />(.*)/;
                $chr = $1;
                $log->debug("Working on chromosome $chr");
                $chr =~ s/:[^:]*$//;
                $ref_seq = <GENOMESEQ>;
                chomp($ref_seq);
                $chrsize{$chr} = length($ref_seq);
                $CHR2SEQ{$chr} = $ref_seq;
                $totalsize = $totalsize + length($ref_seq);
                if ($totalsize > 1000000000) { # don't store more than 1 gb of sequence in memory at once...
                    $sizeflag = 1;
                }
            }
        }
        clean($props->get('unique_in'), $props->get('unique_out'),
              $props->get('match_length_cutoff'));
        clean($props->get('non_unique_in'), $props->get('non_unique_out'),
               $props->get('match_length_cutoff'));
    }
    close(GENOMESEQ);

    $log->info("Writing sam header");
    open my $sam_header, '>', $props->get('sam_header_out');
    foreach $chr (sort {cmpChrs($a,$b)} keys %samheader) {
        $outstr = $samheader{$chr};
        print $sam_header $outstr;
    }

}

sub clean {
    my ($infilename, $outfilename, $match_length_cutoff) = @_;
    open(INFILE, $infilename);
    open(OUTFILE, ">>$outfilename");
    while ($line = <INFILE>) {
	$flag = 0;
	chomp($line);
	@a = split(/\t/,$line);
	$strand = $a[4];
	$chr = $a[1];
	@b2 = split(/, /,$a[2]);
	$a[3] =~ s/://g;
	$seq_temp = $a[3];
	$seq_temp =~ s/\+//g;
	if (length($seq_temp) < $match_length_cutoff) {
	    next;
	}
	for ($i=0; $i<@b2; $i++) {
	    @c2 = split(/-/,$b2[$i]);
	    if ($c2[1] < $c2[0]) {
		$flag = 1;
	    }
	}
        if (defined $CHR2SEQ{$chr} && !(defined $samheader{$chr})) {
	    $CS = $chrsize{$chr};
	    $samheader{$chr} = "\@SQ\tSN:$chr\tLN:$CS\n";
	}
	if (defined $CHR2SEQ{$chr} && $flag == 0) {
	    if ($line =~ /[^\t]\+[^\t]/) { # insertions will break things, have to fix this, for now not just cleaning these lines
		@LINE = split(/\t/,$line);
		print OUTFILE "$LINE[0]\t$LINE[1]\t$LINE[2]\t$LINE[4]\t$LINE[3]\n";
	    } else {
		@b = split(/, /, $a[2]);
		$SEQ = "";
		for ($i=0; $i<@b; $i++) {
 		    @c = split(/-/,$b[$i]);
		    $len = $c[1] - $c[0] + 1;
		    $start = $c[0] - 1;
		    $SEQ = $SEQ . substr($CHR2SEQ{$chr}, $start, $len);
		}
		&trimleft($SEQ, $a[3], $a[2]) =~ /(.*)\t(.*)/;
		$spans = $1;
		$seq = $2;
		$length1 = length($seq);
		$length2 = length($SEQ);
		for ($i=0; $i<$length2 - $length1; $i++) {
		    $SEQ =~ s/^.//;
		}
		$seq =~ s/://g;
		&trimright($SEQ, $seq, $spans) =~ /(.*)\t(.*)/;
		$spans = $1;
		$seq = $2;
		$seq = addJunctionsToSeq($seq, $spans);

		# should fix the following so it doesn't repeat the operation unnecessarily
		# while processing the RUM_NU file
		$seq_temp = $seq;
		$seq_temp =~ s/://g;
		$seq_temp =~ s/\+//g;
		if (length($seq_temp) >= $match_length_cutoff) {
		    print OUTFILE "$a[0]\t$chr\t$spans\t$strand\t$seq\n";
		}
	    }
	}
    }
    close(INFILE);
    close(OUTFILE);
}

sub removefirst  {
    ($n_1, $spans_1, $seq_1) = @_;
    $seq_1 =~ s/://g;
    @a_1 = split(/, /, $spans_1);
    $length_1 = 0;
    @b_1 = split(/-/,$a_1[0]);
    $length_1 = $b_1[1] - $b_1[0] + 1;
    if ($length_1 <= $n_1) {
	$m_1 = $n_1 - $length_1;
	$spans2_1 = $spans_1;
	$spans2_1 =~ s/^\d+-\d+, //;
	for ($j_1=0; $j_1<$length_1; $j_1++) {
	    $seq_1 =~ s/^.//;
	}
	$return = removefirst($m_1, $spans2_1, $seq_1);
	return $return;
    } else {
	for ($j_1=0; $j_1<$n_1; $j_1++) {
	    $seq_1 =~ s/^.//;
	}
	$spans_1 =~ /^(\d+)-/;
	$start_1 = $1 + $n_1;
	$spans_1 =~ s/^(\d+)-/$start_1-/;
	return $spans_1 . "\t" . $seq_1;
    }
}

sub removelast {
    ($n_1, $spans_1, $seq_1) = @_;
    $seq_1 =~ s/://g;
    @a_1 = split(/, /, $spans_1);
    @b_1 = split(/-/,$a_1[@a_1-1]);
    $length_1 = $b_1[1] - $b_1[0] + 1;
    if ($length_1 <= $n_1) {
	$m_1 = $n_1 - $length_1;
	$spans2_1 = $spans_1;
	$spans2_1 =~ s/, \d+-\d+$//;
	for ($j_1=0; $j_1<$length_1; $j_1++) {
	    $seq_1 =~ s/.$//;
	}
	$return = removelast($m_1, $spans2_1, $seq_1);
	return $return;
    } else {
	for ($j_1=0; $j_1<$n_1; $j_1++) {
	    $seq_1 =~ s/.$//;
	}
	$spans_1 =~ /-(\d+)$/;
	$end_1 = $1 - $n_1;
	$spans_1 =~ s/-(\d+)$/-$end_1/;
	return $spans_1 . "\t" . $seq_1;
    }
}

sub trimleft () {
    ($seq1_2, $seq2_2, $spans_2) = @_;
    # seq2_2 is the one that gets modified and returned

    $seq1_2 =~ s/://g;
    $seq1_2 =~ /^(.)(.)/;
    $genomebase_2[0] = $1;
    $genomebase_2[1] = $2;
    $seq2_2 =~ s/://g;
    $seq2_2 =~ /^(.)(.)/;
    $readbase_2[0] = $1;
    $readbase_2[1] = $2;
    $mismatch_count_2 = 0;
    for ($j_2=0; $j_2<2; $j_2++) {
	if ($genomebase_2[$j_2] eq $readbase_2[$j_2]) {
	    $equal_2[$j_2] = 1;
	} else {
	    $equal_2[$j_2] = 0;
	    $mismatch_count_2++;
	}
    }
    if ($mismatch_count_2 == 0) {
	return $spans_2 . "\t" . $seq2_2;
    }
    if ($mismatch_count_2 == 1 && $equal_2[0] == 0) {
	&removefirst(1, $spans_2, $seq2_2) =~ /^(.*)\t(.*)/;
	$spans_new_2 = $1;
	$seq2_new_2 = $2;
	$seq1_2 =~ s/^.//;
	$return = &trimleft($seq1_2, $seq2_new_2, $spans_new_2);
	return $return;
    }
    if ($equal_2[1] == 0 || $mismatch_count_2 == 2) {
	&removefirst(2, $spans_2, $seq2_2) =~ /^(.*)\t(.*)/;
	$spans_new_2 = $1;
	$seq2_new_2 = $2;
	$seq1_2 =~ s/^..//;
	$return = &trimleft($seq1_2, $seq2_new_2, $spans_new_2);
	return $return;
    }
}

sub trimright () {
    ($seq1_2, $seq2_2, $spans_2) = @_;
    # seq2_2 is the one that gets modified and returned

    $seq1_2 =~ s/://g;
    $seq1_2 =~ /(.)(.)$/;
    $genomebase_2[0] = $2;
    $genomebase_2[1] = $1;
    $seq2_2 =~ s/://g;
    $seq2_2 =~ /(.)(.)$/;
    $readbase_2[0] = $2;
    $readbase_2[1] = $1;
    $mismatch_count_2 = 0;

    for ($j_2=0; $j_2<2; $j_2++) {
	if ($genomebase_2[$j_2] eq $readbase_2[$j_2]) {
	    $equal_2[$j_2] = 1;
	} else {
	    $equal_2[$j_2] = 0;
	    $mismatch_count_2++;
	}
    }
    if ($mismatch_count_2 == 0) {
	return $spans_2 . "\t" . $seq2_2;
    }
    if ($mismatch_count_2 == 1 && $equal_2[0] == 0) {
	&removelast(1, $spans_2, $seq2_2) =~ /(.*)\t(.*)$/;
	$spans_new_2 = $1;
	$seq2_new_2 = $2;
	$seq1_2 =~ s/.$//;
	$return = &trimright($seq1_2, $seq2_new_2, $spans_new_2);
	return $return;
    }
    if ($equal_2[1] == 0 || $mismatch_count_2 == 2) {
	&removelast(2, $spans_2, $seq2_2) =~ /(.*)\t(.*)$/;
	$spans_new_2 = $1;
	$seq2_new_2 = $2;
	$seq1_2 =~ s/..$//;
	$return = &trimright($seq1_2, $seq2_new_2, $spans_new_2);
	return $return;
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

sub countmismatches () {
    ($seq1m, $seq2m) = @_;
    # seq2m is the "read"

    $seq1m =~ s/://g;
    $seq2m =~ s/://g;
    $seq2m =~ s/\+[^+]\+//g;

    @C1 = split(//,$seq1m);
    @C2 = split(//,$seq2m);
    $NUM=0;
    for ($k=0; $k<@C1; $k++) {
	if ($C1[$k] ne $C2[$k]) {
	    $NUM++;
	}
    }
    return $NUM;
}

