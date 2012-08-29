package RUM::Action::Start;

use strict;
use warnings;
use autodie;

use base 'RUM::Action';


use RUM::Common qw(format_large_int min_match_length);
use RUM::Logging;
use RUM::Action::Clean;
use RUM::Action::Reset;

our $log = RUM::Logging->get_logger;

RUM::Lock->register_sigint_handler;

sub new { shift->SUPER::new(name => 'align', @_) }

sub start {

    my ($self) = @_;

    my $c = $self->config;

    my $platform      = $self->platform;
    my $platform_name = $c->platform;
    my $local = $platform_name =~ /Local/;

    if ( ! -d $c->in_output_dir('.rum')) {
        die($c->output_dir . " does not appear to be a RUM output directory." .
            " Please use 'rum_runner align' to start a new job");
    }

    my $report = RUM::JobReport->new($c);
    if ( ! ($c->parent || $c->child)) {
        $report->print_header;
    }

    if ( !$local && ! ( $c->parent || $c->child ) ) {
        $self->logsay("Submitting tasks and exiting");
        $platform->start_parent;
        return;
    }
    my $dir = $self->config->output_dir;
    $self->say(
        "If this is a big job, you should keep an eye on the rum_errors*.log",
        "files in the output directory. If all goes well they should be empty.",
        "You can also run \"$0 status -o $dir\" to check the status of the job.");

    if ($self->config->should_preprocess) {
        $platform->preprocess;
    }

    $self->_show_match_length;
    $self->_check_read_lengths;

    my $chunk = $self->config->chunk;
    
    # If user said --process or at least didn't say --preprocess or
    # --postprocess, then check if we still need to process, and if so
    # execute the processing phase.
    if ($c->should_process) {
        if ($self->still_processing) {
            $platform->process($chunk);
        }
    }

    # If user said --postprocess or didn't say --preprocess or
    # --process, then we need to do postprocessing.
    if ($c->should_postprocess) {
        
        # If we're called with "--chunk X --postprocess", that means
        # we're supposed to process chunk X and do postprocessing only
        # if X is the last chunk. I realize that's not very
        # intuitive...
        #
        # TODO: Come up with a better way for the parent to
        # communicate with one of its child processes, telling it to
        # do postprocessing
        if ( !$chunk || $chunk == $self->config->chunks ) {
            $platform->postprocess;
            $self->_final_check;
        }

    }
    RUM::Lock->release;
}

sub run {
    my ($class) = @_;
    my $self = $class->new;
    $self->make_config;

    $self->start;
}

sub make_config {

    my ($self) = @_;

    my @transient_options = qw(quiet verbose no_clean output_dir);

    my @reset_options = qw(limit_nu_cutoff index_dir name qsub
                           platform alt_genes alt_quants blat_only dna
                           genome_only junctions limit_bowtie_nu
                           limit_nu max_insertions min_identity
                           min_length preserve_names quals_file
                           quantify ram read_length strand_specific
                           variable_length_reads blat_min_identity
                           blat_tile_size blat_step_size
                           blat_max_intron blat_rep_match);

    my @directives = qw(preprocess process postprocess chunk parent child);

    my $config = RUM::Config->new->parse_command_line(
        options => [@transient_options, @reset_options, @directives],
        load_default => 1);

    my @specified = grep { $config->is_specified($_) } @reset_options;

    if (@specified) {
        $self->say("Since you specified some parameters, I am resetting the ".
                   "job to just after the preprocessing phase.");
        RUM::Action::Reset->new(config => $config)->reset_job;
        $config->save;
    }

    if ($config->lock_file) {
        $log->info("Got lock_file argument (" .
                   $config->lock_file . ")");
        $RUM::Lock::FILE = $config->lock_file;
    }

    return $self->{config} = $config;
}

sub _show_match_length {
    my ($self) = @_;
    my $c = $self->config;

    if ($c->min_length) {
        $self->logsay(
            "I am going to report alignments of length " .
            $c->min_length . 
            " or longer, based on the user providing a " . 
            "--min-length option.");
    }
    elsif ($c->read_length && $c->read_length ne 'v') {
        my $min_length = min_match_length($c->read_length);
        $self->logsay(
            "*** Note: I am going to report alignments of length ",
            "$min_length, based on a read length of ",
            $c->read_length ,
            ". If you want to change the minimum size of ",
            "alignments reported, use the --min-length option");
    }
    elsif ($c->read_length && $c->read_length eq 'v') {
        $self->logsay(
            "You have variable-length reads and didn't specify ",
            "--min-length, so I will calculate the minimum ",
            "match length for each read based on read length.");
    }
}

sub _check_read_lengths {
    my ($self) = @_;
    my $c = $self->config;
    my $rl = $c->read_length;

    unless ($rl) {
        $log->info("I haven't determined read length yet");
        return;
    }

    my $fixed = ! $c->variable_length_reads;

    if ( $fixed && $rl < 55 && !$c->nu_limit) {
        $self->say;
        $self->logsay(
            "WARNING: You have pretty short reads ($rl bases). If ",
            "you have a large genome such as mouse or human then the files of ",
            "ambiguous mappers could grow very large. In this case it's",
            "recommended to run with the --limit-bowtie-nu option. You can ",
            "watch the files that start with 'X' and 'Y' and see if they are ",
            "growing larger than 10 gigabytes per million reads at which ",
            "point you might want to use --limit-nu");
    }

}

sub _final_check {
    my ($self) = @_;
    my $ok = 1;
    
    $self->say();
    $self->logsay("Checking for errors");
    $self->logsay("-------------------");

    $ok = $self->_chunk_error_logs_are_empty && $ok;
    $ok = $self->_all_files_end_with_newlines && $ok;

    if ($ok) {
        $self->logsay("No errors. Very good!");
        unless ($self->config->no_clean) {
            $self->logsay("Cleaning up.");
            RUM::Action::Clean->new(config => $self->config)->clean;
        }
    }
}

sub _all_files_end_with_newlines {
    my ($self, $file) = @_;
    my $c = $self->config;

    my @files = qw(
                      RUM_Unique
                      RUM_NU
                      RUM_Unique.cov
                      RUM_NU.cov
                      RUM.sam
                      
              );

    if ($c->should_quantify) {
        push @files, "feature_quantifications_" . $c->name;
    }
    if ($c->should_do_junctions) {
        push @files, ('junctions_all.rum',
                      'junctions_all.bed',
                      'junctions_high-quality.bed');
    }

    my $result = 1;
    
    for $file (@files) {
        my $file = $self->config->in_output_dir($file);
        my $tail = `tail $file`;
        
        unless ($tail =~ /\n$/) {
            $log->error("RUM_Unique does not end with a newline, that probably means it is incomplete.");
            $result = 0;
        }
    }
    if ($result) {
        $log->info("All files end with a newline, that's good");
    }
    return $result;
}


1;
