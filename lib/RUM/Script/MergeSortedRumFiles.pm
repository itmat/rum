#!/usr/bin/perl

package RUM::Script::MergeSortedRumFiles;

use strict;
no warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use Carp;
use RUM::FileIterator qw(file_iterator pop_it peek_it merge_iterators);
use RUM::Logging;
use Pod::Usage;
use RUM::Script qw(show_usage get_options);
our $log = RUM::Logging->get_logger();

sub main {

    get_options("chunk_ids_file|chunk-ids-file=s" => \(my $chunk_ids_file),
                         "quiet|q" => sub { $log->less_logging(1) },
                       "verbose|v" => sub { $log->more_logging(1) });

    $log->debug("A debug message");

    my ($outfile, @infiles) = @ARGV;

    pod2usage("Please provide an output file and input files\n") unless $outfile;
    pod2usage("Please provide one or more input files\n") unless @infiles;
    
    my %chunk_ids_mapping;
    
    if ($chunk_ids_file) {
        $log->info("Reading chunk id mapping from $chunk_ids_file");
        if (-e $chunk_ids_file) {
            
            open(INFILE, $chunk_ids_file)
                or $log->logdie("Can't open $chunk_ids_file for reading: $!");
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

    $log->info("Merging ".scalar(@file)." files into $outfile");    

    # If there's only one file, just copy it
    if (@file == 1) {
        $log->debug("There's only one file; just copying it");
        `cp $file[0] $outfile`;
        return;
    }

    # Otherwise if there's more than one file, open iterators over all
    # the files and merge them together.
    my @iters;
    for my $filename (@file) {
        $log->debug("Opening iterator for $filename");
        open my $file, "<", $filename
            or croak "Can't open $filename for reading: $!";
        my $iter = file_iterator($file);
        push @iters, $iter if peek_it($iter);
    }

    open my $out, ">", $outfile;
    $log->debug("Merging iterators");
    merge_iterators($out, @iters);
}
