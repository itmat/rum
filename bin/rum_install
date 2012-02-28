#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use File::Copy;
use Carp;

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
issue RUM_runner.pl for general usage.

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


# Maps os name to bin tarball name
my %bin_tarball_map = (
    darwin => "bin_mac1.5.tar",
    linux  => "bin_linux64.tar"
);

my $tarball = "RUM-Pipeline-1.11.tar.gz";
my $bin_tarball = $bin_tarball_map{$^O}
    or croak "I don't have a binary tarball for your operating systen ($^O)";


# Make any directories that need to be created
my @dirs = ("$dir/", "$dir/bin", "$dir/indexes", "$dir/data", "$dir/conf");
for my $subdir (@dirs) {
    unless (-d $subdir) {
        mkdir $subdir or croak "mkdir $subdir: $!";
    }
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
        $cmd = "wget $url";
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
download "http://github.s3.amazonaws.com/downloads/PGFI/rum/$tarball";
mv $tarball, "$dir/$tarball";
shell "tar -C $dir --strip-components 1 -zxf $dir/$tarball";
rm "$dir/$tarball";

# Download the binary tarball, move it to the right directory, and
# unzip it.
download "http://itmat.rum.s3.amazonaws.com/$bin_tarball";
mv $bin_tarball, $dir;
shell "tar -C $dir -xf $dir/$bin_tarball";
rm "$dir/$bin_tarball";

# Read names of organisms for which we have indexes
download "http://itmat.rum.s3.amazonaws.com/organisms.txt";
open my $organisms_file, "<", "organisms.txt"
    or croak "Can't open organisms.txt for reading: $!";
my @organisms;
while (defined ($_ = <$organisms_file>)) {
    /^-- (.*) start --/ and push @organisms, $1;
}
push @organisms, "NONE";
close $organisms_file;

print <<EOF;
--------------------------------------
The following organisms are available:

EOF

my $j = 1;
for my $org (@organisms) {
    printf "(%d) %s\n", $j++, $org;
}

print <<EOF;
--------------------------------------

EOF

print "Enter the number of the organism you want to install: ";

my $orgnumber = <STDIN>;
chomp($orgnumber);
print "\n";
while(!($orgnumber =~ /^\d+$/) || ($orgnumber <= 0) || ($orgnumber > @organisms)) {
    printf "Please enter a number between 1 and %d: ", scalar @organisms;
    $orgnumber = <STDIN>;
}
$orgnumber--;

if($organisms[$orgnumber] eq "NONE") {
    die "\nNo indexes installed.\n\n";
}
print "You have chosen organism $organisms[$orgnumber]\n\n";
print "Please wait while the files download...\n\n";


my $org = $organisms[$orgnumber];
$org =~ s/([ \[ \] \( \) ])/\\$1/xg;

# Read through the organisms file until we find the start line for my
# organism
open(INFILE, "organisms.txt");
do {
    $_ = <INFILE>;
    chomp;
} until(/-- $org start --/);

my @zippedfiles;

# Now read until the end line for this organism, and download each
# file listed.
my $line = <INFILE>;
chomp($line);

until($line =~ /-- $org end --/) {
    print "$line\n";
    my $file = $line;
    $file =~ s!.*/!!;
    download $line;

    # If it's a config file, it goes in the conf dir, otherwise it
    # goes in the indexes dir
    my $subdir = $line =~ /rum.config/ ? "conf" : "indexes";
    mv $file, "$dir/$subdir/$file";
    if($file =~ /.gz$/) {
        push @zippedfiles, "$dir/indexes/$file";
    }
    $line = <INFILE>;
    chomp($line);
}
print "\n";
print "Unzipping, please wait...\n";
if (@zippedfiles) {
    shell("gunzip -f @zippedfiles");
}

print "All done.\n";
