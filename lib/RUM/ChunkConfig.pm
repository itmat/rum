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
                      bin_dir annotations genome_fa
                      match_length_cutoff max_insertions);

    my @optional = qw(min_overlap);

    for (@required) {
        my $val = delete $options{$_};
        croak "Need a value for $_" unless defined $val;
        $self->{$_} = $val;
    };

    return bless $self, $class;
}

# Utilities for modifying a filename

sub bin { $_[0]->bin_dir . "/" . $_[1] }
sub script { "$Bin/../bin/" . $_[1] }
sub chunk_suffixed { $_[0]->output_dir . "/" . $_[1] . "." . $_[0]->{chunk} }
sub chunk_replaced { $_[0]->output_dir . sprintf("/".$_[1], $_[0]->{chunk}) }

# Directory and executable locations

sub bin_dir    { $_[0]->{bin_dir} }
sub output_dir { $_[0]->{output_dir} }
sub bowtie_bin { $_[0]->bin("bowtie") }
sub blat_bin   { $_[0]->bin("blat") }
sub mdust_bin  { $_[0]->bin("mdust") }

# The raw input for the job

sub genome_bowtie { $_[0]->{genome_bowtie} }
sub genome_blat   { $_[0]->genome_fa }
sub genome_fa     { $_[0]->{genome_fa} }
sub trans_bowtie  { $_[0]->{transcriptome_bowtie} }
sub annotations   { $_[0]->{annotations} }
sub reads_file    { $_[0]->{reads} }

# These functions return options that the user can control.

sub read_length             { $_[0]->{read_length} }
sub min_overlap             { $_[0]->{min_overlap} }
sub max_insertions          { $_[0]->{max_insertions} }
sub match_length_cutoff     { $_[0]->{match_length_cutoff} }
sub limit_nu_cutoff         { $_[0]->{limit_nu_cutoff} }

sub read_length_opt         { ("--read-length",         $_[0]->read_length) }
sub min_overlap_opt         { ("--min-overlap",         $_[0]->min_overlap) }
sub max_insertions_opt      { ("--max-insertions",      $_[0]->max_insertions) }
sub match_length_cutoff_opt { ("--match-length-cutoff", $_[0]->match_length_cutoff) }
sub limit_nu_cutoff_opt     { ("--limit-nu",            $_[0]->limit_nu_cutoff) }
sub faok_opt                { $_[0]->{faok} ? "--faok" : ":" }
sub count_mismatches_opt    { $_[0]->{count_mismatches} ? "--count-mismatches" : "" } 
sub paired_end_opt          { $_[0]->{paired_end} ? "--paired" : "--single" }
sub dna_opt                 { $_[0]->{dna} ? "--dna" : "" }

sub blat_opts {
    # TODO: Allow me to be configured
    return "-minIdentity='93' -tileSize='12' -stepSize='6' -repMatch='256' -maxIntron='500000'";
}

# These functions return filenames that are named uniquely for this
# chunk.

sub genome_bowtie_out  { $_[0]->chunk_suffixed("X") }
sub trans_bowtie_out   { $_[0]->chunk_suffixed("Y") }
sub bowtie_unmapped    { $_[0]->chunk_suffixed("R") }
sub blat_unique        { $_[0]->chunk_suffixed("BlatUnique") }
sub blat_nu            { $_[0]->chunk_suffixed("BlatNU") }
sub gu                 { $_[0]->chunk_suffixed("GU") }
sub tu                 { $_[0]->chunk_suffixed("TU") }
sub gnu                { $_[0]->chunk_suffixed("GNU") }
sub tnu                { $_[0]->chunk_suffixed("TNU") }
sub cnu                { $_[0]->chunk_suffixed("CNU") }
sub blat_output        { $_[0]->chunk_replaced("R.%d.blat") }
sub mdust_output       { $_[0]->chunk_replaced("R.%d.mdust") }
sub bowtie_unique      { $_[0]->chunk_suffixed("BowtieUnique") }
sub bowtie_nu          { $_[0]->chunk_suffixed("BowtieNU") }
sub bowtie_blat_unique { $_[0]->chunk_suffixed("RUM_Unique_temp") }
sub bowtie_blat_nu     { $_[0]->chunk_suffixed("RUM_NU_temp") }
sub cleaned_unique     { $_[0]->chunk_suffixed("RUM_Unique_temp2") }
sub cleaned_nu         { $_[0]->chunk_suffixed("RUM_NU_temp2") }
sub sam_header         { $_[0]->chunk_suffixed("sam_header") }
sub rum_nu_id_sorted   { $_[0]->chunk_suffixed("RUM_NU_idsorted") }
sub rum_nu_deduped     { $_[0]->chunk_suffixed("RUM_NU_temp3") }
sub rum_nu             { $_[0]->chunk_suffixed("RUM_NU") }
sub rum_unique         { $_[0]->chunk_suffixed("RUM_Unique") }
sub quals_file         { $_[0]->chunk_suffixed("quals") }


1;
