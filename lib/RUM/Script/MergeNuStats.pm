package RUM::Script::MergeNuStats;

no warnings;
use RUM::Usage;
use RUM::Logging;
use RUM::Common qw(read_chunk_id_mapping);
use Getopt::Long;

our $log = RUM::Logging->get_logger();

sub main {

    GetOptions(
        "chunks|n=s" => \(my $numchunks),
        "help|h" => sub { RUM::Usage->help },
        "verbose|v" => sub { $log->more_logging(1) },
        "quiet|q"   => sub { $log->less_logging(1) },
        "chunk-ids-file=s" => \(my $chunk_ids_file));

    my $output_dir = $ARGV[0] or RUM::Usage->bad(
        "Please give the data directory on the command line");

    defined($numchunks) or RUM::Usage->bad(
        "Please specify the number of chunks with --chunks or -n");

    my %chunk_ids_mapping = read_chunk_id_mapping($chunk_ids_file);


    for ($i=1; $i<=$numchunks; $i++) {

        $filename = "$output_dir/nu_stats.$i";
        if ($chunk_ids_file =~ /\S/ && $chunk_ids_mapping{$i} =~ /\S/) {
            $filename = $filename . "." . $chunk_ids_mapping{$i};
        }
        open(INFILE, "$filename");
        $line = <INFILE>;
        while ($line = <INFILE>) {
            chomp($line);
            @a = split(/\t/,$line);
            if (defined $hash{$a[0]}) {
                $hash{$a[0]} = $hash{$a[0]} + $a[1];
            } else {
                $hash{$a[0]} = $a[1];
            }
        }
    }

    print "\n------------------------------------------\n";
    print "num_locs\tnum_reads\n";
    foreach $cnt (sort {$a<=>$b} keys %hash) {
        print "$cnt\t$hash{$cnt}\n";
    }


}

1;
