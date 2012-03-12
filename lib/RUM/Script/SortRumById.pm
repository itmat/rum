package RUM::Script::SortRumById;

no warnings;

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
    open(INFILE, $infile) 
        or die "Can't open $infile for reading: $!";
    $seqnum_prev = 0;
    $temp1sortedfile = $infile . "_sorted_temp1";
    $temp1unsortedfile = $infile . "_unsorted_temp1";
    $temp2sortedfile = $infile . "_sorted_temp2";
    $temp2unsortedfile = $infile . "_unsorted_temp2";
    $temp3sortedfile = $infile . "_sorted_temp3";
    $temp3unsortedfile = $infile . "_unsorted_temp3";

    open(OUTFILE1, ">$temp1sortedfile") 
        or die "Can't open $temp1sortedfile for writing: $!";
    open(OUTFILE2, ">$temp1unsortedfile") 
        or die "Can't open $temp1unsortedfile for writing: $!";
    $still_unsorted_flag = 0;
    while ($line = <INFILE>) {
        $line =~ /^seq.(\d+)/;
        $seqnum = $1;
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


    $num_merges = 0;
    $still_unsorted_flag = 1;
    while ($still_unsorted_flag == 1) {
        $still_unsorted_flag = 0;
        open(INFILE, "$temp1unsortedfile") 
            or die "Can't open $temp1unsortedfile for reading: $!";
        $seqnum_prev = 0;
        open(OUTFILE1, ">$temp2sortedfile") 
            or die "Can't open $temp2sortedfile for writing: $!";
        open(OUTFILE2, ">$temp2unsortedfile") 
            or die "Can't open $temp2unsortedfile for writing: $!";
        while ($line = <INFILE>) {
            $line =~ /^seq.(\d+)/;
            $seqnum = $1;
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
        merge();
        $num_merges++;
    }

    `mv $temp1sortedfile $sortedfile`;
    unlink("$temp1unsortedfile");
    $log->debug("Number of merges required to sort '$infile': $num_merges");
    $log->debug("Done sorting '$infile' to $sortedfile");

}

sub merge () {
    open(INFILE1, "$temp1sortedfile") 
        or die "Can't open $temp1sortedfile for reading: $!";
    open(INFILE2, "$temp2sortedfile") 
        or die "Can't open $temp2sortedfile for reading: $!";
    open(OUTFILE, ">$temp3sortedfile") 
        or die "Can't open $temp3sortedfile for writing: $!";
    $flag = 0;
    $line1 = <INFILE1>;
    chomp($line1);
    $line1 =~ /^seq.(\d+)/;
    $seqnum1 = $1;
    $line2 = <INFILE2>;
    chomp($line2);
    $line2 =~ /^seq.(\d+)/;
    $seqnum2 = $1;
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
