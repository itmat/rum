package RUM::Script::Runner;

use strict;
use warnings;

use Getopt::Long;
use FindBin qw($Bin);
FindBin->again;

use RUM::ChunkMachine;
use RUM::Repository;
use RUM::Usage;
use RUM::Logging;
use RUM::Pipeline;
use RUM::Common qw(is_fasta is_fastq head num_digits);
use File::Path qw(mkpath);
use Text::Wrap qw(wrap fill);
use RUM::Workflow qw(shell);
use Carp;
our $log = RUM::Logging->get_logger();

our $LOGO;

sub DEBUG  { $log->debug(wrap("", "", @_))  }
sub INFO   { $log->info(wrap("", "", @_))   }
sub WARN   { $log->warn(wrap("", "", @_))   }
sub ERROR  { $log->error(wrap("", "", @_))  }
sub FATAL  { $log->fatal(wrap("", "", @_))  }
sub LOGDIE { $log->logdie(wrap("", "", @_)) }

sub main {
    my $config = __PACKAGE__->get_options();
    my $self = __PACKAGE__->new(config => $config);
    $self->show_logo();

    if ($config->do_status) {
        $self->print_status;
        return;
    }

    $self->preprocess  if $config->do_preprocess;

    if ($config->do_shell_script) {
        $self->export_shell_script;
        return;
    }

    $self->process     if $config->do_process;
    $self->postprocess if $config->do_postprocess;
}


sub get_options {
    
    my $c = RUM::Config->new();

    Getopt::Long::Configure(qw(no_ignore_case));
    my @argv = @ARGV;
    GetOptions(

        "version|V"    => \(my $do_version),
        "kill"         => \(my $do_kill),
        "preprocess"   => \(my $do_preprocess),
        "process"      => \(my $do_process),
        "postprocess"  => \(my $do_postprocess),
        "status"       => \(my $do_status),
        "shell-script" => \(my $do_shell_script),

        "config=s"    => \(my $rum_config_file),

        "output|o=s"  => \(my $output_dir),
        "name=s"      => \(my $name),
        "chunks=s"    => \(my $num_chunks = 0),
        "chunk=s"     => \(my $chunk),
        "help-config" => \(my $do_help_config),
        "read-lengths=s" => \(my $read_lengths),

        "max-insertions-per-read=s" => \(my $num_insertions_allowed),
        "strand-specific" => \(my $strand_specific),
        "ram" => \(my $ram = 6),
        "preserve-names" => \(my $preserve_names),
        "no-clean" => \(my $no_clean),
        "junctions" => \(my $junctions),
        "blat-only" => \(my $blat_only),
        "quantify" => \(my $quantify),
        "count-mismatches" => \(my $count_mismatches),
        "variable-read-lengths|variable-length-reads" => \(my $variable_read_lengths),
        "dna" => \(my $dna),
        "genome-only" => \(my $genome_only),

        "limit-bowtie-nu" => \(my $limit_bowtie_nu),
        "limit-nu=s" => \(my $nu_limit),
        "qsub" => \(my $qsub),
        "alt-genes=s" => \(my $alt_genes),
        "alt-quants=s" => \(my $alt_quant),

        "min-identity" => \(my $min_identity = 93),

        "tileSize=s" => \(my $tile_size = 12),
        "stepSize=s" => \(my $step_size = 6),
        "repMatch=s" => \(my $rep_match = 256),
        "maxIntron=s" => \(my $max_intron = 500000),

        "min-length=s" => \(my $min_length),

        "quals-file|qual-file=s" => \(my $quals_file),
        "verbose|v"   => sub { $log->more_logging(1) },
        "quiet|q"     => sub { $log->less_logging(1) },
        "help|h"        => sub { RUM::Usage->help }

    );

    if ($do_version) {
        print "RUM version $RUM::Pipeline::VERSION, released $RUM::Pipeline::RELEASE_DATE\n";
        return;
    }
    if ($do_help_config) {
        print $RUM::ConfigFile::DOC;
        return;
    }

    !defined($quals_file) || $quals_file =~ /\// or RUM::Usage->bad(
        "do not specify -quals file with a full path, put it in the '$output_dir' directory.");
    
    $min_identity =~ /^\d+$/ && $min_identity <= 100 or RUM::Usage->bad(
        "--min-identity must be an integer between zero and 100. You
        have given '$min_identity'.");

    if (defined($min_length)) {
        $min_length =~ /^\d+$/ && $min_length >= 10 or RUM::Usage->bad(
            "--min-length must be an integer >= 10. You have given '$min_length'.");
    }
    
    if (defined($nu_limit)) {
        $nu_limit =~ /^\d+$/ && $nu_limit > 0 or RUM::Usage->bad(
            "--limit-nu must be an integer greater than zero.\nYou have given '$nu_limit'.");
    }

    $preserve_names && $variable_read_lengths and RUM::Usage->bad(
        "Cannot use both -preserve_names and -variable_read_lengths at the same time.\nSorry, we will fix this eventually.");

    if ($alt_genes) {
        -r $alt_genes or LOGDIE "Can't read from $alt_genes: $!";
    }
    if ($alt_quant) {
        -r $alt_quant or LOGDIE "Can't read from $alt_quant: $!";
    }

    $rum_config_file or RUM::Usage->bad(
        "Please specify a rum config file with --config");

    $output_dir or RUM::Usage->bad(
        "Please specify an output directory with --output or -o");

    $name or RUM::Usage->bad(
        "Please provide a name with --name");
    $name = fix_name($name);

    # Check the values supplied as the reads
    my @reads = @ARGV;
    @reads == 1 or @reads == 2 or RUM::Usage->bad(
        "Please provide one or two read files");
    $reads[0] ne $reads[1] or RUM::Usage->bad(
        "You specified the same file for the forward and reverse reads, must be an error...");

    my $config = RUM::Config->new(
        reads => \@reads,
        preserve_names => $preserve_names,
        min_length => $min_length,
        output_dir => $output_dir,
        num_chunks => $num_chunks
    );

    $config->set('chunk', $chunk) if $chunk;

    if ($chunk) {
        $log->debug("I was told to run chunk $chunk, so I won't preprocess or postprocess the files");
        $config->set('do_process', 1);
        $config->set("do_$_", 0) for qw(preprocess postprocess);
    }
    elsif ($do_preprocess || $do_process || $do_postprocess) {
        $config->set('do_preprocess', $do_preprocess);
        $config->set('do_process', $do_process);
        $config->set('do_postprocess', $do_postprocess);
    }
    else {
        $config->set("do_$_", 1) for qw(preprocess process postprocess);
    }

    $config->set('do_status', $do_status);
    $config->set('do_shell_script', $do_shell_script);

    $config->load_rum_config_file($rum_config_file);
    $config->set('argv', \@argv);
    return $config;
}


sub config {
    return $_[0]->{config};
}

sub preprocess {
    my ($self) = @_;
    $self->setup;
    $self->check_input();
    $self->reformat_reads();
    $self->determine_read_length();
}

sub step_printer {
    my ($chunk) = @_;
    return sub {
        my ($step, $skipping) = @_;
        my $indent = $skipping ? "(skipping) " : "(running)  ";
        my $comment = $chunk->step_comment($step);
        $log->info(wrap($indent, "           ", $comment));
    };
}

sub process {
    my ($self) = @_;
    $self->determine_read_length();
    my $config = $self->config;

    $log->info("Chunk is ". ($config->chunk ? "yes" : "no"));

    if (my $chunk = $config->chunk) {
        $log->info("Running chunk $chunk");
        my $machine = $self->chunk_machine($chunk);
        $machine->execute(step_printer($machine));
    }
    elsif (my $n = $config->num_chunks) {
        $log->info("Creating $n chunks");
        my @pids;

        my %pid_to_chunk;
        my %run_count;

        my $kickoff_chunk = sub {
            my ($chunk) = @_;
            my @argv = (@{ $config->argv }, "--chunk", $chunk);
            if (my $pid = fork) {
                $pid_to_chunk{$pid} = $chunk;
            }
            else {
                my $cmd = "$0 @argv > /dev/null";
                my $config = $config->for_chunk($chunk);
                $ENV{RUM_CHUNK_LOG} = $config->log_file;
                $ENV{RUM_CHUNK_ERROR_LOG} = $config->error_log_file;
                exec $cmd;
            }            
        };

        for my $chunk (1 .. $config->num_chunks) {
            $kickoff_chunk->($chunk);
        }

        while (1) {
            my $pid = wait;
            if ($pid < 0) {
                $log->info("All children done");
                last;
            }
            elsif ($?) {
                $log->error("Pid $pid (chunk $pid_to_chunk{$pid}) exited with status $?. I will attempt to restart it.");
            }
            else {
                $log->info("Pid $pid (chunk $pid_to_chunk{$pid}) finished");
            }
        }
    }
    else {
        $log->info("Running whole job (not splitting into chunks)");
        my $chunk = RUM::ChunkMachine->new($config);
        $chunk->execute(step_printer($chunk));
    }



}

sub postprocess {
    my ($self) = @_;
    
}

sub setup {
    my ($self) = @_;
    my $output_dir = $self->config->output_dir;
    unless (-d $output_dir) {
        mkpath($output_dir) or LOGDIE "mkdir $output_dir: $!";
    }

}

################################################################################
##
## Preprocessing checks on the input files
##

our $READ_CHECK_LINES = 50000;


sub check_input {
    my ($self) = @_;
    INFO("Checking input files");
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
    my ($self, $fh, $name) = @_;

    for my $filename (@{ $self->config->reads }) {
        
        open my $fh, "<", $filename or croak
            "Can't open reads file $filename for reading: $!";

        while (local $_ = <$fh>) {
            next unless /:Y:/;
            $_ = <$fh>;
            chomp;
            /^--$/ and LOGDIE "you appear to have entries in your fastq file \"$name\" for reads that didn't pass quality. These are lines that have \":Y:\" in them, probably followed by lines that just have two dashes \"--\". You first need to remove all such lines from the file, including the ones with the two dashes...";
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
                LOGDIE("It seems your read lengths differ from your quality string lengths. Check line:\n$linea$line1\n$lineb$line2.\nThis error could also be due to having reads of length 10 or less, if so you should remove those reads.");
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
                WARN("It seems your read lengths vary, but you didn't set -variable_length_reads. I'm going to set it for you, but it's generally safer to set it on the command-line since I only spot check the file.");
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

    my @lines = head($self->config->reads_fa, 2);
    my $read = $lines[1];
    my $len = split(//,$read);
    my $min = $self->config->min_length;
    $log->debug("Read length is $len, min is $min") if $log->is_debug;
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
    my ($class, %options) = @_;
    my $self = {};
    $self->{config} = delete $options{config};
    bless $self, $class;
}

sub show_logo {
    my $msg = <<EOF;

RUM Version $RUM::Pipeline::VERSION

$LOGO
EOF
    $log->info($msg);

}

sub fix_name {

    my ($name) = @_;

    my $name_o = $name;
    $name =~ s/\s+/_/g;
    $name =~ s/^[^a-zA-Z0-9_.-]//;
    $name =~ s/[^a-zA-Z0-9_.-]$//g;
    $name =~ s/[^a-zA-Z0-9_.-]/_/g;
    
    if($name ne $name_o) {
        WARN("Name changed from '$name_o' to '$name'.");
        if(length($name) > 250) {
            LOGDIE("The name must be less than 250 characters.");
        }
    }
    return $name;
}

sub check_gamma {
    my ($self) = @_;
    my $host = `hostname`;
    if ($host =~ /login.genomics.upenn.edu/ && !$self->config->qsub) {
        LOGDIE("you cannot run RUM on the PGFI cluster without using the --qsub option.");
    }
}

sub reads {
    return @{ $_[0]->config->reads };
}

sub reformat_reads {

    my ($self) = @_;

    INFO("Reformatting reads file... please be patient.");

    my $config = $self->config;
    my $output_dir = $config->output_dir;
    my $parse_fastq = $config->script("parsefastq.pl");
    my $parse_fasta = $config->script("parsefasta.pl");
    my $parse_2_fasta = $config->script("parse2fasta.pl");
    my $parse_2_quals = $config->script("fastq2qualities.pl");
    my $num_chunks = $config->num_chunks;

    my @reads = @{ $config->reads };

    my $reads_fa = $config->reads_fa;
    my $quals_fa = $config->quals_fa;

    my $name_mapping_opt = $config->preserve_names ? "-name_mapping $output_dir/read_names_mapping" : "";    
    
    my $error_log = "$output_dir/rum.error-log";

    # Going to figure out here if these are standard fastq files

    my @fh;
    for my $filename (@reads) {
        open my $fh, "<", $filename;
        push @fh, $fh;
    }

    my $is_fasta = is_fasta($fh[0]);
    my $is_fastq = is_fastq($fh[0]);
    my $preformatted;

    my $reads_in = join(",,,", @reads);

    if($is_fastq  && !$config->variable_read_lengths && $num_chunks > 1) {
        INFO("Splitting fastq file into $num_chunks chunks with separate reads and quals");
        shell("perl $parse_fastq $reads_in $num_chunks $reads_fa $quals_fa $name_mapping_opt 2>> $output_dir/rum.error-log");
        my @errors = `grep -A 2 "something wrong with line" $error_log`;
        die "@errors" if @errors;
        $self->{quals} = 1;
        $self->{input_needs_splitting} = 0;
    }
 
    elsif ($is_fasta && !$config->variable_read_lengths && !$preformatted && $num_chunks > 1) {
        INFO("Splitting fasta file into $num_chunks chunks");
        shell("perl $parse_fasta $reads_in $num_chunks $reads_fa $name_mapping_opt 2>> $error_log");
        $self->{quals} = 0;
        $self->{input_needs_splitting} = 0;
     } 

    elsif (!$preformatted) {
        INFO("Splitting fasta file into reads and quals");
        shell("perl $parse_2_fasta @reads > $reads_fa 2>> $error_log");
        shell("perl $parse_2_quals @reads > $quals_fa 2>> $error_log");
        $self->{input_needs_splitting} = 1;
        my $X = join("\n", head($config->quals_fa, 20));
        if($X =~ /\S/s && !($X =~ /Sorry, can't figure these files out/s)) {
            $self->{quals} = "true";
        }
    }
}

sub print_status {
    my ($self) = @_;
    local $_;
    my $config = $self->config;

    my @steps;
    my %num_completed;
    my %comments;
    my @machines = $self->chunk_machines;
    for my $m (@machines) {

        for my $row ($m->state_report) {
            my ($completed, $name) = @$row;
            unless (exists $num_completed{$name}) {
                $num_completed{$name} = 0;
                $comments{$name} = $m->step_comment($name);
                push @steps, $name;
            }
            $num_completed{$name} += $completed;
        }
    }


    my $n = @machines;
    my $digits = num_digits($n);
    my $format = "%${digits}d/%${digits}d";

    for (@steps) {
        my $progress = sprintf $format, $num_completed{$_}, $n;
        my $comment   = $comments{$_};
        $log->info("$progress $comment");
    }

}

sub chunk_machine {
    my ($self, $chunk_num) = @_;
    my $config = $self->config->for_chunk($chunk_num);
    return RUM::ChunkMachine->new($config);
}

sub chunk_machines {
    my ($self) = @_;
    my $config = $self->config;
    my $n = $config->num_chunks;

    my @chunk_nums;


    if ($n > 1) {
        if ($config->chunk) {
            return ($self->chunk_machine($_));
        }
        else {
            return map { $self->chunk_machine($_) } (1 .. $n);
        }
    }
    
    return (RUM::ChunkMachine->new($config));
}

sub export_shell_script {
    my ($self) = @_;

    INFO("Generating pipeline shell script for each chunk");
    for my $m ($self->chunk_machines) {
        my $file = $m->config->pipeline_sh;
        open my $out, ">", $file or die "Can't open $file for writing: $!";
        print $out $m->shell_script;
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

1;

