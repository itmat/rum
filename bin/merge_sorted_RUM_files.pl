#!/usr/bin/perl

package RUM::Script::MergeSortedRumFiles;

use strict;
no warnings;



if(@ARGV<2) {
    die "Usage: merge_sorted_RUM_files.pl <outfile> <infile1> <infile2> [<infile3> ... <infileN>] [option]

    Where: the infiles are RUM_Unique or RUM_NU files, each sorted by location,
           without the forward and reverse reads separated.  They will be merged
           into a single sorted file output to <outfile>.

    Option:
           -chunk_ids_file f : If a file mapping chunk N to N.M.  This is used
                               specifically for the RUM pipeline when chunks were
                               restarted and names changed. 

";
}

use FindBin qw($Bin);
use lib "$Bin/../lib";
use Carp;
use RUM::Common qw(roman Roman isroman arabic);
use RUM::Sort qw(by_location);
use RUM::FileIterator qw(file_iterator pop_it peek_it merge_iterators);
use RUM::Logging;
use Getopt::Long;

our $log = RUM::Logging->get_logger();

GetOptions("chunk_ids_file|chunk-ids-file=s" => \(my $chunk_ids_file));

my ($outfile, @infiles) = @ARGV;

my %chunk_ids_mapping;

if ($chunk_ids_file) {
    $log->info("Reading chunk id mapping from $chunk_ids_file");
    if (-e $chunk_ids_file) {

        open(INFILE, $chunk_ids_file)
            or die "Error: cannot open '$chunk_ids_file' for reading.\n\n";
        while (defined (my $line = <INFILE>)) {
            chomp($line);
            my @a = split(/\t/,$line);
            $chunk_ids_mapping{$a[0]} = $a[1];
        }
        close(INFILE);
    } else {
        $log->error("Chunk id mapping file $chunk_ids_file does not exist");
    }
}

if (@infiles == 1) {
    $log->debug("There's only one file; just copying it");
    my $infile = $infiles[0];
    `cp $infile $outfile`;
    exit(0);
}

my @file;
for (my $i=0; $i<@infiles; $i++) {
    $file[$i] = $infiles[$i];
    my $j = $i+1;
    my $mapped_id = $chunk_ids_mapping{$j} || "";
    if ($mapped_id =~ /\S/) {
        $file[$i] =~ s/(\d|\.)+$//;
        $file[$i] = $file[$i] . ".$j." . $mapped_id;
    }
}

my @iters;
for my $filename (@file) {
    $log->debug("Opening iterator for $filename");
    open my $file, "<", $filename
        or croak "Can't open $filename for reading: $!";
    my $iter = file_iterator($file);
    push @iters, $iter if peek_it($iter);
}

open my $out, ">", $outfile;
merge_iterators($out, @iters);
