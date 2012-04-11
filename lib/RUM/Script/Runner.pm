package RUM::Script::Runner;

use strict;
use warnings;

use Getopt::Long;
use File::Path qw(mkpath);
use Text::Wrap qw(wrap fill);
use Carp;
use RUM::Logging;
use RUM::Workflows;
use RUM::WorkflowRunner;
use RUM::Repository;
use RUM::Usage;
use RUM::Pipeline;
use RUM::Cluster::SGE;
use RUM::Common qw(is_fasta is_fastq head num_digits shell format_large_int);

our $log = RUM::Logging->get_logger;
our $LOGO;

sub do_version { $_[0]->{directives}{version} }
sub do_help { $_[0]->{directives}{help} }
sub do_help_config { $_[0]->{directives}{help_config} }
sub do_diagram { $_[0]->{directives}{diagram} }
sub do_save { $_[0]->{directives}{save} }

sub be_quiet { $_[0]->{directives}{quiet} }
sub do_qsub { $_[0]->{directives}{qsub} }

sub do_status { $_[0]->{directives}{status} }
sub do_clean { $_[0]->{directives}{clean} }
sub do_veryclean { $_[0]->{directives}{veryclean} }

sub do_shell_script { $_[0]->{directives}{shell_script} }
sub do_dry_run { $_[0]->{directives}{dry_run} }

sub do_preprocess { $_[0]->{directives}{preprocess} }
sub do_process { $_[0]->{directives}{process} }
sub do_postprocess { $_[0]->{directives}{postprocess} }

sub say {
    my ($self, @msg) = @_;
    $log->info("@msg");
    print wrap("", "", @msg) . "\n" unless $self->be_quiet;
}

sub main {
    my ($class) = @_;
    $class->new->run;
}

sub run {
    my ($self) = @_;
    $self->get_options();

    if ($self->do_version) {
        $self->say("RUM version $RUM::Pipeline::VERSION, released $RUM::Pipeline::RELEASE_DATE");
    }
    elsif ($self->do_help) {
        RUM::Usage->help;
    }
    elsif ($self->do_help_config) {
        $self->say($RUM::ConfigFile::DOC);
    }
    elsif ($self->do_shell_script) {
        $self->export_shell_script;
    }
    else {
        $self->run_pipeline;
    }
}

sub run_pipeline {
    my ($self) = @_;

    $self->check_config();        
    $self->setup;
    
    $self->config->save if $self->do_save;
    return if $self->do_dry_run;

    if ($self->do_diagram) {
        $self->diagram;
        return;
    }

    if ($self->do_status) {
        $self->print_processing_status if $self->do_process;
        $self->print_postprocessing_status if $self->do_postprocess;
        return;
    }

    if ($self->do_clean || $self->do_veryclean) {
        $self->clean;
        return;
    }
    my $chunk = $self->config->chunk;
    $self->say("Chunk is $chunk");
    $self->show_logo;
    $self->setup;

    if (! $self->do_qsub && ! $chunk) {
        $self->check_ram;
    }

    if ($self->do_qsub) {
        my $cluster = RUM::Cluster::SGE->new($self->config);
        $cluster->submit_preproc  if $self->do_preprocess;
        $cluster->submit_proc     if $self->do_process;
        $cluster->submit_postproc if $self->do_postprocess;
    }
    else {
        $self->preprocess  if $self->do_preprocess;
        $self->process     if $self->do_process;
        $self->postprocess if $self->do_postprocess;
    }
}

sub get_options {
    my ($self) = @_;

    my $quiet;
    Getopt::Long::Configure(qw(no_ignore_case));

    GetOptions(

        # Options for doing things other than running the RUM
        # pipeline.
        "version|V"    => \(my $do_version),
        "kill"         => \(my $do_kill),
        "status"       => \(my $do_status),
        "shell-script" => \(my $do_shell_script),
        "help|h"       => \(my $do_help),
        "help-config"  => \(my $do_help_config),
        "dry-run|n"    => \(my $do_dry_run),
        "clean"        => \(my $do_clean),
        "veryclean"    => \(my $do_veryclean),
        "diagram"      => \(my $do_diagram),
        "save"         => \(my $do_save),

        # Options controlling which portions of the pipeline to run.
        "preprocess"   => \(my $do_preprocess),
        "process"      => \(my $do_process),
        "postprocess"  => \(my $do_postprocess),
        "chunk=s"      => \(my $chunk),

        # Options typically entered by a user to define a job.
        "config=s"    => \(my $rum_config_file),
        "output|o=s"  => \(my $output_dir),
        "name=s"      => \(my $name),

        # Control how we divide up the job.
        "chunks=s" => \(my $num_chunks),
        "ram=s"    => \(my $ram),
        "qsub"     => \(my $do_qsub),

        # Control logging and cleanup of temporary files.
        "no-clean"  => \(my $no_clean),
        "verbose|v" => sub { $log->more_logging(1) },
        "quiet|q"   => sub { $log->less_logging(1); $quiet = 1; },

        # Advanced parameters
        "read-lengths=s" => \(my $read_lengths),
        "max-insertions-per-read=s" => \(my $max_insertions = 1),
        "strand-specific" => \(my $strand_specific),
        "preserve-names" => \(my $preserve_names),
        "junctions" => \(my $junctions),
        "blat-only" => \(my $blat_only),
        "quantify" => \(my $quantify),
        "count-mismatches" => \(my $count_mismatches),
        "variable-read-lengths|variable-length-reads" => \(my $variable_read_lengths),
        "dna" => \(my $dna),
        "genome-only" => \(my $genome_only),
        "limit-bowtie-nu" => \(my $limit_bowtie_nu),
        "limit-nu=s"   => \(my $nu_limit),
        "alt-genes=s"  => \(my $alt_genes),
        "alt-quants=s" => \(my $alt_quant),
        "min-identity" => \(my $min_identity),
        "min-length=s" => \(my $min_length),
        "quals-file|qual-file=s" => \(my $quals_file),

        # Options for blat
        "minIdentity|blat-min-identity=s" => \(my $blat_min_identity),
        "tileSize|blat-tile-size=s"       => \(my $blat_tile_size),
        "stepSize|blat-step-size=s"       => \(my $blat_step_size),
        "repMatch|blat-rep-match=s"       => \(my $blat_rep_match),
        "maxIntron|blat-max-intron=s"     => \(my $blat_max_intron)
    );


    my $dir = $output_dir || ".";

    my $c = RUM::Config->load($dir);
    !$c or ref($c) =~ /RUM::Config/ or confess("Not a config: $c");
    $c = RUM::Config->default unless $c;
    ref($c) =~ /RUM::Config/ or confess("Not a config: $c");
    $c->set(argv => [@ARGV]);

    if ($c->chunk) {
        RUM::Usage->bad("Can't use --preprocess with --chunk")
              if $do_preprocess;
        RUM::Usage->bad("Can't use --postprocess with --chunk")
              if $do_postprocess;
    }

    unless ($do_preprocess || $do_process || $do_postprocess) {
        $do_preprocess  = ! $chunk;
        $do_process     = 1;
        $do_postprocess = ! $chunk;
    }
          
    $self->{directives} = {
        version      => $do_version,
        diagram      => $do_diagram,
        kill         => $do_kill,
        shell_script => $do_shell_script,
        help         => $do_help,
        help_config  => $do_help_config,
        dry_run      => $do_dry_run,
        save         => $do_save,
        status       => $do_status,
        clean        => $do_clean,
        veryclean    => $do_veryclean,
        preprocess   => $do_preprocess,
        process      => $do_process,
        postprocess  => $do_postprocess,
        quiet        => $quiet,
        qsub         => $do_qsub
    };

    my $set = sub { 
        my ($k, $v) = @_;
        return unless defined $v;
        my $existing = $c->get($k);
#        warn "Changing $k from $existing to $v" 
#            if defined($existing) && $existing ne $v;

        $c->set($k, $v);
    };

    $c->set('bowtie_nu_limit', 100) if $limit_bowtie_nu;
    $set->('quantify', $quantify);
    $set->('strand_specific', $strand_specific);
    $set->('ram', $ram);
    $set->('junctions', $junctions);
    $set->('count_mismatches', $count_mismatches);
    $set->('max_insertions', $max_insertions),
    $set->('cleanup', !$no_clean);
    $set->('dna', $dna);
    $set->('genome_only', $genome_only);
    $set->('chunk', $chunk);
    $set->('min_length', $min_length);
    $set->('output_dir',  $output_dir);
    $set->('num_chunks',  $num_chunks);
    $set->('reads', @ARGV ? [@ARGV] : undef);
    $set->('preserve_names', $preserve_names);
    $set->('variable_length_reads', $variable_read_lengths);
    $set->('user_quals', $quals_file);
    $set->('rum_config_file', $rum_config_file);
    $set->('name', $name);
    $set->('min_identity', $min_identity);
    $set->('nu_limit', $nu_limit);
    $set->('alt_genes', $alt_genes);
    $set->('alt_quant_model', $alt_quant);

    $set->('blat_min_identity', $blat_min_identity);
    $set->('blat_tile_size', $blat_tile_size);
    $set->('blat_step_size', $blat_step_size);
    $set->('blat_rep_match', $blat_rep_match);
    $set->('blat_max_intron', $blat_max_intron);
    
    $self->{config} = $c;
}

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


sub config {
    return $_[0]->{config};
}

sub clean {
    my ($self) = @_;
    my $c = $self->config;
    $self->determine_read_length;
    my $very = $self->do_veryclean;

    if ($self->do_process) {
        for my $w ($self->chunk_workflows) {
            $w->clean($very);
        }
    }

    if ($self->do_postprocess) {
        RUM::Workflows->postprocessing_workflow($c)->clean($very);
    }
}

sub diagram {
    my ($self) = @_;

    print "My num chunks is ", $self->config->num_chunks, "\n";

    if ($self->do_process) {
        for my $c ($self->chunk_configs) {
            my $dot = $self->config->in_output_dir(sprintf("chunk%03d.dot", $c->chunk));
            my $pdf = $self->config->in_output_dir(sprintf("chunk%03d.pdf", $c->chunk));
            open my $dot_out, ">", $dot;
            RUM::Workflows->chunk_workflow($c)->state_machine->dotty($dot_out);
            close $dot_out;
            system("dot -o$pdf -Tpdf $dot");
        }
    }

    if ($self->do_postprocess) {
        my $dot = $self->config->in_output_dir("postprocessing.dot");
        my $pdf = $self->config->in_output_dir("postprocessing.pdf");
        open my $dot_out, ">", $dot;
        RUM::Workflows->postprocessing_workflow($self->config)->state_machine->dotty($dot_out);
        close $dot_out;
        system("dot -o$pdf -Tpdf $dot");
    }
}

sub preprocess {
    my ($self) = @_;

    $self->say();
    $self->say("Preprocessing");
    $self->say("-------------");
    $self->check_input();
    $self->reformat_reads();
    $self->determine_read_length();
    $self->config->save;
}

sub step_printer {
    my ($self, $workflow) = @_;
    return sub {
        my ($step, $skipping) = @_;
        my $indent = $skipping ? "(skipping) " : "(running)  ";
        my $comment = $workflow->comment($step);
        $self->say(wrap($indent, "           ", $comment));
    };
}


sub process_in_chunks {
    my ($self) = @_;
    my $n = $self->config->num_chunks;
    $log->info("Creating $n chunks");

    my %pid_to_chunk; # Maps a process ID to the chunk it is running
    my @tasks; # Maps a chunk number to a RUM::RestartableTask
    
    for my $chunk ($self->chunk_nums) {
        my @argv = ("--output", $self->config->output_dir,
                    "--chunk", $chunk);
        my $cmd = "$0 @argv > /dev/null";
        my $config = $self->config->for_chunk($chunk);                
        my $workflow = RUM::Workflows->chunk_workflow($config);

        my $run = sub {
            if (my $pid = fork) {
                $pid_to_chunk{$pid} = $chunk;
            }
            else {
                $ENV{RUM_CHUNK} = $chunk;
                exec $cmd;
            }
        };

        my $task =  RUM::WorkflowRunner->new($workflow, $run);
        $tasks[$chunk] = $task;
        $task->run;
    }

    #my $status_pid;
    #if (my $pid = fork) {
    #    $status_pid = $pid;
    #}
    #else {
    #    while (1) {
    #        sleep 5;
    #        $self->print_status;
    #    }
    #}

    # Repeatedly wait for one of my children to exit. Check the
    # exit status, and if it is non-zero, attempt to restart the
    # child process unless it has failed too many times.
    while (1) {
        my $pid = wait;
        
        if ($pid < 0) {
            $log->info("All children done");
            last;
        }
        
        my $chunk = delete $pid_to_chunk{$pid} or $log->warn(
            "I don't know what chunk pid $pid is for");

        #unless (keys %pid_to_chunk) {
        #    $log->info("All chunks have finished");
        #    kill(9, $status_pid);
        #    wait;
        #    last;
        #}

        my $task = $tasks[$chunk];
        my $prefix = "PID $pid (chunk $chunk)";
        
        if ($?) {
            my $failures = sprintf("failed %d times in a row, %d times total",
                                   $task->times_started($task->workflow->state),
                                   $task->times_started);
            my $restarted = $task->run;

            my $action = $restarted ? "restarted it" : "giving up on it";
            $log->error("$prefix $failures; $action");
        }
        else {
            $log->info("$prefix finished");
        }
    }
    
}

sub process {
    my ($self) = @_;
    $self->determine_read_length();
    my $config = $self->config;

    $log->debug("Chunk is ". ($config->chunk ? "yes" : "no"));

    my $n = $config->num_chunks || 1;
    $self->say("Processing in $n chunks");
    $self->say("-----------------------");

    if ($n == 1 || $config->chunk) {
        my $chunk = $config->chunk || 1;
        $log->info("Running chunk $chunk");
        my $config = $self->config->for_chunk($chunk);
        my $w = RUM::Workflows->chunk_workflow($config);
        $w->execute($self->step_printer($w));
    }
    elsif ($config->num_chunks) {
        $self->process_in_chunks;
    }
}

sub postprocess {
    my ($self) = @_;
    $self->say("Postprocessing");
    $self->say("--------------");
    $self->determine_read_length();
    my $w = RUM::Workflows->postprocessing_workflow($self->config);
    $w->execute($self->step_printer($w));
}

sub setup {
    my ($self) = @_;
    my $output_dir = $self->config->output_dir;
    unless (-d $output_dir) {
        mkpath($output_dir) or die "mkdir $output_dir: $!";
    }

}

################################################################################
##
## Preprocessing checks on the input files
##

our $READ_CHECK_LINES = 50000;


sub check_input {
    my ($self) = @_;
    $log->debug("Checking input files");
    $self->check_reads_for_quality;

    if ($self->reads == 1) {
        $self->check_single_reads_file;
    }
    else {
        $self->check_read_file_pair;
    }

}

sub check_single_reads_file {
    my ($self) = @_;

    my $config = $self->config;
    my @reads  = $self->reads;

    # ??? I think if there are two read files, they are definitely
    # paired end. Not sure what implications this has for
    # input_needs_splitting or preformatted.
    return if @reads == 2;

    my $head = join("\n", head($reads[0], 4));
    $head =~ /seq.(\d+)(.).*seq.(\d+)(.)/s or return;

    my @nums  = ($1, $3);
    my @types = ($2, $4);

    my ($paired, $needs_splitting, $preformatted) = (0, 0, 0);

    if($nums[0] == 1 && $nums[1] == 1 && $types[0] eq 'a' && $types[1] eq 'b') {
        $log->info("Input appears to be paired-end");
        ($paired, $needs_splitting, $preformatted) = (1, 1, 1);
    }
    if($nums[0] == 1 && $nums[1] == 2 && $types[0] eq 'a' && $types[1] eq 'a') {
        $log->info("Input does not appear to be paired-end");
        ($paired, $needs_splitting, $preformatted) = (0, 1, 1);
    }
    $config->set("paired_end", $paired);
    $config->set("input_needs_splitting", $needs_splitting);
    $config->set("input_is_preformatted", $preformatted);
}


sub check_reads_for_quality {
    my ($self) = @_;

    for my $filename (@{ $self->config->reads }) {
        $log->debug("Checking $filename");
        open my $fh, "<", $filename or croak
            "Can't open reads file $filename for reading: $!\n";

        while (local $_ = <$fh>) {
            next unless /:Y:/;
            $_ = <$fh>;
            chomp;
            /^--$/ and die "you appear to have entries in your fastq file \"$filename\" for reads that didn't pass quality. These are lines that have \":Y:\" in them, probably followed by lines that just have two dashes \"--\". You first need to remove all such lines from the file, including the ones with the two dashes...";
        }
    }
}

sub check_read_files_same_size {
    my ($self) = @_;
    my @sizes = map -s, $self->reads;
    $sizes[0] == $sizes[1] or die
        "The fowards and reverse files are different sizes. $sizes[0]
        versus $sizes[1].  They should be the exact same size.";
}

sub check_read_file_pair {

    my ($self) = @_;

    my @reads = @{ $self->config->reads };

    $self->check_read_files_same_size();

    my $config = $self->config;

    # Check here that the quality scores are the same length as the reads.

    my $len = `head -50000 $reads[0] | wc -l`;
    chomp($len);
    $len =~ s/[^\d]//gs;

    my $parse2fasta = $config->script("parse2fasta.pl");
    my $fastq2qualities = $config->script("fastq2qualities.pl");

    my $reads_temp = $config->in_output_dir("reads_temp.fa");
    my $quals_temp = $config->in_output_dir("quals_temp.fa");
    my $error_log  = $config->in_output_dir("rum.error-log");

    $log->debug("Checking that reads and quality strings are the same length");
    shell("perl $parse2fasta     @reads | head -$len > $reads_temp 2>> $error_log");
    shell("perl $fastq2qualities @reads | head -$len > $quals_temp 2>> $error_log");
    my $X = `head -20 $quals_temp`;
    if($X =~ /\S/s && !($X =~ /Sorry, can't figure these files out/s)) {
        open(RFILE, $reads_temp);
        open(QFILE, $quals_temp);
        while(my $linea = <RFILE>) {
            my $lineb = <QFILE>;
            my $line1 = <RFILE>;
            my $line2 = <QFILE>;
            chomp($line1);
            chomp($line2);
            if(length($line1) != length($line2)) {
                die("It seems your read lengths differ from your quality string lengths. Check line:\n$linea$line1\n$lineb$line2.\nThis error could also be due to having reads of length 10 or less, if so you should remove those reads.");
            }
        }
    }

    # Check that reads are not variable length
    if($X =~ /\S/s) {
        open(RFILE, $reads_temp);
        my $length_flag = 0;
        my $length_hold;
        while(my $linea = <RFILE>) {
            my $line1 = <RFILE>;
            chomp($line1);
            if($length_flag == 0) {
                $length_hold = length($line1);
                $length_flag = 1;
            }
            if(length($line1) != $length_hold && !$config->variable_read_lengths) {
                warn("It seems your read lengths vary, but you didn't set -variable_length_reads. I'm going to set it for you, but it's generally safer to set it on the command-line since I only spot check the file.");
                $config->set('variable_read_lengths', 1);
            }
            $length_hold = length($line1);
        }
    }

    # Clean up:

    unlink($reads_temp);
    unlink($quals_temp);
}

sub determine_read_length {
    
    my ($self) = @_;

    my @lines = head($self->config->chunk_suffixed("reads.fa"), 2);
    my $read = $lines[1];
    my $len = length($read);
    my $min = $self->config->min_length;
    $log->debug("Read length is $len, min is " . ($min ||"")) if $log->is_debug;
    if ($self->config->variable_read_lengths) {
        $log->info("Using variable read length");
        $self->config->set("read_length", "v");
    }
    else{
        $self->config->set("read_length", $len);
        if (($min || 0) > $len) {
            die "You specified a minimum length alignment to report as '$min', however your read length is only $len\n";
        }
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
    if ($host =~ /login.genomics.upenn.edu/ && !$self->config->qsub) {
        die("you cannot run RUM on the PGFI cluster without using the --qsub option.");
    }
}

sub reads {
    return @{ $_[0]->config->reads };
}

sub reformat_reads {

    my ($self) = @_;

    $self->say("Reformatting reads file... please be patient.");

    my $config = $self->config;
    my $output_dir = $config->output_dir;
    my $parse_fastq = $config->script("parsefastq.pl");
    my $parse_fasta = $config->script("parsefasta.pl");
    my $parse_2_fasta = $config->script("parse2fasta.pl");
    my $parse_2_quals = $config->script("fastq2qualities.pl");
    my $num_chunks = $config->num_chunks || 1;

    my @reads = @{ $config->reads };

    my $reads_fa = $config->chunk_suffixed("reads.fa");
    my $quals_fa = $config->chunk_suffixed("quals.fa");

    my $name_mapping_opt = $config->preserve_names ?
        "-name_mapping $output_dir/read_names_mapping" : "";    
    
    my $error_log = "$output_dir/rum.error-log";

    # Going to figure out here if these are standard fastq files

    my @fh;
    for my $filename (@reads) {
        open my $fh, "<", $filename;
        push @fh, $fh;
    }

    my $is_fasta = is_fasta($fh[0]);
    my $is_fastq = is_fastq($fh[0]);
    my $preformatted = @reads == 1 && $config->input_is_preformatted;
    my $reads_in = join(",,,", @reads);

    my $have_quals = 0;

    if($is_fastq && !$config->variable_read_lengths) {
        $self->say("Splitting fastq file into $num_chunks chunks ",
                   "with separate reads and quals");
        shell("perl $parse_fastq $reads_in $num_chunks $reads_fa $quals_fa $name_mapping_opt 2>> $output_dir/rum.error-log");
        my @errors = `grep -A 2 "something wrong with line" $error_log`;
        die "@errors" if @errors;
        $have_quals = 1;
        $self->{input_needs_splitting} = 0;
    }
 
    elsif ($is_fasta && !$config->variable_read_lengths && !$preformatted) {
        $self->say("Splitting fasta file into $num_chunks chunks");
        shell("perl $parse_fasta $reads_in $num_chunks $reads_fa $name_mapping_opt 2>> $error_log");
        $have_quals = 0;
        $self->{input_needs_splitting} = 0;
     } 

    elsif (!$preformatted) {

        $self->say("Splitting fasta file into reads and quals");
        shell("perl $parse_2_fasta @reads > $reads_fa 2>> $error_log");
        shell("perl $parse_2_quals @reads > $quals_fa 2>> $error_log");
        $self->{input_needs_splitting} = 1;
        my $X = join("\n", head($config->chunk_suffixed("quals.fa"), 20));
        if($X =~ /\S/s && !($X =~ /Sorry, can\'t figure these files out/s)) {
            $have_quals = "true";
        }
    }
    else {
        # This should only be entered when we have one read file
        $self->say("Splitting read file, please be patient...");        

        $self->breakup_file($reads[0], 0);

        if ($have_quals) {
            $self->say( "Half done splitting; starting qualities...");
            breakup_file($config->chunk_suffixed("quals.fa"), 1);
        }
        elsif ($config->user_quals) {
            $self->say( "Half done splitting; starting qualities...");
            breakup_file($config->user_quals, 1);
        }
        $self->say("Done splitting");
    }
}

sub print_processing_status {
    my ($self) = @_;

    local $_;
    my $c = $self->config;

    my @steps;
    my %num_completed;
    my %comments;

    my @chunks;

    if ($c->chunk) {
        push @chunks, $c->chunk;
    }
    else {
        push @chunks, (1 .. $c->num_chunks || 1);
    }

    for my $chunk (@chunks) {
        my $w = RUM::Workflows->chunk_workflow($c->for_chunk($chunk));
        my $handle_state = sub {
            my ($name, $completed) = @_;
            unless (exists $num_completed{$name}) {
                $num_completed{$name} = 0;
                $comments{$name} = $w->comment($name);
                push @steps, $name;
            }
            $num_completed{$name} += $completed;
        };

        $w->walk_states($handle_state);
    }

    my $n = @chunks;
    my $digits = num_digits($n);
    my $h1     = "   Chunks ";
    my $h2     = "Done / Total";
    my $format =  "%4d /  %4d ";

    $self->say("Processing in $n chunks");
    $self->say("-----------------------");
    $self->say($h1);
    $self->say($h2);
    for (@steps) {
        my $progress = sprintf $format, $num_completed{$_}, $n;
        my $comment   = $comments{$_};
        my $indent = ' ' x length($progress);
        $self->say(wrap($progress, $indent, $comment));
    }

}

sub print_postprocessing_status {
    my ($self) = @_;
    my $c = $self->config;

    $self->say();
    $self->say("Postprocessing");
    $self->say("--------------");
    my $postproc = RUM::Workflows->postprocessing_workflow($c);
    my $handle_state = sub {
        my ($name, $completed) = @_;
        $self->say(($completed ? "X" : " ") . " " . $postproc->comment($name));
    };
    $postproc->walk_states($handle_state);
}

sub chunk_nums {
    my ($self) = @_;
    my $c = $self->config;
    if ($c->chunk) {
        return ($c->chunk);
    }
    return (1 .. $c->num_chunks || 1)
}

sub chunk_configs {
    my ($self) = @_;
    map { $self->config->for_chunk($_) } $self->chunk_nums;
}

sub chunk_workflows {
    my ($self) = @_;
    map { RUM::Workflows->chunk_workflow($_) } $self->chunk_configs;
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

sub breakup_file  {
    my ($self, $FILE, $qualflag) = @_;

    my $c = $self->config;

    if(!(open(INFILE, $FILE))) {
       die("Cannot open '$FILE' for reading.");
    }
    my $tail = `tail -2 $FILE | head -1`;
    $tail =~ /seq.(\d+)/s;
    my $numseqs = $1;
    my $piecesize = int($numseqs / ($c->num_chunks || 1));

    my $t = `tail -2 $FILE`;
    $t =~ /seq.(\d+)/s;
    my $NS = $1;
    my $piecesize2 = format_large_int($piecesize);
    if(!($FILE =~ /qual/)) {
	if($c->num_chunks > 1) {
	    $self->say("processing in ".
                     $c->num_chunks . 
                         " pieces of approx $piecesize2 reads each\n");
	} else {
	    my $NS2 = format_large_int($NS);
	    $self->say("processing in one piece of $NS2 reads\n");
	}
    }
    if($piecesize % 2 == 1) {
	$piecesize++;
    }
    my $bflag = 0;

    my $F2 = $FILE;
    $F2 =~ s!.*/!!;
    
    my $PS = $c->paired_end ? $piecesize * 2 : $piecesize;

    for(my $i=1; $i < $c->num_chunks; $i++) {
        my $chunk_config = $c->for_chunk($i);
	my $outfilename = $chunk_config->chunk_suffixed("reads.fa");

        $log->debug("Building $outfilename");
	open(OUTFILE, ">$outfilename");
	for(my $j=0; $j<$PS; $j++) {
	    my $line = <INFILE>;
	    chomp($line);
	    if($qualflag == 0) {
		$line =~ s/[^ACGTNab]$//s;
	    }
	    print OUTFILE "$line\n";
	    $line = <INFILE>;
	    chomp($line);
	    if($qualflag == 0) {
		$line =~ s/[^ACGTNab]$//s;
	    }
	    print OUTFILE "$line\n";
	}
	close(OUTFILE);
    }
    my $chunk_config = $c->num_chunks ? $c->for_chunk($c->num_chunks) : $c;
    my $outfilename = $chunk_config->chunk_suffixed("reads.fa");
    open(OUTFILE, ">$outfilename");
    while(my $line = <INFILE>) {
	print OUTFILE $line;
    }
    close(OUTFILE);

    return 0;
}

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
    $_ = `free -g`; 
    if (/Mem:\s+(\d+)/s) {
        return $1;
    }

    # this should work on freeBSD
    $_ = `grep memory /var/run/dmesg.boot`;
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
        

1;

