package RUM::Script::MergeGnuAndTnuAndCnu;

no warnings;

use RUM::Usage;
use RUM::Logging;
use Getopt::Long;

our $log = RUM::Logging->get_logger();

$|=1;

sub main {

    GetOptions(
        "gnu-in=s" => \(my $infile1),
        "tnu-in=s" => \(my $infile2),
        "cnu-in=s" => \(my $infile3),
        "output=s" => \(my $outfile),
        "help|h"    => sub { RUM::Usage->help },
        "verbose|v" => sub { $log->more_logging(1) },
        "quiet|q"   => sub { $log->less_logging(1) });

    $infile1 or RUM::Usage->bad("Missing --gnu-in option");
    $infile2 or RUM::Usage->bad("Missing --tnu-in option");
    $infile3 or RUM::Usage->bad("Missing --cnu-in option");
    $outfile or RUM::Usage->bad("Missing --output option");
    
    open(INFILE1, "<", $infile1) or die "Can't open $infile1 for reading: $!";
    open(INFILE2, "<", $infile2) or die "Can't open $infile2 for reading: $!";
    open(INFILE3, "<", $infile3) or die "Can't open $infile3 for reading: $!";

    $last_row_gnu = `tail -1 $infile1`;
    $last_row_tnu = `tail -1 $infile2`;
    $last_row_cnu = `tail -1 $infile3`;
    $last_row_gnu =~ /seq.(\d+)[^\d]/;
    $last_id_gnu = $1;
    $last_row_tnu =~ /seq.(\d+)[^\d]/;
    $last_id_tnu = $1;
    $last_row_cnu =~ /seq.(\d+)[^\d]/;
    $last_id_cnu = $1;
    $last_id = $last_id_gnu;
    if ($last_id_tnu > $last_id) {
        $last_id = $last_id_tnu;
    }
    if ($last_id_cnu > $last_id) {
        $last_id = $last_id_cnu;
    }
    $line1 = <INFILE1>;
    $line2 = <INFILE2>;
    $line3 = <INFILE3>;
    chomp($line1);
    chomp($line2);
    chomp($line3);

    open(OUTFILE, ">", $outfile) or die "Can't open $outfile for writing: $!";

    for ($s=1; $s<=$last_id; $s++) {
        undef %hash;
        $line1 =~ /seq.(\d+)([^\d])/;
        $n = $1;
        $type = $2;
        while ($n == $s) {
            if ($type eq "\t") {
                $hash{$line1}++;
            } else {
                $line1b = <INFILE1>;
                chomp($line1b);
                if ($line1b eq '') {
                    last;
                }
                $hash{"$line1\n$line1b"}++;
            }
            $line1 = <INFILE1>;
            chomp($line1);
            if ($line1 eq '') {
                last;
            }
            $line1 =~ /seq.(\d+)([^\d])/;
            $n = $1;
            $type = $2;
        }
        $line2 =~ /seq.(\d+)([^\d])/;
        $n = $1;
        $type = $2;
        while ($n == $s) {
            if ($type eq "\t") {
                $hash{$line2}++;
            } else {
                $line2b = <INFILE2>;
                chomp($line2b);
                if ($line2b eq '') {
                    last;
                }
                $hash{"$line2\n$line2b"}++;
            }
            $line2 = <INFILE2>;
            chomp($line2);
            if ($line2 eq '') {
                last;
            }
            $line2 =~ /seq.(\d+)([^\d])/;
            $n = $1;
            $type = $2;
        }
        $line3 =~ /seq.(\d+)([^\d])/;
        $n = $1;
        $type = $2;
        while ($n == $s) {
            if ($type eq "\t") {
                $hash{$line3}++;
            } else {
                $line3b = <INFILE3>;
                chomp($line3b);
                if ($line3b eq '') {
                    last;
                }
                $hash{"$line3\n$line3b"}++;
            }
            $line3 = <INFILE3>;
            chomp($line3);
            if ($line3 eq '') {
                last;
            }
            $line3 =~ /seq.(\d+)([^\d])/;
            $n = $1;
            $type = $2;
        }
        for $key (keys %hash) {
            if ($key =~ /\S/) {
                print OUTFILE "$key\n";
            }
        }
    }

    close(INFILE1);
    close(INFILE2);
    close(INFILE3);
}
