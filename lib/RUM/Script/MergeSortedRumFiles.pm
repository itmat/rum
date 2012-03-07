#!/usr/bin/perl

package RUM::Script::MergeSortedRumFiles;

use strict;
no warnings;

use Getopt::Long;
use Pod::Usage;
use RUM::FileIterator qw(file_iterator merge_iterators peek_it);
use RUM::Logging;

# This gets a logger, which will be a Log::Log4perl logger if it's
# installed, otherwise a RUM::Logger. Any package that wants to do
# logging should get its own logger by calling this method, so that a
# user can control how the logging works for different packages using
# conf/rum_logging.conf.
our $log = RUM::Logging->get_logger();

sub main {

    GetOptions(

        # This will accept either -chunk_ids_file or --chunk-ids-file,
        # and assign the value the user provides for that option to
        # $chunk_ids_file.
        "chunk_ids_file|chunk-ids-file=s" => \(my $chunk_ids_file),

        # This will call $log->less_logging(1) if we see either
        # --quiet or -q
        "quiet|q" => sub { $log->less_logging(1) },

        # This will call $log->more_logging(1) if we see either
        # --verbose or -v
        "verbose|v" => sub { $log->more_logging(1) },
    
        # This dies with a verbose usage message if the user supplies
        # --help or -h.
        "help|h" => sub { pod2usage(-verbose=>2) }
    );

    my ($outfile, @infiles) = @ARGV;

    # pod2usage prints the given message as well as the NAME and
    # SYNOPSIS sections of the POD contained in the script that was
    # called (in this case bin/merge_sorted_RUM_files.pl) and exits.
    # It's a good way to exit with a usage message.
    pod2usage("Please provide an output file and input files\n") unless $outfile;
    pod2usage("Please provide one or more input files\n") unless @infiles;
    
    my %chunk_ids_mapping;
    
    if ($chunk_ids_file) {
        $log->info("Reading chunk id mapping from $chunk_ids_file");
        if (-e $chunk_ids_file) {

            # logdie dies and writes the message to the log
            # file(s) and the screen.
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
        $log->debug("Reading from $filename");
        open my $file, "<", $filename
            or $log->logdie("Can't open $filename for reading: $!");
        my $iter = file_iterator($file);
        push @iters, $iter if peek_it($iter);
    }

    open my $out, ">", $outfile
        or $log->logdie("Can't open $outfile for writing: $!");
    merge_iterators($out, @iters);
}
