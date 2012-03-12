package RUM::Script::LimitNU;

use strict;
no warnings;

use File::Copy;
use RUM::Usage;
use RUM::Logging;
use Getopt::Long;

our $log = RUM::Logging->get_logger();
$|=1;

sub main {
    
    GetOptions(
        "output|o=s" => \(my $outfile_name),
        "cutoff|n=s" => \(my $cutoff),
        "help|h"     => sub { RUM::Usage->help },
        "verbose|v"  => sub { $log->more_logging(1) },
        "quiet|q"    => sub { $log->less_logging(1) });

    #$cutoff && $cutoff > 0 or RUM::Usage->bad(
    #    "Please specify a positive cutoff with --cutoff or -n");
    $outfile_name or RUM::Usage->bad(
        "Please specify an output file with --output or -o");
    my $infile_name = $ARGV[0] or RUM::Usage->bad(
        "Please provide an input file");

    if (!int($cutoff)) {
        $log->info("Not filtering out mappers");
        copy($infile_name, $outfile_name);
        return 0;
    }

    $log->info("Filtering out mappers that appear $cutoff times or more");
   
    my (%hash_a, %hash_b);

    open my $infile, "<", $infile_name
        or die "Can't open $infile_name for reading: $!";
    open my $outfile, ">", $outfile_name 
        or die "Can't open $outfile_name for writing: $!";

    while (defined (my $line = <$infile>)) {
        $line =~ /seq.(\d+)([^\d])/;
        my $seqnum = $1;
        my $type = $2;
        if($type eq "a" || $type eq "\t") {
            $hash_a{$seqnum}++;
        }
        if($type eq "b" || $type eq "\t") {
            $hash_b{$seqnum}++;
        }
    }

    seek($infile, 0, 0);
    while(defined (my $line = <$infile>)) {
        $line =~ /seq.(\d+)[^\d]/;
        my $seqnum = $1;
        if($hash_a{$seqnum}+0 <= $cutoff && $hash_b{$seqnum}+0 <= $cutoff) {
            print $outfile $line;
        }
    }
}

