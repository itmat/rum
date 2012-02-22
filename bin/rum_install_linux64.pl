#!/usr/bin/perl

# Written by Gregory R Grant
# University of Pennsylvania, 2010

if(@ARGV < 1 || $ARGV[0] =~ /help/ || $ARGV[0] eq "?") {
    die "
Usage: rum_install_linux64.pl <dir>

Where <dir> is the directory to install to.  This should
not be a system directory, it should be some directory
in user space.  This will install all of the scripts and
indexes under this directory.

Note: You will need 'wget' installed for this to work.

This script sets up the rum pipeline on a 64 bit linux
machine.  You will be queried for the right organism to
install.  After installation is complete, cd into the
install directory and issue RUM_runner.pl for general
usage.

For more information on running and interpreting the
output, please see the following webpage:
  - http://cbil.upenn.edu/RUM/userguide.php

To create your own indexes, please see the following
webpage:
  - http://cbil.upenn.edu/RUM/makeindexes.php

";
}

$dir = $ARGV[0];
$dir =~ s!\/$!!;

if(!(-d "$dir/")) {
    `mkdir $dir/`;
}
if(!(-d "$dir/scripts")) {
    `mkdir $dir/scripts`;
}
if(!(-d "$dir/bin")) {
    `mkdir $dir/bin`;
}
if(!(-d "$dir/indexes")) {
    `mkdir $dir/indexes`;
}
if(!(-d "$dir/data")) {
    `mkdir $dir/data`;
}
if(!(-d "$dir/lib")) {
    `mkdir $dir/lib`;
}

`wget https://github.com/downloads/PGFI/rum/RUM-Pipeline-1.11.tar.gz`
`yes|mv rum_pipeline.tar $dir/`;
`tar -C $dir --strip-components 1 -xvf $dir/rum_pipeline.tar`;
`yes|rm $dir/rum_pipeline.tar`;

`wget -O bin_linux64.tar http://itmat.rum.s3.amazonaws.com/bin_linux64.tar`;
`yes|mv bin_linux64.tar $dir/`;
`tar -C $dir -xvf $dir/bin_linux64.tar`;
`yes|rm $dir/bin_linux64.tar`;

`wget -O organisms.txt http://itmat.rum.s3.amazonaws.com/organisms.txt`;

$str = `grep "start \-\-" organisms.txt`;
@organisms = split(/\n/,$str);
$num_organisms = @organisms;
print "\n";
print "--------------------------------------\n";
print "The following organisms are available:\n\n";
for($i=0; $i<@organisms; $i++) {
    $organisms[$i] =~ s/^-- //;
    $organisms[$i] =~ s/ start --$//;
    $j = $i+1;
    print "($j) $organisms[$i]\n";
}
$j = @organisms+1;
print "($j) NONE\n";
print "--------------------------------------\n";
print "\n";
print "Enter the number of the organism you want to install: ";
$orgnumber = <STDIN>;
chomp($orgnumber);
print "\n";
while(!($orgnumber =~ /^\d+$/) || ($orgnumber <= 0) || ($orgnumber > $num_organisms+1)) {
    $NN = $num_organisms+1;
    print "Please enter a number between 1 and $NN: ";
    $orgnumber = <STDIN>;
}
$orgnumber--;
if($orgnumber == @organisms) {
    die "\nNo indexes installed.\n\n";
}
print "You have chosen organism $organisms[$orgnumber]\n\n";

open(INFILE, "organisms.txt");
$line = <INFILE>;
chomp($line);
$org = "$organisms[$orgnumber]";
$org =~ s/\[/\\[/g;
$org =~ s/\]/\\]/g;
$org =~ s/\(/\\(/g;
$org =~ s/\)/\\)/g;

until($line =~ /-- $org start --/) {
    $line = <INFILE>;
    chomp($line);
}
$line = <INFILE>;
chomp($line);
$zippedfiles = "";
until($line =~ /-- $org end --/) {
    print "$line\n";
    $file = $line;
    $file =~ s!.*/!!;
    if($line =~ /rum.config/) {
	`wget -O $file $line`;
	`yes|mv $file $dir/lib/$file`;
    } else {
	`wget -O $file $line`;
	`yes|mv $file $dir/indexes/$file`;
	if($file =~ /.gz$/) {
	    $zippedfiles = $zippedfiles . "$dir/indexes/$file ";
	}
    }
    $line = <INFILE>;
    chomp($line);
}
print "\n";
print "unzipping, please wait...\n";
if($zippedfiles =~ /\S/) {
    `yes|gunzip -f $zippedfiles`;
}
