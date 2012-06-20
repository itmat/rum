package RUM::Script::FinalCleanup;

no warnings;

use Getopt::Long;
use File::Temp qw(tempfile);

use RUM::Usage;
use RUM::Logging;
use RUM::Common qw(roman Roman isroman arabic);
use RUM::Sort qw(cmpChrs);

our $log = RUM::Logging->get_logger();
$|=1;

our $match_length_cutoff;
our %CHR2SEQ;
our %samheader;
our %chrsize;

sub main {

    GetOptions(
        "unique-in=s" => \(my $unique_in),
        "non-unique-in=s" => \(my $non_unique_in),
        "unique-out=s" => \(my $unique_out),
        "non-unique-out=s" => \(my $non_unique_out),
        "sam-header-out=s"   => \(my $sam_header_out),
        "genome=s" => \(my $genome),
        "match-length-cutoff=s" => \($match_length_cutoff = 0),
        "faok"  => \(my $faok),
        "help|h"    => sub { RUM::Usage->help },
        "verbose|v" => sub { $log->more_logging(1) },
        "quiet|q"   => sub { $log->less_logging(1) },
    );

    $unique_in or RUM::Usage->bad(
        "Please provide input file of unique mappers with --unique-in");
    $non_unique_in or RUM::Usage->bad(
        "Please provide input file of non-unique mappers with --non-unique-in");
    $unique_out or RUM::Usage->bad(
        "Please provide output file of unique mappers with --unique-out");
    $non_unique_out or RUM::Usage->bad(
        "Please provide output file of non-unique mappers with --non-unique-out");
    $genome or RUM::Usage->bad(
        "Please provide genome fasta file with --genome");

    $sam_header_out or RUM::Usage->bad(
        "Please provide sam header output file with --sam-header-out");

    my (undef, $dir, undef) = File::Spec->splitpath($unique_out);

    if (!$faok) {
        $log->info("Modifying genome fa file");

        my $fh = File::Temp->new(TEMPLATE => "_tmp_final_cleanup.XXXXXXXX",
                                 UNLINK => 1, 
                                 DIR => $dir);

        open(INFILE, $genome);
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
        open(GENOMESEQ, $genome);
    }
    
    # Truncate output files
    open(OUTFILE, ">$unique_out");
    close(OUTFILE);
    open(OUTFILE, ">$non_unique_out");
    close(OUTFILE);

    $FLAG = 0;

    $log->info("Cleaning mappers");
    while ($FLAG == 0) {
        undef %CHR2SEQ;
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
        &clean($unique_in, $unique_out);
        &clean($non_unique_in, $non_unique_out);
    }
    close(GENOMESEQ);

    $log->info("Writing sam header");
    open(SAMHEADER, ">$sam_header_out");
    foreach $chr (sort {cmpChrs($a,$b)} keys %samheader) {
        $outstr = $samheader{$chr};
        print SAMHEADER $outstr;
    }
    close(SAMHEADER);

}

sub clean () {
    use strict;
    my ($infilename, $outfilename) = @_;
    open my $infile, "<", $infilename;
    open my $outfile, ">>", $outfilename;

    while (my $line = <$infile>) {
	my $flag = 0;
	chomp($line);
	my @a = split(/\t/,$line);
	my $strand = $a[4];
	my $chr = $a[1];
	my @b2 = split(/, /,$a[2]);
	$a[3] =~ s/://g;
	my $seq_temp = $a[3];
	$seq_temp =~ s/\+//g;
	if (length($seq_temp) < $match_length_cutoff) {
	    next;
	}
	for (my $i=0; $i<@b2; $i++) {
	    my @c2 = split(/-/,$b2[$i]);
	    if ($c2[1] < $c2[0]) {
		$flag = 1;
	    }
	}
        if (defined $CHR2SEQ{$chr} && !(defined $samheader{$chr})) {
	    my $CS = $chrsize{$chr};
	    $samheader{$chr} = "\@SQ\tSN:$chr\tLN:$CS\n";
	}
	if (defined $CHR2SEQ{$chr} && $flag == 0) {
	    if ($line =~ /[^\t]\+[^\t]/) { # insertions will break things, have to fix this, for now not just cleaning these lines
		my @LINE = split(/\t/,$line);
		print $outfile "$LINE[0]\t$LINE[1]\t$LINE[2]\t$LINE[4]\t$LINE[3]\n";
	    } else {
		my @b = split(/, /, $a[2]);
		my $SEQ = "";
		for (my $i=0; $i<@b; $i++) {
 		    my @c = split(/-/,$b[$i]);
		    my $len = $c[1] - $c[0] + 1;
		    my $start = $c[0] - 1;
		    $SEQ = $SEQ . substr($CHR2SEQ{$chr}, $start, $len);
		}
		&trimleft($SEQ, $a[3], $a[2]) =~ /(.*)\t(.*)/;
		my $spans = $1;
		my $seq = $2;
		my $length1 = length($seq);
		my $length2 = length($SEQ);
		for (my $i=0; $i<$length2 - $length1; $i++) {
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
		    print $outfile "$a[0]\t$chr\t$spans\t$strand\t$seq\n";
		}
	    }
	}
    }

}

sub removefirst {
    use strict;
    my ($n_1, $spans_1, $seq_1) = @_;
    $seq_1 =~ s/://g;
    my @spans = split(/, /, $spans_1);
    my ($start, $end) = split /-/, $spans[0];
    my $length_1 = $end - $start + 1;

    if ($length_1 <= $n_1) {
	my $m_1 = $n_1 - $length_1;
	my $spans2_1 = $spans_1;
	$spans2_1 =~ s/^\d+-\d+, //;
	for (my $j_1=0; $j_1<$length_1; $j_1++) {
	    $seq_1 =~ s/^.//;
	}
	return removefirst($m_1, $spans2_1, $seq_1);
    } else {
	for (my $j_1=0; $j_1<$n_1; $j_1++) {
	    $seq_1 =~ s/^.//;
	}
	$spans_1 =~ /^(\d+)-/;
	my $start_1 = $1 + $n_1;
	$spans_1 =~ s/^(\d+)-/$start_1-/;
	return $spans_1 . "\t" . $seq_1;
    }
}

sub removelast {
    use strict;
    my ($n, $spans, $seq) = @_;
    $seq =~ s/://g;
    my @spans = split /, /, $spans;
    my ($start, $end) = split /-/, $spans[$#spans];

    my $length_1 = $end - $start + 1;

    if ($length_1 <= $n) {
	my $m_1 = $n - $length_1;
	my $spans2_1 = $spans;
	$spans2_1 =~ s/, \d+-\d+$//;
        $seq = substr $seq, 0, length($seq) - $length_1;
	return removelast($m_1, $spans2_1, $seq);
    } else {
        $seq = substr $seq, 0, length($seq) - $n;
	$spans =~ /-(\d+)$/;
	my $end_1 = $1 - $n;
	$spans =~ s/-(\d+)$/-$end_1/;
	return $spans . "\t" . $seq;
    }
}

sub trimleft {
    use strict;
    my ($seq1_2, $seq2_2, $spans_2) = @_;
    # seq2_2 is the one that gets modified and returned

    $seq1_2 =~ s/://g;
    $seq1_2 =~ /^(.)(.)/;
    my @genomebase_2;
    $genomebase_2[0] = $1;
    $genomebase_2[1] = $2;
    $seq2_2 =~ s/://g;
    $seq2_2 =~ /^(.)(.)/;
    my @readbase_2;
    $readbase_2[0] = $1;
    $readbase_2[1] = $2;
    my $mismatch_count_2 = 0;
    my @equal_2;
    for (my $j_2=0; $j_2<2; $j_2++) {
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
	removefirst(1, $spans_2, $seq2_2) =~ /^(.*)\t(.*)/;
	my $spans_new_2 = $1;
        my $seq2_new_2 = $2;
	$seq1_2 =~ s/^.//;
	return trimleft($seq1_2, $seq2_new_2, $spans_new_2);
    }
    if ($equal_2[1] == 0 || $mismatch_count_2 == 2) {
	removefirst(2, $spans_2, $seq2_2) =~ /^(.*)\t(.*)/;
	my $spans_new_2 = $1;
	my $seq2_new_2 = $2;
	$seq1_2 =~ s/^..//;
	return trimleft($seq1_2, $seq2_new_2, $spans_new_2);
    }
}

sub trimright {
    use strict;
    my ($seq1_2, $seq2_2, $spans_2) = @_;
    # seq2_2 is the one that gets modified and returned

    $seq1_2 =~ s/://g;
    $seq1_2 =~ /(.)(.)$/;
    my @genomebase_2 = ($2, $1);

    $seq2_2 =~ s/://g;
    $seq2_2 =~ /(.)(.)$/;
    my @readbase_2 = ($2, $1);

    my $mismatch_count_2 = 0;
    my @equal_2;
    for my $j_2 (0, 1) {
	if ($genomebase_2[$j_2] eq $readbase_2[$j_2]) {
	    $equal_2[$j_2] = 1;
	} else {
	    $equal_2[$j_2] = 0;
	    $mismatch_count_2++;
	}
    }
    if (!$mismatch_count_2) {
	return $spans_2 . "\t" . $seq2_2;
    }
    if ($mismatch_count_2 == 1 && !$equal_2[0]) {
	removelast(1, $spans_2, $seq2_2) =~ /(.*)\t(.*)$/;
	my $spans_new_2 = $1;
	my $seq2_new_2 = $2;
	$seq1_2 =~ s/.$//;
	return trimright($seq1_2, $seq2_new_2, $spans_new_2);
    }
    if (!$equal_2[1] || $mismatch_count_2 == 2) {
	removelast(2, $spans_2, $seq2_2) =~ /(.*)\t(.*)$/;
	my $spans_new_2 = $1;
	my $seq2_new_2 = $2;
	$seq1_2 =~ s/..$//;
	return trimright($seq1_2, $seq2_new_2, $spans_new_2);
    }
}

sub addJunctionsToSeq () {
    use strict;
    my ($seq_in, $spans_in) = @_;
    my @spans = split(/, /,$spans_in);
    my $seq_out = "";
    my $place = 0;

    for my $span (@spans) {

        my ($start, $end) = split /-/, $span;
	my $len = $end - $start + 1;
	if ($seq_out) {
            $seq_out .= ":";
	}
        $seq_out .= substr $seq_in, $place, $len;
        $place += $len;
    }
    return $seq_out;
}

1;
