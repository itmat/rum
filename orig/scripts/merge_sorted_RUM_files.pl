#!/usr/bin/perl

use FindBin qw($Bin);
use lib "$Bin/../../lib";

use RUM::Common qw(roman Roman isroman arabic);
use RUM::ChrCmp qw(cmpChrs);
use RUM::FileIterator qw(file_iterator pop_it peek_it);

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

use strict;
my $outfile = $ARGV[0];
my $options_start_index;
my $options = "false";
my $numfiles = 0;
for (my $i=0; $i<@ARGV; $i++) {
    if($ARGV[$i] =~ /^-/) {
        $options = "true";
        $options_start_index = $i;
        $i = @ARGV;
    } else {
        $numfiles = $i;
    }
}

my $chunk_ids_file = "";
my %chunk_ids_mapping;

if ($options eq "true") {
    for (my $i = $options_start_index; $i<@ARGV; $i++) {
        if ($ARGV[$i] eq '-chunk_ids_file') {
            $chunk_ids_file = $ARGV[$i+1];
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
                    
            }
        }
    }
}

if ($numfiles == 1) {
    my $infile = $ARGV[1];
    `cp $infile $outfile`;
    exit(0);
}

my @file;
for (my $i=0; $i<$numfiles; $i++) {
    $file[$i] = $ARGV[$i+1];
    my $j = $i+1;
    if ($chunk_ids_file =~ /\S/ && $chunk_ids_mapping{$j} =~ /\S/) {
        $file[$i] =~ s/(\d|\.)+$//;
        $file[$i] = $file[$i] . ".$j." . $chunk_ids_mapping{$j};
    }
}

my @iters;
for my $filename (@file) {
    open my $file, "<", $filename;
    my $iter = file_iterator($file);
    push @iters, $iter if peek_it($iter);
}

open my $out, ">", $outfile;

merge_iterators($out, @iters);

sub merge_iterators {

    my ($outfile, @iters) = @_;

    while (@iters) {
        
        my $argmin = 0;
        my $min = peek_it($iters[$argmin]);
        for (my $i = 1; $i < @iters; $i++) {
            
            my $rec = peek_it($iters[$i]);
            
            # Set $smaller to 1 if the next record from this iterator
            # is smaller than the current minimum
            my $smaller = 0;
            if ($rec->{chr} eq $min->{chr}) {
                if ($min->{start} > $rec->{start}) {
                    $smaller = 1;
                } elsif ($min->{start} == $rec->{start}) {
                    if ($min->{end} > $rec->{end}) {
                        $smaller = 1;
                    }
                }
            } else {
                if (cmpChrs($rec->{chr}, $min->{chr}) < 0) {
                    $smaller = 1;
                }
            }
            
            # If this one is smaller, set $argmin and $min
            # appropriately
            if ($smaller) {
                $argmin = $i;
                $min = peek_it($iters[$argmin]);
            }
        }
        
        if ($min->{entry} =~ /\S/) {
            print $outfile "$min->{entry}\n";
            
        }
        
        # Pop the iterator that we just printed a record from; this
        # way the next iteration will be looking at the next value. If
        # this iterator doesn't have a next value, then we've
        # exhausted it, so remove it from our list.
        pop_it($iters[$argmin]);        
        unless (peek_it($iters[$argmin])) {
            splice @iters, $argmin, 1;
        }
    }
}
