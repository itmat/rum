use Test::More;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Repository;
use RUM::TestUtils;
use File::Path;
use File::Temp qw(tempdir);
use strict;
use warnings;

use RUM::Workflows;
use RUM::Config;

my $repo = RUM::Repository->new(root_dir => "$Bin/../");

# This will fail if indexes are not installed, but that's ok, because
# we'll skip the tests anyway.
my @indexes = eval { $repo->indexes(pattern => qr/TAIR/); };

my $out_dir = "$Bin/tmp/40-workflows";
my $conf_dir = $repo->conf_dir;
my $index_dir = $repo->indexes_dir;
my $annotations = $RUM::TestUtils::GENE_INFO;
my $index_conf = "$conf_dir/rum.config_Arabidopsis";

if (-e $index_conf) {
    plan tests => 23;
}
else {
    plan skip_all => "Arabidopsis index needed";
}


my %defaults = (
    strand_specific => 0,
    output_dir => $out_dir,
    read_length => 75,
    rum_config_file => $index_conf,
    dna => 0,
    num_chunks => 2,
    genome_only => 0,
    name => "foo",
    alt_quant_model => "",
    alt_genes => undef,
    blat_min_identity => 93,
    blat_tile_size => 12,
    blat_step_size => 6,
    blat_rep_match => 256,
    blat_max_intron => 500000,
    ram => 6,
    genome_size => 1000000000
);

SKIP: {

    skip "no index", 2 unless @indexes == 1;
    my $index = $indexes[0];
    my $config = RUM::Config->new(
        %defaults,
        paired_end    => 1,
        max_insertions => 1,
        alt_genes => undef
    );

    $config->load_rum_config_file;
    rmtree($out_dir);
    mkpath $out_dir;

    my $chunk = RUM::Workflows->chunk_workflow($config, 1);

#    open my $dot, ">", "workflow.dot";
#    $chunk->state_machine->dotty($dot);
#    close ($dot);
    
    open my $script_file, ">", "$out_dir/run.sh" or die "Can't open script";
#    $chunk->shell_script($script_file);
}

sub would_run {
    my ($w, $command_re) = @_;
    ok(grep(/$command_re/, $w->all_commands), "$command_re would be run");
}

sub would_not_run {
    my ($w, $command_re) = @_;
    ok( ! grep(/$command_re/, $w->all_commands), "$command_re would not be run");
}

my $c = RUM::Config->new(
    %defaults,
);
$c->load_rum_config_file;
my $w = RUM::Workflows->postprocessing_workflow($c);
would_run($w, qr/merge rum_unique/i);
would_run($w, qr/merge rum_nu/i);
would_run($w, qr/compute mapping stat/i);
would_run($w, qr/merge quants/i);
would_not_run($w, 'merge_alt_quants');

$c = RUM::Config->new(%defaults);
$c->set('strand_specific', 1);
$c->load_rum_config_file;
$w = RUM::Workflows->postprocessing_workflow($c);

would_not_run($w, qr/merge quants$/i);
would_run($w, qr/merge.quants.p.*s/i);
would_run($w, qr/merge.quants.p.*a/i);
would_run($w, qr/merge.quants.m.*s/i);
would_run($w, qr/merge.quants.m.*a/i);
would_run($w, qr/merge.strand.specific.quants/i);

# Alt quants

$c = RUM::Config->new(%defaults, 'alt_quant_model', => "foo");
$c->load_rum_config_file;
$w = RUM::Workflows->postprocessing_workflow($c);
would_run($w, qr/merge.*quants$/i);
would_run($w, qr/merge.alt.quants/i);

$c = RUM::Config->new(%defaults);
$c->set('strand_specific', 1);
$c->set('alt_quant_model', "foo");
$c->load_rum_config_file;

$w = RUM::Workflows->postprocessing_workflow($c);

would_run($w, qr/merge.quants.*p.*s/i);
would_run($w, qr/merge.quants.*p.*a/i);
would_run($w, qr/merge.quants.*m.*s/i);
would_run($w, qr/merge.quants.*m.*a/i);
would_run($w, qr/merge.strand.specific.quants/i);
would_run($w, qr/merge.alt.quants.*p.*s/i);
would_run($w, qr/merge.alt.quants.*p.*a/i);
would_run($w, qr/merge.alt.quants.*m.*s/i);
would_run($w, qr/merge.alt.quants.*m.*a/i);
would_run($w, qr/merge.strand.specific.alt.quants/i);
