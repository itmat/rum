package RUM::Script::FinalCleanup;

use strict;
no warnings;

use Getopt::Long;
use File::Temp qw(tempfile);

use RUM::Usage;
use RUM::Logging;
use RUM::Common qw(roman Roman isroman arabic);
use RUM::RUMIO;
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
        my $flag = 0;
        while (my $line = <INFILE>) {
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

    my $FLAG = 0;

    $log->info("Cleaning mappers");
    while ($FLAG == 0) {
        undef %CHR2SEQ;
        my $sizeflag = 0;
        my $totalsize = 0;
        while ($sizeflag == 0) {
            my $line = <GENOMESEQ>;
            if ($line eq '') {
                $FLAG = 1;
                $sizeflag = 1;
            } else {
                chomp($line);
                $line =~ />(.*)/;
                my $chr = $1;
                $log->debug("Working on chromosome $chr");
                $chr =~ s/:[^:]*$//;
                my $ref_seq = <GENOMESEQ>;
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
    for my $chr (sort {cmpChrs($a,$b)} keys %samheader) {
        print SAMHEADER $samheader{$chr};
    }
    close(SAMHEADER);

}

sub clean {
    my ($infilename, $outfilename) = @_;
    my $iter = RUM::RUMIO->new(-file => $infilename,
                               strand_last => 1);

    open my $outfile, ">>", $outfilename;
    
    my $out = RUM::RUMIO->new(-fh => $outfile);

    while (my $aln = $iter->next_val) {
        my $line = $aln->raw;
	my $flag = 0;
	my $chr = $aln->chromosome;
        my $seq_in = $aln->seq;
	$seq_in =~ s/://g;

	my $seq_temp = $seq_in;
	$seq_temp =~ s/\+//g;

	if (length($seq_temp) < $match_length_cutoff) {
	    next;
	}
        my $span_str = RUM::RUMIO->format_locs($aln);

        local $_;
	for my $span (@{ $aln->locs }) {
	    my ($start, $end) = @{ $span };
	    if ($end < $start) {
		$flag = 1;
	    }
	}
        if (defined $CHR2SEQ{$chr} && !(defined $samheader{$chr})) {
	    my $CS = $chrsize{$chr};
	    $samheader{$chr} = "\@SQ\tSN:$chr\tLN:$CS\n";
	}
	if (defined $CHR2SEQ{$chr} && $flag == 0) {
            # insertions will break things, have to fix this, for now
            # not just cleaning these lines
	    if ($seq_in =~ /\+/) {
		$out->write_aln($aln);
	    } else {
		my $SEQ = "";
		for my $span (@{ $aln->locs }) {
 		    my ($start, $end) = @{ $span };
		    my $len = $end - $start + 1;
                    $start--;
		    $SEQ .= substr($CHR2SEQ{$chr}, $start, $len);
		}
                my ($spans, $seq) = trimleft($SEQ, $aln->seq, $span_str);

                $SEQ = substr $SEQ, length($SEQ) - length($seq);
		$seq =~ s/://g;
		my ($spans, $seq) = trimright($SEQ, $seq, $spans);
		$seq = addJunctionsToSeq($seq, $spans);

		# should fix the following so it doesn't repeat the operation unnecessarily
		# while processing the RUM_NU file
		$seq_temp = $seq;
		$seq_temp =~ s/[:+]//g;
		if (length($seq_temp) >= $match_length_cutoff) {

                    my $new_aln = $aln->copy(
                        locs => [ map { [ split /-/ ] } split(/, /, $spans) ],
                        seq => $seq
                    );

                    $out->write_aln($new_aln);
		}
	    }
	}
    }

}

sub removefirst {
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
	return ($spans_1, $seq_1);
    }
}

sub removelast {
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
	return ($spans, $seq);
    }
}

sub trimleft {
    my ($genome, $read, $spans) = @_;
    # seq2_2 is the one that gets modified and returned

    $genome =~ s/://g;
    $genome =~ /^(.)(.)/;
    my @genomebase = ($1, $2);

    $read =~ s/://g;
    $read =~ /^(.)(.)/;
    my @readbase = ($1, $2);

    my $trim_len = ($genomebase[1] ne $readbase[1] ? 2 :
                    $genomebase[0] ne $readbase[0] ? 1 :
                    0);

    if ($trim_len) {
	my ($spans_new_2, $seq2_new_2) = removefirst($trim_len, $spans, $read);
	return trimleft(substr($genome, $trim_len), $seq2_new_2, $spans_new_2);
    }
    else {
        return ($spans, $read);
    }
}

sub trimright {
    my ($genome, $read, $spans) = @_;
    # seq2_2 is the one that gets modified and returned

    $genome =~ s/://g;
    $genome =~ /(.)(.)$/;
    my @genomebase = ($2, $1);

    $read =~ s/://g;
    $read =~ /(.)(.)$/;
    my @readbase = ($2, $1);

    my $trim_len = ($genomebase[1] ne $readbase[1] ? 2 :
                    $genomebase[0] ne $readbase[0] ? 1 :
                    0);

    if ($trim_len) {
	my ($spans_new_2, $seq2_new_2) = removelast($trim_len, $spans, $read);
        my $new_len = length($genome) - $trim_len;
	return trimright(substr($genome, 0, $new_len), $seq2_new_2, $spans_new_2);
    }
    else {
        return ($spans, $read);
    }
}

sub addJunctionsToSeq () {
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
