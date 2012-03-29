#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use FindBin qw($Bin);
use Cwd;

my $dir = getcwd;
my $re = qr/$dir/;

GetOptions(
    "interval=s" => \(my $interval = 3));


while (1) {
    my @procs = grep /$re/, `ps`;
    @procs or last;
    local $_ = $procs[int(rand(@procs))];
    my ($pid) = split;
    print "Killing $pid\n";
    system("kill $pid")==0 or warn "Couldn't kill $pid: $!\n";
    sleep($interval);
}
