#!/usr/bin/env perl 

use strict;
use warnings;
use autodie;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Config;
use Data::Dumper;

my $config = eval {
    RUM::Config->new->parse_command_line(load_default => 1,
                                         options => [RUM::Config->property_names]);
};

if ($@) {
    print Dumper($@);
}

print "[job]\n";
for my $name ($config->property_names) {
    if (defined(my $value = $config->get($name))) {
        print $name, "=", $config->get($name), "\n";
    }
}


print "\n\n[index]\n";
my $index = RUM::Index->load($config->index_dir);
for my $k (keys %{ $index }) {
    if (defined (my $v = $index->{$k})) {
        print "$k=$v\n";
    }
}

