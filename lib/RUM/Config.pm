package RUM::Config;

use strict;
use warnings;
use Carp;
use FindBin qw($Bin);
use RUM::Logging;
our $AUTOLOAD;
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

our @LITERAL_PROPERTIES = qw (forward chunk output_dir paired_end
 match_length_cutoff max_insertions num_chunks bin_dir genome_bowtie
 genome_fa transcriptome_bowtie annotations num_chunks read_length
 min_overlap max_insertions match_length_cutoff limit_nu_cutoff
 preserve_names variable_length_reads config_file
 bowtie_bin mdust_bin blat_bin trans_bowtie min_length reads
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
    rum_nu_sorted      => "RUM_Unique.sorted",
    chr_counts_u       => "chr_counts_u",
    chr_counts_nu      => "chr_counts_nu",
    reads_fa           => "reads.fa",
    quals_fa           => "quals.fa"
);

our %DEFAULTS = (
    num_chunks            => 1,
    preserve_names        => 0,
    variable_length_reads => 0,
    min_length            => undef,
    min_overlap           => undef,
    max_insertions        => undef,
    match_length_cutoff   => undef,
    limit_nu_cutoff       => undef);


sub variable_read_lengths {
    $_[0]->variable_length_reads
}

sub load_rum_config_file {
    my ($self, $path) = @_;
    
    open my $in, "<", $path or croak "Can't open config file $path: $!";
    my $cf = RUM::ConfigFile->parse($in);
    
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

    if ($data{config_file}) {
        open my $in, "<", $data{config_file}
            or croak "Can't open config file $data{config_file}: $!";
        my $config = RUM::ConfigFile->parse($in);
        
        $data{annotations} = $config->gene_annotation_file;
        unless ($data{dna}) {
            -e $data{annotations} or
                die("the file '$data{annotations}' does not seem to exist.");
        }
        
        $data{bowtie_bin} = $config->bowtie_bin;
        $data{blat_bin} = $config->blat_bin;
        $data{mdust_bin} = $config->mdust_bin;
        $data{genome_bowtie} = $config->bowtie_genome_index;
        $data{trans_bowtie} = $config->bowtie_gene_index;
        $data{genome_fa} = $config->blat_genome_index;

        -e $data{bowtie_bin} or die("the executable '$data{bowtie_bin}' does not seem to exist.");
        -e $data{blat_bin} or die("the executable '$data{blat_bin}' does not seem to exist.");
        -e $data{mdust_bin} or die("the executable '$data{mdust_bin}' does not seem to exist.");        
        -e $data{genome_fa} or die("the file '$data{genome_fa}' does not seem to exist.");
    }

    return bless \%data, $class;
}

sub for_chunk {
    my ($self, $chunk) = @_;
    my %options = %{ $self };
    $options{chunk} = $chunk;

    return __PACKAGE__->new(%options);
}

# Utilities for modifying a filename

sub script {
    "$Bin/../bin/" . $_[1] 
}

sub chunk_suffix {
    $_[0]->{chunk} ? ".$_[0]->{chunk}" : "" 
}

sub chunk_suffixed { 
    my ($self, $file) = @_;
    if (my $dir = $self->output_dir) {
        return "$dir/$file" . $self->chunk_suffix;
    }
}

sub chunk_replaced {
    my ($self, $file) = @_;
    my $dir = $self->output_dir;
    $dir = "$dir/" if $dir;
    sprintf("$dir/$file", $_[0]->{chunk} || 0)
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

sub blat_output  { $_[0]->chunk_replaced("R.%d.blat") }
sub mdust_output { $_[0]->chunk_replaced("R.%d.mdust") }

sub state_dir { $_[0]->chunk_replaced("state-%03d") }

sub quant {
    my ($self, $strand, $sense) = @_;
    return $self->chunk_suffixed("quant.$strand$sense");
}

sub pipeline_sh { $_[0]->chunk_suffixed("pipeline.sh") }

# TODO: Maybe support name mapping?
sub name_mapping_opt   { "" } 

sub properties {
    (@LITERAL_PROPERTIES, keys %CHUNK_SUFFIXED_PROPERTIES)
}

sub is_property {
    my $name = shift;
    grep { $name eq $_ } (@LITERAL_PROPERTIES, keys %CHUNK_SUFFIXED_PROPERTIES)
}

sub set {
    my ($self, $key, $value) = @_;
    die "No such property $key" unless is_property($key);
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

1;
