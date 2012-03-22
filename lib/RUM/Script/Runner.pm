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
use RUM::Common qw(is_fasta is_fastq head);
use File::Path qw(mkpath);
use Text::Wrap qw(wrap fill);
use RUM::Workflow qw(shell);
our $log = RUM::Logging->get_logger("RUM::UI");

our $LOGO;

sub DEBUG  { $log->debug(wrap("", "", @_))  }
sub INFO   { $log->info(wrap("", "", @_))   }
sub WARN   { $log->warn(wrap("", "", @_))   }
sub ERROR  { $log->error(wrap("", "", @_))  }
sub FATAL  { $log->fatal(wrap("", "", @_))  }
sub LOGDIE { $log->logdie(wrap("", "", @_)) }

sub main {
    my $self = __PACKAGE__->new();
    $self->get_options();
}

sub get_options {

    GetOptions(

        "version"   => \(my $do_version),
        "kill"      => \(my $do_kill),
        "postprocess" => \(my $do_postprocess),

        "config=s"    => \(my $rum_config_file),
        "forward=s"   => \(my $forward),
        "reverse=s"   => \(my $reverse),
        "output|o=s"  => \(my $output_dir),
        "name=s"      => \(my $name),
        "chunks=s"    => \(my $num_chunks = 1),
        "help"        => sub { RUM::Usage->help },
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
        "quiet|q"     => sub { $log->less_logging(1) }
    );

    if ($do_version) {
        print "RUM version $RUM::Pipeline::VERSION, released $RUM::Pipeline::RELEASE_DATE\n";
        return;
    }
    if ($do_help_config) {
        print $RUM::ChunkConfig::CONFIG_DESC;
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
        -r $alt_genes or die "Can't read from $alt_genes: $!";
    }
    if ($alt_quant) {
        -r $alt_quant or die "Can't read from $alt_quant: $!";
    }

    $rum_config_file or RUM::Usage->bad(
        "Please specify a rum config file with --config");

    $output_dir or RUM::Usage->bad(
        "Please specify an output directory with --output or -o");

    $name or RUM::Usage->bad(
        "Please provide a name with --name");
    $name = fix_name($name);

}

sub setup {
    my ($self) = @_;
    my $output_dir = $self->config->output_dir;
    unless (-d $output_dir) {
        mkpath($output_dir) or die "mkdir $output_dir: $!";
    }


}

sub config {
    return $_[0]->{config};
}

sub prepare_chunks {

    my ($self) = @_;

    for my $chunk_num (1 .. $self->num_chunks) {
        my $config = RUM::ChunkConfig->new(config_file => $self->rum_config_file,
                                           forward     => $self->forward_reads,
                                           chunk       => $chunk_num,
                                           output_dir  => $self->output_dir,
                                           paired_end  => $self->reverse_reads ? 1 : 0);
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

our $READ_CHECK_LINES = 50000;


sub check_reads {
    my ($self) = @_;

    my @reads  = $self->reads;

    return if @reads == 2;

    $self->check_reads_for_quality;

    $self->{$_} = 0 for qw(paired_end needs_splitting preformatted);

    my $head = join("\n", head($reads[0], 4));
    $head =~ /seq.(\d+)(.).*seq.(\d+)(.)/s or die
        "I can't seem to find sequence identifiers in file @reads\n";

    my @nums  = ($1, $3);
    my @types = ($2, $4);



    if($nums[0] == 1 && $nums[1] == 1 && $types[0] eq 'a' && $types[1] eq 'b') {
        $self->{$_} = 1 for qw(paired_end file_needs_splitting preformatted);
    }
    if($nums[0] == 1 && $nums[1] == 2 && $types[0] eq 'a' && $types[1] eq 'a') {
        $self->{$_} = 1 for qw(file_needs_splitting preformatted);
    }
}

sub postprocess_only { shift->{postprocess_only} }
sub output_dir       { shift->{output_dir} }

sub scripts_dir { 
    return "$Bin/../bin";
}

sub reads {
    return @{ $_[0]->{reads} };
}

sub check_reads_for_quality {
    my ($self, $fh, $name) = @_;

    for my $filename ($self->reads) {
        
        open my $fh, "<", $filename or die
            "Can't open reads file $filename for reading: $!";

        while (local $_ = <$fh>) {
            next unless /:Y:/;
            $_ = <$fh>;
            chomp;
            /^--$/ and die
                "you appear to have entries in your fastq file
                \"$name\" for reads that didn't pass quality. These
                are lines that have \":Y:\" in them, probably followed
                by lines that just have two dashes \"--\". You first
                need to remove all such lines from the file, including
                the ones with the two dashes...";
            }
    }
}

sub check_reads_2 {

    my ($self) = @_;

    my @reads = $self->reads;

    return if @reads == 1 || $self->postprocess_only;

    @reads <= 2 or RUM::Usage->bad(
        "You've given more than two files of reads, should be at most
            two files.");

    $reads[0] ne $reads[1] or RUM::Usage->bad(
        "You specified the same file for the forward and reverse
        reads, must be an error...");

    
    my @sizes = map -s, @reads;
    $sizes[0] == $sizes[1] or die
        "The fowards and reverse files are different sizes. $sizes[0]
        versus $sizes[1].  They should be the exact same size.";

    my $config = $self->config;

    $self->check_reads_for_quality;

    # Check here that the quality scores are the same length as the reads.

    my $len = `head -50000 $reads[0] | wc -l`;
    chomp($len);
    $len =~ s/[^\d]//gs;

    my $scripts_dir = $self->scripts_dir;
    my $output_dir  = $self->output_dir;

    `perl $scripts_dir/parse2fasta.pl     $reads[0] $reads[1] | head -$len > $output_dir/reads_temp.fa 2>> $output_dir/rum.error-log`;
    `perl $scripts_dir/fastq2qualities.pl $reads[0] $reads[1] | head -$len > $output_dir/quals_temp.fa 2>> $output_dir/rum.error-log`;
    my $X = `head -20 $output_dir/quals_temp.fa`;
    if($X =~ /\S/s && !($X =~ /Sorry, can't figure these files out/s)) {
        open(RFILE, "$output_dir/reads_temp.fa");
        open(QFILE, "$output_dir/quals_temp.fa");
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
        open(RFILE, "$output_dir/reads_temp.fa");
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
                $config->{variable_read_lengths} = 1;
            }
            $length_hold = length($line1);
        }
    }

    # Clean up:

    unlink("$output_dir/reads_temp.fa");
    unlink("$output_dir/quals_temp.fa");

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

    my @reads = $self->reads;

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

    my $len = `head -50000 $reads[0] | wc -l`;
    chomp($len);
    $len =~ s/[^\d]//gs;
    my $is_big_file = $len == 50000;

    if($is_fastq  && !$config->variable_read_lengths && $is_big_file) {
        INFO("Splitting fastq file into $num_chunks chunks with separate reads and quals");
        shell("perl $parse_fastq $reads_in $num_chunks $reads_fa $quals_fa $name_mapping_opt 2>> $output_dir/rum.error-log");
        my @errors = `grep -A 2 "something wrong with line" $error_log`;
        die "@errors" if @errors;
        $self->{quals} = 1;
        $self->{file_needs_splitting} = 0;
    }
 
    elsif ($is_fasta && !$config->variable_read_lengths && !$preformatted && $is_big_file) {
        INFO("Splitting fasta file into $num_chunks chunks");
        shell("perl $parse_fasta $reads_in $num_chunks $reads_fa $name_mapping_opt 2>> $error_log");
        $self->{quals} = 0;
        $self->{file_needs_splitting} = 0;
     } 

    elsif (!$preformatted) {
        INFO("Splitting fasta file into reads and quals");
        shell("perl $parse_2_fasta @reads > $reads_fa 2>> $error_log");
        shell("perl $parse_2_quals @reads > $quals_fa 2>> $error_log");
        $self->{file_needs_splitting} = 1;
        my $X = join("\n", head($config->quals_fa, 20));
        if($X =~ /\S/s && !($X =~ /Sorry, can't figure these files out/s)) {
            $self->{quals} = "true";
        }
    }
}

sub run_chunks {
    my ($self) = @_;
    my $config = $self->config;

    print "My chunks are ", $config->num_chunks;



    my @configs = ($config);
    if ($config->num_chunks > 1) {
        @configs = map { $config->for_chunk($_) } (1 .. $config->num_chunks);
    }
    
    my @machines = map { RUM::ChunkMachine->new($_) } @configs;

    for my $m (@machines) {
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

