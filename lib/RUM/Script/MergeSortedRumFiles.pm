#!/usr/bin/perl

package RUM::Script::MergeSortedRumFiles;

use strict;
no warnings;

use Getopt::Long;
use Pod::Usage;
use RUM::Common qw(read_chunk_id_mapping);
use RUM::FileIterator qw(file_iterator merge_iterators peek_it);
use RUM::Logging;
use RUM::Usage;

# This gets a logger, which will be a Log::Log4perl logger if it's
# installed, otherwise a RUM::Logger. Any package that wants to do
# logging should get its own logger by calling this method, so that a
# user can control how the logging works for different packages using
# conf/rum_logging.conf.
our $log = RUM::Logging->get_logger();

sub main {

    GetOptions(

        # This will accept either --output or -o and save the argument
        # to $outfile.
        "output|o=s" => \(my $outfile),

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
        "help|h" => sub { RUM::Usage->help }
    );

    # GetOptions leaves any leftover options in @ARGV, so the
    # remaining options will be our input files.
    my @infiles = @ARGV;

    # pod2usage prints the given message as well as the NAME and
    # SYNOPSIS sections of the POD contained in the script that was
    # called (in this case bin/merge_sorted_RUM_files.pl) and exits.
    # It's a good way to exit with a usage message.
    @infiles or RUM::Usage->bad(
        "Please specify one or more input files");
    $outfile or RUM::Usage->bad(
        "Please specify an output file with --output\n");
    
    my %chunk_ids_mapping = read_chunk_id_mapping($chunk_ids_file);

    $log->info("Merging ".scalar(@infiles)." files into $outfile");    

    # If there's only one file, just copy it
    if (@infiles == 1) {
        $log->debug("There's only one file; just copying it");
        `cp $infiles[0] $outfile`;
        return;
    }

    # Otherwise if there's more than one file, open iterators over all
    # the files and merge them together.
    my @iters;
    for my $filename (@infiles) {
        $log->debug("Reading from $filename");
        my $iter = RUM::RUMIO->new(-file => $filename)->aln_iterator->peekable;
        push @iters, $iter if $iter->peek;
    }

    open my $out, ">", $outfile
        or $log->logdie("Can't open $outfile for writing: $!");
    merge_iterators($out, @iters);
}
