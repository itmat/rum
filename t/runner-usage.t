use Test::More;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Repository;
use RUM::TestUtils;
use RUM::Pipeline;
use RUM::Usage;
use RUM::Script::Main;
use RUM::Action::Align;
use File::Path;
use File::Temp qw(tempdir);
use strict;
use warnings;

our $config = "$Bin/../conf/rum.config_Arabidopsis";
our $bad_reads  = "$SHARED_INPUT_DIR/bad-reads.fq";
our $good_reads_same_size_as_bad  = "$SHARED_INPUT_DIR/good-reads-same-size-as-bad.fq";
our $forward_64_fq = "$SHARED_INPUT_DIR/forward64.fq";
our $reverse_64_fq = "$SHARED_INPUT_DIR/reverse64.fq";
our $forward_64_fa = "$SHARED_INPUT_DIR/forward64.fa";
our $reverse_64_fa = "$SHARED_INPUT_DIR/reverse64.fa";
our $alt_genes     = "$SHARED_INPUT_DIR/alt_genes.txt";
our $alt_quant     = "$SHARED_INPUT_DIR/alt_quant.txt";

our $log = RUM::Logging->get_logger;

BEGIN {
    eval "use Test::Exception";
    plan skip_all => "Test::Exception needed" if $@;
}

if (-e $config) {
    plan tests => 84;
}
else {
    plan skip_all => "Arabidopsis index needed";
}

{
    # Redefine a couple methods in RUM::Usage so we can run the
    # scripts in a way that would normally cause them to exit.

    no warnings "redefine";
   
    *RUM::Usage::bad = sub {
        die "RUM::Usage::bad(@_)";
    };
}

sub capturing_stdout (&) {
    
    my ($code) = @_;
    
    open my $out, ">", \(my $data = "") or die "Can't open output string: $!";
    *STDOUT_BAK = *STDOUT;

    eval { 
        *STDOUT = $out;
        $code->();
        *STDOUT = *STDOUT_BAK;
    };
    if ($@) {
        *STDOUT = *STDOUT_BAK;
    }

    close $out;
    die $@ if $@;
    return $data;
}

sub run_rum {
    my @args = @_;
    @ARGV = @args;

    my $data = eval { capturing_stdout { RUM::Script::Main->main() } };
    return $@ || $data;
}

sub rum_fails_ok {
    my ($args, $re, $name) = @_;
    open my $out, ">", \(my $data) or die "Can't open output string: $!";

    *STDOUT_BAK = *STDOUT;

    @ARGV = @$args;

    *STDOUT = $out;
    throws_ok { RUM::Script::Main->main } $re, $name;
    *STDOUT = *STDOUT_BAK;
}

sub rum {
    my @args = @_;

    @ARGV = @_;
    my $rum = RUM::Action::Align->new();
    eval {
        $rum->get_options;
        $rum->check_config;
        $rum->config->set('genome_size', 1000000000);
    };
    if ($@) {
        BAIL_OUT("Can't get RUM::Script::Main: $@");
    }
    return $rum;
}

sub rum_random_out_dir {
    return rum(@_, "--output", tempdir(CLEANUP => 1));
}

sub preprocess {
    my @args = @_;
    my $rum = rum(@args);

    capturing_stdout { 
        $RUM::Action::Align::log->less_logging(2);
        $rum->{directives}{quiet} = 1;
        $rum->setup;
        $rum->platform->preprocess;
    };
    
    return $rum;
}

sub tmp_out {
    return tempdir(TEMPLATE => "runner-usage.XXXXXX", CLEANUP => 1);
}

# Check that RUM prints out the version
my $version = $RUM::Pipeline::VERSION;
like(run_rum("version"), qr/$version/, "version prints out version");

# Check that --help-config prints a description of the help file
like(run_rum("help", "config"),
     qr/gene annotation file/, "help config prints config info");
like(run_rum("help", "config"),
     qr/bowtie genome index/, "help config prints config info");


# Check that it fails if required arguments are missing
rum_fails_ok(["align", "--config", $config, "--output", tmp_out(), "--name", "asdf"],
             qr/please.*read files/i, "Missing read files");

rum_fails_ok(["align", "--config", $config, "--output", tmp_out(), "--name", "asdf", 
              "1.fq", "2.fq", "3.fq"],
             qr/please.*read files/i, "Too many read files");

rum_fails_ok(["align", "--config", $config, "--output", tmp_out(), "--name", "asdf", 
              "1.fq", "1.fq"],
             qr/same file for the forward and reverse/i,
             "Duplicate read file");
rum_fails_ok(["align", "--config", $config, "--output", tmp_out(), "--name", "asdf", 
              $forward_64_fa, "$SHARED_INPUT_DIR/reads.fa"],
             qr/same size/i, "Read files are not the same size");

#rum_fails_ok(["--config", $config, "--name", "asdf", "in.fq"],
#             qr/--output/i, "Missing output dir");

rum_fails_ok(["align", "--config", $config, "--output", tmp_out(), "in.fq"],
             qr/--name/i, "Missing name");

rum_fails_ok(["align", "--output", tmp_out(), "--name", "foo", "in.fq"],
             qr/--config/i, "Missing config");

rum_fails_ok(["align", "--config", "missing-config-file",
              "--output", tmp_out(), "--name", "asdf", "in.fq"],
             qr/no such file/i, "Config file that doesn't exist");

my $name = 'a' x 300;
rum_fails_ok(
    ["align", "--config", $config, "--output", tmp_out(), "--name", $name," in.fq"],
    qr/250 characters/, "Long name");

# Check that we set some default values correctly
{
    my @argv = ("--config", $config,
                "--output", "foo",
                "--name", "asdf",
                $forward_64_fq);
    
    my $rum = rum(@argv);
    my $c = $rum->config or BAIL_OUT("Can't get RUM");
    is($c->name, "asdf", "Name");
    like($c->output_dir, qr/foo$/, "Output dir");
    like($c->rum_config_file, qr/$config/, "Config");
    is($c->min_length, undef, "min length");
    is($c->max_insertions, 1, "max insertions");
    ok(!$c->dna, "no DNA");
    ok(!$c->genome_only, "no genome only");
    ok(!$c->variable_length_reads, "no variable read lengths");
    ok(!$c->count_mismatches, "no count mismatches");
    ok(!$c->junctions, "no junctions");
    ok(!$c->strand_specific, "no strand-specific");
    is($c->ram, undef, "ram");
    is($c->bowtie_nu_limit, undef, "Bowtie nu limit");
    is($c->nu_limit, undef, "nu limit");
}

# Check that we clean up a name
is(rum("--config", $config,
       "--output", "foo",
       $forward_64_fq, "--name", ",foo bar,baz,")->config->name,
   "foo_bar_baz",
   "Clean up name with invalid characters");

# Check that rum fails if a read file is missing
rum_fails_ok(["align","--config", $config, "--output", tmp_out(),
              "--name", "asdf", "asdf.fq", "-q"],
             qr/read from.*asdf.fq/i,
             "Read file doesn't exist");    
rum_fails_ok(["align", "--config", $config, "--output", tmp_out(), "--name", "asdf", 
              $forward_64_fq, "asdf.fq", "-q"],
             qr/read from.*asdf.fq/i, 
             "Read file doesn't exist");    

# Check bad reads
rum_fails_ok(["align", "--config", $config, "--output", tmp_out(), "--name", "asdf", 
              $bad_reads, "-q"],
             qr/you appear to have entries/i, "Bad reads");    
rum_fails_ok(["align", "--config", $config, "--output", tmp_out(), "--name", "asdf",
              $bad_reads, $good_reads_same_size_as_bad, "-q"], 
             qr/you appear to have entries/i, "Bad reads");    
rum_fails_ok(["align", "--config", $config, "--output", tmp_out(), "--name", "asdf",
              $good_reads_same_size_as_bad, $bad_reads, "-q"],
             qr/you appear to have entries/i, "Bad reads");    

# Check that we preprocess a single paired-end fasta file correctly
{
    $log->warn("About to preprocess");
    warn "Here";
    my $rum = preprocess("--config", $config,
                         "-o", tempdir(CLEANUP => 1),
                         "--name", "asdf", "$SHARED_INPUT_DIR/reads.fa");
    warn "Done";
    my $prefix = "1, paired, fa, no chunks";
    
    ok($rum->config->paired_end, "$prefix is paired end");
    ok($rum->config->input_is_preformatted, "$prefix is preformatted");
    ok($rum->config->input_needs_splitting, "$prefix needs splitting");
    ok(-e $rum->config->in_output_dir("chunks/reads.fa.1"), "$prefix: made reads");
    ok(! -e $rum->config->in_output_dir("quals.fa.1"), "$prefix: didn't make quals");
}

# Check that we process a single forward-read-only fasta file correctly
{
    my $rum = preprocess("--config", $config,
                         "-o", tempdir(CLEANUP => 1),
                         "--name", "asdf",
                         "$SHARED_INPUT_DIR/forward_only.fa");

    my $prefix = "1, single, fa, no chunks";
    ok( ! $rum->config->paired_end, "$prefix: not paired end");
    ok($rum->config->input_is_preformatted, "$prefix: is preformatted");
    ok($rum->config->input_needs_splitting, "$prefix: needs splitting");
}

# TODO: What to do for single reads file that is not preformatted?
#    $rum = rum(@argv, $forward_64_fq);
#    $rum->preprocess;
#    ok( ! $rum->config->paired_end, "Not paired end");
#    ok( ! $rum->config->input_is_preformatted, "Not preformatted");
#    ok($rum->config->input_needs_splitting, "Needs splitting");


# Check that we process a pair of fastq files correctly
{
    my @argv = ("--config", $config, "--name", "asdf");
    my $rum = rum(@argv, "-o", tempdir(CLEANUP => 1),
                  $forward_64_fq, $reverse_64_fq);
    $rum->setup;
    $rum->platform->preprocess;
    my $forward_64_fq = $rum->config->output_dir . "/chunks/reads.fa";
    my $quals = $rum->config->output_dir . "/chunks/quals.fa";

    my $prefix = "2, paired, fq, no chunks";
    ok(-e $forward_64_fq, "$prefix: made reads file");
    ok(-e $quals, "$prefix: made quals file");
}


# Check that we process a pair of fastq files correctly when tnhe need
# to be split into chunks.
{
    my @argv = ("--config", $config, "--name", "asdf");
    my $rum = preprocess(@argv, "-o", tempdir(CLEANUP => 1),
                         "--chunks", 2,
                         $forward_64_fq, $reverse_64_fq);

    my $prefix = "2, paired, fq, 2 chunks";
    for my $type (qw(reads quals)) {
        for my $chunk (1, 2) {
            ok(-e $rum->config->output_dir . "/chunks/$type.fa.$chunk",
               "$prefix: made $type $chunk");
        }
    }
}

# Check that we process a pair of fasta files correctly when the need
# to be split into chunks
{
    my @argv = ("--config", $config, "--name", "asdf");
    my $rum = preprocess(@argv, "-o", tempdir(CLEANUP => 0),
                  "--chunks", 2,
                  $forward_64_fa, $reverse_64_fa);
    my $prefix = "2, paired, fa, 2 chunks";
    for my $chunk (1, 2) {
        ok(-e $rum->config->output_dir . "/chunks/reads.fa.$chunk",
           "$prefix: made reads $chunk");
    }
    for my $chunk (1, 2) {
        ok( ! -e $rum->config->output_dir . "/chunks/quals.fa.$chunk",
           "$prefix: didn't make quals $chunk");
    }

}


sub chunk_cmd_unlike {
    my ($args, $step, $re, $comment) = @_;
    chunk_cmd_like($args, $step, $re, $comment, 1);
}

sub chunk_cmd_like {
    my ($args, $step, $re, $comment, $negate) = @_;
    my $rum = rum(@$args);

    eval {
        my $config = $rum->config;
        $config->set('read_length', 75);
        my $workflow = RUM::Workflows->chunk_workflow($config, 3);
        my @commands = $workflow->commands($step);
        my @cmd = @{ $commands[0] };
        if ($negate) {
            unlike("@cmd", $re, $comment);           
        }
        else {
            like("@cmd", $re, $comment);        
        }

    };
    if ($@) {
        fail("Failed with $@");
    }
}

sub postproc_cmd_unlike {
    my ($args, $step, $re, $comment) = @_;
    postproc_cmd_like($args, $step, $re, $comment, 1);
}

sub postproc_cmd_like {
    my ($args, $step, $re, $comment, $negate) = @_;
    my $rum = rum(@$args);

    eval {
        my $config = $rum->config;
        $config->set('read_length', 75);
        my $workflow = RUM::Workflows->postprocessing_workflow($config);
        my @commands = $workflow->commands($step);
        my @cmd = @{ $commands[0] };
        
        if ($negate) {
            unlike("@cmd", $re, $comment);           
        }
        else {
            like("@cmd", $re, $comment);        
        }

    };
    if ($@) {
        fail("Failed with $@");
    }
}

#
# Tests that verify that options to rum_runner make it into the
# workflow

my @standard_args = ("--config", $config,
                     "--output", tempdir(CLEANUP => 1),
                     "--name", "asdf",
                     $forward_64_fq, $reverse_64_fq);

for (qw(genome transcriptome)) {
    chunk_cmd_like([@standard_args], "Run bowtie on $_", qr/bowtie.*-a/,
                   "bowtie on $_ with -a");
    chunk_cmd_like([@standard_args, "--limit-bowtie-nu"],
                   "Run bowtie on $_", qr/bowtie.*-k 100/,
                   "bowtie on $_ with -k 100");
}

#chunk_cmd_like([@standard_args], "Move NU file", qr/mv.*RUM_NU.*temp.+RUM_NU/i,
#               "Just move RUM_NU");               

chunk_cmd_like([@standard_args, "--limit-nu", 15], "Limit NU",
               qr/limit_nu.pl --cutoff\s*15/i, 
               "Cutoff passed to limit_nu");    

rum_fails_ok(["align", @standard_args, "--limit-nu", "asdf"],
               qr/nu must be an integer greater than/i, 
               "Bad --limit-nu");    

chunk_cmd_like([@standard_args[0..$#standard_args - 1], "--max-insertions-per-read", 2],
               "Parse blat output",
               qr/--max-insertions 2/i, 
               "--max-insertions-per-read");

chunk_cmd_unlike([@standard_args],
                 "Generate quants",
                 qr/--strand/i, 
                 "not --strand-specific quantifications");
chunk_cmd_like([@standard_args, "--strand-specific"],
               "Generate quants for strand p, sense s",
               qr/--strand p/i, 
               "--strand-specific quantifications");
chunk_cmd_like([@standard_args, "--strand-specific"],
               "Generate quants for strand p, sense a",
               qr/--strand p.*--anti/i, 
               "--strand-specific quantifications");

# Check the blat options
chunk_cmd_like([@standard_args],
               "Run blat on unmapped reads",
               qr/-maxIntron=500000 -minIdentity=93 -repMatch=256 -stepSize=6 -tileSize=12/,
               "Blat default options");

chunk_cmd_like([@standard_args,
                "--maxIntron",   1,
                "--minIdentity", 2,
                "--repMatch",    3,
                "--stepSize",    4,
                "--tileSize",    5,
            ],
               "Run blat on unmapped reads",
               qr/-maxIntron=1 -minIdentity=2 -repMatch=3 -stepSize=4 -tileSize=5/,
               "Blat specified options");
rum_fails_ok(["align", @standard_args, "--minIdentity", 200],
             qr/identity must be an integer/i,
             "Min identity too high");
rum_fails_ok(["align", @standard_args, "--minIdentity", "foo"],
             qr/identity must be an integer/i,
             "Min identity not an int");



rum_fails_ok(["align", @standard_args, "--min-length", 5],
             qr/length must be an integer/,
             "Min length too low");

rum_fails_ok(["align", @standard_args, "--variable-length", "--preserve-names"],
             qr/can.*t use.*preserve.*names.*variable.*length/i,
             "--variable-length and --preserve-names fail");
# Check --alt-genes
rum_fails_ok(["align", @standard_args, "--alt-genes", "foobar"],
             qr/foobar.*no such file/i,
             "Bad --alt-genes");
postproc_cmd_like([@standard_args, "--alt-genes", $alt_genes],
                  "make_junctions",
                  qr/--genes $alt_genes/i,
                  "--alt-genes gets passed to make_RUM_junctions_file");
# Check --alt-quant
rum_fails_ok(["align", @standard_args, "--alt-quant", "foobar"],
             qr/foobar.*no such file/i,
             "Bad --alt-quant");

chunk_cmd_unlike([@standard_args, "--alt-quant", $alt_quant],
                 "Parse transcriptome Bowtie output",
                  qr/$alt_quant/i,
                  "--alt-quant does not get passed to make_tu_and_tnu");

chunk_cmd_unlike([@standard_args, "--alt-quant", $alt_quant, "--strand-specific"],
                  "Generate quants for strand p, sense a",
                  qr/--genes.*$alt_quant/i,
                  "Generate quants based on gene info file with --alt-quant and --strand-specific");
chunk_cmd_like([@standard_args, "--alt-quant", $alt_quant, "--strand-specific"],
                  "Generate alt quants for strand p, sense a",
                  qr/--genes.*$alt_quant/i,
                  "Generate alt quants with --alt-quant and --strand-specific");

chunk_cmd_unlike([@standard_args, "--alt-quant", $alt_quant],
                  "Generate quants",
                  qr/--genes.*$alt_quant/i,
                  "Generate quants based on gene info file with --alt-quant");
chunk_cmd_like([@standard_args, "--alt-quant", $alt_quant],
                  "Generate alt quants",
                  qr/--genes.*$alt_quant/i,
                  "Generate alt quants with --alt-quant");


chunk_cmd_like([@standard_args, "--count-mismatches"],
               "Clean up RUM files",
               qr/--count-mismatches/,
               "--count-mismatches is passed to RUM_finalcleanup.pl");
chunk_cmd_unlike([@standard_args],
               "Clean up RUM files",
               qr/--count-mismatches/,
               "--count-mismatches is not passed to RUM_finalcleanup.pl when ".
                   "it isn't specified");

chunk_cmd_like([@standard_args, "--ram", 8],
               "Sort RUM_NU",
               qr/--ram 8/,
               "--ram is passed sort_rum_by_location.pl");

chunk_cmd_unlike([@standard_args],
                 "Parse blat output",
                 qr/--match-length-cutoff/,
                 "--match-length-cutoff is left out of parse blat out");

chunk_cmd_like([@standard_args, "--min-length", 40],
                 "Parse blat output",
                 qr/--match-length-cutoff 40/,
                 "--match-length-cutoff is passed to parse blat out");


chunk_cmd_unlike([@standard_args],
                 "Clean up RUM files",
                 qr/--match-length-cutoff/,
                 "--match-length-cutoff is left out of RUM_finalcleanup");

chunk_cmd_like([@standard_args, "--min-length", 40],
                 "Clean up RUM files",
                 qr/--match-length-cutoff 40/,
                 "--match-length-cutoff is passed to RUM_finalcleanup");

chunk_cmd_unlike([@standard_args],
                 "Merge unique mappers together",
                 qr/--min-overlap/,
                 "--min-overlap is left out of merge_gu_and_tu");

chunk_cmd_like([@standard_args, "--min-length", 40],
                 "Merge unique mappers together",
                 qr/--min-overlap 40/,
                 "--min-overlap is passed to merge_gu_and_tu");

chunk_cmd_unlike([@standard_args],
                 "Merge bowtie and blat results",
                 qr/--min-overlap/,
                 "--min-overlap is left out of merge_bowtie_and_blat");

chunk_cmd_like([@standard_args, "--min-length", 40],
                 "Merge bowtie and blat results",
                 qr/--min-overlap 40/,
                 "--min-overlap is passed to merge_bowtie_and_blat");
