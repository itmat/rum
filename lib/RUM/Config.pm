package RUM::Config;

use strict;
use warnings;
use Carp;
use FindBin qw($Bin);
use RUM::Logging;
use File::Spec;
use Data::Dumper;

our $AUTOLOAD;
our $log = RUM::Logging->get_logger;
FindBin->again;

=head1 NAME

RUM::Config - Configuration for a RUM job

=cut

our @LITERAL_PROPERTIES = qw (forward chunk output_dir paired_end
 match_length_cutoff num_chunks bin_dir genome_bowtie
 genome_fa transcriptome_bowtie annotations num_chunks read_length
 min_overlap max_insertions match_length_cutoff limit_nu_cutoff
 preserve_names variable_length_reads config_file
 bowtie_bin mdust_bin blat_bin trans_bowtie min_length reads
 input_needs_splitting
 input_is_preformatted
 count_mismatches
 argv
 rum_config_file
 name
 min_identity
 nu_limit
 alt_genes
 alt_quant
 dna
 genome_only
 cleanup
 junctions
 ram
 strand_specific
 user_quals
 mapping_stats
 quantify
 alt_quant_model
 novel_inferred_internal_exons_quantifications
 bowtie_nu_limit
    blat_min_identity
blat_tile_size
blat_step_size
blat_rep_match
blat_max_intron
                         );

our %CHUNK_SUFFIXED_PROPERTIES = (
    genome_bowtie_out  => "X",
    trans_bowtie_out   => "Y",
    bowtie_unmapped    => "R",
    blat_unique        => "BlatUnique",
    blat_nu            => "BlatNU",
    gu                 => "GU",
    tu                 => "TU",
    gnu                => "GNU",
    tnu                => "TNU",
    cnu                => "CNU",
    bowtie_unique      => "BowtieUnique",
    bowtie_nu          => "BowtieNU",
    bowtie_blat_unique => "RUM_Unique_temp",
    bowtie_blat_nu     => "RUM_NU_temp",
    cleaned_unique     => "RUM_Unique_temp2",
    cleaned_nu         => "RUM_NU_temp2",
    sam_header         => "sam_header",
    rum_nu_id_sorted   => "RUM_NU_idsorted",
    rum_nu_deduped     => "RUM_NU_temp3",
    rum_nu             => "RUM_NU",
    rum_unique         => "RUM_Unique",
    quals_file         => "quals",
    sam_file           => "RUM.sam",
    nu_stats           => "nu_stats",
    rum_unique_sorted  => "RUM_Unique.sorted",
    rum_nu_sorted      => "RUM_NU.sorted",
    chr_counts_u       => "chr_counts_u",
    chr_counts_nu      => "chr_counts_nu",
    reads_fa           => "reads.fa",
    quals_fa           => "quals.fa",
    log_file           => "rum.log",
    error_log_file     => "rum-errors.log",
    mapping_stats         => "mapping_stats.txt",
    junctions_all_rum => "junctions_all.rum",
    junctions_all_bed => "junctions_all.bed",
    "junctions_high_quality_bed" => "junctions_high-quality.bed",
    rum_unique_cov => "RUM_Unique.cov",
    rum_nu_cov => "RUM_nu.cov",
    u_footprint => "u_footprint",
    nu_footprint => "nu_footprint",
    inferred_internal_exons => "inferred_internal_exons.bed",
);

our %DEFAULTS = (
    num_chunks            => 0,
    preserve_names        => 0,
    variable_length_reads => 0,
    min_length            => undef,
    min_overlap           => undef,
    max_insertions        => undef,
    match_length_cutoff   => undef,
    limit_nu_cutoff       => undef,
    nu_limit              => undef,
    chunk                 => undef,
    bowtie_nu_limit       => undef
);

=head1 CONSTRUCTOR

=over 4

=item new(%options)

Create a new RUM::Config with the given options.

=back

=cut

sub new {
    my ($class, %options) = @_;
    my %data = %DEFAULTS;
    
    for (@LITERAL_PROPERTIES) {
        if (exists $options{$_}) {
            $data{$_} = delete $options{$_};
        }
    }
    
    if (my @extra = keys(%options)) {
        croak "Extra arguments to Config->new: @extra";
    }

    return bless \%data, $class;
}



sub variable_read_lengths {
    $_[0]->variable_length_reads
}

sub load_rum_config_file {
    my ($self) = @_;
    my $path = $self->rum_config_file or croak
        "No RUM config file was supplied";
    open my $in, "<", $path or croak "Can't open config file $path: $!";
    my $cf = RUM::ConfigFile->parse($in);
    $cf->make_absolute;
    my %data;
    $data{annotations}   = $cf->gene_annotation_file;
    $data{bowtie_bin}    = $cf->bowtie_bin;
    $data{blat_bin}      = $cf->blat_bin;
    $data{mdust_bin}     = $cf->mdust_bin;
    $data{genome_bowtie} = $cf->bowtie_genome_index;
    $data{trans_bowtie}  = $cf->bowtie_gene_index;
    $data{genome_fa}     = $cf->blat_genome_index;

    -e $data{annotations} || $self->dna or die
        "the file '$data{annotations}' does not seem to exist.";         

    -e $data{bowtie_bin} or die
        "the executable '$data{bowtie_bin}' does not seem to exist.";

    -e $data{blat_bin} or die
        "the executable '$data{blat_bin}' does not seem to exist.";

    -e $data{mdust_bin} or die
        "the executable '$data{mdust_bin}' does not seem to exist.";        

    -e $data{genome_fa} or die
        "the file '$data{genome_fa}' does not seem to exist.";
    
    $self->set("config_file", $path);
    local $_;
    for (keys %data) {
        $self->set($_, $data{$_});
    }
    
}

sub for_chunk {
    my ($self, $chunk) = @_;
    my %options = %{ $self };
    $options{chunk} = $chunk;

    return __PACKAGE__->new(%options);
}

# Utilities for modifying a filename

sub script {
    return File::Spec->catfile("$Bin/../bin", $_[1]);
}

sub in_output_dir {
    my ($self, $file) = @_;
    my $dir = $self->output_dir;
    return $dir ? File::Spec->catfile($dir, $file) : $file;
}

sub chunk_suffixed { 
    my ($self, $file) = @_;
    my $chunk = $self->chunk;
    return $self->in_output_dir(defined($chunk) ? "$file.$chunk" : $file);
}

sub chunk_replaced {
    my ($self, $format) = @_;
    return $self->in_output_dir(sprintf($format, $self->chunk || 0));
}

# These functions return options that the user can control.

sub opt {
    my ($self, $opt, $arg) = @_;
    return defined($arg) ? ($opt, $arg) : "";
}

sub read_length_opt         { $_[0]->opt("--read-length", $_[0]->read_length) }
sub min_overlap_opt         { $_[0]->opt("--min-overlap", $_[0]->min_overlap) }
sub max_insertions_opt      { $_[0]->opt("--max-insertions", $_[0]->max_insertions) }
sub match_length_cutoff_opt { $_[0]->opt("--match-length-cutoff", $_[0]->match_length_cutoff) }
sub limit_nu_cutoff_opt     { $_[0]->opt("--cutoff", $_[0]->nu_limit) }
sub bowtie_cutoff_opt       { my $x = $_[0]->bowtie_nu_limit; $x ? "-k $x" : "-a" }
sub faok_opt                { $_[0]->{faok} ? "--faok" : ":" }
sub count_mismatches_opt    { $_[0]->{count_mismatches} ? "--count-mismatches" : "" } 
sub paired_end_opt          { $_[0]->{paired_end} ? "--paired" : "--single" }
sub dna_opt                 { $_[0]->{dna} ? "--dna" : "" }

sub blat_opts {
    # TODO: Allow me to be configured
    my ($self) = @_;
    my %opts = (
        minIdentity => $self->blat_min_identity,
        tileSize => $self->blat_tile_size,
        stepSize => $self->blat_step_size,
        repMatch => $self->blat_rep_match,
        maxIntron => $self->blat_max_intron);

    return join(" ", map("-$_='$opts{$_}'", sort keys %opts));
}

# These functions return filenames that are named uniquely for this
# chunk.

sub blat_output  { $_[0]->chunk_replaced("R.%d.blat") }
sub mdust_output { $_[0]->chunk_replaced("R.%d.mdust") }

sub state_dir { $_[0]->chunk_replaced("state-%03d") }

# $quantify and $quantify_specified default to false
# Both set to true if --quantify is given
# $quantify set to true if --dna is not given
# If $genomeonly, $quantify set to $quantify_specified
# So quantify if 

sub quant {
    my $self = shift;
    my ($strand, $sense) = @_;
    if ($strand && $sense) {
        return $self->chunk_suffixed("quant.$strand$sense");
    }

    if ($self->chunk) {
        return $self->chunk_suffixed("quant");
    }
    return $self->chunk_suffixed("feature_quantifications_" . $self->name);
}

sub alt_quant {
    my $self = shift;
    my ($strand, $sense) = @_;
    if ($strand && $sense) {
        return $self->chunk_suffixed("feature_quantifications.altquant.$strand$sense");
    }
    return $self->chunk_suffixed("feature_quantifications_" . $self->name . ".altquant");
    
}

sub pipeline_sh { $_[0]->chunk_suffixed("pipeline.sh") }

# TODO: Maybe support name mapping?
sub name_mapping_opt   { "" } 

sub properties {
    (@LITERAL_PROPERTIES, keys %CHUNK_SUFFIXED_PROPERTIES, keys %DEFAULTS)
}

sub is_property {
    my $name = shift;
    grep { $name eq $_ } (@LITERAL_PROPERTIES, keys %CHUNK_SUFFIXED_PROPERTIES)
}

sub set {
    my ($self, $key, $value) = @_;
    confess "No such property $key" unless is_property($key);
    $self->{$key} = $value;
}

sub AUTOLOAD {
    my ($self) = @_;
    
    my @parts = split /::/, $AUTOLOAD;
    my $name = $parts[-1];
    
    return if $name eq "DESTROY";
    
    is_property($name) or croak "No such property $name";
    
    if ($CHUNK_SUFFIXED_PROPERTIES{$name}) {
        return $self->chunk_suffixed($CHUNK_SUFFIXED_PROPERTIES{$name});
    }
    exists $self->{$name} or croak "Property $name was not set";

    return $self->{$name};
}

sub should_quantify {
    my ($self) = @_;
    return !($self->dna || $self->genome_only) || $self->quantify;
}

sub should_do_junctions {
    my ($self) = @_;
    return !$self->dna || $self->genome_only || $self->junctions;
}

sub junctions_file {
    my ($self, $type, $strand) = @_;
    return $self->in_output_dir("junctions") ;
}

sub novel_inferred_internal_exons_quantifications {
    my ($self) = @_;
    return $self->in_output_dir("novel_inferred_internal_exons_quantifications_"
                                    .$self->name);
}

sub ram_opt {
    return $_[0]->ram == 6 ? "" : "--ram ".$_[0]->ram;
}

sub export {
    my ($self, $fh) = @_;
    print $fh Dumper($self);
}

1;
