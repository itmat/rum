package RUM::Script::RemoveDups;

no warnings;

use RUM::Usage;
use RUM::Logging;
use Getopt::Long;

our $log = RUM::Logging->get_logger();
$|=1;

sub main {

    GetOptions(
        "non-unique-out=s" => \(my $outfile),
        "unique-out=s" => \(my $outfileu),
        "help|h"    => sub { RUM::Usage->help },
        "verbose|v" => sub { $log->more_logging(1) },
        "quiet|q"   => sub { $log->less_logging(1) });

    my $infile = $ARGV[0] or RUM::Usage->bad(
        "Please provide an input file of non-unique mappers");
    $outfile or RUM::Usage->bad(
        "Specify an output file for non-unique mappers with --non-unique-out");
    $outfileu or RUM::Usage->bad(
        "Specify an output file for unique mappers with --unique-out");

    open(RUMNU, $infile) or die "Can't open $infile for reading: $!";
    $flag = 0;
    $entry = "";
    $seqnum = 1;
    open(OUTFILE, ">", $outfile) 
        or die "Can't open $outfile for writing: $!";
    open(OUTFILEU, ">>", $outfileu) 
        or die "Can't open $outfileu for appending: $!";
    while ($flag == 0) {
        $line = <RUMNU>;
        chomp($line);
        $type = "";
        $line =~ /seq.(\d+)(.)/;
        $sn = $1;
        $type = $2;
        if ($sn == $seqnum && $type eq "a") {
            if ($entry eq '') {
                $entry = $line;
            } else {
                $hash{$entry} = 1;
                $entry = $line;
            }
        }
        if ($sn == $seqnum && $type eq "b") {
            if ($entry =~ /a/) {
                $entry = $entry . "\n" . $line;
            } else {
                $entry = $line; # a line with 'b' never follows a merged of the same id, 
                # otherwise this would wax the merged...
            }
            $hash{$entry} = 1;
            $entry = '';
        }
        if ($sn == $seqnum && $type eq "\t") {
            if ($entry eq '') {
                $entry = $line;
                $hash{$entry} = 1;
                $entry = '';
            } else {
                $hash{$entry} = 1;
                $entry = $line;
            }
        }
        if ($sn > $seqnum || $line eq '') {
            $len = -1 * (1 + length($line));
            seek(RUMNU, $len, 1);
            $hash{$entry} = 1;
            $cnt=0;
            foreach $key (keys %hash) {
                if ($key =~ /\S/) {
                    $cnt++;
                }	    
            }
            foreach $key (keys %hash) {
                if ($key =~ /\S/) {
                    chomp($key);
                    $key =~ s/^\s*//s;
                    if ($cnt == 1) {
                        print OUTFILEU "$key\n";
                    } else {
                        print OUTFILE "$key\n";
                    }
                }
            }
            undef %hash;
            $seqnum = $sn;
            $entry = '';
        }
        if ($line eq '') {
            $flag = 1;
        }
    }
    close(OUTFILE);
    close(OUTFILEU);
    return 0;
}
