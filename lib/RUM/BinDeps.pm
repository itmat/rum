package RUM::BinDeps;

=head1 NAME

RUM::BinDeps - Manages dependencies (blat, bowtie, mdust)

=head1 SYNOPSIS

  use RUM::BinDeps;

  my $deps = RUM::BinDeps;

  # Download the binaries
  $deps->fetch;

  # Get the paths to installed binaries
  my $blat   = $deps->blat;
  my $bowtie = $deps->bowtie;
  my $mdust  = $deps->mdust;

=head1 CONSTRUCTORS

=over 4

=item RUM::BinDeps->new

Make a new RUM::BinDeps.

=cut

=back

=head1 OBJECT METHODS

=over 4

=cut

use strict;
use warnings;
use autodie;

use Carp;
use File::Copy qw(cp);
use File::Temp qw(tempdir);
use RUM::Repository qw(download);
use RUM::Logging;

use base "RUM::Base";

our $log = RUM::Logging->get_logger;

# Maps os name to bin tarball name
our %BIN_TARBALL_MAP = (
    darwin => "bin_mac1.5.tar",
    linux  => "bin_linux64.tar"
);

our $BIN_TARBALL_URL_PREFIX = "http://itmat.rum.s3.amazonaws.com";

=item $deps->fetch

Download the binary dependencies (blat, bowtie, mdust) and put them in
the "lib/RUM" directory.

=cut

sub fetch {
    my ($self) = @_;

#    if (-e $self->blat && -e $self->bowtie && -e $self->mdust) {
#        $self->say("Already have blat, bowtie, and mdust; not installing them");
#        return;
#    }
    $self->say("Downloading blat, bowtie, and mdust");

    my $tmp_dir = $self->_download_to_tmp_dir;

    for my $bin (qw(bowtie blat mdust)) {
        my $path = File::Spec->catfile($tmp_dir, $bin);
        -e $path or croak "I couldn't seem to download $bin";
        my $newpath = $self->_path($bin);
        $self->logsay("Installing $bin");
        $self->logsay("cp $path $newpath");
        cp $path, $newpath;
        $self->logsay("chmod 0755 $newpath");
        chmod 0755, $newpath;
    }
}

=item $deps->dir

Return the directory that the dependencies should be in.

=cut

sub dir {
    my $path = $INC{"RUM/BinDeps.pm"};
    my ($vol, $dir, $file) = File::Spec->splitpath($path);
    return File::Spec->catfile($dir);
}

=item $deps->blat

=item $deps->bowtie

=item $deps->mdust

Return the path to blat, bowtie, or mdust.

=cut

sub blat   { $_[0]->_path("blat") }
sub bowtie { $_[0]->_path("bowtie") }
sub mdust  { $_[0]->_path("mdust") }

###
### Private methods
###

# Download the tarball that contains the binaries for this platform
# into a temporary directory, and return the directory.
sub _download_to_tmp_dir {

    my ($self) = @_;

    my $bin_tarball = $BIN_TARBALL_MAP{$^O}
        or croak "I don't have a binary tarball for this operating system ($^O)";
    my $url = "$BIN_TARBALL_URL_PREFIX/$bin_tarball";

    my $tmp_dir = tempdir(CLEANUP => 0);
    my $local = "$tmp_dir/$bin_tarball";

    $log->info("Downloading binary tarball $url to $local");

    download($url, $local);

    -e $local or croak "Didn't seem to download $url";
    system("tar -C $tmp_dir --strip-components 1 -xf $local") == 0
        or croak "Can't unpack $local";
    return $tmp_dir;
}

# Return the path to the file with the given name within my binary
# directory.
sub _path { 
    my ($self, $name) = @_;
    return File::Spec->catfile($self->dir, $name);
}
