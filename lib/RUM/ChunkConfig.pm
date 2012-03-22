package RUM::ChunkConfig;

use strict;
use warnings;
use Carp;
use FindBin qw($Bin);
use RUM::Logging;
our $log = RUM::Logging->get_logger;
FindBin->again;

our $CONFIG_DESC = <<EOF;
The following describes the configuration file:

Note: All entries can be absolute path, or relative path to where RUM
is installed.

1) gene annotation file, can be absolute, or relative to where RUM is installed
   e.g.: indexes/mm9_ucsc_refseq_gene_info.txt

2) bowtie executable, can be absolute, or relative to where RUM is installed
   e.g.: bowtie/bowtie

3) blat executable, can be absolute, or relative to where RUM is installed
   e.g.: blat/blat

4) mdust executable, can be absolute, or relative to where RUM is installed
   e.g.: mdust/mdust

5) bowtie genome index, can be absolute, or relative to where RUM is installed
   e.g.: indexes/mm9

6) bowtie gene index, can be absolute, or relative to where RUM is installed
   e.g.: indexes/mm9_genes_ucsc_refseq

7) blat genome index, can be absolute, or relative to where RUM is installed
   e.g. indexes/mm9_genome_sequence_single-line-seqs.fa

8) [DEPRECATED] perl scripts directory. This is now ignored, and this script
    will use $Bin/../bin

9) [DEPRECATED] lib directory. This is now ignored, and this script will use
    $Bin/../lib
EOF



sub new {
    my ($class, %options) = @_;
    my $self = {};

    # TODO: Add read_length, match_length_cutoff
    my @required = qw(forward chunk output_dir paired_end 
                      match_length_cutoff max_insertions);

    open my $config_in, "<", $options{config_file}
        or croak "Can't open $options{config_file} for reading: $!";

    $self->{annotations} = read_config_path($config_in);
    unless ($self->{dna}) {
        -e $self->{annotations} or
            die("the file '$self->{annotations}' does not seem to exist.");
    }

    $self->{bowtie_bin} = read_config_path($config_in);
    -e $self->{bowtie_bin} or die("the executable '$self->{bowtie_bin}' does not seem to exist.");

    $self->{blat_bin} = read_config_path($config_in);
    -e $self->{blat_bin} or die("the executable '$self->{blat_bin}' does not seem to exist.");

    $self->{mdust_bin} = read_config_path($config_in);
    -e $self->{mdust_bin} or die("the executable '$self->{mdust_bin}' does not seem to exist.");

    $self->{genome_bowtie} = read_config_path($config_in);
    $self->{transcriptome_bowtie} = read_config_path($config_in);
    $self->{genome_fa} = read_config_path($config_in);

    -e $self->{genome_fa} or die("the file '$self->{genome_fa}' does not seem to exist.");
    
    my @optional = qw(min_overlap);

    for (@required) {
        my $val = delete $options{$_};
        croak "Need a value for $_" unless defined $val;
        $self->{$_} = $val;
    };

    # TODO: combine forward and reverse reads?
    $self->{reads} = $self->{forward};

    return bless $self, $class;
}

# Reads a path from the config file and returns it, making sure it's
# an absolute path. If it's specified as a relative path, we turn it
# into an absolute path by prepending the root directory of the RUM
# installation to it.
sub read_config_path {

    my ($in) = @_;
    my $maybe_rel_path = <$in>;
    unless (defined($maybe_rel_path)) {
        $log->info($CONFIG_DESC);
        die("The configuration file seems to be missing some lines. Please see the instructions for the configuration file above.");
    }
    chomp $maybe_rel_path;
    my $root = "$Bin/../";
    my $abs_path = File::Spec->rel2abs($maybe_rel_path, $root);
    return $abs_path;
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

sub opt {
    my ($self, $opt, $arg) = @_;
    return defined($arg) ? ($opt, $arg) : "";
}

sub read_length_opt         { $_[0]->opt("--read-length", $_[0]->read_length) }
sub min_overlap_opt         { $_[0]->opt("--min-overlap", $_[0]->min_overlap) }
sub max_insertions_opt      { $_[0]->opt("--max-insertions", $_[0]->max_insertions) }
sub match_length_cutoff_opt { $_[0]->opt("--match-length-cutoff", $_[0]->match_length_cutoff) }
sub limit_nu_cutoff_opt     { $_[0]->opt("--limit-nu", $_[0]->limit_nu_cutoff) }
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
sub sam_file           { $_[0]->chunk_suffixed("RUM.sam") }
sub nu_stats           { $_[0]->chunk_suffixed("nu_stats") }
sub rum_unique_sorted  { $_[0]->chunk_suffixed("RUM_Unique.sorted") }
sub rum_nu_sorted      { $_[0]->chunk_suffixed("RUM_Unique.sorted") }

sub chr_counts_u       { $_[0]->chunk_suffixed("chr_counts_u") }
sub chr_counts_nu      { $_[0]->chunk_suffixed("chr_counts_nu") }

sub state_dir { $_[0]->chunk_replaced("state-%03d") }

sub quant {
    my ($self, $strand, $sense) = @_;
    return $self->chunk_suffixed("quant.$strand$sense");
}


# TODO: Maybe support name mapping?
sub name_mapping_opt   { "" } 
1;
