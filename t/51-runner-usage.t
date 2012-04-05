use Test::More tests => 66;
use Test::Exception;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Repository;
use RUM::TestUtils;
use RUM::Pipeline;
use RUM::Usage;
use File::Path;
use File::Temp qw(tempdir);
use strict;
use warnings;

our $config = "_testing/conf/rum.config_Arabidopsis";
our $bad_reads  = "$SHARED_INPUT_DIR/bad-reads.fq";
our $good_reads_same_size_as_bad  = "$SHARED_INPUT_DIR/good-reads-same-size-as-bad.fq";
our $forward_64_fq = "$SHARED_INPUT_DIR/forward64.fq";
our $reverse_64_fq = "$SHARED_INPUT_DIR/reverse64.fq";
our $forward_64_fa = "$SHARED_INPUT_DIR/forward64.fa";
our $reverse_64_fa = "$SHARED_INPUT_DIR/reverse64.fa";

BEGIN { 
    use_ok('RUM::Script::Runner');
}                                               

{
    # Redefine a couple methods in RUM::Usage so we can run the
    # scripts in a way that would normally cause them to exit.

    no warnings "redefine";
   
    *RUM::Usage::bad = sub {
        die "RUM::Usage::bad(@_)";
    };
}

sub run_rum {
    my @args = @_;

    open my $out, ">", \(my $data) or die "Can't open output string: $!";

    *STDOUT_BAK = *STDOUT;
    *STDOUT = $out;

    @ARGV = @args;

    RUM::Script::Runner->main();

    *STDOUT = *STDOUT_BAK;
    close $out;
    return $data;
}

sub rum {
    my @args = @_;

    @ARGV = @_;
    my $rum = RUM::Script::Runner->new();
    eval {
        $rum->get_options;
        $rum->check_config;
    };
    if ($@) {
        fail("Failed with $@");
        return undef;
    }
    return $rum;
}

sub rum_random_out_dir {
    return rum(@_, "--output", tempdir(CLEANUP => 1));
}

sub version_ok {
    my $version = $RUM::Pipeline::VERSION;

    like(run_rum("--version"), qr/$version/, "--version prints out version");
    like(run_rum("-V"), qr/$version/, "-V prints out version");
}

sub help_config_ok {
    my $version = $RUM::Pipeline::VERSION;
    my $out = run_rum("--help-config");
    like($out, qr/gene annotation file/, "--help-config prints config info");
    like($out, qr/bowtie genome index/, "--help-config prints config info");
}

sub check_missing_args {

    throws_ok sub {
        run_rum("--config", $config, "--output", "bar", "--name", "asdf") 
    }, qr/please.*read files/i, "Missing read files";

    throws_ok sub {
        run_rum("--config", $config, "--output", "bar", "--name", "asdf", 
                "1.fq", "2.fq", "3.fq") 
    }, qr/please.*read files/i, "Too many read files";

    throws_ok sub {
        run_rum("--config", $config, "--output", "bar", "--name", "asdf", 
                "1.fq", "1.fq") 
    }, qr/same file for the forward and reverse/i, "Duplicate read file";

    throws_ok sub {
        run_rum("--config", $config, "--output", "bar", "--name", "asdf", 
                $forward_64_fa, "$SHARED_INPUT_DIR/reads.fa") 
    }, qr/same size/i, "Read files are not the same size";

    throws_ok sub {
        run_rum("--config", $config, "--name", "asdf", "in.fq") 
    }, qr/--output/i, "Missing output dir";

    throws_ok sub {
        run_rum("--config", $config, "--output", "bar", "in.fq") 
    }, qr/--name/i, "Missing name";

    throws_ok sub {
        run_rum("--output", "bar", "--name", "asdf", "in.fq") 
    }, qr/--config/i, "Missing config";

    throws_ok sub {
        run_rum("--config", "missing-config-file",
                "--output", "bar", "--name", "asdf", "in.fq") 
    }, qr/no such file/i, "Config file that doesn't exist";

    throws_ok sub {
        my $name = 'a' x 300;
        run_rum("--config", $config, "--output", "bar", "--name", $name, 
                "in.fq");
    }, qr/250 characters/, "Long name";

    
}

sub check_defaults {
    
    my @argv = ("--config", $config,
                "--output", "foo",
                "--name", "asdf",
                $forward_64_fq);

    my $rum = rum(@argv);
    my $c = $rum->config;
    is($c->name, "asdf", "Name");
    is($c->output_dir, "foo", "Output dir");
    is($c->rum_config_file, $config, "Config");
    ok($c->cleanup, "cleanup");
    is($c->min_length, undef, "min length");
    is($c->max_insertions, 1, "max insertions");

    ok(!$c->dna, "no DNA");
    ok(!$c->genome_only, "no genome only");
    ok(!$c->variable_read_lengths, "no variable read lengths");
    ok(!$c->count_mismatches, "no count mismatches");
    ok(!$c->junctions, "no junctions");
    ok(!$c->strand_specific, "no strand-specific");
    is($c->ram, 6, "ram");

    is($c->bowtie_nu_limit, undef, "Bowtie nu limit");
    is($c->nu_limit, undef, "nu limit");
}

sub check_fixes_name {
    my @argv = ("--config", $config,
                "--output", "foo",
                "-n",
                "in.fq");    
    is(rum(@argv, "--name", ",foo bar,baz,")->config->name,
       "foo_bar_baz",
       "Fixes name");
}

sub check_missing_reads_file {
    throws_ok sub {
        run_rum("--config", $config, "--output", "bar", "--name", "asdf", "asdf.fq", "-q") 
    }, qr/asdf.fq.*no such file or directory/i, "Read file doesn't exist";    
    throws_ok sub {
        run_rum("--config", $config, "--output", "bar", "--name", "asdf", $forward_64_fq, "asdf.fq", "-q") 
    }, qr/asdf.fq.*no such file or directory/i, "Read file doesn't exist";    
}

sub check_bad_reads {
    throws_ok sub {
        run_rum("--config", $config, "--output", "bar", "--name", "asdf", $bad_reads, "-q") 
    }, qr/you appear to have entries/i, "Bad reads";    

    throws_ok sub {
        run_rum("--config", $config, "--output", "bar", "--name", "asdf",
                $bad_reads, $good_reads_same_size_as_bad, "-q") 
    }, qr/you appear to have entries/i, "Bad reads";    

    throws_ok sub {
        run_rum("--config", $config, "--output", "bar", "--name", "asdf",
                $good_reads_same_size_as_bad, $bad_reads, "-q") 
    }, qr/you appear to have entries/i, "Bad reads";    

}

sub preprocess {
    my @args = @_;
    my $rum = rum(@args);
    eval { $rum->preprocess };
    return $rum;
}

sub check_single_paired_fa {
    my $rum = preprocess("--config", $config,
                  "-o", tempdir(CLEANUP => 1),
                  "--name", "asdf", "$SHARED_INPUT_DIR/reads.fa");
    
    my $prefix = "1, paired, fa, no chunks";

    ok($rum->config->paired_end, "$prefix is paired end");
    ok($rum->config->input_is_preformatted, "$prefix is preformatted");
    ok($rum->config->input_needs_splitting, "$prefix needs splitting");
    ok(-e $rum->config->reads_fa, "$prefix: made reads");
    ok(! -e $rum->config->quals_fa, "$prefix: didn't make quals");
}

sub check_single_forward_fa {
    my $rum = preprocess("--config", $config,
                  "-o", tempdir(CLEANUP => 1),
                  "--name", "asdf",
                  "$SHARED_INPUT_DIR/forward_only.fa");
    my $prefix = "1, single, fa, no chunks";
    ok( ! $rum->config->paired_end, "$prefix: not paired end");
    ok($rum->config->input_is_preformatted, "$prefix: is preformatted");
    ok($rum->config->input_needs_splitting, "$prefix: needs splitting");
}

sub check_single_forward_fa_chunks {
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



sub check_pair_fastq_files {
    my @argv = ("--config", $config, "--name", "asdf");
    my $rum = rum(@argv, "-o", tempdir(CLEANUP => 1),
                  $forward_64_fq, $reverse_64_fq);
    $rum->preprocess;
    my $forward_64_fq = $rum->config->output_dir . "/reads.fa";
    my $quals = $rum->config->output_dir . "/quals.fa";

    my $prefix = "2, paired, fq, no chunks";
    ok(-e $forward_64_fq, "$prefix: made reads file");
    ok(-e $quals, "$prefix: made quals file");
}

sub check_pair_fastq_files_with_chunks {
    my @argv = ("--config", $config, "--name", "asdf");
    my $rum = preprocess(@argv, "-o", tempdir(CLEANUP => 1),
                  "--chunks", 2,
                  $forward_64_fq, $reverse_64_fq);

    my $prefix = "2, paired, fq, 2 chunks";
    for my $type (qw(reads quals)) {
        for my $chunk (1, 2) {
            ok(-e $rum->config->output_dir . "/$type.fa.$chunk",
               "$prefix: made $type $chunk");
        }
    }
}

sub check_pair_fasta_files_with_chunks {
    my @argv = ("--config", $config, "--name", "asdf");
    my $rum = preprocess(@argv, "-o", tempdir(CLEANUP => 0),
                  "--chunks", 2,
                  $forward_64_fa, $reverse_64_fa);
    my $prefix = "2, paired, fa, 2 chunks";
    for my $chunk (1, 2) {
        ok(-e $rum->config->output_dir . "/reads.fa.$chunk",
           "$prefix: made reads $chunk");
    }
    for my $chunk (1, 2) {
        ok( ! -e $rum->config->output_dir . "/quals.fa.$chunk",
           "$prefix: didn't make quals $chunk");
    }
}

sub check_limit_nu {
    throws_ok sub {
        run_rum("--config", $config, "--output", "bar", "--name", "asdf", 
                $forward_64_fq,, $reverse_64_fq,
                "--limit-nu", "asdf");
    }, qr/--limit-nu/i, "Bad --limit-nu";    

    my @argv = ("--config", $config,
                "--output", "foo",
                "--name", "asdf",
                $forward_64_fq,
                "--limit-nu", 50);

    my $rum = rum(@argv);
    my $c = $rum->config;
    is($c->nu_limit, 50, "Nu limit");

    @argv = ("--config", $config,
             "--output", "foo",
             "--name", "asdf",
             $forward_64_fq,
             "--limit-bowtie-nu");

    $rum = rum(@argv);
    $c = $rum->config;
    is($c->bowtie_nu_limit, 100, "Nu limit");
}

version_ok;
help_config_ok;
check_missing_args;
check_defaults;
check_fixes_name;
check_missing_reads_file;
check_bad_reads;
check_single_forward_fa;
check_pair_fastq_files;
check_pair_fasta_files_with_chunks;
check_single_paired_fa;
check_pair_fastq_files_with_chunks;
check_limit_nu;

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
        my $workflow = RUM::Workflows->chunk_workflow($config);
        my @commands = $workflow->commands($step);
        
        if ($negate) {
            unlike($commands[0], $re, $comment);           
        }
        else {
            like($commands[0], $re, $comment);        
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

chunk_cmd_like([@standard_args], "Move NU file", qr/mv.*RUM_NU.*temp.+RUM_NU/i,
               "Just move RUM_NU");               

chunk_cmd_like([@standard_args, "--limit-nu", 15], "Limit NU",
               qr/limit_nu.pl --cutoff\s*15/i, 
               "Cutoff passed to limit_nu");    

chunk_cmd_like([@standard_args, "--max-insertions-per-read", 2],
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
