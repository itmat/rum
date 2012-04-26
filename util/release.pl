#!/usr/bin/env perl

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Net::Amazon::S3;
use RUM::Pipeline;
use Data::Dumper;
use File::Temp;

my $AWS_KEY_MESSAGE = <<EOF;
You need a file named ~/.aws_pgfi_key that looks like this:

{ 
  aws_access_key_id => "the access key id",
  aws_secret_access_key => "secret access key"
}

where the strings are replaced by the actual credentials for
the pgfi aws account.
EOF

my $key_file = glob "~/.aws_pgfi_key";
-f $key_file or die "Key file does not exist. $AWS_KEY_MESSAGE";

my $key_hash = do "$key_file";

my $version = $RUM::Pipeline::VERSION;
my $tag = "v$version";
my $tarball = "RUM-Pipeline-$RUM::Pipeline::VERSION.tar.gz";
my $bucket_name = "pgfi.rum";

my $aws_access_key_id     = $key_hash->{access_key_id};
my $aws_secret_access_key = $key_hash->{secret_access_key};

unless ($aws_secret_access_key && $aws_access_key_id) {
    die $AWS_KEY_MESSAGE;
}

print "Version:      $RUM::Pipeline::VERSION\n";
print "Release date: $RUM::Pipeline::RELEASE_DATE\n";
print "Git Tag:      $tag\n";
print "\n";
print "Release (y/n): ";
$_ = <>;
/^y/i or die "Not releasing\n";

-f $tarball or die
    "$tarball doesn't exist, please create it with make dist\n";

my @tags = `git tag -l`;
$? and die "Couldn't get tags with git tag -l";

for (@tags) {
    chomp;
    $_ eq $tag and die 
        "Tag $tag already exists; you'll need to change the version number ".
            "in RUM::Pipeline\n";
}

open my $in, "<", "bin/rum_install.pl";
open my $out, ">", "rum_install.pl.tmp";
my $found_tarball;
while ($_ = <$in>) {
    s/\$tarball\s*=\s*".*"\s*;/\$tarball = "$tarball";/ and $found_tarball++;
    print $out $_;
}
close $out;

die "Didn't find tarball line in install script\n" unless $found_tarball;

my $s3 = Net::Amazon::S3->new(
    {aws_access_key_id => $aws_access_key_id,
     aws_secret_access_key => $aws_secret_access_key
 });

sub die_s3 { 
    die $s3->err . ": " . $s3->errstr;
}

my $bucket = $s3->bucket($bucket_name);

print "Files on the server:\n";

my $list = $bucket->list_all() or die "Couldn't list keys: " . $s3->errstr;
for (@{ $list->{keys} }) {
    my $key = $_->{key};
    my $size = $_->{size};
    print "  $key ($size)\n";
}

print "Uploading $tarball\n";
$bucket->add_key_filename(
    $tarball,
    $tarball
) or die_s3;

print "Uploading rum_install.pl";
$bucket->add_key_filename(
    "rum_install.pl", 
    "rum_install.pl.tmp"
) or die_s3;

print "Setting permissions to public-read\n";
$bucket->set_acl({acl_short => "public-read"}) or die_s3;
$bucket->set_acl({acl_short => "public-read", key => $tarball}) or die_s3;
$bucket->set_acl({acl_short => "public-read", key => "rum_install.pl"}) or die_s3;
unlink "rum_install.pl.tmp";

print "Tagging release\n";
system("git tag $tag") == 0 or die "Error creating tag";
