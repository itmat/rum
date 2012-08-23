#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use Test::More tests => 4;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use RUM::Script::MakeTuAndTnu;
use RUM::TestUtils;

my $gene_info = $RUM::TestUtils::PFAL_GENE_INFO;

GetOptions(
    "single=s" => \(my $single_dir = "$Bin/data/make-tu-and-tnu/single"),
    "paired=s" => \(my $paired_dir = "$Bin/data/make-tu-and-tnu/paired"));

SKIP: {
    skip qq{Don't have pfalciparum index}, 4 unless -e $gene_info;
    for my $type (qw(paired single)) {

        my $job_dir = $type eq 'single' ? $single_dir : $paired_dir;

        my $u  = temp_filename(TEMPLATE => "TU-$type.XXXXXX");
        my $nu = temp_filename(TEMPLATE => "TNU-$type.XXXXXX");
                
        my $script = RUM::Script::MakeTuAndTnu->new;
        $script->{max_distance_between_paired_reads} = 500000;
        $script->{paired} = $type eq 'paired';

        open my $annotfile, '<', $gene_info;
        open my $infile,    '<', "$job_dir/chunks/Y.1";

        $script->parse_output($annotfile, $infile, $u, $nu);

        no_diffs($u,  "$job_dir/chunks/TU.1",   "$type TU");
        no_diffs($nu, "$job_dir/chunks/TNU.1", "$type TNU");
    }
}
