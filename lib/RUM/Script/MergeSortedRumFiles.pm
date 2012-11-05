#!/usr/bin/perl

package RUM::Script::MergeSortedRumFiles;

use strict;
no warnings;
use autodie;
use Data::Dumper;
use RUM::Common qw(read_chunk_id_mapping);
use RUM::FileIterator qw(file_iterator merge_iterators peek_it);
use base 'RUM::Script::Base';

# This gets a logger, which will be a Log::Log4perl logger if it's
# installed, otherwise a RUM::Logger. Any package that wants to do
# logging should get its own logger by calling this method, so that a
# user can control how the logging works for different packages using
# conf/rum_logging.conf.
our $log = RUM::Logging->get_logger();

sub accepted_options {
    return (
        RUM::Property->new(
            opt => 'output|o=s',
            desc => 'The file to write the merged results to',
            required => 1),
        RUM::Property->new(
            opt => 'input',
            desc => 'Sorted RUM input file',
            positional => 1,
            required => 1,
            nargs => '+'),
    );
}

sub summary {
    'Merge sorted RUM files'
}

sub synopsis_footer {
    'where infiles are RUM_Unique or RUM_NU files, each sorted by location,
without the forward and reverse reads separated.  They will be merged
into a single sorted file output to <outfile>.'
}

sub run {
    my ($self) = @_;

    my $props = $self->properties;

    # GetOptions leaves any leftover options in @ARGV, so the
    # remaining options will be our input files.
    print Dumper($props);
    my @file = @{ $props->get('input') };
    my $outfile = $props->get('output');

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
        open my $file, "<", $filename;
        my $iter = file_iterator($file);
        push @iters, $iter if peek_it($iter);
    }

    open my $out, ">", $outfile;
    merge_iterators($out, @iters);
}
