package RUM::Script::SortRumById;

no warnings;
use autodie;

use base 'RUM::Script::Base';

our $log = RUM::Logging->get_logger();

sub summary {
    'Sort a RUM file by sequence number'
}

sub description {
    'This script sorts a RUM output file by sequence number.  It keeps consistent pairs together.'
}

sub accepted_options {
    return (
        RUM::Property->new(
            opt => 'output|o=s',
            desc => 'Output file',
            required => 1),
        RUM::Property->new(
            opt => 'input',
            desc => 'Input file',
            required => 1,
            positional => 1)
    );
}

sub run {
    my ($self) = @_;
    my $props = $self->properties;
    my $sortedfile = $props->get('output');
    my $infile     = $props->get('input');

    $log->info("Sorting '$infile'");

    $|=1;
    open(INFILE, $infile);
    $seqnum_prev = 0;
    $temp1sortedfile = $infile . "_sorted_temp1";
    $temp1unsortedfile = $infile . "_unsorted_temp1";
    $temp2sortedfile = $infile . "_sorted_temp2";
    $temp2unsortedfile = $infile . "_unsorted_temp2";
    $temp3sortedfile = $infile . "_sorted_temp3";
    $temp3unsortedfile = $infile . "_unsorted_temp3";

    open(OUTFILE1, ">$temp1sortedfile");
    open(OUTFILE2, ">$temp1unsortedfile");
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
        open(INFILE, "$temp1unsortedfile");
        $seqnum_prev = 0;
        open(OUTFILE1, ">$temp2sortedfile");
        open(OUTFILE2, ">$temp2unsortedfile");
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
    open(INFILE1, "$temp1sortedfile");
    open(INFILE2, "$temp2sortedfile");
    open(OUTFILE, ">$temp3sortedfile");
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
