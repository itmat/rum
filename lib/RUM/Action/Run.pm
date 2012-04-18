package RUM::Action::Run;

use strict;
use warnings;

use Getopt::Long;
use File::Path qw(mkpath);
use Text::Wrap qw(wrap fill);
use Carp;
use Data::Dumper;

use RUM::Directives;
use RUM::Logging;
use RUM::Workflows;
use RUM::Usage;
use RUM::Pipeline;
use RUM::Common qw(format_large_int);

use RUM::Lock;
use RUM::Action::Help;
use RUM::Action::Version;
use RUM::Action::Status;
use RUM::Action::Diagram;
use RUM::Action::Clean;
use RUM::Action::Kill;

use base 'RUM::Base';

our $log = RUM::Logging->get_logger;
our $LOGO;

=head1 NAME

RUM::Action::Run

=head1 METHODS

=over 4

=cut

################################################################################
###
### Parsing and validating command line options
###

=item get_options

Parse @ARGV and build a RUM::Config from it. Also set some flags in
$self->{directives} based on some boolean options.

=cut

sub get_options {
    my ($self) = @_;

    my $quiet;
    Getopt::Long::Configure(qw(no_ignore_case));

    my $d = $self->{directives} = RUM::Directives->new;

    GetOptions(

        # Advanced (user shouldn't run these)
        "child"        => sub { $d->set_child },
        "parent"       => sub { $d->set_parent },

        # Options controlling which portions of the pipeline to run.
        "preprocess"   => sub { $d->set_preprocess;  $d->unset_all; },
        "process"      => sub { $d->set_process;     $d->unset_all; },
        "postprocess"  => sub { $d->set_postprocess; $d->unset_all; },
        "chunk=s"      => \(my $chunk),

        # Options typically entered by a user to define a job.
        "config=s"    => \(my $rum_config_file),
        "output|o=s"  => \(my $output_dir),
        "name=s"      => \(my $name),
        "chunks=s"    => \(my $num_chunks),
        "qsub"        => \(my $qsub),
        "platform=s"  => \(my $platform),

        # Advanced options
        "alt-genes=s"      => \(my $alt_genes),
        "alt-quants=s"     => \(my $alt_quant),
        "blat-only"        => \(my $blat_only),
        "count-mismatches" => \(my $count_mismatches),
        "dna"              => \(my $dna),
        "genome-only"      => \(my $genome_only),
        "junctions"        => \(my $junctions),
        "limit-bowtie-nu"  => \(my $limit_bowtie_nu),
        "limit-nu=s"       => \(my $nu_limit),
        "max-insertions-per-read=s" => \(my $max_insertions),
        "min-identity"              => \(my $min_identity),
        "min-length=s"              => \(my $min_length),
        "no-clean"                  => \(my $no_clean),
        "preserve-names"            => \(my $preserve_names),
        "quals-file|qual-file=s"    => \(my $quals_file),
        "quantify"                  => \(my $quantify),
        "ram=s"    => \(my $ram),
        "read-lengths=s" => \(my $read_lengths),
        "strand-specific" => \(my $strand_specific),
        "variable-read-lengths|variable-length-reads" => \(my $variable_read_lengths),

        # Options for blat
        "minIdentity|blat-min-identity=s" => \(my $blat_min_identity),
        "tileSize|blat-tile-size=s"       => \(my $blat_tile_size),
        "stepSize|blat-step-size=s"       => \(my $blat_step_size),
        "repMatch|blat-rep-match=s"       => \(my $blat_rep_match),
        "maxIntron|blat-max-intron=s"     => \(my $blat_max_intron),

        "force|f"   => \(my $force),
        "quiet|q"   => sub { $log->less_logging(1); $quiet = 1; },
        "verbose|v" => sub { $log->more_logging(1) },

    );

    my $dir = $output_dir || ".";

    my $c = RUM::Config->load($dir);
    !$c or ref($c) =~ /RUM::Config/ or confess("Not a config: $c");
    my $did_load;
    if ($c) {
        $self->say("Using settings found in " . $c->settings_filename);
        $did_load = 1;
    }
    else {
        $c = RUM::Config->default unless $c;
        $c->set('output_dir', File::Spec->rel2abs($dir));
    }

    ref($c) =~ /RUM::Config/ or confess("Not a config: $c");
    $c->set(argv => [@ARGV]);

    # If a chunk is specified, that implies that the user wants to do
    # the 'processing' phase, so unset preprocess and postprocess
    if ($chunk) {
        RUM::Usage->bad("Can't use --preprocess with --chunk")
              if $d->preprocess;
        RUM::Usage->bad("Can't use --postprocess with --chunk")
              if $d->postprocess;
        $d->unset_all;
        $d->set_process;
    }

    my $did_set;

    my $set = sub { 
        my ($k, $v) = @_;
        return unless defined $v;
        my $existing = $c->get($k);
        if (defined($existing) && $existing ne $v) {
            $did_set = 1;
            $log->warn("Changing $k from $existing to $v");
        }

        $c->set($k, $v);
    };

    $platform = 'SGE' if $qsub;

    $alt_genes = File::Spec->rel2abs($alt_genes) if $alt_genes;
    $alt_quant = File::Spec->rel2abs($alt_genes) if $alt_quant;
    $rum_config_file = File::Spec->rel2abs($rum_config_file) if $rum_config_file;

    my @reads = map { File::Spec->rel2abs($_) } @ARGV;

    $set->('alt_genes', $alt_genes);
    $set->('alt_quant_model', $alt_quant);
    $set->('bowtie_nu_limit', 100) if $limit_bowtie_nu;
    $set->('blat_min_identity', $blat_min_identity);
    $set->('blat_tile_size', $blat_tile_size);
    $set->('blat_step_size', $blat_step_size);
    $set->('blat_rep_match', $blat_rep_match);
    $set->('blat_max_intron', $blat_max_intron);
    $set->('blat_only', $blat_only);
    $set->('chunk', $chunk);
    $set->('cleanup', !$no_clean);
    $set->('count_mismatches', $count_mismatches);
    $set->('dna', $dna);
    $set->('genome_only', $genome_only);
    $set->('junctions', $junctions);
    $set->('max_insertions', $max_insertions),
    $set->('min_identity', $min_identity);
    $set->('min_length', $min_length);
    $set->('name', $name);
    $set->('nu_limit', $nu_limit);
    $set->('num_chunks',  $num_chunks);
    $set->('platform', $platform);
    $set->('preserve_names', $preserve_names);
    $set->('quantify', $quantify);
    $set->('ram', $ram);
    $set->('reads', @reads ? [@reads] : undef) if @reads && @reads ne @{ $c->reads || [] };
    $set->('rum_config_file', $rum_config_file);
    $set->('strand_specific', $strand_specific);
    $set->('user_quals', $quals_file);
    $set->('variable_length_reads', $variable_read_lengths);

    if ($did_set && $did_load && !$force && !$d->child) {
        RUM::Usage->bad("I found job settings in " . $c->settings_filename . ", but you specified different settings on the command line. I won't run without the --force flag. If you want to use the saved settings, please don't provide any extra options on the command line. If you need to change the settings, please either delete " . $c->settings_filename . " or run again with --force.");
    }

    $self->{config} = $c;
}


=item check_config

Check my RUM::Config for errors. Calls RUM::Usage->bad (which exits)
if there are any errors.

=cut

sub check_config {
    my ($self) = @_;

    my @errors;

    my $c = $self->config;
    $c->output_dir or push @errors,
        "Please specify an output directory with --output or -o";
    
    # Job name
    if ($c->name) {
        length($c->name) <= 250 or push @errors,
            "The name must be less than 250 characters";
        $c->set('name', fix_name($c->name));
    }
    else {
        push @errors, "Please specify a name with --name";
    }

    $c->rum_config_file or push @errors,
        "Please specify a rum config file with --config";
    $c->load_rum_config_file if $c->rum_config_file;

    my $reads = $c->reads;

    $reads && (@$reads == 1 || @$reads == 2) or push @errors,
        "Please provide one or two read files";
    if ($reads && @$reads == 2) {
        $reads->[0] ne $reads->[1] or push @errors,
        "You specified the same file for the forward and reverse reads, ".
            "must be an error";
    }
    
    if (defined($c->user_quals)) {
        $c->quals_file =~ /\// or push @errors,
            "do not specify -quals file with a full path, ".
                "put it in the '". $c->output_dir."' directory.";
    }

    $c->min_identity =~ /^\d+$/ && $c->min_identity <= 100 or push @errors,
        "--min-identity must be an integer between zero and 100. You
        have given '".$c->min_identity."'.";

    if (defined($c->min_length)) {
        $c->min_length =~ /^\d+$/ && $c->min_length >= 10 or push @errors,
            "--min-length must be an integer >= 10. You have given '".
                $c->min_length."'.";
    }
    
    if (defined($c->nu_limit)) {
        $c->nu_limit =~ /^\d+$/ && $c->nu_limit > 0 or push @errors,
            "--limit-nu must be an integer greater than zero. You have given '".
                $c->nu_limit."'.";
    }

    $c->preserve_names && $c->variable_read_lengths and push @errors,
        "Cannot use both --preserve-names and --variable-read-lengths at ".
            "the same time. Sorry, we will fix this eventually.";

    local $_ = $c->blat_min_identity;
    /^\d+$/ && $_ <= 100 or push @errors,
        "--blat-min-identity or --minIdentity must be an integer between ".
            "0 and 100.";

    @errors = map { wrap('* ', '  ', $_) } @errors;

    my $msg = "Usage errors:\n\n" . join("\n", @errors);
    RUM::Usage->bad($msg) if @errors;    
    
    if ($c->alt_genes) {
        -r $c->alt_genes or die
            "Can't read from alt gene file ".$c->alt_genes.": $!";
    }
    if ($c->alt_quant_model) {
        -r $c->alt_quant_model or die
            "Can't read from ".$c->alt_quant_model.": $!";
    }
    
}

sub get_lock {
    my ($self) = @_;
    return if $self->directives->parent || $self->directives->child;
    my $c = $self->config;
    my $dir = $c->output_dir;
    my $lock = $c->lock_file;
    RUM::Lock->acquire($lock) or die
          "It seems like rum_runner may already be running in $dir. You can try running \"$0 kill\" to stop it. If you are sure there's nothing running in $dir, remove $lock and try again.\n";
}

################################################################################
###
### High-level orchestration
###

sub run {
    my ($class) = @_;
    my $self = $class->new;
    $self->get_options();

    my $d = $self->directives;
    $self->check_config;        
    $self->check_gamma;
    $self->setup;
    $self->get_lock;


    $self->show_logo;
    
    $self->check_ram unless $d->child;
    $self->config->save unless $d->child;
    $self->dump_config;
    
    my $platform = $self->platform;
    
    if ( ref($platform) !~ /Local/ && ! ( $d->parent || $d->child ) ) {
        $self->say("Submitting tasks and exiting");
        $platform->start_parent;
        return;
    }
    
    if ($d->preprocess || $d->all) {
        $platform->preprocess;
    }
    if ($d->process || $d->all) {
        $platform->process;
    }
    if ($d->postprocess || $d->all) {
        $platform->postprocess;
    }
}


################################################################################
###
### Other tasks not directly involved with running the pipeline
###


sub setup {
    my ($self) = @_;
    my $output_dir = $self->config->output_dir;
    unless (-d $output_dir) {
        mkpath($output_dir) or die "mkdir $output_dir: $!";
    }
    unless (-d "$output_dir/.rum") {
        mkpath("$output_dir/.rum") or die "mkdir $output_dir/.rum: $!";
    }
}


sub new {
    my ($class) = @_;
    my $self = {};
    $self->{config} = undef;
    $self->{directives} = undef;
    bless $self, $class;
}

sub show_logo {
    my ($self) = @_;
    my $msg = <<EOF;

RUM Version $RUM::Pipeline::VERSION

$LOGO
EOF
    $self->say($msg);

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

sub check_gamma {
    my ($self) = @_;
    my $host = `hostname`;
    if ($host =~ /login.genomics.upenn.edu/ && !$self->config->platform eq 'Local') {
        die("you cannot run RUM on the PGFI cluster without using the --qsub option.");
    }
}

sub export_shell_script {
    my ($self) = @_;

    $self->say("Generating pipeline shell script for each chunk");
    for my $chunk ($self->chunk_nums) {
        my $config = $self->config->for_chunk($chunk);
        my $w = RUM::Workflows->chunk_workflow($chunk);
        my $file = IO::File->new($config->pipeline_sh);
        open my $out, ">", $file or die "Can't open $file for writing: $!";
        $w->shell_script($out);
    }
}


sub dump_config {
    my ($self) = @_;
    $log->debug("-" x 40);
    $log->debug("Job configuration");
    $log->debug("RUM Version: $RUM::Pipeline::VERSION");
    
    for my $key ($self->config->properties) {
        my $val = $self->config->get($key);
        next unless defined $val;
        $val = Data::Dumper->new([$val])->Indent(0)->Dump if ref($val);
        $log->debug("$key: $val");
    }
    $log->debug("-" x 40);
}

################################################################################
###
### Checking available memory
###

sub genome_size {
    my ($self) = @_;

    $self->say("Determining how much RAM you need based on your genome.");

    my $c = $self->config;
    my $genome_blat = $c->genome_fa;

    my $gs1 = -s $genome_blat;
    my $gs2 = 0;
    my $gs3 = 0;

    open my $in, "<", $genome_blat or croak "$genome_blat: $!";

    local $_;
    while (defined($_ = <$in>)) {
        next unless /^>/;
        $gs2 += length;
        $gs3 += 1;
    }

    my $genome_size = $gs1 - $gs2 - $gs3;
    my $gs4 = &format_large_int($genome_size);
    my $gsz = $genome_size / 1000000000;
    my $min_ram = int($gsz * 1.67)+1;
}

sub check_ram {

    my ($self) = @_;

    my $c = $self->config;

    return if $c->ram_ok;

    if (!$c->ram) {
        $self->say("I'm going to try to figure out how much RAM ",
                   "you have. If you see some error messages here, ",
                   " don't worry, these are harmless.");
        my $available = $self->available_ram;
        $c->set('ram', $available);
    }

    my $genome_size = $self->genome_size;
    my $gs4 = &format_large_int($genome_size);
    my $gsz = $genome_size / 1000000000;
    my $min_ram = int($gsz * 1.67)+1;
    
    $self->say();

    my $totalram = $c->ram;
    my $RAMperchunk;
    my $ram;

    # We couldn't figure out RAM, warn user.
    if ($totalram) {
        $RAMperchunk = $totalram / ($c->num_chunks||1);
    } else {
        warn("Warning: I could not determine how much RAM you " ,
             "have.  If you have less than $min_ram gigs per ",
             "chunk this might not work. I'm going to ",
             "proceed with fingers crossed.\n");
        $ram = $min_ram;      
    }
    
    if ($totalram) {

        if($RAMperchunk >= $min_ram) {
            $self->say(sprintf(
                "It seems like you have %.2f Gb of RAM on ".
                "your machine. Unless you have too much other stuff ".
                "running, RAM should not be a problem.", $RAMperchunk));
        } else {
            $self->say(
                "Warning: you have only $RAMperchunk Gb of RAM ",
                "per chunk.  Based on the size of your genome ",
                "you will probably need more like $min_ram Gb ",
                "per chunk. Anyway I can try and see what ",
                "happens.");
            print("Do you really want me to proceed?  Enter 'Y' or 'N': ");
            local $_ = <STDIN>;
            if(/^n$/i) {
                exit();
            }
        }
        $self->say();
        $ram = $min_ram;
        if($ram < 6 && $ram < $RAMperchunk) {
            $ram = $RAMperchunk;
            if($ram > 6) {
                $ram = 6;
            }
        }

        $c->set('ram', $ram);
        $c->set('ram_ok', 1);
        $c->save;
        # sleep($PAUSE_TIME);
    }

}

sub available_ram {

    my ($self) = @_;

    my $c = $self->config;

    return $c->ram if $c->ram;

    local $_;

    # this should work on linux
    $_ = `free -g 2>/dev/null`; 
    if (/Mem:\s+(\d+)/s) {
        return $1;
    }

    # this should work on freeBSD
    $_ = `grep memory /var/run/dmesg.boot 2>/dev/null`;
    if (/avail memory = (\d+)/) {
        return int($1 / 1000000000);
    }

    # this should work on a mac
    $_ = `top -l 1 | grep free`;
    if (/(\d+)(.)\s+used, (\d+)(.) free/) {
        my $used = $1;
        my $type1 = $2;
        my $free = $3;
        my $type2 = $4;
        if($type1 eq "K" || $type1 eq "k") {
            $used = int($used / 1000000);
        }
        if($type2 eq "K" || $type2 eq "k") {
            $free = int($free / 1000000);
        }
        if($type1 eq "M" || $type1 eq "m") {
            $used = int($used / 1000);
        }
        if($type2 eq "M" || $type2 eq "m") {
            $free = int($free / 1000);
        }
        return $used + $free;
    }
    return 0;
}

$LOGO = <<'EOF';
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                 _   _   _   _   _   _    _
               // \// \// \// \// \// \/
              //\_//\_//\_//\_//\_//\_//
        o_O__O_ o
       | ====== |       .-----------.
       `--------'       |||||||||||||
        || ~~ ||        |-----------|
        || ~~ ||        | .-------. |
        ||----||        ! | UPENN | !
       //      \\        \`-------'/
      // /!  !\ \\        \_  O  _/
     !!__________!!         \   /
     ||  ~~~~~~  ||          `-'
     || _        ||
     |||_|| ||\/|||
     ||| \|_||  |||
     ||          ||
     ||  ~~~~~~  ||
     ||__________||
.----|||        |||------------------.
     ||\\      //||                 /|
     |============|                //
     `------------'               //
---------------------------------'/
---------------------------------'
  ____________________________________________________________
- The RNA-Seq Unified Mapper (RUM) Pipeline has been initiated -
  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
EOF


################################################################################
###
### Finishing up
###



1;

