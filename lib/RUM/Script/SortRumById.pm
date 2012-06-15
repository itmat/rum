package RUM::Script::SortRumById;

use strict;
use warnings;
use autodie;

use Carp;
use File::Copy qw(mv);
use Getopt::Long;

use RUM::Usage;
use RUM::Logging;
use RUM::RUMIO;

our $log = RUM::Logging->get_logger();

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

    my @sorted_files   = map { "${infile}_sorted_temp$_"   } (1, 2, 3);
    my @unsorted_files = map { "${infile}_unsorted_temp$_" } (1, 2);

    # Split the input file into two file: one with rows that are
    # sorted by id, and another with rows that aren't.
    split_sorted_and_unsorted($infile, $sorted_files[0], $unsorted_files[0]);
    
    my $num_merges = 0;
    my $num_unsorted;
    do  {

        # Split the unsorted file into sorted and unsorted components
        $num_unsorted = split_sorted_and_unsorted($unsorted_files[0], $sorted_files[1], $unsorted_files[1]);

        # Now we should have two sorted files. Merge them together
        # into a larger third sorted file.
        merge(@sorted_files);

        # Now $unsorted_files[0] has been split and $unsorted_files[1]
        # has not, so swap them.
        @unsorted_files[0,1] = @unsorted_files[1,0];

        # Now $sorted_files[2] is 0 and 1 merged together. Swap 0 and
        # 2, so that 0 becomes the new large file.
        @sorted_files[2,0]   = @sorted_files[0,2];

        $num_merges++;
    } while ($num_unsorted);

    mv $sorted_files[0], $sortedfile or croak "mv $sorted_files[0] $sortedfile: $!";

    unlink @sorted_files, @unsorted_files;

    $log->debug("Number of merges required to sort '$infile': $num_merges");
    $log->debug("Done sorting '$infile' to $sortedfile");
}

sub split_sorted_and_unsorted {
    my ($in, $sorted_name, $unsorted_name) = @_;
    use strict;
    my $iter = RUM::RUMIO->new(-file => $in);
    open my $sorted, ">", $sorted_name;
    open my $unsorted, ">", $unsorted_name;

    my $aln_prev;
    my $count = 0;
    while (my $aln = $iter->next_val) {
        my $line = $aln->raw;

        if (!$aln_prev || $aln_prev->cmp_read_ids($aln) <= 0) {
            print $sorted $line . "\n";
            $aln_prev = $aln;
        } else {
            print $unsorted $line . "\n";
            $count++;
        }
    }
    return $count;
}

sub merge {
    use strict;
    my ($in1, $in2, $out) = @_;

    my $it1 = RUM::RUMIO->new(-file => $in1)->peekable;
    my $it2 = RUM::RUMIO->new(-file => $in2)->peekable;

    my $merged = $it1->merge(sub { $_[0]->cmp_read_ids($_[1]) }, $it2);
    
    open my $out_fh, ">", $out;

    while (my $aln = $merged->next_val) {
        print $out_fh $aln->raw . "\n";
    }
}
