package RUM::Index;

=head1 NAME

RUM::Index - Configuration for a RUM index

=head1 SYNOPSIS

  use RUM::Index

  my $index = RUM::Index->load("indexes/mm9");

  my $genes = $index->gene_annotations;
  my $genome = $index->genome_fasta;
  my $bowtie_genome_index = $index->bowtie_genome_index;
  my $bowtie_transcriptome_index = $index->bowtie_transcriptome_index;

=head1 CONSTRUCTORS

=over 4

=cut

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

=item RUM::Index->load($dir)

Load "$dir/rum_index.conf" and return it as a new RUM::Index.

=cut

sub load {
    my ($class, $dir) = @_;

    my $filename = File::Spec->catfile($dir, $CONFIG_FILENAME);

    my $map = do $filename or die "There is no RUM index at $dir. Has the index moved from its original location?\n";
    return $class->new(%{ $map }, directory => $dir);
}

=item RUM::Index->new(%options)

Create a new RUM::Index with the following fields:

=over 4

=item directory

=item gene_annotations

=item bowtie_genome_index

=item bowtie_transcriptome_index

=item genome_fasta

=item common_name

=item latin_name

=item genome_build

=item genome_size

=back

=cut

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

=back

=head1 OBJECT METHODS

=head2 Properties

These methods just return simple attributes of the index:

=over 4

=item $index->bowtie_genome_index

=item $index->bowtie_transcriptome_index

=item $index->config_filename

=item $index->directory

=item $index->gene_annotations

=item $index->genome_fasta

=item $index->genome_size

=back

=cut

sub gene_annotations           { $_[0]->_in_my_dir($_[0]->{gene_annotations}) }
sub bowtie_genome_index        { $_[0]->_in_my_dir($_[0]->{bowtie_genome_index}) }
sub bowtie_transcriptome_index { $_[0]->_in_my_dir($_[0]->{bowtie_transcriptome_index}) }
sub genome_fasta               { $_[0]->_in_my_dir($_[0]->{genome_fasta}) }
sub genome_size                { $_[0]->{genome_size} }
sub directory                  { $_[0]->{directory} }
sub config_filename            { File::Spec->catfile($_[0]->directory, $CONFIG_FILENAME) }

=head2 Other Methods

=over 4

=item $index->save

Save the index in the file pointed to by $index->config_filename.

=cut

sub save {
    my ($self) = @_;
    
    local $_;
    for (@FIELDS) {
        $self->{$_} or croak "Can't save index config without $_"
            unless /common|latin|build/;
    }

    open my $out, ">", $self->config_filename;
    my %map = %{ $self };
    delete $map{directory};
    print $out Dumper(\%map);
    close $out;
}

sub _in_my_dir { 
    my ($self, $file) = @_;
    return File::Spec->catfile($self->directory, $file);
}

1;

=back

=cut
