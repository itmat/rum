package RUM::Script::SortRumByLocation;

no warnings;
use autodie;

use FindBin qw($Bin);

use Carp;
use Getopt::Long;
use RUM::Sort qw(by_chromosome);
use RUM::Usage;
use RUM::RUMIO;
use File::Copy qw(mv cp);

our $log = RUM::Logging->get_logger();
$|=1;

sub main {
    GetOptions(
        "output|o=s" => \(my $outfile),
        "separate" => \(my $separate = 0),
        "ram=s"    => \(my $ram = 6),
        "max-chunk-size=s" => \(my $maxchunksize),
        "allow-small-chunks" => \(my $allowsmallchunks = 0),
        "help|h"    => sub { RUM::Usage->help },
        "verbose|v" => sub { $log->more_logging(1) },
        "quiet|q"   => sub { $log->less_logging(1) });
        
    my $infile = $ARGV[0] or RUM::Usage->bad(
        "Please specify an input file");

    $outfile or RUM::Usage->bad(
        "Please specify an output file with -o or --output");

    my $running_indicator_file = $outfile;
    $running_indicator_file =~ s![^/]+$!!;
    $running_indicator_file = $running_indicator_file . ".running";

    open(OUTFILE, ">$running_indicator_file") 
        or die "Can't open $running_indicator_file for writing: $!";
    print OUTFILE "0";
    close(OUTFILE);
    
    my $maxchunksize_specified;

    if (defined($ram)) {
        int($ram) > 0 or RUM::Usage->bad(
            "--ram must be a positive integer; you gave $ram");
    }
        
    if (defined($maxchunksize)) {
        $maxchunksize_specified = 1;
        int($maxchunksize) > 0 or RUM::Usage->bad(
            "--max-chunk-size must be a positive integer; you gave $maxchunksize");
    }
    else {
        $maxchunksize = 9000000
    }

    # We have a test that exercises the ability to merge chunks together,
    # so allow max chunk sizes smaller than 500000 if that flag is set.
    $maxchunksize >= 500000 || $allowsmallchunks or
        RUM::Usage->bad("--max-chunks-ize must be at least 500,000.");
    
    my $max_count_at_once;
    if ($maxchunksize_specified) {
        $max_count_at_once = $maxchunksize;
    }
    else {
        if ($ram >= 7) {
            $max_count_at_once = 10000000;
        } elsif ($ram >=6) {
            $max_count_at_once = 8500000;
        } elsif ($ram >=5) {
            $max_count_at_once = 7500000;
        } elsif ($ram >=4) {
            $max_count_at_once = 6000000;
        } elsif ($ram >=3) {
            $max_count_at_once = 4500000;
        } elsif ($ram >=2) {
            $max_count_at_once = 3000000;
        } else {
            $max_count_at_once = 1500000;
        }
    }
    my %options = (max_count_at_once => $max_count_at_once,
                   separate => $separate,
                   outfile => $outfile,
                   infile  => $infile);
    my $chr_counts = doEverything(%options);

    my $size_input = -s $infile;
    my $size_output = -s $outfile;

    my $clean = "false";
    for (my $i=0; $i<2; $i++) {
        if ($size_input != $size_output) {
            $log->warn("Sorting \"$infile\":  failed, trying again.");
            &doEverything(%options);
            system "rm -f $running_indicator_file";
            $size_output = -s $outfile;
        } else {
            $i = 2;
            $clean = "true";
            print "\n$infile reads per chromosome:\n\nchr_name\tnum_reads\n";
            foreach my $chr (sort by_chromosome keys %$chr_counts) {
                print "$chr\t$chr_counts->{$chr}\n";
            }
        }
    }

    if ($clean eq "false") {
        $log->error("While trying to sort \"$infile\": the size of the " .
                    "unsorted input ($size_input) and sorted output files " .
                    "($size_output) are not equal.  I tried three times and " .
                    "it failed every time.  Must be something strange about " .
                    "the input file");
    }

}

sub get_chromosome_counts {
    use strict;
    my ($filename) = @_;

    my $in = RUM::RUMIO->new(-file => $filename)->aln_iterator->group_by(sub {$_[0]->is_mate($_[1])});

    my %counts;

    while (my $alns = $in->next_val) {
        my $chr = $alns->next_val->chromosome;
        $counts{$chr}++;
    }
    return %counts;
}

sub are_mates {
    $_[0]->is_mate($_[1]);
}

sub doEverything  {

    use strict;

    my %options = @_;
    my $max_count_at_once = $options{max_count_at_once};
    my $separate = $options{separate};
    my $outfile  = $options{outfile};
    my $infile  = $options{infile};

    open(FINALOUT, ">", $outfile)
        or die "Can't open $outfile for writing: $!";
    my %chr_counts = get_chromosome_counts($infile);


    my (@CHR, %CHUNK);

    my $cnt=0;
    foreach my $chr (sort by_chromosome keys %chr_counts) {
	$CHR[$cnt] = $chr;
	$cnt++;
    }
    my $chunk = 0;
    $cnt=0;
    while ($cnt < @CHR) {
	my $running_count = $chr_counts{$CHR[$cnt]};
	$CHUNK{$CHR[$cnt]} = $chunk;
	if ($chr_counts{$CHR[$cnt]} > $max_count_at_once) { 
            # it's bigger than $max_count_at_once all by itself..
	    $CHUNK{$CHR[$cnt]} = $chunk;
	    $cnt++;
	    $chunk++;
	    next;
	}
	$cnt++;
	while ($cnt < @CHR &&
                   $running_count+$chr_counts{$CHR[$cnt]} < $max_count_at_once) {
            my $chr = $CHR[$cnt];
	    $running_count = $running_count + $chr_counts{$chr};
	    $CHUNK{$chr} = $chunk;
	    $cnt++;
	}
	$chunk++;
    }
    
    # DEBUG
    #foreach $chr (sort {cmpChrs($a,$b)} keys %CHUNK) {
    #    print STDERR "$chr\t$CHUNK{$chr}\n";
    #}
    # DEBUG
    my %F1;
    my $numchunks = $chunk;
    for (my $chunk=0;$chunk<$numchunks;$chunk++) {
	open $F1{$chunk}, ">" . $infile . "_sorting_tempfile." . $chunk;
    }
    open(INFILE, $infile);
    while (my $line = <INFILE>) {
	chomp($line);
	my @a = split(/\t/,$line);
	my $FF = $F1{$CHUNK{$a[1]}};
	if ($line =~ /\S/) {
	    print $FF "$line\n";
	}
    }
    for ($chunk=0;$chunk<$numchunks;$chunk++) {
	close $F1{$chunk};
    }
    
    $cnt=0;
    $chunk=0;
    
    while ($cnt < @CHR) {

	my %chrs_current;
	my $running_count = $chr_counts{$CHR[$cnt]};
	$chrs_current{$CHR[$cnt]} = 1;
	if ($chr_counts{$CHR[$cnt]} > $max_count_at_once) { # it's a monster chromosome, going to do it in
	    # pieces for fear of running out of RAM.
	    my $INFILE = $infile . "_sorting_tempfile." . $CHUNK{$CHR[$cnt]};
	    open my $sorting_chunk_in, "<", $INFILE;

            # Open an iterator over the records in $sorting_chunk_in

            my $grouper = $separate ? sub { undef } : \&are_mates;

            my $it = RUM::RUMIO->new(-fh => $sorting_chunk_in)->group_by($grouper);
	    my $FLAG = 0;
	    my $chunk_num = 0;

	    while ($FLAG == 0) {
		$chunk_num++;

                my $suffix = $chunk_num == 1 ? 0 : 1;
                my $tempfilename = $CHR[$cnt] . "_temp.$suffix";
                open my $this_chunk_out, ">", $tempfilename;
                my $num_read = RUM::RUMIO->sort_by_location(
                    $it, $this_chunk_out, max => $max_count_at_once);
                close($this_chunk_out);
                unless ($num_read) {
                    $FLAG = 1;
                }
		
		# merge with previous chunk (if necessary):
                #	    print "chunk_num = $chunk_num\n";
		if ($chunk_num > 1) {

                    my @tempfiles = map "$CHR[$cnt]_temp.$_", (0,1,2);

                    open my $in1, "<", $tempfiles[0];
                    open my $in2, "<", $tempfiles[1];
                    open my $temp_merged_out, ">", $tempfiles[2];

                    my @iters = map { RUM::RUMIO->new(-file => $_) } @tempfiles;
                    for (@iters) {
                        $_ = $_->peekable;
                    }

		    RUM::RUMIO->merge_iterators($temp_merged_out, @iters);
                    close($temp_merged_out);
                    
                    mv $tempfiles[2], $tempfiles[0]
                        or croak "Couldn't move $tempfiles[2] to $tempfiles[0]: $!";
                    unlink($tempfiles[1]);
		}
	    }
	    my $tempfilename = $CHR[$cnt] . "_temp.0";
	    close(FINALOUT);
	    `cat $tempfilename >> $outfile`;
	    open(FINALOUT, ">>$outfile");
	    unlink($tempfilename);
	    $tempfilename = $CHR[$cnt] . "_temp.1";
	    system "rm -f $tempfilename";
	    $tempfilename = $CHR[$cnt] . "_temp.2";
	    system "rm -f $tempfilename";
	    $cnt++;
	    $chunk++;
	    next;
	}
	
	# START NORMAL CASE (SO NOT DEALING WITH A MONSTER CHROMOSOME)
	
	$cnt++;
	while ($cnt < @CHR && 
                   $running_count+$chr_counts{$CHR[$cnt]} < $max_count_at_once) {
	    $running_count = $running_count + $chr_counts{$CHR[$cnt]};
	    $chrs_current{$CHR[$cnt]} = 1;
	    $cnt++;
	}
	my $INFILE = $infile . "_sorting_tempfile." . $chunk;
        my $grouper = $separate ? sub { undef } : \&are_mates;
        my $iter = RUM::RUMIO->new(-file => $INFILE)->group_by($grouper);
        RUM::RUMIO->sort_by_location($iter, *FINALOUT);
	$chunk++;
    }
    close(FINALOUT);
    
    for ($chunk=0;$chunk<$numchunks;$chunk++) {
	unlink($infile . "_sorting_tempfile." . $chunk);
    }

    return \%chr_counts;
}

