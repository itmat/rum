package RUM::Script::CountReadsMapped;

use strict;
no warnings;
use autodie;

use RUM::Usage;
use RUM::Logging;
use RUM::RUMIO;
use Getopt::Long;

our $log = RUM::Logging->get_logger();

sub log_stray_multi_mapper {
    my ($seqnum, $count, $line) = @_;
    my $msg = join(
        " ", "Looks like there's\na multi-mapper in the RUM_Unique file.",
        "$seqnum $count $line");
    $log->warn($msg);
}

sub line_iterator {
    my @filenames = @_;
    my @iters = map { RUM::RUMIO->new(-file => $_) } @filenames;
    return RUM::Iterator->append(@iters);
}

sub main {

    use RUM::Common qw(format_large_int);
    my (@unique_in, @non_unique_in);
    GetOptions(
        "unique-in=s"     => \@unique_in,
        "non-unique-in=s" => \@non_unique_in,
        "min-seq=s"       => \(my $min_seq_num),
        "max-seq=s"       => \(my $max_seq_num = 0),
        "help|h"    => sub { RUM::Usage->help },
        "verbose|v" => sub { $log->more_logging(1) },
        "quiet|q"   => sub { $log->less_logging(1) });

    my $max_num_seqs_specified;
    my $min_num_seqs_specified;

    @unique_in or RUM::Usage->bad(
        "Please specify a file of unique mappers with --unique-in. " .
        "You can specify this option multiple times.");
    @non_unique_in or RUM::Usage->bad(
        "Please specify a file of non-unique mappers " .
        "with --non-unique-in. You can specify this option multiple times.");

    my $unique_it = line_iterator(@unique_in);
    my $nu_it = line_iterator(@non_unique_in);

    if (defined($max_seq_num)) {
        $max_num_seqs_specified = "true";
        $max_seq_num =~ /^\d+$/ or RUM::Usage->bad(
            "--max-seq must be a number, not $max_seq_num");
    }
    if (defined($min_seq_num)) {
        $min_num_seqs_specified = "true";
        $min_seq_num =~ /^\d+$/ or RUM::Usage->bad(
            "--min-seq must be a number, not $min_seq_num");
    }

    my $num_areads = 0;
    my $num_breads = 0;
    my $current_seqnum = 0;
    my $previous_seqnum = 0;
    my $seqnum;
    my (%typea, %typeb);
    my ($num_a_only, $num_b_only);
    my (%joined, %unjoined);
    my $num_unjoined_consistent;
    my $numjoined;

    while (defined(my $aln = $unique_it->())) {
        my $line = $aln->raw;

        $seqnum = $aln->order;
        $current_seqnum = $seqnum;
        if ($current_seqnum > $previous_seqnum) {
            foreach my $key (keys %typea) {
                $num_a_only++ unless $typeb{$key};
            }
            foreach my $key (keys %typeb) {
                $num_b_only++ unless $typea{$key};
            }
            undef %typea;
            undef %typeb;
            undef %joined;
            undef %unjoined;
            $previous_seqnum = $current_seqnum;
        }

        $min_seq_num = $seqnum unless defined($min_seq_num);

        if ($seqnum > $max_seq_num && !$max_num_seqs_specified) {
            $max_seq_num = $seqnum;
        }
        if ($seqnum < $min_seq_num && !$min_num_seqs_specified) {
            $min_seq_num = $seqnum;
        }

        if (! ($aln->is_forward || $aln->is_reverse)) {
            $joined{$seqnum}++;
            $numjoined++;
            if ($joined{$seqnum} > 1) {
                log_stray_multi_mapper($seqnum, $joined{$seqnum}, $line);
            }
        }
        else {
            $unjoined{$seqnum}++;
            if ($unjoined{$seqnum} > 1) {
                $num_unjoined_consistent++;
            }
            if ($unjoined{$seqnum} > 2) {
                log_stray_multi_mapper($seqnum, $joined{$seqnum}, $line);
            }
        }
        if ($aln->is_forward) {
            $typea{$seqnum}++;
            $num_areads++;
            if ($typea{$seqnum} > 1) {
                log_stray_multi_mapper($seqnum, $joined{$seqnum}, $line);
                }
        }
        if ($aln->is_reverse) {
            $typeb{$seqnum}++;
            $num_breads++;
            if ($typeb{$seqnum} > 1) {
                log_stray_multi_mapper($seqnum, $joined{$seqnum}, $line);
            }
        }
    }

    my $is_paired = keys %typeb;

    foreach my $key (keys %typea) {
        $num_a_only++ unless $typeb{$key};
    }
    foreach my $key (keys %typeb) {
        $num_b_only++ unless $typea{$key};
    }

    undef %typea;
    undef %typeb;
    undef %joined;
    undef %unjoined;

    my $f = format_large_int($seqnum);
    my $total= $max_seq_num - $min_seq_num + 1;
    $f = format_large_int($total);
    if ($num_breads > 0) {
        print "Number of read pairs: $f\n";
    } else {
        print "Number of reads: $f\n";
    }
    my $percent_a_mapped;
    my $percent_b_mapped;
    my $num_bothmapped;
    my $percent_bothmapped;
    if ($num_breads > 0) {
        print "\nUNIQUE MAPPERS\n--------------\n";
        $num_bothmapped = $numjoined + $num_unjoined_consistent;
        $f = format_large_int($num_bothmapped);
        $percent_bothmapped = int($num_bothmapped/ $total * 10000) / 100;
        print "Both forward and reverse mapped consistently: $f ($percent_bothmapped%)\n";
        $f = format_large_int($numjoined);
        print "   - do overlap: $f\n";
        $f = format_large_int($num_unjoined_consistent);
        print "   - don't overlap: $f\n";
        $f = format_large_int($num_a_only);
        print "Number of forward mapped only: $f\n";
    }
    $f = format_large_int($num_b_only);
    if ($num_breads > 0) {
        print "Number of reverse mapped only: $f\n";
    }
    my $num_a_total = $num_a_only + $num_bothmapped;
    my $num_b_total = $num_b_only + $num_bothmapped;
    $f = format_large_int($num_a_total);
    $percent_a_mapped = int($num_a_total / $total * 10000) / 100;
    if ($num_breads > 0) {
        print "Number of forward total: $f ($percent_a_mapped%)\n";
    } else {
        print "------\nUNIQUE MAPPERS: $f ($percent_a_mapped%)\n";
    }
    $f = format_large_int($num_b_total);
    $percent_b_mapped = int($num_b_total / $total * 10000) / 100;
    if ($num_breads > 0) {
        print "Number of reverse total: $f ($percent_b_mapped%)\n";
    }
    my $at_least_one_of_forward_or_reverse_mapped = $num_bothmapped + $num_a_only + $num_b_only;
    $f = format_large_int($at_least_one_of_forward_or_reverse_mapped);
    my $percent_at_least_one_of_forward_or_reverse_mapped = int($at_least_one_of_forward_or_reverse_mapped/ $total * 10000) / 100;
    if ($num_breads > 0) {
        print "At least one of forward or reverse mapped: $f ($percent_at_least_one_of_forward_or_reverse_mapped%)\n";
        print "\n";
    }

    $current_seqnum = 0;
    $previous_seqnum = 0;
    my $num_ambig_consistent=0;
    my $num_ambig_a_only=0;
    my $num_ambig_b_only=0;
    my ($num_ambig_a, $num_ambig_b);
    #print "------\n";
    my (%ambiga, %ambigb, %allids);
    my $seqnum;
    while (defined(my $aln = $nu_it->())) {
        $seqnum = $aln->order;
        $current_seqnum = $seqnum;
        if ($current_seqnum > $previous_seqnum) {

            foreach $seqnum (keys %allids) {
                if ( $ambiga{$seqnum} && $ambigb{$seqnum} ) {
                    $num_ambig_consistent++;	
                }
                elsif ( $ambiga{$seqnum} ) {
                    $num_ambig_a++;
                }
                elsif ( $ambigb{$seqnum} ) {
                    $num_ambig_b++;
                }
            }
            undef %allids;
            undef %ambiga;
            undef %ambigb;
            $previous_seqnum = $current_seqnum;
        }

        $ambiga{$seqnum}++ if $aln->contains_forward;
        $ambigb{$seqnum}++ if $aln->contains_reverse;;
        $allids{$seqnum}++;
    }

    foreach $seqnum (keys %allids) {
        if ($ambiga{$seqnum} && $ambigb{$seqnum}) {
            $num_ambig_consistent++;	
        }
        elsif ($ambiga{$seqnum}) {
            $num_ambig_a++;
        }
        elsif ($ambigb{$seqnum}) {
            $num_ambig_b++;
        }
    }
    undef %allids;
    undef %ambiga;
    undef %ambigb;
    my ($f, $p);

    $f = format_large_int($num_ambig_a);
    $p = int($num_ambig_a/$total * 1000) / 10;
    if ($num_breads > 0) {
        print "\nNON-UNIQUE MAPPERS\n------------------\n";
        print "Total number forward only ambiguous: $f ($p%)\n";
    } else {
        print "NON-UNIQUE MAPPERS: $f ($p%)\n";
    }
    $f = format_large_int($num_ambig_b);
    $p = int($num_ambig_b/$total * 1000) / 10;
    if ($num_breads > 0) {
        print "Total number reverse only ambiguous: $f ($p%)\n";
    }
    $f = format_large_int($num_ambig_consistent);
    $p = int($num_ambig_consistent/$total * 1000) / 10;
    if ($num_breads > 0) {
        print "Total number consistent ambiguous: $f ($p%)\n";
        print "\n";
        print "\nTOTAL\n-----\n";
    }

    my $num_forward_total = $num_a_total + $num_ambig_a + $num_ambig_consistent;
    my $num_reverse_total = $num_b_total + $num_ambig_b + $num_ambig_consistent;
    my $num_consistent_total = $num_bothmapped + $num_ambig_consistent;
    $f = format_large_int($num_forward_total);
    $p = int($num_forward_total/$total * 1000) / 10;
    if ($num_breads > 0) {
        print "Total number forward: $f ($p%)\n";
    } else {
        print "-----\nTOTAL: $f ($p%)\n-----\n";
    }
    $f = format_large_int($num_reverse_total);
    $p = int($num_reverse_total/$total * 1000) / 10;
    if ($num_breads > 0) {
        print "Total number reverse: $f ($p%)\n";
    }
    $f = format_large_int($num_consistent_total);
    $p = int($num_consistent_total/$total * 1000) / 10;
    if ($num_breads > 0) {
        print "Total number consistent: $f ($p%)\n";
    }
    my $total_fragment = $at_least_one_of_forward_or_reverse_mapped + $num_ambig_a + $num_ambig_b + $num_ambig_consistent;
    $f = format_large_int($total_fragment);
    $p = int($total_fragment/$total * 1000) / 10;
    if ($num_breads > 0) {
        print "At least one of forward or reverse mapped: $f ($p%)\n";
    }

}

1;
