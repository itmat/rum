#!/usr/bin/env perl

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use File::Path qw(rmtree mkpath);
use Test::More;
use File::Temp qw(tempdir);
use RUM::Action::Align;

our $dir = "$Bin/tmp/end-to-end";
our $config = "$Bin/../conf/rum.config_Arabidopsis";
our @reads = map "$Bin/data/shared/$_.fq", qw(forward reverse);

sub run_end_to_end {
    rmtree($dir);
    mkpath($dir);
    
    @ARGV = ("-o", $dir, "--name", "test", "--config", $config, @reads);
    
    RUM::Action::Align->run;
}

if (-e $config) {
    plan tests => 1;
}
else {
    plan skip_all => "Arabidopsis index needed";
}

SKIP: {

    run_end_to_end;
    open my $stats, "$dir/mapping_stats.txt";
    my $data = join("", (<$stats>));
    like $data, qr/num_locs\tnum_reads\n1\t577/, "Mapping stats has count by loc";
}

