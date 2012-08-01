package RUM::Config;

use strict;
use warnings;

use Carp;
use FindBin qw($Bin);
use File::Spec;
use File::Path qw(mkpath);
use Data::Dumper;

use RUM::Logging;
use RUM::ConfigFile;

our $AUTOLOAD;
our $log = RUM::Logging->get_logger;
FindBin->again;

our $FILENAME = ".rum/job_settings";

=head1 NAME

RUM::Config - Configuration for a RUM job

=cut

our %DEFAULTS = (

    # These properties are actually set by the user
    num_chunks            => undef,
    ram                   => undef,
    max_insertions        => 1,
    strand_specific       => 0,
    min_identity          => 93,
    blat_min_identity     => 93,
    blat_tile_size        => 12,
    blat_step_size        => 6,
    blat_rep_match        => 256,
    blat_max_intron       => 500000,
    name                  => undef,
    platform              => "Local",
    output_dir            => ".",
    rum_index             => undef,
    reads                 => undef,
    user_quals            => undef,
    alt_genes             => undef,
    alt_quant_model       => undef,
    alt_quant             => undef,
    genome_only           => 0,
    blat_only             => 0,
    quantify              => 0,
    junctions             => 0,
    preserve_names        => 0,
    variable_length_reads => 0,
    min_length            => undef,
    max_insertions        => 1,
    limit_nu_cutoff       => undef,
    nu_limit              => undef,
    bowtie_nu_limit       => undef,
    dna                   => 0,
    count_mismatches      => undef,

    # These are derived from the user-provided properties, and saved
    # to the .rum/job_settings file

    ram_ok                => 0,
    input_needs_splitting => undef,
    input_is_preformatted => undef,
    paired_end            => 0,
    read_length           => undef,

    # Loaded from the rum config file
    genome_bowtie         => undef,
    genome_fa             => undef,
    annotations           => undef,
    trans_bowtie          => undef,
    genome_size           => undef,
);

=head1 CONSTRUCTOR

=over 4

=item new(%options)

Create a new RUM::Config with the given options. %options can contain
mappings from the keys in %DEFAULTS to the values to use for those
keys.

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

=head1 CLASS METHODS

=over 4

=item load_rum_config_file

Load the settings from the rum index configuration file I am
configured with. This allows you to call annotations, genome_bowtie,
trans_bowtie, and genome_fa on me rather than loading the config
object yourself.

=cut

sub load_rum_config_file {
    my ($self) = @_;
    my $path = $self->rum_index or croak
        "No RUM index config file was supplied";

    my $index = RUM::Index->load($path);

    my %data;
    $data{annotations}   = $index->gene_annotations;
    $data{genome_bowtie} = $index->bowtie_genome_index;
    $data{trans_bowtie}  = $index->bowtie_transcriptome_index;
    $data{genome_fa}     = $index->genome_fasta;
    $data{genome_size}   = $index->genome_size;

    -e $data{annotations} || $self->dna or die
        "the file '$data{annotations}' does not seem to exist.";         

    -e $data{genome_fa} or die
        "the file '$data{genome_fa}' does not seem to exist.";
    
    local $_;
    for (keys %data) {
        $self->set($_, $data{$_});
    }
}

=item script($name)

Return the path to the rum script of the given name.

=cut

sub script {
    return File::Spec->catfile("$Bin/../bin", $_[1]);
}

=back

=head1 OBJECT METHODS

=head2 Directories

These methods return the paths to some directories I need:

=over 4

=item postproc_dir

=item chunk_dir

=item temp_dir

=back

=cut

sub postproc_dir {
    my ($self, $file) = @_;
    return File::Spec->catfile($self->output_dir, "postproc");
}

sub chunk_dir {
    my ($self) = @_;
    return File::Spec->catfile($self->output_dir, "chunks");
}

sub temp_dir {
    my ($self) = @_;
    return File::Spec->catfile($self->output_dir, "tmp");
}

=head2 File paths

These methods return paths to files relative to some of my directories.

=over 4

=item in_output_dir($file)

Return a path to a file with the given name, relative to our output directory.

=cut

sub in_output_dir {
    my ($self, $file) = @_;
    my $dir = $self->output_dir;
    return $dir ? File::Spec->catfile($dir, $file) : $file;
}

=item in_chunk_dir($name)

Return a path to a file with the given name, relative to our chunk
directory.

=cut

sub in_chunk_dir {
    my ($self, $name) = @_;
    my $path = File::Spec->catfile($self->output_dir, "chunks", $name);
}

=item in_postproc_dir($file)

Return a path to a file with the given name, relative to our postproc directory.

=cut

sub in_postproc_dir {
    my ($self, $file) = @_;
    my $dir = $self->postproc_dir;
    mkpath $dir;
    return File::Spec->catfile($dir, $file);
}

=item chunk_file

Return a path to a file in our chunk directory, based on the given
filename, with the given chunk as the suffix.

=cut

sub chunk_file {
    my ($self, $name, $chunk) = @_;
    $chunk or return undef;
    return $self->in_chunk_dir("$name.$chunk");
}

# These functions return options that the user can control.

=item opt($opt, $arg)

Return a list of the option and its argument if argument is defined,
otherwise an empty string.

=cut

sub opt {
    my ($self, $opt, $arg) = @_;
    return defined($arg) ? ($opt, $arg) : "";
}

=back

=head2 Getting option lists for scripts

The following methods can be used to get options to pass into sub
programs, based on the configuration:

=over 4

=item read_length_opt

=item min_overlap_opt

=item max_insertions_opt

=item match_length_cutoff_opt

=item limit_nu_cutoff_opt

=item bowtie_cutoff_opt

=item faok_opt

=item count_mismatches_opt

=item paired_end_opt

=item dna_opt

=item blat_opts

=item name_mapping_opt

=item ram_opt

=back

=cut

sub read_length_opt         { $_[0]->opt("--read-length", $_[0]->read_length) }
sub min_overlap_opt         { $_[0]->opt("--min-overlap", $_[0]->min_length) }
sub max_insertions_opt      { $_[0]->opt("--max-insertions", $_[0]->max_insertions) }
sub match_length_cutoff_opt { $_[0]->opt("--match-length-cutoff", $_[0]->min_length) }
sub limit_nu_cutoff_opt     { $_[0]->opt("--cutoff", $_[0]->nu_limit) }
sub bowtie_cutoff_opt       { my $x = $_[0]->bowtie_nu_limit; $x ? "-k $x" : "-a" }
sub faok_opt                { $_[0]->{faok} ? "--faok" : ":" }
sub count_mismatches_opt    { $_[0]->{count_mismatches} ? "--count-mismatches" : "" } 
sub paired_end_opt          { $_[0]->{paired_end} ? "--paired" : "--single" }
sub dna_opt                 { $_[0]->{dna} ? "--dna" : "" }
sub name_mapping_opt   { "" } 
sub ram_opt {
    return $_[0]->ram ? ("--ram", $_[0]->ram || $_[0]->min_ram_gb) : ();
}
sub blat_opts {
    my ($self) = @_;
    my %opts = (
        minIdentity => $self->blat_min_identity,
        tileSize => $self->blat_tile_size,
        stepSize => $self->blat_step_size,
        repMatch => $self->blat_rep_match,
        maxIntron => $self->blat_max_intron);

    return map("-$_=$opts{$_}", sort keys %opts);
}

=head2 Other

=over 4

=item is_property($name)

Return true if the given name is a property that can be configured.

=cut

sub is_property {
    my $name = shift;
    exists $DEFAULTS{$name};
}

=item set($key, $value)

Set the value of $key to $value.

=cut

sub set {
    my ($self, $key, $value) = @_;
    confess "No such property $key" unless is_property($key);
    $self->{$key} = $value;
}

=item save

Save the configuration to a file in the $output_dir/.rum.

=cut

sub save {
    my ($self) = @_;
    $log->debug("Saving config file, chunks is " . $self->num_chunks);
    my $filename = $self->in_output_dir($FILENAME);
    open my $fh, ">", $filename or croak "$filename: $!";
    print $fh Dumper($self);
}

sub destroy {
    my ($self) = @_;
    my $filename = $self->in_output_dir($FILENAME);
    unlink $filename;
}

=item load($dir, $force)

Load a saved RUM::Config file.

=cut

sub load {
    my ($class, $dir, $force) = @_;
    my $filename = "$dir/$FILENAME";

    unless (-e $filename) {
        if ($force) {
            die "$dir doesn't seem to be a RUM output directory\n";
        }
        else {
            return;
        }
    }
    my $conf = do $filename;
    ref($conf) =~ /$class/ or croak "$filename did not return a $class";
    return $conf;
}

=item get($name)

Return the value of the property with the given name.

=cut

sub get {
    my ($self, $name) = @_;
    is_property($name) or croak "No such property $name";
    
    exists $self->{$name} or croak "Property $name was not set";

    return $self->{$name};
}

=item properties

Return a list of the names of my properties.

=cut

sub properties {
    sort keys %DEFAULTS;
}

=item settings_filename

Return the name of the file I should be saved to.

=cut

sub settings_filename {
    my ($self) = @_;
    return ($self->in_output_dir($FILENAME));
}

=item lock_file

Return the path to the lock file that should prevent other instances
of the pipeline from running in the same output directory.

=cut

sub lock_file {
    my ($self) = @_;
    $self->in_output_dir(".rum/lock");
}

=item min_ram_gb

Return the minimum amount of ram that is needed, based on the genome size.

=cut

sub min_ram_gb {
    my ($self) = @_;
    my $genome_size = $self->genome_size;
    defined($genome_size) or croak "Can't get min ram without genome size";
    my $gsz = $genome_size / 1000000000;
    my $min_ram = int($gsz * 1.67)+1;
    return $min_ram;
}

=back

=head2 Derived Values

These values are derived based on properties provided by the user or
the defaults:

=over 4

=item should_quantify

Return true if the pipeline should do quantifications, based on the
values of the I<dna>, I<genome_only>, and I<quantify> properties.

=cut

sub should_quantify {
    my ($self) = @_;
    return !($self->dna || $self->genome_only) || $self->quantify;
}

=item should_do_junctions

Return true if the pipeline should do junctions, based on the values
of the I<dna>, I<genome_only>, and I<junctions> properties.

=cut

sub should_do_junctions {
    my ($self) = @_;
    return !$self->dna || $self->genome_only || $self->junctions;
}

=back

=head2 Output Files

These functions all return the paths to output files.

=over 4

=item u_footprint

=item nu_footprint

=item mapping_stats_final

=item sam_header

=item sam_header($chunk)

=cut

sub u_footprint { shift->in_postproc_dir("u_footprint.txt") }
sub nu_footprint { shift->in_postproc_dir("nu_footprint.txt") }
sub mapping_stats_final {
    $_[0]->in_output_dir("mapping_stats.txt");
}
sub sam_header { 
    my ($self, $chunk) = @_;
    $self->chunk_file("sam_header", $chunk) or $self->in_postproc_dir("sam_header");
}

=item quant(%options)

=item alt_quant(%options)

Return the filename for a quant file or an alt quant file, optionally
given a chunk, strand, and sense. The following are valid keys for
options:

=over 4

=item chunk

=item strand

=item sense

=back

=cut

sub quant {
    my ($self, %opts) = @_;

    my $chunk = $opts{chunk};
    my $strand = $opts{strand};
    my $sense  = $opts{sense};
    if ($strand && $sense) {
        my $name = "quant.$strand$sense";
        return $chunk ? $self->chunk_file($name, $chunk) : $self->in_output_dir($name);
    }

    if ($chunk) {
        return $self->chunk_file("quant", $chunk);
    }
    return $self->in_output_dir("feature_quantifications_" . $self->name);
}

sub alt_quant {
    my ($self, %opts) = @_;
    my $chunk  = $opts{chunk};
    my $strand = $opts{strand} || "";
    my $sense  = $opts{sense}  || "";
    my $name = $self->name;

    if ($chunk) {
        my @parts = ("quant", "$strand$sense", "altquant");
        my $filename = join ".", grep { $_ } @parts;
        return $self->chunk_file($filename, $chunk);
    }
    elsif ($strand && $sense) {
        return $self->in_output_dir("feature_quantifications.altquant.$strand$sense");
    }
    else {
        return $self->in_output_dir("feature_quantifications_$name.altquant");
    }
}

=item novel_inferred_internal_exons_quantifications

Return the name of the novel inferred internal exons quants file.

=cut

sub novel_inferred_internal_exons_quantifications {
    my ($self) = @_;
    return $self->in_output_dir("novel_inferred_internal_exons_quantifications_"
                                    .$self->name);
}

=item preprocessed_reads

Return the path to preprocessed reads file (reads.fa in the output
directory).

=cut

sub preprocessed_reads {
    return shift->in_output_dir("reads.fa");
}

sub AUTOLOAD {
    my ($self) = @_;
    
    my @parts = split /::/, $AUTOLOAD;
    my $name = $parts[-1];
    
    return if $name eq "DESTROY";
    
    return $self->get($name);
}

1;

