#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use File::Copy;
use Carp;
use LWP::Simple;

=head1 NAME

rum_install.pl - RUM Pipeline Installer

=head1 SYNOPSIS

rum_install.pl F<dir>

Where F<dir> is the directory to install to.  This should not be a
system directory, it should be some directory in user space.  This
will install all of the scripts and indexes under this directory.

Note: You will need either ftp, wget, or curl installed for this to
work.

This script sets up the rum pipeline on a Mac or a 64 bit Linux
machine.  You will be queried for the right organism to install.
After installation is complete, cd into the install directory and
issue bin/RUM_runner.pl for general usage.

For more information on running and interpreting the output, please
see the following webpage:

=over 4

=item - http://cbil.upenn.edu/RUM/userguide.php

=back

To create your own indexes, please see the following webpage:

=over 4

=item - http://cbil.upenn.edu/RUM/makeindexes.php

=back

=head1 AUTHOR

Written by Gregory R. Grant, University of Pennsylvania, 2010

=cut

$|=1;

# Get options from the user and print the help message if we need to.
sub usage {
    pod2usage { -verbose => 1 };
}
GetOptions("help|h" => \&usage);
my $dir = $ARGV[0] or usage();
$dir =~ s!\/$!!;

my $tarball = "RUM-Pipeline-v1.11.0.tar.gz";

# Make any directories that need to be created
unless (-d $dir) {
    mkdir $dir or croak "mkdir $dir: $!";
}

##
## Some wrappers around system calls that add error handling
##

sub shell {
    my ($cmd) = @_;
    print "$cmd\n";
    system($cmd) == 0 or croak "$cmd: $!";
}

sub download {
    my ($url) = @_;
    my $cmd;

    # Which -s returns 0 if it finds the command, 1 otherwise.
    if (system("which -s wget") == 0) {
        $cmd = "wget -q $url";
    }
    elsif (system("which -s curl") == 0) {
        $cmd = "curl -O $url";
    }
    elsif (system("which -s ftp") == 0) {
        $cmd = "ftp $url";
    }
    else {
        croak "I can't find ftp, wget, or curl on your path; ".
            "please install one of those programs.";
    }

    shell($cmd);    
}

sub mv {
    my ($from, $to) = @_;
    move $from, $to or croak "mv $from $to: $!";
}

sub rm {
    my ($file) = @_;
    unlink $file or croak "rm $file: $!";
}

# Download the source tarball, move it to the right directory, and
# unzip it
download("https://github.com/downloads/PGFI/rum/$tarball");
my $abs_path = File::Spec->rel2abs($tarball, ".");
shell "tar -C $dir --strip-components 1 -zxf $abs_path";
rm "$dir/$tarball";
if (my $pid = fork()) {
    wait();
    print "Done installing rum pipeline to $dir\n";
}
else {
    exec("perl", "$dir/bin/rum_indexes");
}
