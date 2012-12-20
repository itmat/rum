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
no warnings;
use autodie;

use FindBin qw($Bin);
use RUM::Repository::IndexSpec;
use RUM::ConfigFile;
use RUM::Index;
use Carp;
use File::Spec;
use File::Path qw(mkpath);
use File::Copy qw(cp);
use File::Temp qw(tempdir);
use Exporter qw(import);
use List::Util qw(first);
FindBin->again;

our @EXPORT_OK = qw(download);

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
    $self{bin_dir}        = delete $options{bin_dir};
    $self{organisms_file} = delete $options{organisms_file};

    my @extra = keys %options;
    croak "Unrecognized options to $class->new: @extra" if @extra;
    
    $self{root_dir}       ||= "$Bin/..";
    $self{conf_dir}       ||= "$self{root_dir}/conf";
    $self{indexes_dir}    ||= "$self{root_dir}/indexes";
    $self{bin_dir}        ||= "$self{root_dir}/bin";
    $self{organisms_file} ||= "$self{conf_dir}/organisms.txt";
    
    return bless \%self, $class;
}

=head2 Accessors

=over 4

=item $self->root_dir

=item $self->conf_dir

=item $self->indexes_dir

=item $self->bin_dir

=item $self->organisms_file

=back

=cut

sub root_dir       { $_[0]->{root_dir} }
sub conf_dir       { $_[0]->{conf_dir} }
sub indexes_dir    { $_[0]->{indexes_dir} }
sub bin_dir        { $_[0]->{bin_dir} }
sub organisms_file { $_[0]->{organisms_file} }

=head2 Querying and Modifying the Repository

=over 4

=item $self->fetch_organisms_file

Download the organisms file

=cut

sub fetch_organisms_file {
    my ($self) = @_;
    $self->mkdirs;
    my $file = $self->organisms_file;
    download($ORGANISMS_URL, $file);
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

=item $repo->index_dir($index_spec)

Return the directory where we should store files for the given
RUM::Repository::IndexSpec.

=cut

sub index_dir {
    my ($self, $index_spec) = @_;
    my $config_url = $self->config_url($index_spec) 
        or croak "Can't find the config file";
    my $name = $self->config_url_to_index_name($config_url) 
        or croak "Can't parse the index name from $config_url";
    return File::Spec->catfile($self->indexes_dir, $name);
}

=item $repo->config_url($index_spec)

Return the URL of the index config file for the given RUM::Repository::IndexSpec

=cut

sub config_url {
    my ($self, $index_spec) = @_;
    return first { $self->is_config_url($_) } $index_spec->urls;
}

=item $repo->index_urls

Return the list of index urls for the given RUM::Repository::IndexSpec.

=cut

sub index_urls {
    my ($self, $index_spec) = @_;
    return grep { ! $self->is_config_url($_) } $index_spec->urls;
}

=item $repo->install_index($index, $callback)

Install the given index. F<index> must be a
RUM::Repository::IndexSpec.  If $callback is provided it must be a
CODE ref, and it will be called for each URL we download. It's called
before the download begins with with ("start", $url), after the
download complets with ("end", $url).

=cut

sub install_index {
    my ($self, $index_spec, $callback) = @_;
    $self->mkdirs;

    my @urls = $index_spec->urls;

    my $config_file_url = $self->config_url($index_spec);
    my @index_urls      = $self->index_urls($index_spec);

    my $dir = $self->index_dir($index_spec);

    my $config_filename = File::Spec->catfile($dir, $RUM::Index::CONFIG_FILENAME) . ".old";

    mkpath $dir;
    download($config_file_url, $config_filename);
    open my $in, "<", $config_filename;
    my $config_file = RUM::ConfigFile->parse($in, quiet => 1);

    for my $url (@index_urls) {
        $callback->("start", $url) if $callback;
        my $path = $self->index_filename($index_spec, $url);
        download($url, $path);
        if ($path =~ /.gz$/) {
            system("gunzip -f $path") == 0 or die "Couldn't unzip $path";
        }
        $callback->("end", $url) if $callback;
    }
    
    my $gene_annotations = _basename($config_file->gene_annotation_file);
    my $genome_fasta = _basename($config_file->blat_genome_index);
    my $bowtie_genome_index = _basename($config_file->bowtie_genome_index);
    my $bowtie_gene_index = _basename($config_file->bowtie_gene_index);

    $genome_fasta =~ s/\.gz$//;

    print "Determining the size of the genome.\n";
    
    my $index = RUM::Index->new(
        directory => $dir,
        gene_annotations => $gene_annotations,
        genome_fasta => $genome_fasta,
        bowtie_genome_index => $bowtie_genome_index,
        bowtie_transcriptome_index => $bowtie_gene_index,
        genome_build => $index_spec->build,
        common_name => $index_spec->common,
        latin_name => $index_spec->latin,
        genome_size => genome_size(File::Spec->catfile($dir, $genome_fasta))
    );

    $index->save;
    unlink $config_filename;
        
}

=item genome_size

Return an estimate of the size of the genome.

=cut

sub genome_size {
    my ($filename) = @_;

    my $gs1 = -s $filename;
    my $gs2 = 0;
    my $gs3 = 0;

    open my $in, "<", $filename;

    local $_;
    while (defined($_ = <$in>)) {
        next unless /^>/;
        $gs2 += length;
        $gs3 += 1;
    }

    return $gs1 - $gs2 - $gs3;
}

=item $repo->remove_index($index, $callback)

Removes the given index. F<index> must be a
RUM::Repository::IndexSpec.  If $callback is provided it must be a
CODE ref, and it will be called for each file we remove. It's called
before the remove begins with with ("start", $filename), after the
download completes with ("end", $filename).

=cut

sub remove_index {
    my ($self, $index_spec, $callback) = @_;
    for my $url ($self->index_urls($index_spec)) {
        my $filename = $self->index_filename($index_spec, $url);
        if (-e $filename) {
            $callback->("start", $filename) if $callback;
            unlink $filename or croak "rm $filename: $!";
            $callback->("end", $filename) if $callback;
        }
    }

    my $filename = $self->config_filename($index_spec);
    
    if (-e $filename) {
        $callback->("start", $filename) if $callback;
        unlink $filename or croak "rm $filename: $!";
        $callback->("end", $filename) if $callback;
    }
    
    my $dir = $self->index_dir($index_spec);
    rmdir $dir if -d $dir;
}


=item $repo->index_filename($url) 

Return the local filename for the given URL.

=cut

sub index_filename {
    my ($self, $index_spec, $url) = @_;
    my $config_url = $self->config_url($index_spec);
    my $name = $self->config_url_to_index_name($config_url);
    my ($vol, $dir, $file) = File::Spec->splitpath($url);
    return File::Spec->catfile($self->indexes_dir, $name, $file);
}

=item $repo->config_url_to_index_name($url)

Parse the index name out of the given url and return it.

=cut

sub config_url_to_index_name {
    my ($self, $filename) = @_;

    if ($filename =~ /\/rum.config_(.*)$/) {
        return $1;
    }
    return undef;
}

=item $repo->is_config_url($filename)

Return true if the given $filename seems to be a configuration file
(rum.config_*), false otherwise.

=cut

sub is_config_url {
    my ($self, $filename) = @_;
    return $self->config_url_to_index_name($filename);
}

=item $repo->local_filenames($index)

Return all the local filenames for the given index.

=cut

sub local_filenames {
    my ($self, $index) = @_;
    return map { $self->index_filename($index, $_) } $index->urls;
}

=item $repo->config_filename($index)

Return the configuration file name for the given index.

=cut

sub config_filename {
    my ($self, $index_spec) = @_;

    my $config_file_url = $self->config_url($index_spec);
    my $dir = $self->index_dir($index_spec);

    return File::Spec->catfile($dir, $RUM::Index::CONFIG_FILENAME);
}

=item $repo->genome_fasta_filename($index)

Return the genome fasta file name for the given index.

=cut

sub genome_fasta_filename {
    my ($self, $index) = @_;
    my @filenames = grep { 
        /genome_one-line-seqs.fa/ 
    } $self->local_filenames($index);
    croak "I can't find exactly one genome fasta filename"
        unless @filenames == 1;
    $filenames[0] =~ s/\.gz$//;

    return $filenames[0];
}

=item $repo->has_index($index)

Return a true value if the index exists in this repository, false otherwise.

=cut

sub has_index {
    my ($self, $index) = @_;
    my @index_urls  = $self->index_urls($index);
    my @files = map { $self->index_filename($index, $_) } @index_urls;
#    print "@files are @files\n";
    for (@files) {
        s/\.gz$//;
    }
    my @missing = grep { not -e } @files;
    return !@missing;
}

=item $repo->mkdirs()

Make any directories the repository needs.

=cut

sub mkdirs {
    my ($self) = @_;
    my @dirs = ($self->root_dir,
                $self->conf_dir,
                $self->indexes_dir,
                $self->bin_dir);
    for my $dir (@dirs) {
        unless (-d $dir) {
            mkdir $dir or croak "mkdir $dir: $!";
        }
    }
}

=item $repo->setup()

Make any directories that need to be created, and download the
organisms.txt file if necessary.

=cut

sub setup {
    my ($self) = @_;
    $self->mkdirs();
    $self->fetch_organisms_file();
    return $self;
}

=item download($url, $local)

Attempt to download the file from the given $url to the given $local
path.

=cut

sub download {
    my ($url, $local) = @_;
    my $cmd;

    if (system("which wget > /dev/null") == 0) {
        $cmd = "wget -q -O $local $url";
    }
    elsif (system("which curl > /dev/null") == 0) {
        $cmd = "curl -s -o $local $url";
    }
    elsif (system("which ftp > /dev/null") == 0) {
        $cmd = "ftp -o $local $url";
    }
    else {
        croak "I can't find ftp, wget, or curl on your path; ".
            "please install one of those programs.";
    }
    system($cmd) == 0 or croak "Error running $cmd: $!";
}

=back

=head1 AUTHOR

Mike DeLaurentis (delaurentis@gmail.com)

=head1 COPYRIGHT

Copyright 2012 University of Pennsylvania

=cut

sub _basename {
    my ($path) = @_;
    my ($vol, $dir, $file) = File::Spec->splitpath($path);
    return $file;
}



1;
