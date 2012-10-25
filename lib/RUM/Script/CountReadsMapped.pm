package RUM::Script::CountReadsMapped;


use warnings;
use autodie;

use RUM::Usage;
use RUM::Logging;
use Getopt::Long;
use RUM::CommandLineParser;
use RUM::Property;
use RUM::CommonProperties;
use base 'RUM::Script::Base';

our $log = RUM::Logging->get_logger();

sub description {
    return <<EOF;
File lines should look like this:
seq.6b  chr19   44086924-44086960, 44088066-44088143    CGTCCAATCACACGATCAAGTTCTTCATGAACTTTGG:CTTGCACCTCTGGATGCTTGACAAGGAGCAGAAGCCCGAATCTCAGGGTGGTGCTGGTTGTCTCTGTGACTGCCGTAA
EOF
}

sub log_stray_multi_mapper {
    my ($seqnum, $count, $line) = @_;
    my $msg = join(
        " ", "Looks like there's\na multi-mapper in the RUM_Unique file.",
        "$seqnum ($joined{$seqnum}) $line");
    $log->warn($msg);
}

sub summary {
    'Helps produce mapping_stats.txt'
}

sub line_iterator {

    my @filenames = @_;

    open my $in, shift(@filenames);

    return sub {
        my $line = <$in>;
        return $line if defined $line;
        return undef unless @filenames;
        open $in, "<", shift(@filenames);
        return <$in>;
    };
}

sub command_line_parser {
    my $parser = RUM::CommandLineParser->new;
    $parser->add_prop(
        opt => 'unique-in=s',
        handler => \&RUM::Property::handle_multi,
        required => 1,
        desc => 'File of unique mappers. You can specify this option more than once.');
    $parser->add_prop(
        opt => 'non-unique-in=s',
        handler => \&RUM::Property::handle_multi,
        required => 1,
        desc => 'File of non-unique mappers. You can specify this option more than once.');
    $parser->add_prop(
        opt => 'max-seq=s',
        desc => 'Specify the max sequence id, otherwise will just use the max seq id found in the two files',
        check => \&RUM::CommonProperties::check_int_gte_1);
    $parser->add_prop(
        opt => 'min-seq=s',
        desc => 'Specify the min sequence id, otherwise will just use the min seq id found in the two files',
        check => \&RUM::CommonProperties::check_int_gte_1);
    return $parser;
}

sub run {
    my ($self) = @_;

    use RUM::Common qw(format_large_int);
    
    my $props = $self->properties;
    my $unique_it = line_iterator(@{ $props->get('unique_in') });
    my $nu_it = line_iterator(@{ $props->get('non_unique_in') });
    my $max_seq_num = $props->get('max_seq');
    my $min_seq_num = $props->get('min_seq');

    $flag = 0;
    $num_areads = 0;
    $num_breads = 0;
    $current_seqnum = 0;
    $previous_seqnum = 0;

    while (defined(my $line = $unique_it->())) {

        chomp($line);
        $line =~ /seq.(\d+)([^\d])/;
        $seqnum = $1;
        $type = $2;
        $current_seqnum = $seqnum;
        if ($current_seqnum > $previous_seqnum) {
            foreach $key (keys %typea) {
                if (!$typeb{$key}) {
                    $num_a_only++;
                }
            }
            foreach $key (keys %typeb) {
                if (!$typea{$key}) {
                    $num_b_only++;
                }
            }
            undef %typea;
            undef %typeb;
            undef %joined;
            undef %unjoined;
            $previous_seqnum = $current_seqnum;
        }
        if ($flag == 0 && !$props->has('min_seq')) {
            $flag = 1;
            $min_seq_num = $seqnum;
        }
        if ($seqnum > $max_seq_num && !$props->has('max_seq')) {
            $max_seq_num = $seqnum;
        }
        if ($seqnum < $min_seq_num && !$props->has('min_seq')) {
            $min_seq_num = $seqnum;
        }

        if ($type eq "\t") {
            $joined{$seqnum}++;
            $numjoined++;
            if ($joined{$seqnum} > 1) {
                log_stray_multi_mapper($seqnum, $joined{$seqnum}, $line);
            }
        }
        if ($type eq "a" || $type eq "b") {
            $unjoined{$seqnum}++;
            if ($unjoined{$seqnum} > 1) {
                $num_unjoined_consistent++;
            }
            if ($unjoined{$seqnum} > 2) {
                log_stray_multi_mapper($seqnum, $joined{$seqnum}, $line);
            }
        }
        if ($type eq "a") {
            $typea{$seqnum}++;
            $num_areads++;
            if ($typea{$seqnum} > 1) {
                log_stray_multi_mapper($seqnum, $joined{$seqnum}, $line);
            }
        }
        if ($type eq "b") {
            $typeb{$seqnum}++;
            $num_breads++;
            if ($typeb{$seqnum} > 1) {
                log_stray_multi_mapper($seqnum, $joined{$seqnum}, $line);
            }
        }
    }

    my $is_paired = keys %typeb;

    foreach $key (keys %typea) {
        $num_a_only++ unless $typeb{$key};
    }
    foreach $key (keys %typeb) {
        $num_b_only++ unless $typea{$key};
    }

    undef %typea;
    undef %typeb;
    undef %joined;
    undef %unjoined;

    $f = format_large_int($seqnum);
    $total= $max_seq_num - $min_seq_num + 1;
    $f = format_large_int($total);
    if ($num_breads > 0) {
        print "Number of read pairs: $f\n";
    } else {
        print "Number of reads: $f\n";
    }
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
    $num_a_total = $num_a_only + $num_bothmapped;
    $num_b_total = $num_b_only + $num_bothmapped;
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
    $at_least_one_of_forward_or_reverse_mapped = $num_bothmapped + $num_a_only + $num_b_only;
    $f = format_large_int($at_least_one_of_forward_or_reverse_mapped);
    $percent_at_least_one_of_forward_or_reverse_mapped = int($at_least_one_of_forward_or_reverse_mapped/ $total * 10000) / 100;
    if ($num_breads > 0) {
        print "At least one of forward or reverse mapped: $f ($percent_at_least_one_of_forward_or_reverse_mapped%)\n";
        print "\n";
    }

    $current_seqnum = 0;
    $previous_seqnum = 0;
    $num_ambig_consistent=0;
    $num_ambig_a_only=0;
    $num_ambig_b_only=0;
    $num_ambig_a = 0;

    #print "------\n";
    while (defined($line = $nu_it->())) {
        chomp($line);
        $line =~ /seq.(\d+)(.)/;
        $seqnum = $1;
        $type = $2;
        $current_seqnum = $seqnum;
        if ($current_seqnum > $previous_seqnum) {
            foreach $seqnum (keys %allids) {
                if ( $ambiga{$seqnum} && $ambigb{$seqnum} ) {
                    $num_ambig_consistent++;	
                }
                elsif ( $ambiga{$seqnum} && ! $ambigb{$seqnum} ) {
                    $num_ambig_a++;
                }
                elsif (! $ambiga{$seqnum} && $ambigb{$seqnum} ) {
                    $num_ambig_b++;
                }
            }
            undef %allids;
            undef %ambiga;
            undef %ambigb;
            $previous_seqnum = $current_seqnum;
        }
        if ($type eq "a") {
            $ambiga{$seqnum}++;
        }
        if ($type eq "b") {
            $ambigb{$seqnum}++;
        }
        if ($type eq "\t") {
            $ambiga{$seqnum}++;
            $ambigb{$seqnum}++;
        }
        $allids{$seqnum}++;
    }

    foreach $seqnum (keys %allids) {
        if ($ambiga{$seqnum} && $ambigb{$seqnum}) {
            $num_ambig_consistent++;	
        }
        if ($ambiga{$seqnum} && !$ambigb{$seqnum}) {
            $num_ambig_a++;
        }
        if (!$ambiga{$seqnum} && $ambigb{$seqnum}) {
            $num_ambig_b++;
        }
    }
    undef %allids;
    undef %ambiga;
    undef %ambigb;

    $f = format_large_int($num_ambig_a);
    $p = int($num_ambig_a/$total * 1000) / 10;
    if ($num_breads > 0) {
        print "\nNON-UNIQUE MAPPERS\n------------------\n";
        print "Total number forward only ambiguous: $f ($p%)\n";
    } else {
        print "NON-UNIQUE MAPPERS: $f ($p%)\n";
    }
    $f = format_large_int($num_ambig_b);
    $num_ambig_b ||= 0;

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

    $num_forward_total = $num_a_total + $num_ambig_a + $num_ambig_consistent;
    $num_reverse_total = $num_b_total + $num_ambig_b + $num_ambig_consistent;
    $num_consistent_total = $num_bothmapped + $num_ambig_consistent;
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
    $total_fragment = $at_least_one_of_forward_or_reverse_mapped + $num_ambig_a + $num_ambig_b + $num_ambig_consistent;
    $f = format_large_int($total_fragment);
    $p = int($total_fragment/$total * 1000) / 10;
    if ($num_breads > 0) {
        print "At least one of forward or reverse mapped: $f ($p%)\n";
    }



}

1;
