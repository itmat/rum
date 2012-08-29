package RUM::Action::Init;

use strict;
use warnings;
use autodie;

use base 'RUM::Action';

use File::Path qw(mkpath);

use RUM::Logging;
use RUM::SystemCheck;

our $log = RUM::Logging->get_logger;

RUM::Lock->register_sigint_handler;

sub new { shift->SUPER::new(name => 'align', @_) }

sub initialize {
    my ($self) = @_;

    my $c = $self->config;
    
    #$self->check_config;
    RUM::SystemCheck::check_deps;

    RUM::SystemCheck::check_gamma(
        config => $c);

    $self->setup;
#    $self->get_lock;
    
    my $platform      = $self->platform;
    my $platform_name = $c->platform;
    my $local = $platform_name =~ /Local/;
    
    if ($local) {
        RUM::SystemCheck::check_ram(
            config => $c,
            say => sub { $self->logsay(@_) });
    }
    else {
        $self->say(
            "You are running this job on a $platform_name cluster. ",
            "I am going to assume each node has sufficient RAM for this. ",
            "If you are running a mammalian genome then you should have at ",
            "least 6 Gigs per node");
    }

    $self->say("Saving job configuration");
    $self->config->save;
#    RUM::Lock->release;
    return $self->config;
}

sub run {
    my ($class) = @_;
    my $self = $class->new;

    # Parse the command line and construct a RUM::Config
    my $c = $self->make_config;

    $self->initialize;
    return $self->config;

}

sub make_config {
    my ($self) = @_;

    my @options = qw(limit_nu_cutoff quiet verbose output_dir
                     index_dir name chunks qsub platform alt_genes
                     alt_quants blat_only dna genome_only junctions
                     limit_bowtie_nu limit_nu max_insertions
                     min_identity min_length preserve_names quals_file
                     quantify ram read_length strand_specific
                     variable_length_reads blat_min_identity
                     blat_tile_size blat_step_size blat_max_intron
                     no_clean
                     blat_rep_match);

    my $config = RUM::Config->new->parse_command_line(
        options => \@options,
        positional => ['forward_reads', 'reverse_reads']);

    if ( ! $config->is_new ) {
        die("It looks like there's already a job initialized in " .
            $config->output_dir);
    }

    return $self->{config} = $config;
}


sub check_config {
    my ($self, $action) = @_;

    my $usage = RUM::Usage->new(action => $action);

    my $c = $self->config;

    $c->load_rum_config_file if $c->index_dir;

    my $reads = $c->reads;

    if ($reads) {
        @$reads == 1 || @$reads == 2 or $usage->bad(
            "Please provide one or two read files. You provided " .
            join(", ", @$reads));
    }
    else {
        $usage->bad("Please provide one or two read files.");
    }


    if ($reads && @$reads == 2) {
        $reads->[0] ne $reads->[1] or $usage->bad(
        "You specified the same file for the forward and reverse reads, ".
            "must be an error");

        $c->max_insertions <= 1 or $usage->bad(
            "For paired-end data, you cannot set --max-insertions-per-read".
                " to be greater than 1.");
    }

    if (defined($c->quals_file)) {
        $c->quals_file =~ /\// or $usage->bad(
            "do not specify -quals file with a full path, ".
                "put it in the '". $c->output_dir."' directory.");
    }

    $c->min_identity =~ /^\d+$/ && $c->min_identity <= 100 or $usage->bad(
        "--min-identity must be an integer between zero and 100. You
        have given '".$c->min_identity."'.");


    if (defined($c->min_length)) {
        $c->min_length =~ /^\d+$/ && $c->min_length >= 10 or $usage->bad(
            "--min-length must be an integer >= 10. You have given '".
                $c->min_length."'.");
    }
    
    if (defined($c->nu_limit)) {
        $c->nu_limit =~ /^\d+$/ && $c->nu_limit > 0 or $usage->bad(
            "--limit-nu must be an integer greater than zero. You have given '".
                $c->nu_limit."'.");
    }

    $c->preserve_names && $c->variable_length_reads and $usage->bad(
        "Cannot use both --preserve-names and --variable-read-lengths at ".
            "the same time. Sorry, we will fix this eventually.");

    local $_ = $c->blat_min_identity;
    /^\d+$/ && $_ <= 100 or $usage->bad(
        "--blat-min-identity or --minIdentity must be an integer between ".
            "0 and 100.");

    $c->chunks or $usage->bad(
        "Please tell me how many chunks to split the input into with the "
        . "--chunks option.");

    $usage->check;
    
    if ($c->alt_genes) {
        -r $c->alt_genes or die
            "Can't read from alt gene file ".$c->alt_genes.": $!";
    }

    if ($c->alt_quant_model) {
        -r $c->alt_quant_model or die
            "Can't read from ".$c->alt_quant_model.": $!";
    }

    # If we haven't yet split the input file, make sure that the raw
    # read files exist.
    if ( ! -r $c->preprocessed_reads ) {
        for my $fname (@{ $reads || [] }) {
            -r $fname or die "Can't read from read file $fname";
        }
    }
}

sub fix_name {
    local $_ = shift;

    my $name_o = $_;
    s/\s+/_/g;
    s/^[^a-zA-Z0-9_.-]//;
    s/[^a-zA-Z0-9_.-]$//g;
    s/[^a-zA-Z0-9_.-]/_/g;
    
    return $_;
}

sub setup {
    my ($self) = @_;
    my $output_dir = $self->config->output_dir;
    my $c = $self->config;
    my @dirs = (
        $c->output_dir,
        $c->output_dir . "/.rum",
        $c->chunk_dir
    );
    for my $dir (@dirs) {
        unless (-d $dir) {
            mkpath($dir) or die "mkdir $dir: $!";
        }
    }
}
