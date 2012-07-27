#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 2;
use FindBin qw($Bin);
use File::Copy;
use lib "$Bin/../lib";
use RUM::Script::MergeBowtieAndBlat;
use RUM::TestUtils;

use Getopt::Long;

my %options;
for my $program (qw(Bowtie Blat)) {
    for my $mapper_type (qw(Unique NU)) {
        my $raw_input = "$INPUT_DIR/in1/${program}${mapper_type}.1";
        my $option = ('--'
                      . lc($program) 
                      . '-'
                      . ($mapper_type eq 'Unique' ? 'unique' : 'non-unique')
                      . '-in');
        $options{$option} = temp_filename(TEMPLATE => "${program}${mapper_type}.XXXXXX")->filename;
        copy($raw_input, $options{$option});
    }
}

my $rum_unique = temp_filename(TEMPLATE => 'unique.XXXXXX')->filename;
my $rum_nu     = temp_filename(TEMPLATE => 'non-unique.XXXXXX')->filename;

my $opts = [];

@ARGV = (%options,
         "--unique-out",     $rum_unique,
         "--non-unique-out", $rum_nu, 
         "--quiet",
         @{ $opts });

RUM::Script::MergeBowtieAndBlat->main();
no_diffs($rum_unique, "$INPUT_DIR/out-paired/RUM_Unique_temp", "paired unique @$opts");
no_diffs($rum_nu,     "$INPUT_DIR/out-paired/RUM_NU_temp",     "paired nu     @$opts");

