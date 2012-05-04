#!perl

use strict;
use warnings;

use Test::More;
use lib "lib";
use FindBin qw($Bin);


BEGIN { 
    eval "use Test::Exception";
    plan skip_all => "Test::Exception needed" if $@;
    plan tests => 12;
    use_ok('RUM::ConfigFile');
}

my $valid_config_text = join("", map("$_\n", ('a' .. 'g')));
my $valid_config_hashref = {
    "gene_annotation_file" => "a",
    "bowtie_bin" => "b",
    "blat_bin" => "c",
    "mdust_bin" => "d",
    "bowtie_genome_index" => "e",
    "bowtie_gene_index" => "f",
    "blat_genome_index" => "g"
};

# Parse a valid config file
do {
    open my $config_in, "<", \$valid_config_text;
    my $config = RUM::ConfigFile->parse($config_in);
    is($config->gene_annotation_file, "a");
    is($config->bowtie_bin, "b");
    is($config->blat_bin, "c");
    is($config->mdust_bin, "d");
    is($config->bowtie_genome_index, "e");
    is($config->bowtie_gene_index, "f");
    is($config->blat_genome_index, "g");

    $config->make_absolute("/foo/bar");
    like $config->gene_annotation_file, qr/a$/;
};

# Parse a config file that's too long
do {
    my $config_text = join("", map("$_\n", ('a' .. 'z')));
    open my $config_in, "<", \$config_text;
    is_deeply(RUM::ConfigFile->parse($config_in, quiet=>1), $valid_config_hashref, 
              "Parse valid config file");
};

# Parse a config file that's too short
do {
    my $config_text = join("", map("$_\n", ('a' .. 'd')));
    open my $config_in, "<", \$config_text;
    throws_ok { RUM::ConfigFile->parse($config_in) } qr/not enough lines/i,
        "Throw when a config file is too short";
};

# Stringify a config file
do {
    open my $config_in, "<", \$valid_config_text;
    is(RUM::ConfigFile->parse($config_in)->to_str,
       $valid_config_text,
       "Stringify a config file");
};

