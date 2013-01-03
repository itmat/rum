#!/usr/bin/env perl 

use strict;
use warnings;
use autodie;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Config;
use Data::Dumper;

my @props = grep { $_ ne 'forward_reads' &&
                   $_ ne 'reverse_reads' } RUM::Config->property_names;
@props = RUM::Config->property_names;
my $config = eval {
    RUM::Config->new->parse_command_line(load_default => 1,
                                         options => \@props,
                                         nocheck => 1);
};

if (my $errors = $@) {
    my $msg;
    if (ref($errors) && $errors->isa('RUM::UsageErrors')) {
        $msg = "";
        for my $error ($errors->errors) {
            chomp $error;
            $msg .= "* $error\n";
        }
    }
    else {
        $msg = "\n$errors\n";
    }
    die $msg;
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

