#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 4 ;
use FindBin qw($Bin);
use File::Copy;
use lib "$Bin/../lib";
use RUM::Script::MergeBowtieAndBlat;
use RUM::TestUtils;

use Getopt::Long;




for my $type (qw(paired single)) {
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
    $rum_nu     = "$type-nu";
    $rum_unique = "$type-u";
    
    my $opts = [];
    
    @ARGV = (%options,
             "--unique-out",     $rum_unique,
             "--non-unique-out", $rum_nu, 
             "--$type",
             "--quiet",
             @{ $opts });
    
    warn "Running with @ARGV\n";
    RUM::Script::MergeBowtieAndBlat->main();
    no_diffs($rum_unique, "$INPUT_DIR/out-$type/RUM_Unique_temp", "$type unique @$opts");
    no_diffs($rum_nu,     "$INPUT_DIR/out-$type/RUM_NU_temp",     "$type nu     @$opts");
    
}
