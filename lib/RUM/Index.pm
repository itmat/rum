package RUM::Index;

use strict;
use warnings;
use autodie;

use Carp;
use Data::Dumper;

our @FIELDS = qw(
                    directory
                    
                    gene_annotations
                    bowtie_genome_index
                    bowtie_transcriptome_index
                    genome_fasta

                    common_name
                    latin_name
                    genome_build
                    genome_size
            );

our $CONFIG_FILENAME = "rum_index.conf";

sub load {
    my ($class, $dir) = @_;

    my $filename = File::Spec->catfile($dir, $CONFIG_FILENAME);

    my $map = do $filename or croak "Couldn't load index config from $filename";

    return $class->new(%{ $map }, directory => $dir);
}

sub new {
    my ($class, %options) = @_;
    
    my $self = {};

    for my $key (@FIELDS) {
        if (exists ($options{$key})) {
            $self->{$key} = delete $options{$key};
        }
    }

    return bless $self, $class;
}

sub _in_my_dir { 
    my ($self, $file) = @_;
    return File::Spec->catfile($self->directory, $file);
}

sub gene_annotations           { $_[0]->_in_my_dir($_[0]->{gene_annotations}) }
sub bowtie_genome_index        { $_[0]->_in_my_dir($_[0]->{bowtie_genome_index}) }
sub bowtie_transcriptome_index { $_[0]->_in_my_dir($_[0]->{bowtie_transcriptome_index}) }
sub genome_fasta               { $_[0]->_in_my_dir($_[0]->{genome_fasta}) }
sub genome_size                { $_[0]->{genome_size} }
sub directory                  { $_[0]->{directory} }
sub config_filename            { File::Spec->catfile($_[0]->directory, $CONFIG_FILENAME) }

sub save {
    my ($self) = @_;
    
    local $_;
    for (@FIELDS) {
        $self->{$_} or croak "Can't save index config without $_";
    }

    open my $out, ">", $self->config_filename;
    my %map = %{ $self };
    delete $map{directory};
    print $out Dumper(\%map);
    close $out;
}

1;
