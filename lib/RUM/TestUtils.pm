package RUM::TestUtils;

use strict;
no warnings;

=head1 NAME

RUM::TestUtils - Functions used by tests

=head1 SYNOPSIS

  use RUM::TestUtils qw(:all);

  # Download a file, unless the file already exists locally
  download_file("http://foo.com/bar.tab", "/some/path/bar.tab");

  # Download our tarball of test data from S3
  download_test_data("test-data.tar.gz");

  # Make sure there are no diffs between two files
  no_diffs("got.tab", "expected.tab", "I got what I expected");

=head1 DESCRIPTION

=head1 Subroutines

=over 4

=cut

use Test::More;
use Exporter qw(import);
use File::Spec;
use RUM::FileIterator qw(file_iterator);
use RUM::Sort qw(by_chromosome);
use RUM::Workflow qw(make_paths shell report is_dry_run with_settings 
                     is_on_cluster);
use Carp;
use RUM::Repository qw(download);
our @EXPORT_OK = qw(download_file download_test_data no_diffs
                    is_sorted_by_location);
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
        download($url, $local);
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

=item no_diffs(FILE1, FILE2, NAME)

Uses Test::More to assert that there are no differences between the
two files.

=cut

sub no_diffs {
    my ($file1, $file2, $name) = @_;
    my $diffs = `diff $file2 $file1 > /dev/null`;
    my $status = $? >> 8;
    ok($status == 0, $name);
}

=item is_sorted_by_location(FILENAME)

Asserts that the given RUM file is sorted by location.

=cut

sub is_sorted_by_location {
    my ($filename) = @_;
    open my $in, "<", $filename or croak "Can't open $filename for reading: $!";
    my $it = file_iterator($in);

    my @recs;
    my @keys = qw(chr start end);
    while (my $rec = $it->("pop")) {
        my %rec;
        @rec{@keys} = @$rec{@keys};
        push @recs, \%rec;
    }

    my @sorted = sort {
        by_chromosome($a->{chr}, $b->{chr}) || $a->{start} <=> $b->{start} || $a->{end} <=> $b->{end};
    } @recs;

    is_deeply(\@recs, \@sorted, "Sorted by location");
}




=back

=head1 AUTHOR

Mike DeLaurentis (delaurentis@gmail.com)

=head1 COPYRIGHT

Copyright University of Pennsylvania, 2012

=cut
