package RUM::ChunkConfig;

use strict;
use warnings;
use Carp;
use FindBin qw($Bin);
FindBin->again;

sub new {
    my ($class, %options) = @_;
    my $self = {};


    my @required = qw(genome_bowtie reads chunk output_dir
                      transcriptome_bowtie paired_end read_length
                      bin_dir annotations genome_fa);

    my @optional = qw(min_overlap);

    for (@required) {
        my $val = delete $options{$_};
        croak "Need a value for $_" unless defined $val;
        $self->{$_} = $val;
    };

    return bless $self, $class;
    
}

sub bin { $_[0]->bin_dir . "/" . $_[1] }

sub script { "$Bin/../bin/" . $_[1] }

sub bin_dir { $_[0]->{bin_dir} }

sub output_dir { $_[0]->{output_dir} }

sub chunk { $_[0]->{chunk} }

sub bowtie_bin { $_[0]->bin("bowtie") }
sub blat_bin { $_[0]->bin("blat") }
sub mdust_bin { $_[0]->bin("mdust") }

sub genome_bowtie { shift->{genome_bowtie} }
sub genome_blat { shift->genome_fa }
sub genome_fa { shift->{genome_fa} }


sub transcriptome_bowtie { shift->{transcriptome_bowtie} }

sub annotations { shift->{annotations} }

sub reads_file { shift->{reads} }

sub chunk_suffixed { $_[0]->output_dir . "/" . $_[1] . "." . $_[0]->chunk }
sub chunk_replaced { $_[0]->output_dir . sprintf("/".$_[1], $_[0]->chunk) }

sub blat_output { shift->chunk_replaced("R.%d.blat") }
sub mdust_output { shift->chunk_replaced("R.%d.mdust") }

sub genome_bowtie_out { $_[0]->chunk_suffixed("X") }
sub transcriptome_bowtie_out { $_[0]->chunk_suffixed("Y") }
sub bowtie_unmapped { $_[0]->chunk_suffixed("R") }

sub gu  { $_[0]->chunk_suffixed("GU") }
sub tu  { $_[0]->chunk_suffixed("TU") }
sub gnu { $_[0]->chunk_suffixed("GNU") }
sub tnu { $_[0]->chunk_suffixed("TNU") }
sub cnu { $_[0]->chunk_suffixed("CNU") }

sub bowtie_unique { $_[0]->chunk_suffixed("BowtieUnique") }
sub bowtie_nu { $_[0]->chunk_suffixed("BowtieNU") }

sub paired_end_option { $_[0]->{paired_end} ? "--paired" : "--single" }

sub read_length { $_[0]->{read_length} }
sub min_overlap { $_[0]->{min_overlap} }

sub blat_options {
    # TODO: Allow me to be configured
    return "-minIdentity='93' -tileSize='12' -stepSize='6' -repMatch='256' -maxIntron='500000'";
}

1;
