package RUM::Config;

use strict;
use warnings;

use Carp;
use FindBin qw($Bin);
use File::Spec;
use File::Path qw(mkpath);
use Data::Dumper;
use Scalar::Util qw(blessed);

use Getopt::Long;
use RUM::Logging;
use RUM::ConfigFile;

our $AUTOLOAD;
our $log = RUM::Logging->get_logger;
FindBin->again;

our $FILENAME = ".rum/job_settings";

my @TRANSIENT_PROPERTIES = qw(parent child process preprocess postprocess no_clean
                              quiet verbose);

my $DEFAULT = RUM::Config->new;

our %DEFAULTS = (

    child => undef,
    parent => undef,
    process => undef,
    preprocess => undef,
    postprocess => undef,
    no_clean => undef,
    quiet => undef,
    verbose => undef,

    # These properties are actually set by the user
    max_insertions        => 1,
    strand_specific       => 0,
    min_identity          => 93,
    blat_min_identity     => 93,
    blat_tile_size        => 12,
    blat_step_size        => 6,
    blat_rep_match        => 256,
    blat_max_intron       => 500000,
    platform              => "Local",

    chunks                => undef,
    chunk                => undef,
    ram                   => undef,

    name                  => undef,
    output_dir            => undef,
    index_dir             => undef,
    reads                 => undef,
    user_quals            => undef,
    alt_genes             => undef,
    alt_quant_model       => undef,
    alt_quant             => undef,
    genome_only           => undef,
    blat_only             => undef,
    quantify              => undef,
    junctions             => undef,
    preserve_names        => undef,
    variable_length_reads => undef,
    min_length            => undef,
    max_insertions        => undef,
    limit_nu_cutoff       => undef,
    nu_limit              => undef,
    bowtie_nu_limit       => 100,
    dna                   => undef,
    count_mismatches      => undef,
    no_clean              => undef,

    # These are derived from the user-provided properties, and saved
    # to the .rum/job_settings file

    ram_ok                => undef,
    input_needs_splitting => undef,
    input_is_preformatted => undef,
    paired_end            => undef,
    read_length           => undef,

    # Loaded from the rum config file
    genome_bowtie         => undef,
    genome_fa             => undef,
    annotations           => undef,
    trans_bowtie          => undef,
    genome_size           => undef,
);

my %TRANSIENT = (
    no_clean => 1,
    quiet    => 1,
    verbose  => 1,
    action   => undef,
    
);

sub should_preprocess {
    my $self = shift;
    return $self->preprocess || (!$self->process && !$self->postprocess);
}

sub should_process {
    my $self = shift;
    return $self->process || (!$self->preprocess && !$self->postprocess);
}


sub should_postprocess {
    my $self = shift;
    return $self->postprocess || (!$self->preprocess && !$self->process);
}

sub from_command_line {

    my ($self) = @_;

    my $handle_option = sub {
        my ($name, $value) = @_;
        warn "Setting $name to $value\n";
        $name =~ s/-/_/g;
        $self->set($name, $value);
    };

    my $handle_path = sub {
        my ($name, $path) = @_;
        $handle_option->($name, File::Spec->rel2abs($path));
    };

    GetOptions(

        # Advanced (user shouldn't run these)
        "child"        => $handle_option,
        "parent"       => $handle_option,
        "lock=s"       => $handle_path,

        # Options controlling which portions of the pipeline to run.
        "preprocess"   => $handle_option,
        "process"      => $handle_option,
        "postprocess"  => $handle_option,
        "chunk=i"      => $handle_option,

        "no-clean" => $handle_option,

        'output-dir|o=s' => $handle_path,

        # Options typically entered by a user to define a job.
        "index-dir|i=s" => $handle_path,
        "name=s"        => $handle_option,
        "chunks=i"      => $handle_option,
        "qsub"          => sub { $self->set('platform', 'SGE'); },
        "platform=s"    => $handle_option,

        # Advanced options
        "alt-genes=s"        => $handle_path,
        "alt-quants=s"       => $handle_path,
        "blat-only"          => $handle_option,
        "count-mismatches"   => $handle_option,
        "dna"                => $handle_option,
        "genome-only"        => $handle_option,
        "junctions"          => $handle_option,
        "limit-bowtie-nu!"   => $handle_option,
        "limit-nu=s"         => $handle_option,
        "max-insertions-per-read=s" => $handle_option,
        "min-identity"              => $handle_option,
        "min-length=s"              => $handle_option,
        "preserve-names"            => $handle_option,
        "quals-file|qual-file=s"    => $handle_path,
        "quantify"                  => $handle_option,
        "ram=s"    => $handle_option,
        "read-lengths=s" => $handle_option,
        "strand-specific" => $handle_option,
        "variable-length-reads" => $handle_option,

        # Options for blat
        "minIdentity|blat-min-identity=s" => $handle_option,
        "tileSize|blat-tile-size=s"       => $handle_option,
        "stepSize|blat-step-size=s"       => $handle_option,
        "repMatch|blat-rep-match=s"       => $handle_option,
        "maxIntron|blat-max-intron=s"     => $handle_option
    );

    return $self;
}


sub new {

    my ($class, %params) = @_;

    my $is_default = delete $params{default};

    my $self = {};

    if ($is_default) {
        for my $k (keys %DEFAULTS) {
            if (defined (my $v = $DEFAULTS{$k})) {
                $self->{$k} = $v;
            }
        }
    }
    else {
        $self->{_default} = $class->new(default => 1);
    }

    return bless $self, $class;
}

sub load_rum_config_file {
    my ($self) = @_;
    my $path = $self->index_dir or croak
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

sub script {
    return File::Spec->catfile("$Bin/../bin", $_[1]);
}

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

sub in_output_dir {
    my ($self, $file) = @_;
    my $dir = $self->output_dir;
    return $dir ? File::Spec->catfile($dir, $file) : $file;
}

sub in_chunk_dir {
    my ($self, $name) = @_;
    my $path = File::Spec->catfile($self->output_dir, "chunks", $name);
}

sub in_postproc_dir {
    my ($self, $file) = @_;
    my $dir = $self->postproc_dir;
    mkpath $dir;
    return File::Spec->catfile($dir, $file);
}

sub chunk_file {
    my ($self, $name, $chunk) = @_;
    $chunk or return undef;
    return $self->in_chunk_dir("$name.$chunk");
}

sub opt {
    my ($self, $opt, $arg) = @_;
    return defined($arg) ? ($opt, $arg) : "";
}

sub read_length_opt         { $_[0]->opt("--read-length", $_[0]->read_length) }
sub min_overlap_opt         { $_[0]->opt("--min-overlap", $_[0]->min_length) }
sub max_insertions_opt      { $_[0]->opt("--max-insertions", $_[0]->max_insertions) }
sub match_length_cutoff_opt { $_[0]->opt("--match-length-cutoff", $_[0]->min_length) }
sub limit_nu_cutoff_opt     { $_[0]->opt("--cutoff", $_[0]->nu_limit) }
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
        tileSize    => $self->blat_tile_size,
        stepSize    => $self->blat_step_size,
        repMatch    => $self->blat_rep_match,
        maxIntron   => $self->blat_max_intron);

    return map("-$_=$opts{$_}", sort keys %opts);
}

sub is_property {
    my $name = shift;
    exists $DEFAULTS{$name};
}

my %paths = (
    forward_reads => 1,
    reverse_reads => 1,
    
);

sub set {
    my ($self, %params) = @_;
    croak "Can't call set on $self" unless ref $self;
    for my $k (keys %params) {
        croak "No such property $k" unless is_property($k);
        $self->{$k} = $params{$k};
    }
    
    return $self;
}

sub save {
    my ($self) = @_;
    my $filename = $self->in_output_dir($FILENAME);
    open my $fh, ">", $filename or croak "$filename: $!";
    print $fh Dumper($self);
}

sub destroy {
    my ($self) = @_;
    my $filename = $self->in_output_dir($FILENAME);
    unlink $filename;
}

sub load_default {
    my ($self) = @_;

    my $filename = $self->in_output_dir($FILENAME);

    $self->{_default} = do $filename;
    my $class = blessed($self);
    ref($self->{_default}) =~ /$class/ or croak "$filename did not return a $class";
    return $self;
}

sub get {
    my ($self, $name) = @_;
    ref($self) or croak "Can't call get on $self";
    is_property($name) or croak "No such property $name";
    
    if (defined $self->{$name}) {
        return $self->{$name};
    }
    elsif ($self->{_default}) {
        return $self->{_default}->get($name);
    }
    else {
        return;
        #croak "Property $name was not set. Config is " . Dumper($self);
    }
}

sub properties {
    sort keys %DEFAULTS;
}

sub settings_filename {
    my ($self) = @_;
    return ($self->in_output_dir($FILENAME));
}

sub lock_file {
    my ($self) = @_;
    $self->in_output_dir(".rum/lock");
}

sub min_ram_gb {
    my ($self) = @_;
    my $genome_size = $self->genome_size;
    defined($genome_size) or croak "Can't get min ram without genome size";
    my $gsz = $genome_size / 1000000000;
    my $min_ram = int($gsz * 1.67)+1;
    return $min_ram;
}

sub should_quantify {
    my ($self) = @_;
    return !($self->dna || $self->genome_only) || $self->quantify;
}

sub should_do_junctions {
    my ($self) = @_;
    return !$self->dna || $self->genome_only || $self->junctions;
}

sub u_footprint { shift->in_postproc_dir("u_footprint.txt") }
sub nu_footprint { shift->in_postproc_dir("nu_footprint.txt") }
sub mapping_stats_final {
    $_[0]->in_output_dir("mapping_stats.txt");
}
sub sam_header { 
    my ($self, $chunk) = @_;
    $self->chunk_file("sam_header", $chunk) or $self->in_postproc_dir("sam_header");
}

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
sub novel_inferred_internal_exons_quantifications {
    my ($self) = @_;
    return $self->in_output_dir("novel_inferred_internal_exons_quantifications_"
                                    .$self->name);
}

sub preprocessed_reads {
    return shift->in_output_dir("reads.fa");
}

sub AUTOLOAD {
    my ($self) = @_;
    croak "Can't get property on $self" unless ref $self;
    my @parts = split /::/, $AUTOLOAD;
    my $name = $parts[-1];
    
    return if $name eq "DESTROY";

    return $self->get($name);
}

1;

__END__

=head1 NAME

RUM::Config - Configuration for a RUM job

=head1 CONSTRUCTOR

=over 4

=item new(%options)

Create a new RUM::Config with the given options. %options can contain
mappings from the keys in %DEFAULTS to the values to use for those
keys.

=back

=head1 CLASS METHODS

=over 4

=item load_rum_config_file

Load the settings from the rum index configuration file I am
configured with. This allows you to call annotations, genome_bowtie,
trans_bowtie, and genome_fa on me rather than loading the config
object yourself.

=item script($name)

Return the path to the rum script of the given name.

=back

=head1 OBJECT METHODS

=head2 Directories

These methods return the paths to some directories I need:

=over 4

=item postproc_dir

=item chunk_dir

=item temp_dir

=back

=head2 File paths

These methods return paths to files relative to some of my directories.

=over 4

=item in_output_dir($file)

Return a path to a file with the given name, relative to our output directory.

=item in_chunk_dir($name)

Return a path to a file with the given name, relative to our chunk
directory.

=item in_postproc_dir($file)

Return a path to a file with the given name, relative to our postproc directory.

=item chunk_file

Return a path to a file in our chunk directory, based on the given
filename, with the given chunk as the suffix.

=item opt($opt, $arg)

Return a list of the option and its argument if argument is defined,
otherwise an empty string.

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

=head2 Serializing the configuration

=over 4

=item $config->settings_filename

Return the name of the file I should be saved to.

=item $config->save

Save the configuration to a file in the $output_dir/.rum.

=item RUM::Config->load($dir, $force)

Load a saved RUM::Config file.

=item $config->destroy

Delete the config file.

=back

=head2 Other

=over 4

=item is_property($name)

Return true if the given name is a property that can be configured.

=item set($key, $value)

Set the value of $key to $value.

=item get($name)

Return the value of the property with the given name.

=item properties

Return a list of the names of my properties.

=item lock_file

Return the path to the lock file that should prevent other instances
of the pipeline from running in the same output directory.

=item min_ram_gb

Return the minimum amount of ram that is needed, based on the genome size.

=back

=head2 Derived Values

These values are derived based on properties provided by the user or
the defaults:

=over 4

=item should_quantify

Return true if the pipeline should do quantifications, based on the
values of the I<dna>, I<genome_only>, and I<quantify> properties.

=item should_do_junctions

Return true if the pipeline should do junctions, based on the values
of the I<dna>, I<genome_only>, and I<junctions> properties.

=back

=head2 Output Files

These functions all return the paths to output files.

=over 4

=item u_footprint

=item nu_footprint

=item mapping_stats_final

=item sam_header

=item sam_header($chunk)

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

=item novel_inferred_internal_exons_quantifications

Return the name of the novel inferred internal exons quants file.

=item preprocessed_reads

Return the path to preprocessed reads file (reads.fa in the output
directory).


