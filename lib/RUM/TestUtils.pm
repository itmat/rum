
package RUM::TestUtils;

use strict;
use warnings;

use Test::More;
use Exporter qw(import);
use LWP::UserAgent;
use File::Spec;
use RUM::Workflow qw(make_paths shell report is_dry_run with_settings is_on_cluster);
use Carp;

our @EXPORT_OK = qw(download_file download_test_data no_diffs);
our %EXPORT_TAGS = (
    all => [@EXPORT_OK]);


our $TEST_DATA_URL = "http://pgfi.rum.s3.amazonaws.com/rum-test-data.tar.gz";

=item download_file URL, LOCAL

Download URL and save it with the given LOCAL filename, unless LOCAL
already exists or $DRY_RUN is set.

=cut

sub download_file {
    my ($url, $local) = @_;
    if (-e $local) {
        report "$local exists, skipping\n";
        return;
    }

    report "Download $url to $local";
    my (undef, $dir, undef) = File::Spec->splitpath($local);
    make_paths($dir);
    unless (is_dry_run) {
        my $ua = LWP::UserAgent->new;
        $ua->get($url, ":content_file" => $local);
    }
}

=item download_test_data

Download the test data tarball and unpack it, unless it already
exists or $DRY_RUN is set.

=cut

sub download_test_data {
    my ($local_file) = @_;
    report "Making sure test data is downloaded to $local_file\n";

    download_file($TEST_DATA_URL, $local_file);

    # Get a list of the files in the tarball
    my $tar_out = `tar ztf $local_file`;
    croak "Error running tar: $!" if $?;
    my @files = split /\n/, $tar_out;

    # Get the absolute paths that the files should have when we unzip
    # the tarball.
    my (undef, $dir, undef) = File::Spec->splitpath($local_file);
    @files = map { "$dir/$_" } @files;

    # If all of the files already exist, don't do anything
    my @missing = grep { not -e } @files;
    if (@missing) {   
        report "Unpack test tarball";
        shell("tar", "-zxvf", $local_file, "-C", $dir);
    }
    else {
        report "All files exist; not unzipping";
    }
}

sub no_diffs {
    my ($file1, $file2, $name) = @_;
    my $diffs = `diff $file2 $file1 > $name.diff`;
    my $status = $? >> 8;
    ok($status == 0, $name);
    print "Exit value was $?";
}
