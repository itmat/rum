use Test::More tests => 4;
use Test::Exception;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Repository;
use RUM::TestUtils;
use File::Path;
use File::Temp qw(tempdir);
use strict;
use warnings;

BEGIN { 
    use_ok('RUM::Workflows');
    use_ok('RUM::Config');
}                                               

my $repo = RUM::Repository->new(root_dir => "$Bin/../_testing");

# This will fail if indexes are not installed, but that's ok, because
# we'll skip the tests anyway.
my @indexes = eval { $repo->indexes(pattern => qr/TAIR/); };

my $out_dir = "$Bin/tmp/40-workflows";
my $state_dir = "$out_dir/state";
my $conf_dir = $repo->conf_dir;

SKIP: {

    skip "no index", 2 unless @indexes == 1;
    my $index = $indexes[0];
    my $config = RUM::Config->new(
        chunk         => 1,
        output_dir    => $out_dir,
        paired_end    => 1,
        read_length   => 75,
        match_length_cutoff => 35,
        max_insertions => 1
    );
    $config->load_rum_config_file("$conf_dir/rum.config_Arabidopsis");
    rmtree($out_dir);
    mkpath($config->state_dir);
    
    is($config->genome_bowtie_out, "$out_dir/X.1", "genome bowtie out");
    is($config->blat_output, "$out_dir/R.1.blat", "blat out");
    
    my $chunk = RUM::Workflows->chunk_workflow($config);

    open my $script_file, ">", "$out_dir/run.sh" or die "Can't open script";
    $chunk->shell_script($script_file);
}
