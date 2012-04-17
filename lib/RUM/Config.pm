package RUM::Config;

use strict;
use warnings;

use Carp;
use FindBin qw($Bin);
use File::Spec;
use Data::Dumper;

use RUM::Logging;
use RUM::ConfigFile;

our $AUTOLOAD;
our $log = RUM::Logging->get_logger;
FindBin->again;

=head1 NAME

RUM::Config - Configuration for a RUM job

=cut

our %DEFAULTS = (
    platform => "Local",
    num_chunks => 1,
    ram => undef,
    ram_ok => 0,
    max_insertions => 1,
    strand_specific => 0,
    min_identity => 93,
    blat_min_identity => 93,
    blat_tile_size => 12,
    blat_step_size => 6,
    blat_rep_match => 256,
    blat_max_intron => 500000,

    output_dir => ".",
    name => "",
    rum_config_file => "",
    reads => undef,
    user_quals => undef,
    alt_genes => undef,
    alt_quant_model => undef,

    dna => 0,
    forward => undef,
    paired_end => 0,
    bin_dir => undef,
    genome_bowtie => undef,
    genome_fa => undef,
    transcriptome_bowtie => undef,
    annotations => undef,
    read_length => undef,
    config_file => undef,
    bowtie_bin => undef,
    mdust_bin => undef,
    blat_bin => undef,
    trans_bowtie => undef,
    input_needs_splitting => undef,
    input_is_preformatted => undef,
    count_mismatches => undef,
    argv => undef,
    alt_quant => undef,
    genome_only => 0,
    blat_only => 0,
    cleanup => 1,
    junctions => 0,
    mapping_stats => undef,
    quantify => 0,
    novel_inferred_internal_exons_quantifications => 0,

    # Old defaults
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

sub default {
    my ($class) = @_;
    return $class->new(%DEFAULTS);
}

=head1 CONSTRUCTOR

=over 4

=item new(%options)

Create a new RUM::Config with the given options.

=back

=cut

sub new {
    my ($class, %options) = @_;
    my %data = %DEFAULTS;
    
    for (keys %DEFAULTS) {
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

    return map("-$_=$opts{$_}", sort keys %opts);
}

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

sub is_property {
    my $name = shift;
    exists $DEFAULTS{$name};
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
    
    return $self->get($name);
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
    return $_[0]->ram ? "--ram ".$_[0]->ram : "";
}

sub save {
    my ($self) = @_;
    $log->debug("Saving config file, chunks is " . $self->num_chunks);
    my $filename = $self->in_output_dir("rum_job_config.pl");
    open my $fh, ">", $filename or croak "$filename: $!";
    print $fh Dumper($self);
}

sub load {
    my ($class, $dir) = @_;
    my $filename = "$dir/rum_job_config.pl";
    return unless -e $filename;
    my $conf = do $filename;
    ref($conf) =~ /$class/ or croak "$filename did not return a $class";
    return $conf;
}

sub get {
    my ($self, $name) = @_;
    is_property($name) or croak "No such property $name";
    
    exists $self->{$name} or croak "Property $name was not set";

    return $self->{$name};
}

sub properties {
    sort keys %DEFAULTS;
}
1;
