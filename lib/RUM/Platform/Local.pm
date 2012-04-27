package RUM::Platform::Local;

=head1 NAME

RUM::Platform::Local - A platform that runs the pipeline locally

=head1 DESCRIPTION

Runs the preprocessing and postprocessing phases simply by executing
the workflows in the current process. Runs the processing phase by
forking a subprocess for each chunk.

=head1 METHODS

=over 4

=cut

use strict;
use warnings;

use Carp;
use Text::Wrap qw(wrap fill);

use RUM::WorkflowRunner;
use RUM::Logging;
use RUM::Common qw(is_fasta is_fastq head num_digits shell format_large_int);
use RUM::Workflow;

use base 'RUM::Platform';

our $log = RUM::Logging->get_logger;

our $READ_CHECK_LINES = 50000;

################################################################################
###
### Preprocessing
###

=item preprocess

Checks the read files for quality and reformats them, splitting them
into chunks if necessary. Determines the read length and saves the
configuration so that we don't need to repeat that step.

=cut

sub preprocess {
    my ($self) = @_;

    $self->say();
    $self->say("Preprocessing");
    $self->say("-------------");

    my $config = $self->config;
    if (RUM::Workflows->postprocessing_workflow($config)->steps_done) {
        $self->say("(skipping: we're in the postprocessing phase)");
        return;
    }

    my $all_chunks_started = 1;

    for my $chunk ($self->chunk_nums) {
        my $config = $self->config->for_chunk($chunk);                
        my $workflow = RUM::Workflows->chunk_workflow($config);
        if ( ! $workflow->steps_done) {
            $all_chunks_started = 0;
        }
    }

    if ($all_chunks_started) {
        $self->say("(skipping: we're in the processing phase)");
        return;
    }

    $self->_check_input();
    $self->_reformat_reads();
    $self->_determine_read_length();
    $self->config->save;
}




sub _check_input {
    my ($self) = @_;
    $log->debug("Checking input files");
    $self->_check_reads_for_quality;

    if ($self->_reads == 1) {
        $self->_check_single_reads_file;
    }
    else {
        $self->_check_read_file_pair;
        $self->config->set("paired_end", 1);
        $self->config->save;
    }

}

sub _check_single_reads_file {
    my ($self) = @_;

    my $config = $self->config;
    my @reads  = $self->_reads;

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


sub _check_reads_for_quality {
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

sub _check_read_files_same_size {
    my ($self) = @_;
    my @sizes = map -s, $self->_reads;
    $sizes[0] == $sizes[1] or die
        "The fowards and reverse files are different sizes. $sizes[0]
        versus $sizes[1].  They should be the exact same size.";
}

sub _check_read_file_pair {

    my ($self) = @_;
    
    my @reads = @{ $self->config->reads };

    $self->_check_read_files_same_size();

    my $config = $self->config;

    # Check here that the quality scores are the same length as the reads.

    my $len = `head -50000 $reads[0] | wc -l`;
    chomp($len);
    $len =~ s/[^\d]//gs;

    my $parse2fasta = $config->script("parse2fasta.pl");
    my $fastq2qualities = $config->script("fastq2qualities.pl");

    my $reads_temp = $config->in_output_dir("reads_temp.fa");
    my $quals_temp = $config->in_output_dir("quals_temp.fa");
    my $error_log = $self->_preproc_error_log_filename;

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

sub _determine_read_length {
    
    my ($self) = @_;

    my @lines = head($self->config->for_chunk(1)->chunk_suffixed("reads.fa"), 2);
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

sub _preproc_error_log_filename {
    my ($self) = @_;
    my $dir = File::Spec->catfile($self->config->output_dir, "tmp");
    unless (-e $dir) {
        mkdir $dir or croak "mkdir $dir: $!";
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
    my $num_chunks = $config->num_chunks || 1;

    my @reads = @{ $config->reads };

    my $reads_fa = $config->for_chunk(1)->in_output_dir("reads.fa");
    my $quals_fa = $config->for_chunk(1)->in_output_dir("quals.fa");

    my $name_mapping_opt = $config->preserve_names ?
        "-name_mapping $output_dir/read_names_mapping" : "";    
    
    my $error_log = $self->_preproc_error_log_filename;

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
        shell("perl $parse_fastq $reads_in $num_chunks $reads_fa $quals_fa $name_mapping_opt 2>> $error_log");
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

        $self->_breakup_file($reads[0], 0);

        if ($have_quals) {
            $self->say( "Half done splitting; starting qualities...");
            _breakup_file($config->chunk_suffixed("quals.fa"), 1);
        }
        elsif ($config->user_quals) {
            $self->say( "Half done splitting; starting qualities...");
            _breakup_file($config->user_quals, 1);
        }
        $self->say("Done splitting");
    }
}

sub _breakup_file  {
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


## Processing

=item process

Runs the processing phase. If the configuration specifies a single
chunk, we run that chunk in the foreground and print messages to
stdout. If not, we fork off a subprocess for each chunk and wait for
all the chunks to finish.

=cut

sub process {
    my ($self) = @_;

    my $config = $self->config;

    my $postproc_started = RUM::Workflows->postprocessing_workflow($config)->steps_done;

    $log->debug("Chunk is ". ($config->chunk ? "yes" : "no"));

    my $n = $config->num_chunks || 1;
    $self->say();
    $self->say("Processing in $n chunks");
    $self->say("-----------------------");

    if ($postproc_started) {
        $self->say("(skipping: we're in the postprocessing phase)");
        return;
    }

    if ($n == 1 || $config->chunk) {
        my $chunk = $config->chunk || 1;
        $log->info("Running chunk $chunk");
        my $config = $self->config->for_chunk($chunk);
        my $w = RUM::Workflows->chunk_workflow($config);
        $w->execute($self->_step_printer($w), ! $self->directives->no_clean);
    }
    elsif ($config->num_chunks) {
        $self->_process_in_chunks;
    }
}


sub _process_in_chunks {
    my ($self) = @_;
    my $n = $self->config->num_chunks;
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
        my @cmd = ($0, "align", "--child", "--output", $self->config->output_dir,
                   "--chunk", $chunk);
        push @cmd, "--no-clean" if $self->directives->no_clean;
        my $config = $self->config->for_chunk($chunk);                
        my $workflow = RUM::Workflows->chunk_workflow($config);

        my $run = sub {
            if (my $pid = fork) {
                $pid_to_chunk{$pid} = $chunk;
            }
            else {
                $ENV{RUM_CHUNK} = $chunk;
                $ENV{RUM_OUTPUT_DIR} = $config->output_dir;
                open STDOUT, ">", $config->chunk_replaced("chunk_%d.out");
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

=item postprocess

Runs the postprocessing phase, in the current process.

=cut

sub postprocess {
    my ($self) = @_;
    $self->say();
    $self->say("Postprocessing");
    $self->say("--------------");

    my $w = RUM::Workflows->postprocessing_workflow($self->config);
    $w->execute($self->_step_printer($w), ! $self->directives->no_clean);
}

sub _reads {
    return @{ $_[0]->config->reads };
}

1;
