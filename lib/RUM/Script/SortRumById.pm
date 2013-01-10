package RUM::Script::SortRumById;

use strict;
no warnings;
use autodie;

use File::Copy qw(mv);
use RUM::Usage;
use RUM::Logging;
use Getopt::Long;

our $log = RUM::Logging->get_logger();

$|=1;

sub main {

    GetOptions(
        "output|o=s" => \(my $sortedfile),
        "help|h"    => sub { RUM::Usage->help },
        "verbose|v" => sub { $log->more_logging(1) },
        "quiet|q"   => sub { $log->less_logging(1) });

    my $infile = $ARGV[0];

    $infile or RUM::Usage->bad(
        "Please provide an input file to sort");
    $sortedfile or RUM::Usage->bad(
        "Please specify an output file with -o or --output");

    $log->info("Sorting '$infile'");

    my $in_size = `wc -c $infile`;

    my $seqnum_prev = 0;
    my $temp1sortedfile   = $infile . "_sorted_temp1";
    my $temp1unsortedfile = $infile . "_unsorted_temp1";
    my $temp2sortedfile   = $infile . "_sorted_temp2";
    my $temp2unsortedfile = $infile . "_unsorted_temp2";
    my $temp3sortedfile   = $infile . "_sorted_temp3";
    my $temp3unsortedfile = $infile . "_unsorted_temp3";

    my $still_unsorted_flag = 0;

    {
        open my $in, '<', $infile;
        open my $outfile1, '>', $temp1sortedfile;
        open my $outfile2, '>', $temp1unsortedfile;

        while (defined (my $line = <$in>)) {
            $line =~ /^seq.(\d+)/ or die "Bad line $_";
            my $seqnum = $1;
            if ($seqnum >= $seqnum_prev) {
                print $outfile1 $line;
                $seqnum_prev = $seqnum;
            } else {
                print $outfile2 $line;
                $still_unsorted_flag = 1;
            }
        }
    }

    my $num_merges = 0;
    $still_unsorted_flag = 1;
    while ($still_unsorted_flag) {
        $still_unsorted_flag = 0;
        $seqnum_prev = 0;

        {
            open my $in,   '<', $temp1unsortedfile;
            open my $out1, '>', $temp2sortedfile;
            open my $out2, '>', $temp2unsortedfile;

            while (defined (my $line = <$in>)) {
                $line =~ /^seq.(\d+)/;
                my $seqnum = $1;
                if ($seqnum >= $seqnum_prev) {
                    print $out1 $line;
                    $seqnum_prev = $seqnum;
                } else {
                    print $out2 $line;
                    $still_unsorted_flag = 1;
                }
            }
        }

        mv $temp2unsortedfile, $temp1unsortedfile or die "mv failed: $!";
        merge($temp1sortedfile, $temp2sortedfile, $temp3sortedfile);
        $num_merges++;
    }

    mv $temp1sortedfile, $sortedfile or die "mv failed: $!";
    unlink("$temp1unsortedfile");
    $log->info("Number of merges required to sort '$infile': $num_merges");

    my $out_size = `wc -c $sortedfile`;

    if ($out_size != $in_size) {
        die "Sorted file has different size ($out_size) than input file ($in_size). They should be the same.";
    }
    $log->info("Done sorting '$infile' to $sortedfile");

}

sub merge  {
    my ($temp1sortedfile,
        $temp2sortedfile,
        $temp3sortedfile) = @_;

    open my $in1, '<', $temp1sortedfile;
    open my $in2, '<', $temp2sortedfile;

    my $flag = 0;

    my $line1 = <$in1>;
    my $seqnum1;
    if (defined $line1) {
        chomp($line1);
        $line1 =~ /^seq.(\d+)/ or die "Bad line '$_'. I expected the line to start with 'seq.(\\d+)'";
        $seqnum1 = $1;
    }
    
    my $line2 = <$in2>;
    my $seqnum2;
    if (defined $line2) {
        chomp($line2);
        $line2 =~ /^seq.(\d+)/ or die "Bad line '$_'. I expected the line to start with 'seq.(\\d+)'";
        $seqnum2 = $1;
    }

    if ( ! $line2 ) {
	$flag = 1;
	unlink("$temp2sortedfile") if -e $temp2sortedfile;
	unlink("$temp3sortedfile") if -e $temp3sortedfile;
    }
    else {
        open my $out, '>', $temp3sortedfile;

	while ($flag == 0) {

	    while ($seqnum1 <= $seqnum2 && $line1 ne '') {
		print $out "$line1\n";
		$line1 = <$in1>;
		chomp($line1);
		$line1 =~ /^seq.(\d+)/;
		$seqnum1 = $1;
		if ( ! $line1 ) {
		    if ($line2) {
			chomp($line2);
			print $out "$line2\n";
		    }
		    while ($line2 = <$in2>) {
			print $out $line2;
		    }
		}
	    }
	    while ($seqnum2 <= $seqnum1 && $line2 ne '') {
		print $out "$line2\n";
		$line2 = <$in2>;
		chomp($line2);
		$line2 =~ /^seq.(\d+)/;
		$seqnum2 = $1;
		if ( ! $line2 ) {
		    if ($line1) {
			chomp($line1);
			print $out "$line1\n";
		    }
		    while ($line1 = <$in1>) {
			print $out $line1;
		    }
		}
	    }
	    if ( ! ($line1 || $line2) ) {
		$flag = 1;
	    }
	}
        close $out;
	mv $temp3sortedfile, $temp1sortedfile or die "mv failed: $!";
	unlink("$temp2sortedfile");
    }
}
