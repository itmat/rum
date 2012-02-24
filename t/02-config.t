#!perl -T

use Test::More tests => 5;
use Test::Exception;
use lib "lib";

use strict;
use warnings;
use Log::Log4perl qw(:easy);

BEGIN { 
  use_ok('RUM::Config');
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
    is_deeply(RUM::Config->parse($config_in), $valid_config_hashref, 
              "Parse valid config file");
};

# Parse a config file that's too long
do {
    my $config_text = join("", map("$_\n", ('a' .. 'z')));
    open my $config_in, "<", \$config_text;
    is_deeply(RUM::Config->parse($config_in, quiet=>1), $valid_config_hashref, 
              "Parse valid config file");
};

# Parse a config file that's too short
do {
    my $config_text = join("", map("$_\n", ('a' .. 'd')));
    open my $config_in, "<", \$config_text;
    throws_ok { RUM::Config->parse($config_in) } qr/not enough lines/i,
        "Throw when a config file is too short";
};

# Stringify a config file
do {
    open my $config_in, "<", \$valid_config_text;
    is(RUM::Config->parse($config_in)->to_str,
       $valid_config_text,
       "Stringify a config file");
};


