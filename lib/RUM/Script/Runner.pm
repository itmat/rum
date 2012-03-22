package RUM::Script::Runner;

use Getopt::Long;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use RUM::ChunkMachine;
use RUM::Repository;
use RUM::Usage;
use RUM::Logging;
use RUM::Pipeline;
use File::Path qw(mkpath);

our $log = RUM::Logging->get_logger("RUM::UI");

our $LOGO;

sub DEBUG  { $log->debug(wrap("", "", @_))  }
sub INFO   { $log->info(wrap("", "", @_))   }
sub WARN   { $log->warn(wrap("", "", @_))   }
sub ERROR  { $log->error(wrap("", "", @_))  }
sub FATAL  { $log->fatal(wrap("", "", @_))  }
sub LOGDIE { $log->logdie(wrap("", "", @_)) }

sub main {

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

    unless (-d $output_dir) {
        mkpath($output_dir) or die "mkdir $output_dir: $!";
    }

print <<EOF;

RUM Version $RUM::Pipeline::VERSION

$LOGO
EOF


    for my $chunk_num (1 .. $num_chunks) {
        my $config = RUM::ChunkConfig->new(config_file => $rum_config_file,
                                           forward     => $forward,
                                           chunk       => $chunk_num,
                                           output_dir  => $output_dir,
                                           paired_end  => $reverse ? 1 : 0);
    }

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

