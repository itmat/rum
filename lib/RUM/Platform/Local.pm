package RUM::Platform::Local;

use strict;
use warnings;
use autodie;

use Carp;
use Text::Wrap qw(wrap fill);
use File::Path qw(mkpath);

use RUM::WorkflowRunner;
use RUM::Logging;
use RUM::Common qw(is_fasta is_fastq head num_digits shell format_large_int open_r shell);
use RUM::Workflow;
use RUM::JobReport;

use base 'RUM::Platform';

our $log = RUM::Logging->get_logger;

our $READ_CHECK_LINES = 50000;

################################################################################
###
### Preprocessing
###

sub preprocess {
    my ($self) = @_;
    my $config = $self->config;

    my $flag_file = $config->in_chunk_dir("preproc_done");

    $self->say();
    $self->say("Preprocessing");
    $self->say("-------------");

    # If any steps of postprocessing have run, then we don't need to
    # run preprocessing.
    if ($self->postprocessing_workflow->steps_done) {
        $self->say("(skipping: we're in the postprocessing phase)");
        $self->job_report->print_skip_preproc;
        return;
    }

    $self->job_report->print_start_preproc;

    # We don't start any chunks until preprocessing is completely
    # done. So if any chunks have started, we don't need to do
    # preprocessing. TODO: It would be better to split preprocessing
    # up so at can be run as the first step of each chunk.
    for my $chunk ($self->chunk_nums) {
        my $workflow = $self->chunk_workflow($chunk);
        if ($workflow->steps_done) {
            $self->say("(skipping: we're in the processing phase)");
            $log->info("Not preprocessing, as we seem to be in the " .
                           "processing phase");
            return;
        }
    }

    if (-e $flag_file) {
        $self->say("(skipping: preprocessing is done)");
        $self->job_report->print_skip_preproc;
        return;
    }

    $self->_check_input();
    $self->_reformat_reads();
    $self->_determine_read_length();
    $self->config->save;
    $self->{workflows} = undef;
    $self->job_report->print_finish_preproc;
    open my $flag_fh, '>', $flag_file;
    print $flag_fh '';
    close $flag_fh;
}

sub _check_input {
    my ($self) = @_;
    $log->info("Checking input files for quality");
    $self->_check_reads_for_quality;

    if (!$self->config->reverse_reads) {
        $log->info("Got a single read file");
        $self->_check_single_reads_file;
    }
    else {
        $log->info("Got two read files, so assuming paired-end");
        $self->config->set("paired_end", 1);
    }
    $self->_check_read_file_pair;

    $self->logsay(sprintf("Processing as %s-end data",
                          $self->config->paired_end ?
                          "paired" : "single"));
}

sub _check_single_reads_file {
    my ($self) = @_;

    my $config = $self->config;
    my @reads  = $config->reads;

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
        $log->info("Input is in a single file, but appears to be paired-end");
        ($paired, $needs_splitting, $preformatted) = (1, 1, 1);
    }
    if($nums[0] == 1 && $nums[1] == 2 && $types[0] eq 'a' && $types[1] eq 'a') {
        $log->info("Input is in a single file and does not appear to be paired-end");
        ($paired, $needs_splitting, $preformatted) = (0, 1, 1);
    }

    $config->set("paired_end", $paired);
    $config->set("input_needs_splitting", $needs_splitting);
    $config->set("input_is_preformatted", $preformatted);
    $config->save();
}

sub _check_split_files {
    my ($self) = @_;
    $self->say("Checking that files were split properly");
    my $config = $self->config;
    my $chunks = $config->chunk;
    my @errors;
    for my $chunk (1 .. $config->chunks) {
        my $filename = $config->chunk_file('reads.fa', $chunk);
        if (-e $filename) {
            my @lines = `tail -n 2 $filename`;
            my $last_header = $lines[0];
            if ($last_header !~ /^>seq.\d+/) {
                push @errors, "Second to last line in $filename doesn't look ".
                "like a FASTA header line";
            }
        }
        else {
            push @errors, "$filename does not exist";
        }
    }
    if (@errors) {
        my $msg = 'It looks like there was an eror splitting the input ' .
        'files. This could mean that there was a problem with the ' .
        'filesystem during the preprocessing phase. You should probably '.
        'start the job over from the beginning. You can do this '  .
        'by first clearing out the job with "rum_runner kill" and then ' .
        'running it again with "rum_runner align". The specific errors '  .
        'are: ';
        $msg .= "\n\n";
        $msg .= join('', map { "* $_\n" } @errors);
        die $msg;
    }
}





sub _check_reads_for_quality {
    my ($self) = @_;

    for my $filename ($self->config->reads) {
        $log->debug("Checking $filename");
        open my $fh, "<", $filename;
        my $counter = 0;

        while (defined (my $line = <$fh>)) {
            last if $counter++ > 50000;
            next unless $line =~ /:Y:/;
            $line = <$fh>;
            chomp $line;
            if ($line =~ /^--$/) {
                die "you appear to have entries in your fastq file \"$filename\" for reads that didn't pass quality. These are lines that have \":Y:\" in them, probably followed by lines that just have two dashes \"--\". You first need to remove all such lines from the file, including the ones with the two dashes...";
            }
        }
    }
}

sub _check_read_files_same_size {
    my ($self) = @_;
    my @sizes = map -s, $self->config->reads;
    $sizes[0] == $sizes[1] or die
        "The forwards and reverse files are different sizes ($sizes[0] ".
        " and $sizes[1]).  They should be the exact same size.";
}

sub _check_read_file_pair {

    my ($self) = @_;
    
    my @reads = $self->config->reads;

    if (@reads == 2) {
        if ($self->config->variable_length_reads) {
            $self->say("Working with variable length reads; skipping check to make sure files are the same size.");
        } elsif ($reads[0] !~ /\.gz$/ && 
            $reads[1] !~ /\.gz$/) {
            $self->_check_read_files_same_size();
        }
        else {
            $self->say("Working with gzipped input; skipping check to make sure files are the same size.");
        }
    }

    my $config = $self->config;

    # Check here that the quality scores are the same length as the reads.

    my $in = open_r($reads[0]);
    my $len = 0;
    while (defined(my $line = <$in>) &&
           ++$len < 50000) {
    }
    close $in;

    my $parse2fasta = $config->script("parse2fasta.pl");
    my $fastq2qualities = $config->script("fastq2qualities.pl");

    my $reads_temp = $config->in_output_dir("reads_temp.fa");
    my $quals_temp = $config->in_output_dir("quals_temp.fa");
    my $error_log = $self->_preproc_error_log_filename;

    $log->info("Checking that reads and quality strings are the same length");
    shell("perl $parse2fasta     @reads | head -$len > $reads_temp 2>> $error_log");
    shell("perl $fastq2qualities @reads | head -$len > $quals_temp 2>> $error_log");

    if (_got_quals($quals_temp)) {
        open(RFILE, $reads_temp);
        open(QFILE, $quals_temp);
        while(my $linea = <RFILE>) {
            my $lineb = <QFILE>;
            my $line1 = <RFILE>;
            my $line2 = <QFILE>;
            chomp($line1);
            chomp($line2);
            if(length($line1) != length($line2)) {
                die "It seems your read lengths differ from your quality string lengths. Check line:\n$linea$line1\n$lineb$line2.\nThis error could also be due to having reads of length 10 or less, if so you should remove those reads.";
            }
        }
    }

    # Check that reads are not variable length
    $self->_check_variable_length($reads_temp);

    # Clean up:
    unlink($reads_temp);
    unlink($quals_temp);
}


sub _check_variable_length {

    my ($self, $filename) = @_;
    open my $in, "<", $filename;

    $log->info("Determining if reads are variable-length");

    my $length_flag = 0;
    my $length_hold;
    my $c = $self->config;
    while(my $linea = <$in>) {
        my $line1 = <$in>;
        chomp($line1);
        if($length_flag == 0) {
            $length_hold = length($line1);
            $length_flag = 1;
        }
        if(length($line1) != $length_hold && !$c->variable_length_reads) {
            $self->logsay("It seems your read lengths vary, but you didn't set -variable_length_reads. I'm going to set it for you, but it's generally safer to set it on the command-line since I only spot check the file.");
            $self->say();
            $c->set('variable_length_reads', 1);
        }
        $length_hold = length($line1);
    }
    
}


sub _determine_read_length {
    
    my ($self) = @_;

    my @lines = head($self->config->in_output_dir("reads.fa"), 2);
    my $read = $lines[1];
    my $len = length($read);
    my $min = $self->config->min_length;
    $log->debug("Read length is $len, min is " . ($min ||"")) if $log->is_debug;
    if ($self->config->variable_length_reads) {
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

sub _preproc_error_log_filename {
    my ($self) = @_;
    my $dir = File::Spec->catfile($self->config->output_dir, "tmp");
    unless (-e $dir) {
        mkdir $dir;
    }
    File::Spec->catfile($dir, "preproc-error-log");
}

sub _reformat_reads {

    my ($self) = @_;

    $self->say("Reformatting reads file... please be patient.");

    my $config = $self->config;
    my $output_dir = $config->output_dir;
    my $parse_fastq = $config->script("parsefastq.pl");
    my $parse_fasta = $config->script("parsefasta.pl");
    my $parse_2_fasta = $config->script("parse2fasta.pl");
    my $parse_2_quals = $config->script("fastq2qualities.pl");
    my $num_chunks = $config->chunks || 1;

    mkpath($config->chunk_dir);

    my @reads = $config->reads;

    my $reads_fa = $config->in_output_dir("reads.fa");
    my $quals_fa = $config->in_output_dir("quals.fa");

    my $name_mapping_opt = $config->preserve_names ?
        "-name_mapping $output_dir/read_names_mapping" : "";    
    
    my $error_log = $self->_preproc_error_log_filename;

    # Going to figure out here if these are standard fastq files

    my $is_fasta = is_fasta($reads[0]);
    my $is_fastq = is_fastq($reads[0]);
    my $preformatted = @reads == 1 && $config->input_is_preformatted;
    my $reads_in = join(",,,", @reads);

    my $have_quals = 0;

    if($is_fastq && !$config->variable_length_reads) {
        $self->say("Splitting fastq file into $num_chunks chunks ",
                   "with separate reads and quals");
        shell("perl $parse_fastq $reads_in $num_chunks $reads_fa $quals_fa $name_mapping_opt 2>> $error_log");
        my @errors = `grep -A 2 "something wrong with line" $error_log`;
        croak "@errors" if @errors;
        $have_quals = 1;
        $self->{input_needs_splitting} = 0;
        return;
    }
 
    elsif ($is_fasta && !$config->variable_length_reads && !$preformatted) {
        $self->say("Splitting fasta file into $num_chunks chunks");
        shell("perl $parse_fasta $reads_in $num_chunks $reads_fa $name_mapping_opt 2>> $error_log");
        $have_quals = 0;
        $self->{input_needs_splitting} = 0;
        return;
     } 

    elsif (!$preformatted) {
        $self->say("Splitting fasta file into reads and quals");
        shell("perl $parse_2_fasta @reads > $reads_fa 2>> $error_log");
        shell("perl $parse_2_quals @reads > $quals_fa 2>> $error_log");
        
        $have_quals = _got_quals($quals_fa);
    }
    else {
        shell("ln", "-s", $reads_in, $reads_fa);
    }

    # This should only be entered when we have one read file
    $self->say("Splitting read file, please be patient...");        
    
    $self->_breakup_file($reads_fa, 0);

    if ($have_quals) {
        $self->say( "Half done splitting; starting qualities...");
        $self->_breakup_file($quals_fa, 1);
    }
    elsif ($config->quals_file) {
        $self->say( "Half done splitting; starting qualities...");
        $self->_breakup_file($config->user_quals, 1);
    }
    $self->say("Done splitting");
}

sub _got_quals {
    my ($filename) = @_;
    open my $in, "<", $filename;
    for my $i (1 .. 20) {
        defined(local $_ = <$in>) or return 1;
        return 0 if /Sorry, can't figure these files out/s;
    }
    return 1;
}

sub _breakup_file  {
    my ($self, $FILE, $qualflag) = @_;

    my $c = $self->config;

    open(INFILE, $FILE);

    my $tail = `tail -2 $FILE | head -1`;
    $tail =~ /seq.(\d+)/s;
    my $numseqs = $1;
    my $piecesize = int($numseqs / ($c->chunks || 1));

    my $t = `tail -2 $FILE`;
    $t =~ /seq.(\d+)/s;
    my $NS = $1;
    my $piecesize2 = format_large_int($piecesize);
    if(!($FILE =~ /qual/)) {
	if($c->chunks > 1) {
	    $self->say("processing in ".
                     $c->chunks . 
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
    my $base_name = $qualflag ? "quals.fa" : "reads.fa";
    for(my $i=1; $i < $c->chunks; $i++) {
	my $outfilename = $c->chunk_file($base_name, $i);

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

    my $outfilename = $c->chunk_file($base_name, $c->chunks);
    open(OUTFILE, ">$outfilename");
    while(my $line = <INFILE>) {
	print OUTFILE $line;
    }
    close(OUTFILE);

    return 0;
}

## Processing

sub process {
    my ($self, $chunk) = @_;

    my $config = $self->config;

    my $postproc_started = $self->postprocessing_workflow->steps_done;

    $log->debug("Chunk is ".($chunk || ""));

    my $n = $config->chunks || 1;
    $self->say();
    $self->say("Processing in $n chunks");
    $self->say("-----------------------");

    if ($postproc_started) {
        $self->say("(skipping: we're in the postprocessing phase)");
        return;
    }

    $self->_check_split_files();
    
    if ($n == 1 || $chunk) {
        my $chunk = $chunk || 1;
        $log->info("Running chunk $chunk");
        my $w = $self->chunk_workflow($chunk);
        $w->execute($self->_step_printer($w), ! $config->no_clean);
        RUM::JobReport->new($self->config)->print_milestone("Chunk $chunk finished");
    }
    elsif ($config->chunks) {
        $self->_process_in_chunks;
    }
}


sub _process_in_chunks {
    my ($self) = @_;
    my $n = $self->config->chunks;
    my $c = $self->config;
    $log->info("Creating $n chunks");

    my %pid_to_chunk; # Maps a process ID to the chunk it is running
    my @tasks; # Maps a chunk number to a RUM::RestartableTask
    
    $SIG{TERM} = sub {
        $log->warn("Caught SIGTERM, killing child processes");
        for my $pid (keys %pid_to_chunk) {
            $log->warn("  Killing $pid (chunk $pid_to_chunk{$pid})");
            kill 15, $pid;
            waitpid $pid, 0;
        }
        die;
    };

    for my $chunk ($self->chunk_nums) {
        my @cmd = ($0, "resume", "--child", "--output", $c->output_dir,
                   "--chunk", $chunk);
        push @cmd, "--no-clean" if $c->no_clean;
        my $workflow = $self->chunk_workflow($chunk);

        my $run = sub {
            if (my $pid = fork) {
                $pid_to_chunk{$pid} = $chunk;
            }
            else {
                $ENV{RUM_CHUNK} = $chunk;
                $ENV{RUM_OUTPUT_DIR} = $c->output_dir;
                $ENV{RUM_INFO_LOG_FILE}  = RUM::Logging->log_file($chunk);
                $ENV{RUM_ERROR_LOG_FILE} = RUM::Logging->error_log_file($chunk);
                open STDOUT, ">", $c->chunk_file("chunk.out", $chunk);
                exec @cmd;
            }
        };

        my $task =  RUM::WorkflowRunner->new($workflow, $run);
        $tasks[$chunk] = $task;
        $task->run;
    }

    $self->say(
        "All chunks initiated, now the long wait...",
        "I'm going to watch for all chunks to finish, then I will merge everything");

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

    delete $SIG{TERM};
    
}

sub _step_printer {
    my ($self, $workflow) = @_;
    return sub {
        my ($step, $skipping) = @_;
        my $indent = $skipping ? "(skipping) " : "(running)  ";
        my $comment = $workflow->comment($step);
        $self->say(wrap($indent, "           ", $comment));
    };
}

## Post-processing

sub postprocess {
    my ($self) = @_;

    my $c = $self->config;

    # If I'm called before processing is done, sleep until it is
    # done. This is so we can make one of the chunks do
    # postprocessing, but only after all the other chunks are done.
    while ($self->still_processing) {
        $log->info("Processing is not complete, going to sleep");
        sleep(30);
    }
    $log->info("Processing is complete");

    $self->say();
    $self->say("Postprocessing");
    $self->say("--------------");

    $log->info("---");
    $log->info("---");
    $log->info("--- Postprocessing starts here");
    $log->info("---");
    $log->info("---");

    $self->job_report->print_start_postproc;

    my $w = $self->postprocessing_workflow;
    $w->execute($self->_step_printer($w), ! $c->no_clean);

    $self->job_report->print_finish_postproc;
}

sub pid {
    my ($self) = @_;

    my $lock_file = $self->config->lock_file;

    return if ! -e $lock_file;
    open my $in, "<", $lock_file;
    my $pid = int(<$in>) or croak 
    "The lock file $lock_file exists but does not contain a pid";

}

sub stop {
    my ($self) = @_;

    if (defined(my $pid = $self->pid)) {
        $self->say("Killing process $pid");
        kill 15, $pid or croak "I can't kill $pid: $!";
    }
    else {
        $self->alert(
            "There doesn't seem to be a RUM job running in ",
            $self->config->output_dir());
    }

}

sub job_report {
    my ($self) = @_;
    return RUM::JobReport->new($self->config);
}

sub is_running {
    my ($self) = @_;
    return defined $self->pid;
}

sub show_running_status {
    my ($self) = @_;
    my $pid = $self->pid;
    if (defined $pid) {
        $self->say("RUM is currently running (PID $pid).");
    }
    else {
        $self->say("RUM is not running.");
    }
}

1;

__END__

=head1 NAME

RUM::Platform::Local - A platform that runs the pipeline locally

=head1 DESCRIPTION

Runs the preprocessing and postprocessing phases simply by executing
the workflows in the current process. Runs the processing phase by
forking a subprocess for each chunk.

=head1 METHODS

=over 4

=item preprocess

Checks the read files for quality and reformats them, splitting them
into chunks if necessary. Determines the read length and saves the
configuration so that we don't need to repeat that step.

=item process

Runs the processing phase. If the configuration specifies a single
chunk, we run that chunk in the foreground and print messages to
stdout. If not, we fork off a subprocess for each chunk and wait for
all the chunks to finish.

=item postprocess

Runs the postprocessing phase, in the current process.

=item stop

Attempt to stop a running pipeline by getting the pid from the
.rum/lock file and killing that process.

=item job_report

Return a RUM::JobReport that can be used to print timestamps for
milestones.

=item is_running

Return true if the job appears to be running (based on the presence of
the lock file).

=item pid

Return the process id of the parent process.

=item show_running_status

Print a message to stdout indicating whether the job is running or
not.

=back

=head1 AUTHOR

Mike DeLaurentis (delaurentis@gmail.com)

=head1 COPYRIGHT

Copyright 2012, University of Pennsylvania
