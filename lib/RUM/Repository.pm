package RUM::Repository;

use strict;
use warnings;

use FindBin qw($Bin);
use LWP::Simple;
use RUM::Config qw(parse_organisms);
use Carp;
use File::Spec;

FindBin->again;

our $ORGANISMS_URL = "http://itmat.rum.s3.amazonaws.com/organisms.txt";

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

sub root_dir       { $_[0]->{root_dir} }
sub conf_dir       { $_[0]->{conf_dir} }
sub indexes_dir    { $_[0]->{indexes_dir} }
sub organisms_file { $_[0]->{organisms_file} }

sub fetch_organisms_file {
    my ($self) = @_;
    my $file = $self->organisms_file;
    my $status = getstore($ORGANISMS_URL, $file);
    croak "Couldn't download organisms file from $ORGANISMS_URL " .
        "to $file" unless is_success($status);
    return $self;
}

sub organisms {
    my ($self) = @_;
    my $filename = $self->organisms_file;
    open my $orgs, "<", $filename
        or croak "Can't open $filename for reading: $!";
    my @orgs = parse_organisms($orgs);    
}

sub find_indexes {
    my ($self, $pattern) = @_;

    my $re = qr/$pattern/i;

    return grep {
        $_->{common} =~ /$re/ || $_->{build} =~ /$re/ || $_->{latin} =~ /$re/
    } $self->organisms;
}

sub install_index {
    my ($self, $build_name) = @_;
    my @orgs = parse_organisms($self->{organisms_file});
}

sub have_index {
    my ($self, $number) = @_;
 
}

sub index_filename {
    my ($self, $url) = @_;
    my $path = URI->new($url)->path;
    my ($vol, $dir, $file) = File::Spec->splitpath($path);
    return File::Spec->catdir($self->indexes_dir, $file);
}

sub download_index_file {
    my ($self, $url) = @_;
    my $filename = $self->index_filename($url);
    my $status = getstore($url, $filename);
    croak "Couldn't download index file from $url " .
        "to $filename: $status" unless is_success($status);
}

sub remove_index_file {
    my ($self, $url) = @_;
    my $filename = $self->index_filename($url);
    if (-e $filename) {
        unlink $filename or croak "rm $filename: $!";
    }
}


