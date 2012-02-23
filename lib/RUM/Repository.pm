package RUM::Repository;

=head1 NAME

RUM::Repository - Models a local repository of RUM indexes

=head1 SYNOPSIS

  use RUM::Repository;

  my $repo = RUM::Repository->new();

  # Get the root, config, and indexes directories for this repo.
  my $root    = $repo->root_dir;
  my $conf    = $repo->conf_dir;
  my $indexes = $repo->indexes_dir;

  # Download the organisms.txt file for this repo
  $repo->fetch_organisms_file;

  # Get a list of available organisms
  $repo->organisms;

  # Get a list of organisms whose build name, common name, or latin
  # name match a pattern.
  my @hg19 = $repo->find_indexes("hg19");
  my @rat = $repo->find_indexes("rat");
  my @homosapiens = $repo->find_indexes("homo sapiens");

=cut

use strict;
use warnings;

use FindBin qw($Bin);
use LWP::Simple;
use RUM::Repository::IndexSpec;
use Carp;
use File::Spec;

FindBin->again;

our $ORGANISMS_URL = "http://itmat.rum.s3.amazonaws.com/organisms.txt";

=head1 DESCRIPTION

=head2 Constructor

=over 4

=item $repo->new(%options)

Create a new repository. You can use %options to configure the
locations of the directories, but this is not necessary. It will
default to using the index and conf directories relative to the
location of the executable. The following keys are allowable for options:

=over 4

=item B<root_dir>

Use this directory as the root. If B<conf_dir> or B<indexes_dir> are
not supplied, I'll use "$ROOT/conf" and "$ROOT/indexes".

=item B<conf_dir>

Put put the configuration files in this directory.

=item B<indexes_dir>

Put the index files in this directory.

=item B<organisms_file>

Put the organisms file here.

=back

=back

=cut

sub new {
    my ($class, %options) = @_;

    my %self;

    $self{root_dir}       = delete $options{root_dir};    
    $self{conf_dir}       = delete $options{conf_dir};
    $self{indexes_dir}    = delete $options{indexes_dir};
    $self{organisms_file} = delete $options{organisms_file};

    my @extra = keys %options;
    croak "Unrecognized options to $class->new: @extra" if @extra;
    
    $self{root_dir}       ||= "$Bin/..";
    $self{conf_dir}       ||= "$self{root_dir}/conf";
    $self{indexes_dir}    ||= "$self{root_dir}/indexes";
    $self{organisms_file} ||= "$self{conf_dir}/organisms.txt";
    
    return bless \%self, $class;
}

=head2 Accessors

=over 4

=item $self->root_dir

=item $self->conf_dir

=item $self->indexes_dir

=item $self->organisms_file

=back

=cut

sub root_dir       { $_[0]->{root_dir} }
sub conf_dir       { $_[0]->{conf_dir} }
sub indexes_dir    { $_[0]->{indexes_dir} }
sub organisms_file { $_[0]->{organisms_file} }

=head2 Querying and Modifying the Repository

=over 4

=item $self->fetch_organisms_file

Download the organisms file

=cut

sub fetch_organisms_file {
    my ($self) = @_;
    my $file = $self->organisms_file;
    my $status = getstore($ORGANISMS_URL, $file);
    croak "Couldn't download organisms file from $ORGANISMS_URL " .
        "to $file" unless is_success($status);
    return $self;
}

=item $self->indexes

Get a list of available indexes (RUM::Repository::IndexSpec
objects). You can optionally provide a 'pattern' option that will
cause the results to be filtered to include only indexes whose build
name, common name, or latin name match the specified pattern.

  # Get all indexes
  $self->indexes;

  # Should return the mouse index
  $self->indexes(pattern => qr/mm9/);

  # Should return any 'human' indexes
  $self->indexes(pattern => qr/human/);

=cut

sub indexes {
    my ($self, %query) = @_;
    my $filename = $self->organisms_file;
    open my $orgs, "<", $filename
        or croak "Can't open $filename for reading: $!";
    my @orgs = RUM::Repository::IndexSpec->parse($orgs);

    if ($query{pattern}) {
        my $re = qr/$query{pattern}/i;

        return grep {
            $_->common =~ /$re/ || $_->build =~ /$re/ || $_->latin =~ /$re/
        } @orgs;
    }

    return @orgs;
}

=item $repo->install_index($index, $callback)

Install the given index. F<index> must be a
RUM::Repository::IndexSpec.  If $callback is provided it must be a
CODE ref, and it will be called for each URL we download. It's called
before the download begins with with ("start", $url), after the
download complets with ("end", $url).

=cut

sub install_index {
    my ($self, $index, $callback) = @_;
    for my $url ($index->files) {
        $callback->("start", $url) if $callback;
        my $filename = $self->index_filename($url);
        my $status = getstore($url, $filename);
        croak "Couldn't download index file from $url " .
            "to $filename: $status" unless is_success($status);
        $callback->("end", $url) if $callback;
    }
}

=item $repo->install_index($index, $callback)

Removes the given index. F<index> must be a
RUM::Repository::IndexSpec.  If $callback is provided it must be a
CODE ref, and it will be called for each file we remove. It's called
before the remove begins with with ("start", $filename), after the
download completes with ("end", $filename).

=cut

sub remove_index {
    my ($self, $index, $callback) = @_;
    for my $url ($index->files) {
     
        my $filename = $self->index_filename($url);
        if (-e $filename) {
            $callback->("start", $filename) if $callback;
            unlink $filename or croak "rm $filename: $!";
            $callback->("end", $filename) if $callback;
        }
    }
}


=item $repo->index_filename($url) 

Return the local filename for the given URL.

=cut

sub index_filename {
    my ($self, $url) = @_;
    my $path = URI->new($url)->path;
    my ($vol, $dir, $file) = File::Spec->splitpath($path);
    my $subdir = $file =~ /rum.config/ ? $self->conf_dir : $self->indexes_dir;
    return File::Spec->catdir($subdir, $file);
}

