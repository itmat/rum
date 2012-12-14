package RUM::Script::SortRumById;

use strict;
no warnings;
use autodie;

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

    $|=1;
    open INFILE, '<', $infile;
    my $seqnum_prev = 0;
    my $temp1sortedfile   = $infile . "_sorted_temp1";
    my $temp1unsortedfile = $infile . "_unsorted_temp1";
    my $temp2sortedfile   = $infile . "_sorted_temp2";
    my $temp2unsortedfile = $infile . "_unsorted_temp2";
    my $temp3sortedfile   = $infile . "_sorted_temp3";
    my $temp3unsortedfile = $infile . "_unsorted_temp3";

    open OUTFILE1, '>', $temp1sortedfile;
    open OUTFILE2, '>', $temp1unsortedfile;

    my $still_unsorted_flag = 0;
    while (defined (my $line = <INFILE>)) {
        $line =~ /^seq.(\d+)/;
        my $seqnum = $1;
        if ($seqnum >= $seqnum_prev) {
            print OUTFILE1 $line;
            $seqnum_prev = $seqnum;
        } else {
            print OUTFILE2 $line;
            $still_unsorted_flag = 1;
        }
    }
    close(OUTFILE1);
    close(OUTFILE2);
    close(INFILE);

    my $num_merges = 0;
    $still_unsorted_flag = 1;
    while ($still_unsorted_flag == 1) {
        $still_unsorted_flag = 0;

        $seqnum_prev = 0;

        open INFILE,   '<', $temp1unsortedfile;
        open OUTFILE1, '>', $temp2sortedfile;
        open OUTFILE2, '>', $temp2unsortedfile;

        while (defined (my $line = <INFILE>)) {
            $line =~ /^seq.(\d+)/;
            my $seqnum = $1;
            if ($seqnum >= $seqnum_prev) {
                print OUTFILE1 $line;
                $seqnum_prev = $seqnum;
            } else {
                print OUTFILE2 $line;
                $still_unsorted_flag = 1;
            }
        }
        close(OUTFILE1);
        close(OUTFILE2);
        close(INFILE);
        `mv $temp2unsortedfile $temp1unsortedfile`;
        merge($temp1sortedfile, $temp2sortedfile, $temp3sortedfile);
        $num_merges++;
    }

    `mv $temp1sortedfile $sortedfile`;
    unlink("$temp1unsortedfile");
    $log->debug("Number of merges required to sort '$infile': $num_merges");
    $log->debug("Done sorting '$infile' to $sortedfile");

}

sub merge  {
    my ($temp1sortedfile,
        $temp2sortedfile,
        $temp3sortedfile) = @_;

    open INFILE1, '<', $temp1sortedfile;
    open INFILE2, '<', $temp2sortedfile;
    open OUTFILE, '>', $temp3sortedfile;

    my $flag = 0;
    my $line1 = <INFILE1>;
    chomp($line1);
    $line1 =~ /^seq.(\d+)/;
    my $seqnum1 = $1;
    my $line2 = <INFILE2>;
    chomp($line2);
    $line2 =~ /^seq.(\d+)/;
    my $seqnum2 = $1;
    if ($line2 eq '') {
	$flag = 1;
	unlink("$temp2sortedfile");
	unlink("$temp3sortedfile");
    } else {
	while ($flag == 0) {
	    while ($seqnum1 <= $seqnum2 && $line1 ne '') {
		print OUTFILE "$line1\n";
		$line1 = <INFILE1>;
		chomp($line1);
		$line1 =~ /^seq.(\d+)/;
		$seqnum1 = $1;
		if ($line1 eq '') {
		    if ($line2 =~ /\S/) {
			chomp($line2);
			print OUTFILE "$line2\n";
		    }
		    while ($line2 = <INFILE2>) {
			print OUTFILE $line2;		    
		    }
		}
	    }
	    while ($seqnum2 <= $seqnum1 && $line2 ne '') {
		print OUTFILE "$line2\n";
		$line2 = <INFILE2>;
		chomp($line2);
		$line2 =~ /^seq.(\d+)/;
		$seqnum2 = $1;
		if ($line2 eq '') {
		    if ($line1 =~ /\S/) {
			chomp($line1);
			print OUTFILE "$line1\n";
		    }
		    while ($line1 = <INFILE1>) {
			print OUTFILE $line1;
		    }
		}
	    }
	    if ($line1 eq '' && $line2 eq '') {
		$flag = 1;
	    }
	}
	`mv $temp3sortedfile $temp1sortedfile`;
	unlink("$temp2sortedfile");
    }
}
