#!perl -T

use Test::More tests => 5;
use Test::Exception;
use lib "lib";

use strict;
use warnings;
use Log::Log4perl qw(:easy);

BEGIN { 
  use_ok('RUM::Config', qw(parse_config format_config));
}

my $valid_config_text = join("", map("$_\n", ('a' .. 'i')));
my $valid_config_hashref = {
    "gene-annotation-file" => "a",
    "bowtie-bin" => "b",
    "blat-bin" => "c",
    "mdust-bin" => "d",
    "bowtie-genome-index" => "e",
    "bowtie-gene-index" => "f",
    "blat-genome-index" => "g",
    "script-dir" => "h",
    "lib-dir" => "i"
};

# Parse_Config a valid config file
do {
    open my $config_in, "<", \$valid_config_text;
    is_deeply(parse_config($config_in), $valid_config_hashref, 
              "Parse_Config valid config file");
};

# Parse_Config a config file that's too long
do {
    my $config_text = join("", map("$_\n", ('a' .. 'z')));
    open my $config_in, "<", \$config_text;
    throws_ok { parse_config($config_in) } qr/too many lines/i,
        "Throw when a config file is too long";
};

# Parse_Config a config file that's too short
do {
    my $config_text = join("", map("$_\n", ('a' .. 'd')));
    open my $config_in, "<", \$config_text;
    throws_ok { parse_config($config_in) } qr/not enough lines/i,
        "Throw when a config file is too long";
};

# Stringify a config file
do {
    is(format_config(%{$valid_config_hashref}),
       $valid_config_text,
       "Stringify a config file");
};


