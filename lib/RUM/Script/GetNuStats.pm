package RUM::Script::GetNuStats;

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
        "output|o=s" => \(my $outfile),
        "help|h"    => sub { RUM::Usage->help },
        "verbose|v" => sub { $log->more_logging(1) },
        "quiet|q"   => sub { $log->less_logging(1) });

    my $samfile = $ARGV[0] or RUM::Usage->bad(
        "Please provide a sam file");
    open(INFILE, $samfile) or die "Can't open $samfile for reading: $!";

    my $out;
    if ($outfile) {
        open $out, ">", $outfile or die "Can't open $outfile for writing: $!";
    }
    else {
        $out = *STDOUT;
    }
    
    my $doing = "seq.0";
    while (defined(my $line = <INFILE>)) {
        if($line =~ /LN:\d+/) {
            next;
        } else {
            last;
        }
    }

    my %hash;
    while(defined(my $line = <INFILE>)) {
        $line =~ /^(\S+)\t.*IH:i:(\d+)\s/;
        my $id = $1;
        my $cnt = $2;
        if(!($line =~ /IH:i:\d+/)) {
            $doing = $id;
            next;
        }
        #    print "id=$id\n";
        #    print "cnt=$cnt\n";
        if($doing eq $id) {
            next;
        } else {
            $doing = $id;
            $hash{$cnt}++;
        }
    }
    close(INFILE);
    
    print $out "num_locs\tnum_reads\n";
    for my $cnt (sort {$a<=>$b} keys %hash) {
        print $out "$cnt\t$hash{$cnt}\n";
    }
    return 0;
}
