#!/usr/bin/perl

package RUM::Script::MergeSortedRumFiles;

use strict;
use autodie;
no warnings;

use RUM::Common qw(read_chunk_id_mapping);
use RUM::RUMIO;
use RUM::Usage;

use base 'RUM::Script::Base';

sub main {

    my $self = __PACKAGE__->new;
    $self->get_options(

        # This will accept either --output or -o and save the argument
        # to $outfile.
        "output|o=s" => \(my $outfile),

        # This will accept either -chunk_ids_file or --chunk-ids-file,
        # and assign the value the user provides for that option to
        # $chunk_ids_file.
        "chunk_ids_file|chunk-ids-file=s" => \(my $chunk_ids_file),

        # This will call $self->logger->less_logging(1) if we see either
        # --quiet or -q
        "quiet|q" => sub { $self->logger->less_logging(1) },

        # This will call $self->logger->more_logging(1) if we see either
        # --verbose or -v
        "verbose|v" => sub { $self->logger->more_logging(1) },
    
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

    $self->logger->info("Merging ".scalar(@infiles)." files into $outfile");    

    # If there's only one file, just copy it
    if (@infiles == 1) {
        $self->logger->debug("There's only one file; just copying it");
        `cp $infiles[0] $outfile`;
        return;
    }

    # Otherwise if there's more than one file, open iterators over all
    # the files and merge them together.
    my @iters;
    for my $filename (@infiles) {
        $self->logger->debug("Reading from $filename");
        my $iter = RUM::RUMIO->new(-file => $filename)->peekable;
        push @iters, $iter if $iter->peek;
    }

    open my $out, ">", $outfile;
    RUM::RUMIO->merge_iterators($out, @iters);
}

1;

__END__

=head1 NAME

RUM::Script::MergeSortedRumFiles

=head1 METHODS

=over 4

=item RUM::Script::MergeSortedRumFiles->main

Run the script.

=back

=head1 AUTHORS

Gregory Grant (ggrant@grant.org)

Mike DeLaurentis (delaurentis@gmail.com)

=head1 COPYRIGHT

Copyright 2012, University of Pennsylvania


