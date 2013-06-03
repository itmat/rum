package RUM::Pipeline;

use strict;
no warnings;

use base 'RUM::Base';

use Carp;
use File::Path qw(mkpath rmtree);
use File::Find;
use Text::Wrap qw(wrap fill);

use RUM::SystemCheck;
use RUM::Logging;
use RUM::Common qw(format_large_int min_match_length);
use RUM::Platform::Local;

my $log = RUM::Logging->get_logger;

our $VERSION = 'v2.0.5_05';
our $RELEASE_DATE = "June 3, 2012";

our $LOGO = <<'EOF';
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


sub get_lock {
    my ($self) = @_;

    # If rum_runner was called with --parent or --child, then it
    # should have been run by a parent rum_runner process, which we
    # will assume has the lock. So we don't need to try to get
    # exclusive access.
    return if $self->config->parent || $self->config->child;

    my $c = $self->config;
    my $dir = $c->output_dir;
    my $lock = $c->lock_file;

    $log->info("Acquiring lock");
    RUM::Lock->acquire($lock) or die
      "It seems like rum_runner may already be running in $dir. You can try running \"$0 stop\" to stop it. If you are sure there's nothing running in $dir, remove $lock and try again.\n";
}

sub initialize {
    my ($self) = @_;

    my $c = $self->config;

    # Refuse to initialize a job in a directory that already has a job in it.
    if ( ! $c->is_new ) {
        die("It looks like there's already a job initialized in " .
            $c->output_dir);
    }
    
    # Make sure we have bowtie, blat, and mdust, and that we're not
    # running on the head node of the PGFI cluster.
    RUM::SystemCheck::check_deps;
    RUM::SystemCheck::check_gamma(config => $c);
    
    # Make my output dir and chunks dir.
    my @dirs = (
        $c->output_dir,
        $c->chunk_dir
    );
    for my $dir (@dirs) {
        next if -d $dir;
        mkpath($dir) or die "mkdir $dir: $!";
    }

    # If I am running all the chunks on the current machine, check to
    # make sure we have enough ram.
    my $platform      = $self->platform;
    my $platform_name = $c->platform;
    my $local         = $platform_name =~ /Local/;
    if ($local) {
        RUM::SystemCheck::check_ram(
            config => $c,
            say => sub { $self->logsay(@_) });
    }

    # Otherwise if we're running on a cluster, just assume we have
    # enough RAM, but warn the user.
    else {
        $self->say(
            "You are running this job on a $platform_name cluster. ",
            "I am going to assume each node has sufficient RAM for this. ",
            "If you are running a mammalian genome then you should have at ",
            "least 6 Gigs per node");
    }

    RUM::Platform::Local->new($c)->_check_input;

    # Save the new job configuration to the output directory, and
    # return it.
    $self->say("Saving job configuration");
    $self->config->save;
    return $self->config;
}

sub reset_job {
    my ($self) = @_;

    my $config = $self->config;

    my $workflows = RUM::Workflows->new($config);

    my $wanted_step = 0;

    if (my $step = $self->config->from_step) {
        $wanted_step = $step - 1;
    }

    my $processing_steps;
    
    $self->say("Resetting to step $wanted_step\n");

    for my $chunk (1 .. $config->chunks) {
        my $workflow = $workflows->chunk_workflow($chunk);
        $processing_steps = $self->_reset_workflow($workflow, $wanted_step);
    }

    $self->_reset_workflow($workflows->postprocessing_workflow, $wanted_step - $processing_steps);
}

sub reset_if_needed {
    my ($self) = @_;
    my $config = $self->config;
    if ($config->changed_settings) {
        $self->say("Since you specified some parameters, I am resetting the ".
                   "job to just after the preprocessing phase.");
        $self->reset_job;
        $config->save;
    }
}

# Reset the given workflow back to the specified step.
sub _reset_workflow {
    my ($self, $workflow, $wanted_step) = @_;

    my %keep;
    my $plan = $workflow->state_machine->plan or croak "Can't build a plan";
    my @plan = @{ $plan };
    my $state = $workflow->state_machine->start;
    my $step = 0;
    for my $e (@plan) {
        $step++;
        $state = $workflow->state_machine->transition($state, $e);
        if ($step <= $wanted_step) {
            for my $file ($state->flags) {
                $keep{$file} = 1;
            }
        }
        
    }
    
    my @remove = grep { !$keep{$_} } $state->flags;
    
    unlink @remove;
    return $step;
}

sub start {

    my ($self) = @_;

    # We have to get the lock before starting
    $self->get_lock;

    my $c = $self->config;
    my $platform      = $self->platform;
    my $platform_name = $c->platform;
    my $local = $platform_name =~ /Local/;

    # We can't start a job if it hasn't been initialized
    if ( $c->is_new) {
        die($c->output_dir . " does not appear to be a RUM output directory." .
            " Please use 'rum_runner align' to start a new job");
    }

    my $report = RUM::JobReport->new($c);

    # If I'm the top-level RUM process, initialize the job report
    if ( $c->is_top_level ) {
        $report->print_header;
    }

    # If I'm the top-level RUM process and I'm not running locally,
    # just kick off the process that will monitor the job, and return.
    if ( $c->is_top_level && ! $local ) {
        $self->logsay("Submitting tasks and exiting");
        $platform->start_parent;
        return;
    }
    
    my $dir = $c->output_dir;
    $self->say(
        "If this is a big job, you should keep an eye on the rum_errors*.log",
        "files in the output directory. If all goes well they should be empty.",
        "You can also run \"$0 status -o $dir\" to check the status of the job.");

    if ($c->should_preprocess) {
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
        $platform->postprocess;
        $self->_final_check;
        my $isatab_script = $c->script("rum_isatab.pl");
        my $output_dir = $c->output_dir();
        my $isatab_file = $c->in_output_dir('a_rum_' . $c->name . '.txt');
        system "$isatab_script -o $output_dir > $isatab_file";

    }
    RUM::Lock->release;
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

    if ( $fixed && $rl < 55 && $c->no_bowtie_nu_limit) {
        $self->say;
        my $msg = <<"EOF";

WARNING: You have pretty short reads ($rl bases), and you're running
RUM with --no-bowtie-nu-limit. If you have short reads and a large
genome such as mouse or human, running Bowtie without limiting the
number of ambiguous mappers can result in extremely large output
files. By default I will cap the number of ambiguous mappers from
Bowtie at 100 to prevent very large output files, but using
--no-bowtie-nu-limit disables that limit. You may want to watch the
files that start with 'X' and 'Y' to see if they are growing larger
than 10 gigabytes per million reads, at which point you might want to
consider removing the --no-bowtie-nu-limit option.

EOF
     
        $self->logsay($msg);
   
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
            $self->clean;
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

sub clean {
    my ($self, $very) = @_;
    my $c = $self->config;

    local $_;

    # Remove any temporary files (those that end with .tmp.XXXXXXXX)
    $self->logsay("Removing files");
    find sub {
        if (/\.tmp\.........$/) {
            unlink $File::Find::name;
        }
    }, $c->output_dir;

    # Make a list of dirs to remove
    my @dirs = ($c->chunk_dir, $c->temp_dir, $c->postproc_dir);

    # If we're doing a --very clean, also remove the log directory and
    # the final output.
    if ($very) {
        my $log_dir = $c->in_output_dir("log");
        push @dirs, $log_dir, glob("$log_dir.*");
        RUM::Workflows->new($c)->postprocessing_workflow->clean(1);
        unlink($self->config->in_output_dir("quals.fa"),
               $self->config->in_output_dir("reads.fa"));
        unlink $self->config->in_output_dir("rum_job_report.txt");
        $self->say("Destroying job settings file");
        $self->config->destroy;
    }
    $log->info("Removing these directories: @dirs");
    rmtree(\@dirs);
    $self->platform->clean;
}

sub stop {
    my ($self) = @_;
    $self->platform->stop;
}

sub print_status {
    my $self = shift;

    $self->{workflows} = RUM::Workflows->new($self->config);

    $self->print_preprocessing_status;

    my $steps = $self->print_processing_status;
    $self->print_postprocessing_status($steps);
    $self->say();
    $self->_chunk_error_logs_are_empty;

    $self->say("");
    $self->platform->show_running_status;

    my $postproc = $self->{workflows}->postprocessing_workflow;

    if ($postproc->is_complete) {
        $self->say("");
        $self->say("RUM Finished.");
    }
}


sub print_preprocessing_status {
    my ($self) = @_;


    $self->say("Preprocessing");
    $self->say("-------------");
    my @chunks = $self->chunk_nums;
    my $progress = "";

    my $last_completed_chunk = 0;
    my $config = $self->config;
    my $postproc = $self->{workflows}->postprocessing_workflow;
    if ($postproc->is_complete ||
        -f $config->in_chunk_dir("preproc_done")) {
        $last_completed_chunk = @chunks;
    }
    else {
        for my $chunk (@chunks) {
            my $reads_fa = $self->config->chunk_file("reads.fa", $chunk);
            if (-f $reads_fa) {
                $last_completed_chunk = $chunk - 1;
            }
        }
    }

    my $progress = 'X' x $last_completed_chunk;
    $progress .= ' ' x (@chunks - $last_completed_chunk);
    print "$progress     Split input files\n\n";
}

sub print_processing_status {
    my ($self) = @_;

    local $_;
    my $c = $self->config;

    my @chunks = $self->chunk_nums;

    my @errored_chunks;
    my @progress;
    my $workflows = $self->{workflows};

    my $workflow = $workflows->chunk_workflow(1);
    my $plan = $workflow->state_machine->plan or croak "Can't build a plan";
    my @plan = @{ $plan };
    my $postproc = $workflows->postprocessing_workflow($c);
    my $postproc_started = $postproc->steps_done;

    for my $chunk (@chunks) {
        my $w = $workflows->chunk_workflow($chunk);
        my $m = $w->state_machine;
        my $state = $w->state;
        $m->recognize($plan, $state) 
            or croak "Plan doesn't work for chunk $chunk";

        my $skip = $m->skippable($plan, $state);

        $skip = @plan if $postproc_started;

        for (0 .. $#plan) {
            $progress[$_] .= ($_ < $skip ? "X" : " ");
        }
    }

    my $n = @chunks;

    $self->say("Processing in $n chunks");
    $self->say("-----------------------");

    for my $i (0 .. $#plan) {
        my $progress = $progress[$i] . " ";
        my $comment   = sprintf "%2d. %s", $i + 1, $workflow->comment($plan[$i]);
        print $progress, $comment, "\n";
    }

    print "\n" if @errored_chunks;
    for my $line (@errored_chunks) {
        warn "$line\n";
    }
    return @plan;
}

sub print_postprocessing_status {
    my ($self, $step_offset) = @_;
    local $_;
    my $c = $self->config;

    $self->say();
    $self->say("Postprocessing");
    $self->say("--------------");

    my $postproc = $self->{workflows}->postprocessing_workflow($c);

    my $state = $postproc->state;
    my $plan = $postproc->state_machine->plan or croak "Can't build plan";
    my @plan = @{ $plan };
    my $skip = $postproc->state_machine->skippable($plan, $state);
    for my $i (0 .. $#plan) {
        my $progress = $i < $skip ? "X" : " ";
        my $comment   = sprintf "%2d. %s", $i + $step_offset + 1, $postproc->comment($plan[$i]);
        $self->say("$progress $comment");
    };
}

1;

__END__

=pod

=head1 NAME

RUM::Pipeline - RNASeq Unified Mapper Pipeline

=head1 METHODS

=over 4

=item $pipeline->get_lock

Get a lock on the directory, or if another process has the lock, fail.

=item $pipeline->initialize

Initialize a new job based on the settings in my configuration. This
will fail if there's already a job initialized in the output
directory.

=item  $pipeline->reset_job

Reset the job so that the next step will be either the step number
identified by the "from_step" configuration property (if it is set),
or the first processing step (if it isn't). This involves deleting
files to bring the job back to the desired state.

=item $pipeline->reset_if_needed

If the pipeline's configuration has options that are explicitly
specified (rather than just falling back to the saved version of the
config file), resets the job so that it will be restarted from the
beginning (the first processing step).

=item $pipeline->start

Start whatever portions of the pipeline are appropriate based on the
configuration. The action taken will vary depending on how the job is
configured and what state it is in.

=item $pipeline->clean($very)

Remove all temporary and intermediate files that may have been left
behind. If $very is true, also remove the goal files.

=item $pipeline->stop

Stop a running job.

=item $pipeline->print_status

Print the status of all the steps in the workflow.

=item $pipeline->print_preprocessing_status

Print the status of the preprocessing steps of the workflow.

=item $pipeline->print_processing_status

Print the status of the processing steps of the workflow.

=item $pipeline->print_postprocessing_status

Print the status of the postprocessing steps of the workflow.

=back

=head1 VERSION

Version 2.0.5_05

=cut

