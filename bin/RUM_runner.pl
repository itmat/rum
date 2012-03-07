# Written by Gregory R Grant
# University of Pennsylvania, 2011

$version = "1.11.  Released March 5, 2012";

$| = 1;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use File::Spec;
use Carp;
use RUM::Common qw(Roman roman isroman arabic format_large_int);
use RUM::Sort qw(by_chromosome);
use RUM::Subproc qw(spawn check pids_by_command_re kill_all procs
                    child_pids can_kill kill_runaway_procs);

if($ARGV[0] eq '-version' || $ARGV[0] eq '-v' || $ARGV[0] eq '--version' || $ARGV[0] eq '--v') {
    die "RUM version: $version\n";
}

$date = `date`;

our $CONFIG_DESC = <<EOF;
The following describes the configuration file:

Note: All entries can be absolute path, or relative path to where RUM
is installed.

1) gene annotation file, can be absolute, or relative to where RUM is installed
   e.g.: indexes/mm9_ucsc_refseq_gene_info.txt

2) bowtie executable, can be absolute, or relative to where RUM is installed
   e.g.: bowtie/bowtie

3) blat executable, can be absolute, or relative to where RUM is installed
   e.g.: blat/blat

4) mdust executable, can be absolute, or relative to where RUM is installed
   e.g.: mdust/mdust

5) bowtie genome index, can be absolute, or relative to where RUM is installed
   e.g.: indexes/mm9

6) bowtie gene index, can be absolute, or relative to where RUM is installed
   e.g.: indexes/mm9_genes_ucsc_refseq

7) blat genome index, can be absolute, or relative to where RUM is installed
   e.g. indexes/mm9_genome_sequence_single-line-seqs.fa

8) [DEPRECATED] perl scripts directory. This is now ignored, and this script
    will use $Bin/../bin

9) [DEPRECATED] lib directory. This is now ignored, and this script will use
    $Bin/../lib
EOF

if(@ARGV == 1 && @ARGV[0] eq "config") {
    print $CONFIG_DESC;
}
if(@ARGV < 5) {
    print "
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
RUM version: $version
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                 _   _   _   _   _   _
               // \\// \\// \\// \\// \\// \\/
              //\\_//\\_//\\_//\\_//\\_//\\_//
        o_O__O_ o
       | ====== |       .-----------.
       `--------'       |||||||||||||
        || ~~ ||        |-----------|
        || ~~ ||        | .-------. |
        ||----||        ! | UPENN | !
       //      \\\\        \\`-------'/
      // /!  !\\ \\\\        \\_  O  _/
     !!__________!!         \\   /
     ||  ~~~~~~  ||          `-'
     || _        ||
     |||_|| ||\\/|||
     ||| \\|_||  |||
     ||          ||
     ||  ~~~~~~  ||
     ||__________||
.----|||        |||------------------.
     ||\\\\      //||                 /|
     |============|                //
     `------------'               //
---------------------------------'/
---------------------------------'
  .------------------------------------.
  | RNA-Seq Unified Mapper (RUM) Usage |
  ` ================================== '

Usage: RUM_runner.pl <config file> <reads file(s)> <output dir> <num chunks>
                     <name> [options]

<config file>   :  This file tells RUM where to find the various executables
                   and indexes.  This file is included in the 'lib' directory
                   when you download an organism, for example rum.config_mm9
                   for mouse build mm9, which will work if you leave everything
                   in its default location.  To modify or make your own config
                   file, run this program with the single argument 'config' for
                   more information on the config file.

<reads file(s)> :  1) For unpaired data, the single file of reads.
                   2) For paired data the files of forward and reverse reads,
                      separated by three commas ',,,' (with no spaces).

                   NOTE ON FILE FORMATS: Files can be either fasta or fastq,
                   the type is inferred.

<output dir>    :  Where to write the temp, interemediate, and results files.

<num chunks>    :  The number of pieces to break the job into.  Use one chunk
                   unless you are on a cluster, or have multiple cores
                   with lots of RAM.  Have at least one processing core per
                   chunk.  A genome like human will also need about 5 to 6 Gb
                   of RAM per chunk.  Even with a small genome, if you have
                   tens of millions of reads, you will still need a few Gb of
                   RAM to get through the post-processing.

<name>          :  A string to identify this run - use only alphanumeric,
                   underscores, and dashes.  No whitespace or other characters.
                   Must be less than 250 characters.

Options: There are many options, but RUM is typically run with the defaults. The
         option -kill is also quite useful to stop a run, because killing just
         the main program will not always kill the spawned processes.

       -strandspecific : If the data are strand specific, then you can use this
                         option to generate strand specific coverage plots and
                         quantified values.

       -dna       : Run in dna mode, meaning don't map across splice junctions.

       -genome_only : Do RNA mapping, but without using a transcript database.  
                      Note: there will be no feature quantifications in this
                      mode, because those are based on the transcript database.

       -variable_read_lengths : Set this if your reads are not all of the same
                                length.

       -limitNU N : Limits the number of ambiguous mappers in the final output
                    by removing all reads that map to N locations or more.

       -limitBowtieNU : Limits the number of ambiguous mappers in the Bowtie
                        run to a max of 100.  If you have short reads and a
                        large genome, or a very repetitive genome, this might
                        be necessary to keep the bowtie files from getting out
                        of hand - 10Gb per lane is not abnormal but 100Gb might
                        be. (note: 45 bases is considered short for mouse, 70
                        bases considered long, between it's hard to say).

       -quantify : Use this *if* using the -dna flag and you still want quantified
                   features.  If this is set you *must* have the gene models file
                   specified in the rum config file.  Without the -dna flag
                   quantified features are generated by default so you don't
                   need to set this.

       -junctions : Use this *if* using the -dna flag and you still want junction
                    calls.  If this is set you should have the gene models file
                    specified in the rum config file (if you have one).  Without
                    the -dna flag junctions generated by default so you don't
                    need to set this.

       -minlength x : don't report alignments less than this long.  The default
                      = 50 if the readlength >= 80, else = 35 if readlength >= 45
                      else = 0.8 * readlength.  Don't set this too low you will
                      start to pick up a lot of garbage.

       -countmismatches : Report in the last column the number of mismatches,
                          ignoring insertions

       -altgenes x : x is a file with gene models to use for calling junctions
                     novel.  If not specified will use the gene models file
                     specified in the config file.

       -altquant x : if specified x will be used to quantify features in addition
                     to the gene models file specified in the config file.  Both
                     are reported to separate files.

       -qsub      : Use qsub to fire the job off to multiple nodes on a cluster.
                    This means you're on a cluster that understands qsub like
		    the Sun Grid Engine.

                      ** Note: without using -qsub, you can still specify more
                      than one chunk.  It should fire each chunk off to a
                      separate core.  But don't use more chunks than you have
                      cores, because that can slow things down considerable.

       -max_insertions_per_read n : Allow at most n insertions in one read.
                    The default is n=1.  Setting n>1 is only allowed for single
                    end reads.  Don't raise it unless you know what you are
                    doing, because it can greatly increase the false alignments.

       -noclean   : do not remove the intermediate and temp files after finishing.

       -preserve_names : Keep the original read names in the SAM output file.
                         Note: this doesn't work when there are variable length reads.

       -kill      : To kill a job, run with all the same parameters but add
                    -kill.  Note: it is not sufficient to just terminate
                    RUM_runner.pl, that will leave other phantom processes.
                    Use -kill instead.

       -ram n : On some systems RUM might not be able to determine the amount of
                RAM you have.  In that case, with this option you can specify
                the number of Gb of ram you want to dedicate to each chunk.
                This is rarely necessary and never necessary if you have at
                least 6 Gb per chunk.

       -version : Returns the current version.  -v works too.

BLAT options: You can tweak the BLAT portion of RUM to suit your needs. We
                found the following to be a good balance for speed, sensitivity,
                and temporary file size.

       -minidentity x : run blat with minIdentity=x (default x=93).  You
                        shouldn't need to change this.

       -tileSize x : run blat with tileSize=x (default x=12).
                     You shouldn't need to change this.

       -stepSize x : run blat with stepSize=x (default x=6).
                     You shouldn't need to change this.

       -repMatch x : run blat with repMatch=x (default x=256).
                     You shouldn't need to change this.

       -maxIntron x : run blat with maxIntron=x (default x=50000).
		      You shouldn't need to change this.

Default config files are supplied with each organism.  If you need to make or
modify one then running RUM_runner.pl with the one argument 'config' gives an
explaination of the the file.

This program writes very large intermediate files.  If you have a large genome
such as mouse or human then it is recommended to run in chunks on a cluster, or
a machine with multiple processors.  Running with under five million reads per
chunk is usually best, and getting it under a million reads per chunk will speed
things considerably.

You can put an 's' after the number of chunks if they have already been broken
into chunks, so as to avoid repeating this time-consuming step.

Usage (again): RUM_runner.pl <configfile> <reads file(s)> <output dir> <num chunks>
                     <name> [options]

";
   exit();
}

$JID = int(rand(10000000)) + 10;

$configfile = $ARGV[0];
$readsfile = $ARGV[1];
$output_dir = $ARGV[2];
$output_dir =~ s!/$!!;
if(!(-d $output_dir)) {
    die "\nERROR: The directory '$output_dir' does not seem to exists...\n\n";
}

$kill = "false";
$postprocess = "false";
for($i=5; $i<@ARGV; $i++) {
    if($ARGV[$i] eq "-kill") {
       $kill = "true";
    }
    if($ARGV[$i] eq "-postprocess") {
       $postprocess = "true";
    }
}

if($postprocess eq "false" && $kill eq "false") {
    open(ERRORLOG, ">$output_dir/rum.error-log");
    print ERRORLOG "\n--------------------\n";
    print ERRORLOG "Job ID: $JID\n";
    print ERRORLOG "--------------------\n";
}

$numchunks = $ARGV[3];
$NUMCHUNKS = $ARGV[3];
if($numchunks =~ /(\d+)s/) {
    $numchunks = $1;
}
$name = $ARGV[4];
if($name =~ /^-/) {
    print ERRORLOG "\nERROR: The name '$name' is invalid, probably you forgot a required argument\n\n";
    die "\nERROR: The name '$name' is invalid, probably you forgot a required argument\n\n";
}

$name_o = $ARGV[4];
$name =~ s/\s+/_/g;
$name =~ s/^[^a-zA-Z0-9_.-]//;
$name =~ s/[^a-zA-Z0-9_.-]$//g;
$name =~ s/[^a-zA-Z0-9_.-]/_/g;
if($name ne $name_o) {
    print "\nWarning: name changed from '$name_o' to '$name'.\n\n";
    if(length($name) > 250) {
        die "\nError: The name must be less than 250 characters.\n\n";
    }
}

# Defualt options
$dna = "false";
$genomeonly = "false";
$limitNU = "false";
$limitNUhard = "false";
$qsub = "false";
$qsub2 = "false";
$minlength=0;
$blatonly = "false";
$cleanup = "true";
$variable_read_lengths = "false";
$countmismatches = "false";
$num_insertions_allowed = 1;
$junctions = "false";
$quatify = "false";
$ram = 6;
$user_ram = "false";
$user_jid = "false";
$nocat = "false";
$quals_specified = "false";
$strandspecific = "false";
$quantify = "false";
$quantify_specified = "false";
$altgenes = "false";
$altquant = "false";
# BLAT defualt options
$minidentity=93;
$tileSize=12;
$stepSize=6;
$repMatch=256;
$maxIntron=500000;
$preserve_names = "false";

if(@ARGV > 5) {
    for($i=5; $i<@ARGV; $i++) {
	$optionrecognized = 0;

        if($ARGV[$i] eq "-max_insertions_per_read") {
	    $i++;
	    $num_insertions_allowed = $ARGV[$i];
            if($ARGV[$i] =~ /^\d+$/) {
	        $optionrecognized = 1;
	    }
        }
	if($ARGV[$i] eq "-strandspecific") {
	    $strandspecific = "true";
	    $optionrecognized = 1;
	}
        if($ARGV[$i] eq "-ram") {
	    $i++;
	    $ram = $ARGV[$i];
            $user_ram = "true";
            if($ARGV[$i] =~ /^\d+$/) {
	        $optionrecognized = 1;
	    }
        }
        if($ARGV[$i] eq "-jid") {
	    $i++;
	    $JID = $ARGV[$i];
            $user_jid = "true";
            if($postprocess eq "false" && $kill eq "false") {
                close(ERRORLOG);
                open(ERRORLOG, ">$output_dir/rum.error-log");
                print ERRORLOG "\n--------------------\n";
                print ERRORLOG "Job ID: $JID\n";
                print ERRORLOG "--------------------\n";
            }
            if($ARGV[$i] =~ /^\d+$/) {
	        $optionrecognized = 1;
	    }
        }
	if($ARGV[$i] eq "-nocat") {
	    $nocat = "true";
	    $optionrecognized = 1;
	}
	if($ARGV[$i] eq "-preserve_names") {
	    $preserve_names = "true";
	    $optionrecognized = 1;
	}
	if($ARGV[$i] eq "-noclean") {
	    $cleanup = "false";
	    $optionrecognized = 1;
	}
	if($ARGV[$i] eq "-junctions") {
	    $junctions = "true";
	    $optionrecognized = 1;
	}
	if($ARGV[$i] eq "-blatonly") {
	    $blatonly = "true";
	    $optionrecognized = 1;
	}
	if($ARGV[$i] eq "-quantify") {
	    $quantify = "true";
            $quantify_specified = "true";
	    $optionrecognized = 1;
	}
	if($ARGV[$i] eq "-countmismatches") {
	    $countmismatches = "true";
	    $optionrecognized = 1;
	}
	if($ARGV[$i] eq "-variable_read_lengths" || $ARGV[$i] eq "-variable_length_reads") {
	    $variable_read_lengths = "true";
	    $optionrecognized = 1;
	}
	if($ARGV[$i] eq "-kill") {
	    $kill = "true";
	    $optionrecognized = 1;
	}
	if($ARGV[$i] eq "-postprocess") {
            $postprocess = "true";
	    $optionrecognized = 1;
	}
	if($ARGV[$i] eq "-dna") {
	    $dna = "true";
	    $optionrecognized = 1;
	}
	if($ARGV[$i] eq "-genome_only") {
	    $genomeonly = "true";
	    $optionrecognized = 1;
	}
	if($ARGV[$i] eq "-limitBowtieNU") {
	    $limitNU = "true";
	    $optionrecognized = 1;
	}
	if($ARGV[$i] eq "-qsub") {
	    $qsub = "true";
	    $optionrecognized = 1;
	}
	if($ARGV[$i] eq "-qsub2") {
	    $qsub2 = "true";
            $i++;
            $starttime = $ARGV[$i];
	    $optionrecognized = 1;
	}
	if($ARGV[$i] eq "-altgenes") {
	    $altgenes = "true";
            $i++;
            $altgene_file = $ARGV[$i];
            if(!(open(TESTIN, $altgene_file))) {
                print ERRORLOG "\nERROR: cannot open '$altgene_file' for reading.\n\n";
                die "\nERROR: cannot open '$altgene_file' for reading.\n\n";
            }
            close(TESTIN);
	    $optionrecognized = 1;
	}
	if($ARGV[$i] eq "-altquant") {
	    $altquant = "true";
            $i++;
            $altquant_file = $ARGV[$i];
            if(!(open(TESTIN, $altquant_file))) {
                print ERRORLOG "\nERROR: cannot open '$altquant_file' for reading.\n\n";
                die "\nERROR: cannot open '$altquant_file' for reading.\n\n";
            }
            close(TESTIN);
	    $optionrecognized = 1;
	}

	if($ARGV[$i] eq "-qualsfile" || $ARGV[$i] eq "-qualfile") {
	    $quals_specified = "true";
            $i++;
            $quals_file = $ARGV[$i];
            $quals = "true";
            if($quals_file =~ /\//) {
               print ERRORLOG "ERROR: do not specify -quals file with a full path, put it in the '$output_dir' directory.\n\n";
               die "ERROR: do not specify -quals file with a full path, put it in the '$output_dir' directory.\n\n";
            }
	    $optionrecognized = 1;
	}

	if($ARGV[$i] eq "-minidentity") {
	    $minidentity = $ARGV[$i+1];
	    $i++;
	    if(!($minidentity =~ /^\d+$/ && $minidentity <= 100)) {
                print ERRORLOG "\nERROR: minidentity must be an integer between zero and 100.\nYou have given '$minidentity'.\n\n";
		die "\nERROR: minidentity must be an integer between zero and 100.\nYou have given '$minidentity'.\n\n";
	    }
	    $optionrecognized = 1;
	}

        if($ARGV[$i] eq "-tileSize") {
            $tileSize = $ARGV[$i+1];
            $i++;
            $optionrecognized = 1;
        }

        if($ARGV[$i] eq "-stepSize") {
            $stepSize = $ARGV[$i+1];
            $i++;
            $optionrecognized = 1;
        }

        if($ARGV[$i] eq "-repMatch") {
            $repMatch = $ARGV[$i+1];
            $i++;
            $optionrecognized = 1;
        }

        if($ARGV[$i] eq "-maxIntron") {
            $maxIntron = $ARGV[$i+1];
            $i++;
            $optionrecognized = 1;
        }

	if($ARGV[$i] eq "-minlength") {
	    $minlength = $ARGV[$i+1];
	    $i++;
	    if(!($minlength =~ /^\d+$/ && $minlength >= 10)) {
                print ERRORLOG "\nERROR: minlength must be an integer >= 10.\nYou have given '$minlength'.\n\n";
		die "\nERROR: minlength must be an integer >= 10.\nYou have given '$minlength'.\n\n";
	    }
	    $optionrecognized = 1;
	}
	if($ARGV[$i] eq "-limitNU") {
	    $NU_limit = $ARGV[$i+1];
	    $i++;
	    $limitNUhard = "true";
	    if(!($NU_limit =~ /^\d+$/ && $NU_limit > 0)) {
                print ERRORLOG "\nERROR: -limitNU must be an integer greater than zero.\nYou have given '$NU_limit'.\n\n";
		die "\nERROR: -limitNU must be an integer greater than zero.\nYou have given '$NU_limit'.\n\n";
	    }
	    $optionrecognized = 1;
	}
	if($optionrecognized == 0) {
            print ERRORLOG "\nERROR: option $ARGV[$i] not recognized.\n\n";
	    die "\nERROR: option $ARGV[$i] not recognized.\n\n";
	}
    }
}

if(!($starttime =~ /\S/)) {
   $starttime = time();
}

$H = `hostname`;
if($H =~ /login.genomics.upenn.edu/ && $qsub eq "false") {
    print ERRORLOG "ERROR: you cannot run RUM on the PGFI cluster without using the -qsub option.\n\n";
    die "ERROR: you cannot run RUM on the PGFI cluster without using the -qsub option.\n\n";
}

if($dna eq "false") {
    $junctions = "true";
    $quantify = "true";
}

if($preserve_names eq "true" && $variable_length_reads eq "true") {
    print ERRORLOG "ERROR: Cannot use both -preserve_names and -variable_read_lengths at the same time.\nSorry, we will fix this eventually.\n\n";
    die "ERROR: Cannot use both -preserve_names and -variable_read_lengths at the same time.\nSorry, we will fix this eventually.\n\n";
}

if($genomeonly eq "true") {
    $junctions = "true";
    if($quantify_specified eq "true") {
       $quantify = "true";
    } else {
       $quantify = "false";
    }
}

if($kill eq "true") {

    open(ERRORLOG, ">>$output_dir/rum.error-log");
    $DT = `date`;
    print ERRORLOG "\nRUM Job $JID killed using -kill option at $DT\n";
    open(LOGFILE, ">>$output_dir/rum.log_master");
    print LOGFILE "\nRUM Job $JID killed using -kill option at $DT\n";
    close(ERRORLOG);
    close(LOGFILE);

    if(-e "$output_dir/kill_command") {
        $K = `cat "$output_dir/kill_command"`;
        @a = split(/\n/,$K);
        $A = $a[0] . "\n";
        $R = `$A`;
        print "$R\n";
        $A = $a[1] . "\n";
        $R = `$A`;
        print "$R\n";
        exit();
    }

    kill_runaway_procs($output_dir, name => $name, starttime => $starttime);

    print "\nRUM Job $JID killed using -kill option at $DT\n";
    exit();
}


print "

RUM version: $version

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                 _   _   _   _   _   _    _
               // \\// \\// \\// \\// \\// \\/
              //\\_//\\_//\\_//\\_//\\_//\\_//
        o_O__O_ o
       | ====== |       .-----------.
       `--------'       |||||||||||||
        || ~~ ||        |-----------|
        || ~~ ||        | .-------. |
        ||----||        ! | UPENN | !
       //      \\\\        \\`-------'/
      // /!  !\\ \\\\        \\_  O  _/
     !!__________!!         \\   /
     ||  ~~~~~~  ||          `-'
     || _        ||
     |||_|| ||\\/|||
     ||| \\|_||  |||
     ||          ||
     ||  ~~~~~~  ||
     ||__________||
.----|||        |||------------------.
     ||\\\\      //||                 /|
     |============|                //
     `------------'               //
---------------------------------'/
---------------------------------'
  ____________________________________________________________
- The RNA-Seq Unified Mapper (RUM) Pipeline has been initiated -
  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
";

$check = `ps a | grep RUM_runner.pl | grep perl | grep -s -v "\\-c perl"`;
@a = split(/\n/,$check);
$CNT=0;

for($i=0; $i<@a; $i++) {
    chomp($a[$i]);
    next if $a[$i] =~ /screen.*RUM_runner/i;
    $a[$i] =~ s/.*RUM_runner.pl *//;
    @b = split(/ +/,$a[$i]);
    $temp1 = $output_dir;
    $temp2 = $ARGV[2];
    $temp3 = $b[2];
    $temp1 =~ s!.*/!!;
    $temp2 =~ s!.*/!!;
    $temp3 =~ s!.*/!!;
    $cwd = `pwd`;
    chomp($cwd);
    $temp4 = $cwd . "/" . $temp1;
    $temp5 = $cwd . "/" . $temp2;
    $temp6 = $cwd . "/" . $temp3;
    if($temp4 eq $temp6 || $temp5 eq $temp6) {
	$CNT++;
	if($CNT > 1) {
            print ERRORLOG "\nERROR: You seem to already have an instance of RUM_runner.pl running on the\nsame working directory.  This will cause collisions of the temporary files.\n\nExiting.\n\nTry killing by running the same command with -kill.\nIf that doesn't work use kill -9 on the process ID.\n\n";
	    die "\nERROR: You seem to already have an instance of RUM_runner.pl running on the\nsame working directory.  This will cause collisions of the temporary files.\n\nExiting.\n\nTry killing by running the same command with -kill.\nIf that doesn't work use kill -9 on the process ID.\n\n";
	}
    }
}

print "\nIf this is a big job, you should keep an eye on the rum.error-log file as it runs,\nbecause errors in the various chunks will be reported there that might indicate a\nfailure that will require a restart that you otherwise might not become aware of\nuntil it's finished.\n\n";

if($qsub eq "true") {
     $q = `qstat`;
     @b = split(/\n/,$q);
     for($i=2; $i<@b; $i++) {
         $b[$i] =~ s/^\s+//;
         $b[$i] =~ s/\s+$//;
         @a = split(/\s+/,$b[$i]);
         $pid = $a[0];
         $args = `qstat -j $pid | grep job_args`;
         $args =~ s/\s*job_args:+\s+//;
         $args =~ s/,,,//;
         @c = split(/,/,$args);
         $dir = $c[3];
         if($dir eq $output_dir) {
             print ERRORLOG "\nERROR: You seem to already have an instance of RUM_runner.pl running on the\nsame working directory.  This will cause collisions of the temporary files.\n\nExiting.\n\nTry killing by running the same command with -kill.\nIf that doesn't work use kill -9 on the process ID.\n\n";
             die "\nERROR: You seem to already have an instance of RUM_runner.pl running on the\nsame working directory.  This will cause collisions of the temporary files.\n\n";
          }
    }

     print "\nWarning: You are using qsub - so if you have installed RUM somewhere other than your\nhome directory, then you will probably need to specify everything with full paths,\nincluding in the <rum config> file, nor this may not work.\n\n";

     print "You have chosen to submit the jobs using 'qsub'.  I'm going to assume each node has\nsufficient RAM for this.  If you are running a mammalian genome then you should have\nat least 6 Gigs per node.\n\n";

     $starttime = time();
     $clusterID  = $name . "." . $starttime . ".";
     if($clusterID =~ /^\d/) {
         $clusterID = "R." . $clusterID;
     }
     open(KF, ">$output_dir/kill_command");
     $argstring = "";
     for($i=0; $i<@ARGV; $i++) {
#          if($i == 2) {
#              $cwd = `pwd`;
#              chomp($cwd);
#              $ARGV[$i] =~ s!/$!!;
#              $ARGV[$i] =~ s!.*/!!;
#              $ARGV[$i] = $cwd . "/" . $ARGV[$i];
#          }
          $argstring = $argstring . " $ARGV[$i]";
     }
     $argstring =~ s/qsub/qsub2 $starttime/g;
     $mastername = $clusterID . "master";
     print KF "qdel $mastername\n";
     close(KF);
     `qsub -V -cwd -N $mastername -j y -b y perl $0 $argstring`;
     exit(0);
}

if($postprocess eq "false") {
     sleep(1);
     print "Please wait while I check that everything is in order.\n\n";
     sleep(1);
     print "This could take a few minutes.\n\n";
     sleep(1);
}


# Reads a path from the config file and returns it, making sure it's
# an absolute path. If it's specified as a relative path, we turn it
# into an absolute path by prepending the root directory of the RUM
# installation to it.
sub read_config_path {
    use strict;
    use warnings;
    my ($in) = @_;
    my $maybe_rel_path = <$in>;
    unless (defined($maybe_rel_path)) {
        print $CONFIG_DESC;
        die <<EOF;

The configuration file seems to be missing some lines.
Please see the instructions for the configuration file above.

EOF
    }
    chomp $maybe_rel_path;
    my $root = "$Bin/../";
    my $abs_path = File::Spec->rel2abs($maybe_rel_path, $root);
    return $abs_path;
}

open my $config_in, "<", $configfile
    or croak "Can't open the config file $configfile for reading: $!";
$gene_annot_file = read_config_path($config_in);
if($dna eq "false") {
    if(!(-e $gene_annot_file)) {
       print ERRORLOG "\nERROR: the file '$gene_annot_file' does not seem to exist.\n\n";
       die "\nERROR: the file '$gene_annot_file' does not seem to exist.\n\n";
    }
}
$bowtie_exe = read_config_path($config_in);
if(!(-e $bowtie_exe)) {
    print ERRORLOG "\nERROR: the executable '$bowtie_exe' does not seem to exist.\n\n";
}
$blat_exe = read_config_path($config_in);
if(!(-e $blat_exe)) {
    print ERRORLOG "\nERROR: the executable '$blat_exe' does not seem to exist.\n\n";
}
$mdust_exe = read_config_path($config_in);
if(!(-e $mdust_exe)) {
    print ERRORLOG "\nERROR: the executable '$mdust_exe' does not seem to exist.\n\n";
}
$genome_bowtie = read_config_path($config_in);
$transcriptome_bowtie = read_config_path($config_in);
$genome_blat = read_config_path($config_in);
if(!(-e $genome_blat)) {
    print ERRORLOG "\nERROR: the file '$genome_blat' does not seem to exist.\n\n";
}

# We can now find the scripts dir and lib dir based on the location of
# the RUM_runner.pl script. $FindBin::Bin is the directory that
# contains RUM_runner.pl; all the other scripts are in that directory,
# and the pipeline template is in $Bin/../conf.
our $scripts_dir = "$Bin";
our $conf_dir    = "$Bin/../conf";

if (defined (my $old_scripts_dir = <INFILE>)) {
    print <<EOF;

The 'scripts' and 'lib' directory lines in the configuration file are
no longer needed. I will use scripts in $scripts_dir and the pipeline
template in $conf_dir.

EOF
}


$genomefa = $genome_blat;
close(INFILE);

$gs1 = -s $genome_blat;
`grep ">" $genome_blat > $output_dir/temp.1`;
$gs2 = -s "$output_dir/temp.1";
$gs3 = `wc -l $output_dir/temp.1`;
$genome_size = $gs1 - $gs2 - $gs3;
`yes|rm $output_dir/temp.1`;
$gsz = $genome_size / 1000000000;
$min_ram = int($gsz * 1.67)+1;

if($postprocess eq "false") {
     if($qsub2 eq "false") {
          print "I'm going to try to figure out how much RAM you have.\nIf you see some error messages here, don't worry, these are harmless.\n\n";
          sleep(2);
          # figure out how much RAM is available:
          if($user_ram eq "false") {
               $did_not_figure_out_ram = "false";
               $ramcheck = `free -g`;  # this should work on linux
               $ramcheck =~ /Mem:\s+(\d+)/s;
               $totalram = $1;
               if(!($totalram =~ /\d+/)) { # so above still didn't work, trying even harder
                   $x = `grep memory /var/run/dmesg.boot`; # this should work on freeBSD
                   $x =~ /avail memory = (\d+)/;
                   $totalram = int($1 / 1000000000);
                   if($totalram == 0) {
               	$totalram = "";
                   }
               }
               if(!($totalram =~ /\d+/)) { # so above didn't work, trying harder
                   $x = `top -l 1 | grep free`;  # this should work on a mac
                   $x =~ /(\d+)(.)\s+used, (\d+)(.) free/;
                   $used = $1;
                   $type1 = $2;
                   $free = $3;
                   $type2 = $4;
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
                   $totalram = $used + $free;
                   if($totalram == 0) {
                  	$totalram = "";
                   }
               }
               if(!($totalram =~ /\d+/)) { # so above didn't work, warning user
                   $did_not_figure_out_ram = "true";
                   print "\nWarning: I could not determine how much RAM you have.  If you have less\nthan $min_ram gigs per chunk this might not work.  I'm going to proceed with fingers crossed.\n\n";
                   $ram = $min_ram;
               } else {
                   $RAMperchunk = int($totalram / $numchunks);
               }
          }

          if($did_not_figure_out_ram eq "false") {
              if($RAMperchunk >= $min_ram) {
                  print "It seems like you have $totalram Gb of RAM on your machine.\n";
                  print "\nUnless you have too much other stuff running, RAM should not be a problem.\n";
              } else {
                  print "\nWarning: you have only $RAMperchunk Gb of RAM per chunk.  Based on the\nsize of your genome you will probably need more like $min_ram Gb per chunk.\nAnyway I can try and see what happens.\n\n";
                  print "Do you really want me to proceed?  Enter 'Y' or 'N' ";
                  $answer = <STDIN>;
                  if($answer eq "n" || $answer eq "N") {
                      exit();
                  }
              }
              $ram = $min_ram;
              if($ram < 6 && $ram < $RAMperchunk) {
                   $ram = $RAMperchunk;
                   if($ram > 6) {
                       $ram = 6;
                   }
              }
              sleep(1);
          }
     }
}

if($kill eq "false") {
    sleep(1);
    print "\nChecking for phantom processes from prior runs that might need to be killed.\n\n";
    $cleanedflag = kill_runaway_procs($output_dir);
}
if($cleanedflag == 1) {
    sleep(2);
    print "OK there was some cleaning up to do, hopefully that worked.\n\n";
}
sleep(2);

if($postprocess eq "false") {
    for($i=1; $i<=$numchunks; $i++) {
        $logfile = "$output_dir/rum.log_chunk.$i";
        if (-e $logfile) {
       	    unlink($logfile);
        }
    }
}

$paired_end = "";
if(($readsfile =~ /,,,/)) {
   $paired_end = "true";
}
$file_needs_splitting = "false";
$preformatted = "false";
if(!($readsfile =~ /,,,/)) {

    if(!(-e $readsfile)) {
        print ERRORLOG "\nERROR: The reads file '$readsfile' does not seem to exist\n\n";
        die "\nERROR: The reads file '$readsfile' does not seem to exist\n\n";
    }

    open(INFILE, $readsfile);
    for($i=0; $i<50000; $i++) {
        $line = <INFILE>;
        if($line =~ /:Y:/) {
             $line = <INFILE>;
             chomp($ine);
             if($line =~ /^--$/) {
                  print ERRORLOG "\nERROR: you appear to have entries in your fastq file \"$readsfile\" for reads that didn't pass quality.\nThese are lines that have \":Y:\" in them, probably followed by lines that just have two dashes \"--\".\nYou first need to remove all such lines from the file, including the ones with the two dashes...\n\n";
                  die "ERROR: you appear to have entries in your fastq file \"$readsfile\" for reads that didn't pass quality.\nThese are lines that have \":Y:\" in them, probably followed by lines that just have two dashes \"--\".\nYou first need to remove all such lines from the file, including the ones with the two dashes...\n\n";
             }
        }
    }
    close(INFILE);

    $head = `head -4 $readsfile`;
    $head =~ /seq.(\d+)(.).*seq.(\d+)(.)/s;
    $num1 = $1;
    $type1 = $2;
    $num2 = $3;
    $type2 = $4;

    $paired_end = "false";
    if($num1 == 1 && $num2 == 1 & $type1 eq 'a' && $type2 eq 'b') {
         $paired_end = "true";
         $file_needs_splitting = "true";
         $preformatted = "true";
    }
    if($num1 == 1 && $num2 == 2 & $type1 eq 'a' && $type2 eq 'a') {
         $paired_end = "false";
         $file_needs_splitting = "true";
         $preformatted = "true";
    }
}

if($num_insertions_allowed > 1 && $paired_end eq "true") {
    print ERRORLOG "\nERROR: for paired end data, you cannot set -max_insertions_per_read to be greater than 1.\n\n";
    die "\nERROR: for paired end data, you cannot set -max_insertions_per_read to be greater than 1.\n\n";
}

if($paired_end eq "true") {
     print "Processing as paired-end data\n";
} else {
     print "Processing as single-end data\n";
}

$quals = "false";
if($readsfile =~ /,,,/ && $postprocess eq "false") {
    @a = split(/,,,/, $readsfile);
    if(@a > 2) {
        print ERRORLOG "\nERROR: You've given more than two files separated by three commas, should be at most two files.\n\n";
	die "\nERROR: You've given more than two files separated by three commas, should be at most two files.\n\n";
    }
    if(!(-e $a[0])) {
        print ERRORLOG "\nERROR: The reads file '$a[0]' does not seem to exist\n\n";
	die "\nERROR: The reads file '$a[0]' does not seem to exist\n\n";
    }
    if(!(-e $a[1])) {
        print ERRORLOG "\nERROR: The reads file '$a[1]' does not seem to exist\n\n";
	die "\nERROR: The reads file '$a[1]' does not seem to exist\n\n";
    }
    if($a[0] eq $a[1]) {
        print ERRORLOG "\nERROR: You specified the same file for the forward and reverse reads, must be an error...\n\n";
	die "\nERROR: You specified the same file for the forward and reverse reads, must be an error...\n\n";
    }

    # Make sure these aren't fastq files with entries that didn't pass quality:

    $size1 = -s $a[0];
    $size2 = -s $a[1];
    if($size1 != $size2) {
          print ERRORLOG "\nERROR: The fowards and reverse files are different sizes.\n$size1 versus $size2.  They should be the exact same size.\n\n";
          die "\nERROR: The fowards and reverse files are different sizes.\n$size1 versus $size2.  They should be the exact same size.\n\n";
    }

    open(INFILE, $a[0]);
    for($i=0; $i<50000; $i++) {
        $line = <INFILE>;
        if($line =~ /:Y:/) {
             $line = <INFILE>;
             chomp($ine);
             if($line =~ /^--$/) {
                  print ERRORLOG "\nERROR: you appear to have entries in your fastq file \"$a[0]\" for reads that didn't pass quality.\nThese are lines that have \":Y:\" in them, probably followed by lines that just have two dashes \"--\".\nYou first need to remove all such lines from the file, including the ones with the two dashes...\n\n";
                  die "ERROR: you appear to have entries in your fastq file e \"$a[0]\" for reads that didn't pass quality.\nThese are lines that have \":Y:\" in them, probably followed by lines that just have two dashes \"--\".\nYou first need to remove all such lines from the file, including the ones with the two dashes...\n\n";
             }
        }
    }
    close(INFILE);

    open(INFILE, $a[1]);
    for($i=0; $i<50000; $i++) {
        $line = <INFILE>;
        if($line =~ /:Y:/) {
             $line = <INFILE>;
             chomp($ine);
             if($line =~ /^--$/) {
                  print ERRORLOG "\nERROR: you appear to have entries in your fastq file e \"$a[1]\" for reads that didn't pass quality.\nThese are lines that have \":Y:\" in them, probably followed by lines that just have two dashes \"--\".\nYou first need to remove all such lines from the file, including the ones with the two dashes...\n\n";
                  die "ERROR: you appear to have entries in your fastq file e \"$a[1]\" for reads that didn't pass quality.\nThese are lines that have \":Y:\" in them, probably followed by lines that just have two dashes \"--\".\nYou first need to remove all such lines from the file, including the ones with the two dashes...\n\n";
             }
        }
    }
    close(INFILE);

    # Going to figure out here if these are standard fastq files

    $head40 = `head -40 $a[0]`;
    $head40 =~ s/^\s*//s;
    $head40 =~ s/\s*$//s;
    @b = split(/\n/, $head40);
    $fastq = "true";
    for($i=0; $i<10; $i++) {
        if(!($b[$i*4] =~ /^@/)) {
            $fastq = "false";
        }
        if(!($b[$i*4+1] =~ /^[acgtnACGTN.]+$/)) {
            $fastq = "false";
        }
        if(!($b[$i*4+2] =~ /^\+/)) {
            $fastq = "false";
        }
    }

   # Check to see if it's fasta

    $fasta = "true";
    for($i=0; $i<10; $i++) {
        if(!($b[$i*2] =~ /^>/)) {
            $fasta = "false";
        }
        if(!($b[$i*2+1] =~ /^[acgtnACGTN.]+$/)) {
            $fasta = "false";
        }
    }

    # Check here that the quality scores are the same length as the reads.

    $FL = `head -50000 $a[0] | wc -l`;
    chomp($FL);
    $FL =~ s/[^\d]//gs;

    `perl $scripts_dir/parse2fasta.pl $a[0] $a[1] | head -$FL > $output_dir/reads_temp.fa 2>> $output_dir/rum.error-log`;
    `perl $scripts_dir/fastq2qualities.pl $a[0] $a[1] | head -$FL > $output_dir/quals_temp.fa 2>> $output_dir/rum.error-log`;
    $X = `head -20 $output_dir/quals_temp.fa`;
    if($X =~ /\S/s && !($X =~ /Sorry, can't figure these files out/s)) {
        open(RFILE, "$output_dir/reads_temp.fa");
        open(QFILE, "$output_dir/quals_temp.fa");
        while($linea = <RFILE>) {
            $lineb = <QFILE>;
            $line1 = <RFILE>;
            $line2 = <QFILE>;
            chomp($line1);
            chomp($line2);
            if(length($line1) != length($line2)) {
               print ERRORLOG "ERROR: It seems your read lengths differ from your quality string lengths.\nCheck line:\n$linea$line1\n$lineb$line2.\nThis error could also be due to having reads of length 10 or less, if so you should remove those reads.\n\n";
               die "ERROR: It seems your read lengths differ from your quality string lengths.\nCheck line:\n$linea$line1\n$lineb$line2.\nThis error could also be due to having reads of length 10 or less, if so you should remove those reads.\n\n";
            }
        }
    }

    # Check that reads are not variable length

    if($X =~ /\S/s) {
        open(RFILE, "$output_dir/reads_temp.fa");
        $length_flag = 0;
        while($linea = <RFILE>) {
            $line1 = <RFILE>;
            chomp($line1);
            if($length_flag == 0) {
                 $length_hold = length($line1);
                 $length_flag = 1;
            }
            if(length($line1) != $length_hold && $variable_read_lengths eq 'false') {
               print ERRORLOG "\nWARNING: It seems your read lengths vary, but you didn't set -variable_length_reads.\nI'm going to set it for you, but it's generally safer to set it on the command-line since\nI only spot check the file.\n\n";
               print "\nWARNING: It seems your read lengths vary, but you didn't set -variable_length_reads.\nI'm going to set it for you, but it's generally safer to set it on the command-line since\nI only spot check the file.\n\n";
               $variable_read_lengths = "true";
            }
            $length_hold = length($line1);
        }
    }

    # Clean up:

    unlink("$output_dir/reads_temp.fa");
    unlink("$output_dir/quals_temp.fa");

    # Done checking

    print "\nReformatting reads file... please be patient.\n";

    if($fastq eq "true" && $variable_read_lengths eq "false" && $FL == 50000) {
        if($preserve_names eq "false") {
            `perl $scripts_dir/parsefastq.pl $a[0],,,$a[1] $numchunks $output_dir/reads.fa $output_dir/quals.fa 2>> $output_dir/rum.error-log`;
        } else {
            `perl $scripts_dir/parsefastq.pl $a[0],,,$a[1] $numchunks $output_dir/reads.fa $output_dir/quals.fa -name_mapping $output_dir/read_names_mapping 2>> $output_dir/rum.error-log`;
        }
        $x = `grep -A 2 "something wrong with line" $output_dir/rum.error-log`;
        if($x =~ /something wrong/s) {
            print "$x\n";
            exit();
        }
   	$quals = "true";
        $file_needs_splitting = "false";
    } elsif($fasta eq "true" && $variable_read_lengths eq "false" && $FL == 50000 && $preformatted eq "false") {
        if($preserve_names eq "false") {
            `perl $scripts_dir/parsefasta.pl $a[0],,,$a[1] $numchunks $output_dir/reads.fa 2>> $output_dir/rum.error-log`;
        } else {
            `perl $scripts_dir/parsefasta.pl $a[0],,,$a[1] $numchunks $output_dir/reads.fa -name_mapping $output_dir/read_names_mapping 2>> $output_dir/rum.error-log`;
        }
   	$quals = "false";
        $file_needs_splitting = "false";
    } elsif($preformatted eq "false") {
        `perl $scripts_dir/parse2fasta.pl $a[0] $a[1] > $output_dir/reads.fa 2>> $output_dir/rum.error-log`;
        `perl $scripts_dir/fastq2qualities.pl $a[0] $a[1] > $output_dir/quals.fa 2>> $output_dir/rum.error-log`;
        $file_needs_splitting = "true";
        $X = `head -20 $output_dir/quals.fa`;
        if($X =~ /\S/s && !($X =~ /Sorry, can't figure these files out/s)) {
    	     $quals = "true";
        }
    }
    if($preformatted eq "false") {
       $qualsfile = "$output_dir/quals.fa";
       $readsfile = "$output_dir/reads.fa";
    } else {
       $file_needs_splitting = "true";
    }
}

if($postprocess eq "true") {
    $readsfile = "$output_dir/reads.fa";
    if(!(-e $readsfile)) {
        $readsfile = $ARGV[1];
    }
    $qualsfile = "$output_dir/quals.fa";
    $quals = "false";
    if(-e $qualsfile) {
        $X = `head -20 $output_dir/quals.fa`;
        if($X =~ /\S/s && !($X =~ /Sorry, can't figure these files out/s)) {
	    $quals = "true";
        }
    }
}


$head = `head -4 $readsfile`;
$head =~ /seq.(\d+)(.).*seq.(\d+)(.)/s;
$num1 = $1;
$type1 = $2;
$num2 = $3;
$type2 = $4;

if($paired_end eq 'false' && $postprocess eq "false") {
    if($type1 ne "a" || $type2 ne "a") {
        print "\nReformatting reads file... please be patient.\n";

        $head40 = `head -40 $readsfile`;
        $head40 =~ s/^\s*//s;
        $head40 =~ s/\s*$//s;
        @b = split(/\n/, $head40);
        $fastq = "true";
        for($i=0; $i<10; $i++) {
            if(!($b[$i*4] =~ /^@/)) {
                $fastq = "false";
            }
            if(!($b[$i*4+1] =~ /^[acgtnACGTN.]+$/)) {
                $fastq = "false";
            }
            if(!($b[$i*4+2] =~ /^\+/)) {
                $fastq = "false";
            }
        }

        # Check to see if it's fasta

         $fasta = "true";
         for($i=0; $i<10; $i++) {
             if(!($b[$i*2] =~ /^>/)) {
                 $fasta = "false";
             }
             if(!($b[$i*2+1] =~ /^[acgtnACGTN.]+$/)) {
                 $fasta = "false";
             }
         }

        # Check here that the quality scores are the same length as the reads.

        $FL = `head -50000 $readsfile | wc -l`;
        chomp($FL);
        $FL =~ s/[^\d]//gs;

        `perl $scripts_dir/parse2fasta.pl $readsfile | head -$FL > $output_dir/reads_temp.fa 2>> $output_dir/rum.error-log`;
        `perl $scripts_dir/fastq2qualities.pl $readsfile | head -$FL > $output_dir/quals_temp.fa 2>> $output_dir/rum.error-log`;
        $X = `head -20 $output_dir/quals_temp.fa`;
        if($X =~ /\S/s && !($X =~ /Sorry, can't figure these files out/s)) {
            open(RFILE, "$output_dir/reads_temp.fa");
            open(QFILE, "$output_dir/quals_temp.fa");
            while($linea = <RFILE>) {
                $lineb = <QFILE>;
                $line1 = <RFILE>;
                $line2 = <QFILE>;
                chomp($line1);
                chomp($line2);
                if(length($line1) != length($line2)) {
                   print ERRORLOG "ERROR: It seems your read lengths differ from your quality string lengths.\nCheck line:\n$linea$line1\n$lineb$line2.\nThis error could also be due to having reads of length 10 or less, if so you should remove those reads.\n\n";
                   die "ERROR: It seems your read lengths differ from your quality string lengths.\nCheck line:\n$linea$line1\n$lineb$line2.\nThis error could also be due to having reads of length 10 or less, if so you should remove those reads.\n\n";
                }
            }
        }

        # Check that reads are not variable length

        if($X =~ /\S/s) {
            open(RFILE, "$output_dir/reads_temp.fa");
            $length_flag = 0;
            while($linea = <RFILE>) {
                $line1 = <RFILE>;
                chomp($line1);
                if($length_flag == 0) {
                     $length_hold = length($line1);
                     $length_flag = 1;
                }
                if(length($line1) != $length_hold && $variable_read_lengths eq 'false') {
                   print ERRORLOG "\nWARNING: It seems your read lengths vary, but you didn't set -variable_length_reads.\nI'm going to set it for you, but it's generally safer to set it on the command-line since\nI only spot check the file.\n\n";
                   print "\nWARNING: It seems your read lengths vary, but you didn't set -variable_length_reads.\nI'm going to set it for you, but it's generally safer to set it on the command-line since\nI only spot check the file.\n\n";
                   $variable_read_lengths = "true";
                }
                $length_hold = length($line1);
            }
        }

        # Clean up:
        unlink("$output_dir/reads_temp.fa");
        unlink("$output_dir/quals_temp.fa");

        # Done checking

        if($fastq eq "true" && $variable_read_lengths eq "false" && $FL == 50000) {
           if($preserve_names eq "false") {
              `perl $scripts_dir/parsefastq.pl $readsfile $numchunks $output_dir/reads.fa $output_dir/quals.fa 2>> $output_dir/rum.error-log`;
           } else {
              `perl $scripts_dir/parsefastq.pl $readsfile $numchunks $output_dir/reads.fa $output_dir/quals.fa -name_mapping $output_dir/read_names_mapping 2>> $output_dir/rum.error-log`;
           }
           $x = `grep -A 2 "something wrong with line" $output_dir/rum.error-log`;
           if($x =~ /something wrong/s) {
               print "$x\n";
               exit();
           }
           $quals = "true";
           $file_needs_splitting = "false";
        } elsif($fasta eq "true" && $variable_read_lengths eq "false" && $FL == 50000 && $preformatted eq "false") {
           if($preserve_names eq "false") {
               `perl $scripts_dir/parsefasta.pl $readsfile $numchunks $output_dir/reads.fa 2>> $output_dir/rum.error-log`;
           } else {
               `perl $scripts_dir/parsefasta.pl $readsfile $numchunks $output_dir/reads.fa -name_mapping $output_dir/read_names_mapping 2>> $output_dir/rum.error-log`;
           }
       	   $quals = "false";
           $file_needs_splitting = "false";
        } elsif($preformatted eq "false") {
           `perl $scripts_dir/parse2fasta.pl $readsfile > $output_dir/reads.fa 2>> $output_dir/rum.error-log`;
           `perl $scripts_dir/fastq2qualities.pl $readsfile > $output_dir/quals.fa 2>> $output_dir/rum.error-log`;
           $file_needs_splitting = "true";
           $X = `head -20 $output_dir/quals.fa`;
           if($X =~ /\S/s && !($X =~ /Sorry, can't figure these files out/s)) {
	       $quals = "true";
	   }
        }
        if($preformatted eq "true") {
            $file_needs_splitting = "true";
        } else {
            $readsfile = "$output_dir/reads.fa";
            $qualsfile = "$output_dir/quals.fa";
        }
    }
}

$X = `grep -c "This does not appear to be a valid file" $readsfile`;
if($X > 0) {
       print ERRORLOG "ERROR: This does not appear to be a valid input file.\nFastQ files must have FOUR lines for each entry (do not include entries that do not have all four lines).\nFastA must have TWO lines for each entry.\n\n";
       die "ERROR: This does not appear to be a valid input file.\nFastQ files must have FOUR lines for each entry (do not include entries that do not have all four lines).\nFastA must have TWO lines for each entry.\n\n";
}

$head = `head -2 $readsfile | tail -1`;
chomp($head);
@a = split(//,$head);
if($variable_read_lengths eq "false") {
   $readlength = @a;
   if($minlength > $readlength) {
       print ERRORLOG "ERROR: you specified a minimum length alignment to report as '$minlength', however\nyour read length is only $readlength\n";
       die "ERROR: you specified a minimum length alignment to report as '$minlength', however\nyour read length is only $readlength\n";
   }
} else {
   $readlength = "v";
}

if($NUMCHUNKS =~ /(\d+)s/) {
    $file_needs_splitting = "false";
}

if($file_needs_splitting eq "true" && $postprocess eq "false") {
    $x = &breakup_file($readsfile, $numchunks);
    print "Splitting files ... please be patient.\n\n";
    $qualflag = 0;
    if($quals eq "true" || $quals_specified eq "true") {
        print "Half done splitting...\n\n";
        $qualflag = 1;
        if($quals_specified eq 'true') {
       	    $x = &breakup_file("$output_dir/$quals_file", $numchunks);
        } else {
       	    $x = &breakup_file($qualsfile, $numchunks);
        }
    }
}

$head = `head -2 $readsfile | tail -1`;
chomp($head);
$rl = length($head);
$tail = `tail -2 $readsfile | head -1`;
$tail =~ /seq.(\d+)/s;
$nr = $1;

if($minlength == 0) {
   if($rl < 80) {
      if($match_length_cutoff == 0) {
         $match_length_cutoff = 35;
      }
   } else {
      if($match_length_cutoff == 0) {
         $match_length_cutoff = 50;
      }
   }
   if($match_length_cutoff >= .8 * $rl) {
       $match_length_cutoff = int(.6 * $rl);
   }
} else {
	$match_length_cutoff = $minlength;
}

if($quals_specified eq 'true') {
    if(!(open(TESTIN, "$output_dir/$quals_file"))) {
       print ERRORLOG "\nERROR: cannot open '$quals_file' for reading, it should be in the '$output_dir' directory.\n\n";
       die "\nERROR: cannot open '$quals_file' for reading, it should be in the '$output_dir' directory.\n\n";
    }
    close(TESTIN);
    $qualsfile = "$output_dir/$quals_file";
    $quals = "true";
}

if($postprocess eq "true") {
    $head = `head -4 $readsfile`;
    $head =~ /seq.(\d+)(.).*seq.(\d+)(.)/s;
    $num1 = $1;
    $type1 = $2;
    $num2 = $3;
    $type2 = $4;
}

if($postprocess eq "false") {
    open(LOGFILE, ">$output_dir/rum.log_master");
    print LOGFILE "RUM version: $version\n";
    print LOGFILE "\nJob ID: $JID\n";
    print LOGFILE "\nstart: $date\n";
    print LOGFILE "name: $name\n";
    if($configfile =~ /hg(18)/ || $configfile =~ /hg(19)/) {
        print LOGFILE "config file: $configfile  [human - build $1]\n";
    } elsif($configfile =~ /mm(8)/ || $configfile =~ /mm(9)/) {
        print LOGFILE "config file: $configfile  [mouse build $1]\n";
    } else {
        print LOGFILE "config file: $configfile\n";
    }

    print LOGFILE "paired_end: $paired_end\n";
    if($ARGV[1] =~ /,,,/) {
        @RF = split(/,,,/,$ARGV[1]);
        print LOGFILE "forward reads file: $RF[0]\n";
        print LOGFILE "reverse reads file: $RF[1]\n";
    } else {
        print LOGFILE "reads file: $ARGV[1]\n";
    }
    if($gene_annot_file =~ /\S/) {
       print LOGFILE "transcript db: $gene_annot_file\n";
    }
    if($altquant_file =~ /\S/) {
       print LOGFILE "alternate transcript db: $altquant_file\n";
    }
    print LOGFILE "genome db: $genomefa\n";
    if($fasta eq "true") {
       print LOGFILE "input file format: fasta\n";
    }
    if($fastq eq "true") {
       print LOGFILE "input file format: fastq\n";
    }
    print LOGFILE "output_dir: $output_dir\n";
    if($variable_read_lengths eq "false") {
        print LOGFILE "readlength: $rl\n";
    } else {
        print LOGFILE "readlength: variable\n";
    }
    $NR = &format_large_int($nr);
    if($paired_end eq 'false') {
        print LOGFILE "number of reads: $NR\n";
    } else {
        print LOGFILE "number of read pairs: $NR\n";
    }

    if($variable_read_lengths eq "false" || $minlength > 0) {
        if($minlength == 0) {
            print LOGFILE "minimum length alignment to report: $match_length_cutoff\n  *** NOTE: If you want to change the min size of alignment reported, use the -minlength option.\n";
        } else {
            print LOGFILE "minimum length alignment to report: $match_length_cutoff.\n";
        }
        print "\n *** NOTE: I am going to report alginments of length $match_length_cutoff.\n";
        print "If you want to change the minimum size of alignments reported, use the -minlength option.\n\n";
    } else {
        print LOGFILE "minimum length alignment to report: NA since read length is variable\n";
    }
    $nc = $numchunks;
    $nc =~ s/s//;
    print LOGFILE "number of chunks: $nc\n";
    print LOGFILE "ram per chunk: $ram\n";
    print LOGFILE "limitBowtieNU: $limitNU\n";
    if($limitNUhard eq "true") {
        print LOGFILE "limitNU: $limitNUhard (no alignments reported if more than $NU_limit locations)\n";
    } else {
        print LOGFILE "limitNU: $limitNUhard\n";
    }
    print LOGFILE "dna: $dna\n";
    print LOGFILE "output junctions: $junctions\n";
    print LOGFILE "output quantified values: $quantify\n";
    print LOGFILE "strand specific: $strandspecific\n";
    print LOGFILE "number of insertions allowed per read: $num_insertions_allowed\n";
    print LOGFILE "count mismatches: $countmismatches\n";
    print LOGFILE "genome only: $genomeonly\n";
    print LOGFILE "qsub: $qsub2\n";
    print LOGFILE "blat minidentity: $minidentity\n";
    print LOGFILE "blat tileSize: $tileSize\n";
    print LOGFILE "blat stepSize: $stepSize\n";
    print LOGFILE "blat repMatch: $repMatch\n";
    print LOGFILE "blat maxIntron: $maxIntron\n";

    print ERRORLOG "\nNOTE: I am going to report alginments of length $match_length_cutoff.\n";
    print ERRORLOG "  *** If you want to change the min size of alignment reported, use the -minlength option.\n\n";

    if($readlength ne "v" && $readlength < 55 && $limitNU eq "false") {
        print ERRORLOG "\nWARNING: you have pretty short reads ($readlength bases).  If you have a large\n";
        print ERRORLOG "genome such as mouse or human then the files of ambiguous mappers could grow\n";
        print ERRORLOG "very large, in this case it's recommended to run with the -limitBowtieNU option.  You\n";
        print ERRORLOG "can watch the files that start with 'X' and 'Y' to see if they are growing\n";
        print ERRORLOG "larger than 10 gigabytes per million reads at which point you might want to use.\n";
        print ERRORLOG "-limitNU\n\n";

        print "\n\nWARNING: you have pretty short reads ($readlength bases).  If you have a large\n";
        print "genome such as mouse or human then the files of ambiguous mappers could grow\n";
        print "very large, in this case it's recommended to run with the -limitBowtieNU option.  You\n";
        print "can watch the files that start with 'X' and 'Y' to see if they are growing\n";
        print "larger than 10 gigabytes per million reads at which point you might want to use.\n";
        print "-limitNU\n\n";
    }
}

if($blatonly eq "true" && $dna eq "true") {
    $dna = "false";  # setting them both breaks things below
}

if($dna eq "true" && $genomeonly eq "true") {
    die "\nError: Sorry it makes no sense to set both -dna and -genome_only to be true.\n";
}

if($postprocess eq "false") {
    open(OUT, ">$output_dir/restart.ids");
    print OUT "";
    close(OUT);

    $pipeline_template = `cat $conf_dir/pipeline_template.sh`;
    if($cleanup eq 'false') {
        $pipeline_template =~ s/^.*unlink.*$//mg;
        $pipeline_template =~ s!if . -f OUTDIR.RUM_NU_temp3.CHUNK .\nthen\n\nfi\n!!gs;
    }
    if($dna eq "true" || $genomeonly eq "true") {
        $pipeline_template =~ s/# cp /cp /gs;
        $pipeline_template =~ s/xxx1.*xxx2//s;
        $pipeline_template =~ s/\n[^\n]*CNU[^\n]*\n/\n/s;
    }
    if($blatonly eq "true") {
        $pipeline_template =~ s/xxx0.*xxx2//s;
        $pipeline_template =~ s!# cp OUTDIR/GU.CHUNK OUTDIR/BowtieUnique.CHUNK!echo `` >> OUTDIR/BowtieUnique.CHUNK!s;
        $pipeline_template =~ s!# cp OUTDIR/GNU.CHUNK OUTDIR/BowtieNU.CHUNK!echo `` >> OUTDIR/BowtieNU.CHUNK!s;
    }

    print "Number of Chunks: $numchunks\n";
    if($ARGV[1] =~ /,,,/) {
        @RF = split(/,,,/,$ARGV[1]);
        print "Forward Reads File: $RF[0]\n";
        print "Reverse Reads File: $RF[1]\n";
    } else {
        print "Reads File: $ARGV[1]\n";
    }
    print "Paired End: $paired_end\n";

    $readsfile =~ s!.*/!!;
    $readsfile = $output_dir . "/" . $readsfile;
    $t = `tail -2 $readsfile`;
    $t =~ /seq.(\d+)/;
    $NumSeqs = $1;
    $f = &format_large_int($NumSeqs);
    if($paired_end eq 'true') {
       print "Number of Read Pairs: $f\n";
    } else {
       print "Number of Reads: $f\n";
    }

    print "\nEverything seems okay, I am going to fire off the job.\n\n";

    if($qsub2 eq "true") {
	open(KF, ">>$output_dir/kill_command");
	$kc = $name . "." . $starttime . ".*";
	print KF "qdel \"$kc\"\n";
	close(KF);
    }

    for($i=1; $i<=$numchunks; $i++) {
        if(!(open(EOUT, ">$output_dir/errorlog.$i"))) {
            print ERRORLOG "\nERROR: cannot open '$output_dir/errorlog.$i' for writing\n\n";
            die "\nERROR: cannot open '$output_dir/errorlog.$i' for writing\n\n";
        }
        close(EOUT);
        $pipeline_file = $pipeline_template;

        if($altquant eq "true") {
            @PF = split(/\n/,$pipeline_template);
            $pipeline_file = "";
            for($j=0; $j<@PF; $j++) {
                $pipeline_file = $pipeline_file . $PF[$j];
                $pipeline_file = $pipeline_file . "\n";
                if($PF[$j] =~ /rum2quantifications/) {
                    $PF[$j] =~ s/GENEANNOTFILE/$altquant_file/;
                    $PF[$j] =~ s/S1s.CHUNK/S1s.altquant.CHUNK/;
                    $PF[$j] =~ s/S2s.CHUNK/S2s.altquant.CHUNK/;
                    $PF[$j] =~ s/S1a.CHUNK/S1a.altquant.CHUNK/;
                    $PF[$j] =~ s/S2a.CHUNK/S2a.altquant.CHUNK/;
                    $pipeline_file = $pipeline_file . $PF[$j];
                    $pipeline_file = $pipeline_file . "\n";
                }
            }
        }

        $pipeline_file =~ s!ERRORFILE!$output_dir/errorlog!gs;
        if($limitNUhard eq "true") {
    	   $pipeline_file =~ s!LIMITNUCUTOFF!$NU_limit!gs;
        } else {
    	   $pipeline_file =~ s!perl SCRIPTSDIR/limit_NU.pl OUTDIR/RUM_NU_temp3.CHUNK LIMITNUCUTOFF > OUTDIR/RUM_NU.CHUNK[^\n]*\n!mv OUTDIR/RUM_NU_temp3.CHUNK OUTDIR/RUM_NU.CHUNK\n!gs;
        }
        if($num_insertions_allowed != 1) {
    	   $pipeline_file =~ s!MAXINSERTIONSALLOWED!-num_insertions_allowed $num_insertions_alllowed!gs;
        } else {
    	   $pipeline_file =~ s!MAXINSERTIONSALLOWED!!gs;
        }
        if($preserve_names eq "false") {
           $pipeline_file =~ s!NAMEMAPPING.CHUNK!!gs;
        } else {
           $pipeline_file =~ s!NAMEMAPPING!-name_mapping $output_dir/read_names_mapping!gs;
        }
        $pipeline_file =~ s!OUTDIR!$output_dir!gs;
        if($quals eq "false") {
    	   $pipeline_file =~ s!QUALSFILE.CHUNK!none!gs;
        } else {
    	   $pipeline_file =~ s!QUALSFILE!$qualsfile!gs;
        }
        if($strandspecific eq 'true') {
           $pipeline_file =~ s/STRAND1s/-strand p/gs;
           $pipeline_file =~ s/quant.S1s/quant.ps/gs;
           $pipeline_file =~ s/STRAND2s/-strand m/gs;
           $pipeline_file =~ s/quant.S2s/quant.ms/gs;
           $pipeline_file =~ s/STRAND1a/-strand p -anti/gs;
           $pipeline_file =~ s/quant.S1a/quant.pa/gs;
           $pipeline_file =~ s/STRAND2a/-strand m -anti/gs;
           $pipeline_file =~ s/quant.S2a/quant.ma/gs;
        } else {
           $pipeline_file =~ s/STRAND1s//sg;
           $pipeline_file =~ s/quant.S1s/quant/sg;
           $pipeline_file =~ s/[^\n]+quant.S2s[^\n]*\n//sg;
           $pipeline_file =~ s/[^\n]+quant.S1a[^\n]*\n//sg;
           $pipeline_file =~ s/[^\n]+quant.S2a[^\n]*\n//sg;
        }
        if($ram != 6) {
           $pipeline_file =~ s!RAM!-ram $ram!gs;
        } else {
           $pipeline_file =~ s! RAM!!gs;
        }
        $pipeline_file =~ s!CHUNK!$i!gs;
        $pipeline_file =~ s!BOWTIEEXE!$bowtie_exe!gs;
        $pipeline_file =~ s!GENOMEBOWTIE!$genome_bowtie!gs;
        $pipeline_file =~ s!READSFILE!$readsfile!gs;
        $pipeline_file =~ s!SCRIPTSDIR!$scripts_dir!gs;
        $pipeline_file =~ s!TRANSCRIPTOMEBOWTIE!$transcriptome_bowtie!gs;
        $pipeline_file =~ s!GENEANNOTFILE!$gene_annot_file!gs;
        $blat_opts = "-minIdentity='$minidentity' -tileSize='$tileSize' -stepSize='$stepSize' -repMatch='$repMatch' -maxIntron='$maxIntron'";
        $pipeline_file =~ s!BLATEXEOPTS!$blat_opts!gs;
        $pipeline_file =~ s!BLATEXE!$blat_exe!gs;
        $pipeline_file =~ s!MDUSTEXE!$mdust_exe!gs;
        $pipeline_file =~ s!GENOMEBLAT!$genome_blat!gs;
        $pipeline_file =~ s!GENOMEFA!$genomefa!gs;
        $pipeline_file =~ s!READLENGTH!$readlength!gs;
        if($countmismatches eq "true") {
    	   $pipeline_file =~ s!COUNTMISMATCHES!-countmismatches!gs;
        } else {
    	   $pipeline_file =~ s!COUNTMISMATCHES!!gs;
        }
        if($limitNU eq "true") {
    	   $pipeline_file =~ s! -a ! -k 100 !gs;
        }
        if($dna eq 'true') {
    	   $pipeline_file =~ s!DNA!-dna!gs;
        } else {
    	   $pipeline_file =~ s!DNA!!gs;
        }
        if($minlength > 0) {
    	   $pipeline_file =~ s!MATCHLENGTHCUTOFF!-match_length_cutoff $minlength!gs;
           $pipeline_file =~ s!MINOVERLAP!$minlength!gs;
        } else {
    	   $pipeline_file =~ s!MATCHLENGTHCUTOFF!!gs;
           $pipeline_file =~ s!-minoverlap MINOVERLAP!!gs;
        }
        if($paired_end eq "true") {
    	   $pipeline_file =~ s!PAIREDEND!paired!gs;
        } else {
    	   $pipeline_file =~ s!PAIREDEND!single!gs;
        }
        $outfile = $name . "." . $starttime . "." . $i . ".sh";
        if(!(open(OUTFILE, ">$output_dir/$outfile"))) {
            print ERRORLOG "\nERROR: cannot open '$output_dir/$outfile' for writing\n\n";
            die "\nERROR: cannot open '$output_dir/$outfile' for writing\n\n";
        }
        if($qsub2 eq "true") {
    	   $pipeline_file =~ s!2>>\s*[^\s]*!!gs;
    	   $pipeline_file =~ s!2>\s*[^\s]*!!gs;
        }

        print OUTFILE $pipeline_file;

        # Add postprocessing steps to the last chunk only:

        if($i == $numchunks) {
            $t = `tail -2 $readsfile`;
            $t =~ /seq.(\d+)/s;
            $NumSeqs = $1;
            $PPlog = "postprocessing_$name" . ".log";
            $shellscript = "\n\n# Postprocessing stuff starts here...\n\n";
            $shellscript = $shellscript . "perl $scripts_dir/wait.pl $output_dir $JID 2>> $output_dir/PostProcessing-errorlog || exit 1\n";
            if($NumSeqs =~ /(\d+)/) {
                $shellscript = $shellscript . "echo 'computing mapping statistics' > $output_dir/$PPlog\n";
                $shellscript = $shellscript . "echo `date` >> $output_dir/$PPlog\n";
                $shellscript = $shellscript . "perl $scripts_dir/count_reads_mapped.pl $output_dir/RUM_Unique $output_dir/RUM_NU -minseq 1 -maxseq $NumSeqs > $output_dir/mapping_stats.txt 2>> $output_dir/PostProcessing-errorlog || exit 1\n";
            } else {
                $shellscript = $shellscript . "perl $scripts_dir/count_reads_mapped.pl $output_dir/RUM_Unique $output_dir/RUM_NU -minseq 1 > $output_dir/mapping_stats.txt 2>> $output_dir/PostProcessing-errorlog || exit 1\n";
            }
            if($quantify eq "true") {
                $shellscript = $shellscript . "echo 'merging feature quantifications' >> $output_dir/$PPlog\n";
                $shellscript = $shellscript . "echo `date` >> $output_dir/$PPlog\n";
                if($strandspecific eq 'true') {
                    $shellscript = $shellscript . "perl $scripts_dir/merge_quants.pl $output_dir $numchunks $output_dir/feature_quantifications.ps -strand ps -chunk_ids_file $output_dir/restart.ids 2>> $output_dir/PostProcessing-errorlog || exit 1\n";
                    $shellscript = $shellscript . "perl $scripts_dir/merge_quants.pl $output_dir $numchunks $output_dir/feature_quantifications.ms -strand ms -chunk_ids_file $output_dir/restart.ids 2>> $output_dir/PostProcessing-errorlog || exit 1\n";
                    $shellscript = $shellscript . "perl $scripts_dir/merge_quants.pl $output_dir $numchunks $output_dir/feature_quantifications.pa -strand pa -chunk_ids_file $output_dir/restart.ids 2>> $output_dir/PostProcessing-errorlog || exit 1\n";
                    $shellscript = $shellscript . "perl $scripts_dir/merge_quants.pl $output_dir $numchunks $output_dir/feature_quantifications.ma -strand ma -chunk_ids_file $output_dir/restart.ids 2>> $output_dir/PostProcessing-errorlog || exit 1\n";
                    $shellscript = $shellscript . "perl $scripts_dir/merge_quants_strandspecific.pl $output_dir/feature_quantifications.ps $output_dir/feature_quantifications.ms $output_dir/feature_quantifications.pa $output_dir/feature_quantifications.ma $gene_annot_file $output_dir/feature_quantifications_$name 2>> $output_dir/PostProcessing-errorlog || exit 1\n";
                } else {
                    $shellscript = $shellscript . "perl $scripts_dir/merge_quants.pl $output_dir $numchunks $output_dir/feature_quantifications_$name -chunk_ids_file $output_dir/restart.ids 2>> $output_dir/PostProcessing-errorlog || exit 1\n";
                }
                if($altquant eq "true") {
                    if($strandspecific eq 'true') {
                        $shellscript = $shellscript . "perl $scripts_dir/merge_quants.pl $output_dir $numchunks $output_dir/feature_quantifications.altquant.ps -alt -strand ps -chunk_ids_file $output_dir/restart.ids 2>> $output_dir/PostProcessing-errorlog || exit 1\n";
                        $shellscript = $shellscript . "perl $scripts_dir/merge_quants.pl $output_dir $numchunks $output_dir/feature_quantifications.altquant.ms -alt -strand ms -chunk_ids_file $output_dir/restart.ids 2>> $output_dir/PostProcessing-errorlog || exit 1\n";
                        $shellscript = $shellscript . "perl $scripts_dir/merge_quants.pl $output_dir $numchunks $output_dir/feature_quantifications.altquant.pa -alt -strand pa -chunk_ids_file $output_dir/restart.ids 2>> $output_dir/PostProcessing-errorlog || exit 1\n";
                        $shellscript = $shellscript . "perl $scripts_dir/merge_quants.pl $output_dir $numchunks $output_dir/feature_quantifications.altquant.ma -alt -strand ma -chunk_ids_file $output_dir/restart.ids 2>> $output_dir/PostProcessing-errorlog || exit 1\n";
                        $shellscript = $shellscript . "perl $scripts_dir/merge_quants_strandspecific.pl $output_dir/feature_quantifications.altquant.ps $output_dir/feature_quantifications.altquant.ms $output_dir/feature_quantifications.altquant.pa $output_dir/feature_quantifications.altquant.ma $altquant_file $output_dir/feature_quantifications_$name" . ".altquant 2>> $output_dir/PostProcessing-errorlog || exit 1\n";
                    } else {
                        $shellscript = $shellscript . "perl $scripts_dir/merge_quants.pl $output_dir $numchunks $output_dir/feature_quantifications_$name" . ".altquant -alt -chunk_ids_file $output_dir/restart.ids 2>> $output_dir/PostProcessing-errorlog || exit 1\n";
                    }
                }
            }

            $string = "$output_dir/RUM_Unique.sorted";
            for($j=1; $j<$numchunks+1; $j++) {
                $string = $string . " $output_dir/RUM_Unique.sorted.$j";
            }
            $shellscript = $shellscript . "echo 'merging RUM_Unique.sorted files' >> $output_dir/$PPlog\n";
            $shellscript = $shellscript . "echo `date` >> $output_dir/$PPlog\n";
            $shellscript = $shellscript . "perl $scripts_dir/merge_sorted_RUM_files.pl -o $string -chunk_ids_file $output_dir/restart.ids 2>> $output_dir/PostProcessing-errorlog || exit 1\n";
            $string = "$output_dir/RUM_NU.sorted";
            for($j=1; $j<$numchunks+1; $j++) {
                $string = $string . " $output_dir/RUM_NU.sorted.$j";
            }
            $shellscript = $shellscript . "echo 'merging RUM_NU.sorted files' >> $output_dir/$PPlog\n";
            $shellscript = $shellscript . "echo `date` >> $output_dir/$PPlog\n";
            $shellscript = $shellscript . "perl $scripts_dir/merge_sorted_RUM_files.pl -o $string -chunk_ids_file $output_dir/restart.ids 2>> $output_dir/PostProcessing-errorlog || exit 1\n";

            $string = "$output_dir/mapping_stats.txt";
            for($j=1; $j<$numchunks+1; $j++) {
                $string = $string . " $output_dir/chr_counts_u.$j";
            }
            $shellscript = $shellscript . "echo '' >> $output_dir/mapping_stats.txt\n";
            $shellscript = $shellscript . "echo 'RUM_Unique reads per chromosome' >> $output_dir/mapping_stats.txt\n";
            $shellscript = $shellscript . "echo '-------------------------------' >> $output_dir/mapping_stats.txt\n";
            $shellscript = $shellscript . "perl $scripts_dir/merge_chr_counts.pl $string -chunk_ids_file $output_dir/restart.ids 2>> $output_dir/PostProcessing-errorlog || exit 1\n";

            $string = "$output_dir/mapping_stats.txt";
            for($j=1; $j<$numchunks+1; $j++) {
                $string = $string . " $output_dir/chr_counts_nu.$j";
            }
            $shellscript = $shellscript . "echo '' >> $output_dir/mapping_stats.txt\n";
            $shellscript = $shellscript . "echo 'RUM_NU reads per chromosome' >> $output_dir/mapping_stats.txt\n";
            $shellscript = $shellscript . "echo '---------------------------' >> $output_dir/mapping_stats.txt\n";
            $shellscript = $shellscript . "perl $scripts_dir/merge_chr_counts.pl $string -chunk_ids_file $output_dir/restart.ids 2>> $output_dir/PostProcessing-errorlog || exit 1\n";

            $shellscript = $shellscript . "perl $scripts_dir/merge_nu_stats.pl $output_dir $numchunks -chunk_ids_file $output_dir/restart.ids >> $output_dir/mapping_stats.txt 2>> $output_dir/PostProcessing-errorlog || exit 1\n";

            if($junctions eq "true") {
               $shellscript = $shellscript . "echo 'computing junctions' >> $output_dir/$PPlog\n";
               $shellscript = $shellscript . "echo `date` >> $output_dir/$PPlog\n";
               if($altgenes eq "true") {
                    $ANNOTFILE = $altgene_file;
               } else {
                    $ANNOTFILE = $gene_annot_file;
               }
               if($strandspecific eq 'true') {
                   $shellscript = $shellscript . "perl $scripts_dir/make_RUM_junctions_file.pl $output_dir/RUM_Unique $output_dir/RUM_NU $genomefa $ANNOTFILE $output_dir/junctions_ps_all.rum $output_dir/junctions_ps_all.bed $output_dir/junctions_high-quality_ps.bed -faok -strand p 2>> $output_dir/PostProcessing-errorlog || exit 1\n";
                   $shellscript = $shellscript . "perl $scripts_dir/make_RUM_junctions_file.pl $output_dir/RUM_Unique $output_dir/RUM_NU $genomefa $ANNOTFILE $output_dir/junctions_ms_all.rum $output_dir/junctions_ms_all.bed $output_dir/junctions_high-quality_ms.bed -faok -strand m 2>> $output_dir/PostProcessing-errorlog || exit 1\n";
               } else {
                   $shellscript = $shellscript . "perl $scripts_dir/make_RUM_junctions_file.pl $output_dir/RUM_Unique $output_dir/RUM_NU $genomefa $ANNOTFILE $output_dir/junctions_all_temp.rum $output_dir/junctions_all_temp.bed $output_dir/junctions_high-quality_temp.bed -faok 2>> $output_dir/PostProcessing-errorlog || exit 1\n";
               }
               if($strandspecific eq 'true') {
                     $shellscript = $shellscript . "cp $output_dir/junctions_ps_all.rum $output_dir/junctions_all_temp.rum\n";
                     $shellscript = $shellscript . "grep -v long_overlap_nu_reads $output_dir/junctions_ms_all.rum >> $output_dir/junctions_all_temp.rum\n";
                     $shellscript = $shellscript . "cp $output_dir/junctions_ps_all.bed $output_dir/junctions_all_temp.bed\n";
                     $shellscript = $shellscript . "grep -v rum_junctions_neg-strand $output_dir/junctions_ms_all.bed >> $output_dir/junctions_all_temp.bed\n";
                     $shellscript = $shellscript . "cp $output_dir/junctions_high-quality_ps.bed $output_dir/junctions_high-quality_temp.bed\n";
                     $shellscript = $shellscript . "grep -v rum_junctions_neg-strand $output_dir/junctions_high-quality_ms.bed >> $output_dir/junctions_high-quality_temp.bed\n";
                     if($cleanup eq 'true') {
                         $shellscript = $shellscript . "yes|rm $output_dir/junctions_high-quality_ps.bed $output_dir/junctions_high-quality_ms.bed $output_dir/junctions_ps_all.bed $output_dir/junctions_ms_all.bed $output_dir/junctions_ps_all.rum $output_dir/junctions_ms_all.rum\n";
                     }
               }
               $shellscript = $shellscript . "perl $scripts_dir/sort_by_location.pl $output_dir/junctions_all_temp.rum $output_dir/junctions_all.rum -location_column 1 -skip 1\n";
               $shellscript = $shellscript . "perl $scripts_dir/sort_by_location.pl $output_dir/junctions_all_temp.bed $output_dir/junctions_all.bed -location_columns 1,2,3 -skip 1\n";
               $shellscript = $shellscript . "perl $scripts_dir/sort_by_location.pl $output_dir/junctions_high-quality_temp.bed $output_dir/junctions_high-quality.bed -location_columns 1,2,3 -skip 1\n";
               if($cleanup eq 'true') {
                   $shellscript = $shellscript . "yes|rm $output_dir/junctions_high-quality_temp.bed $output_dir/junctions_all_temp.bed $output_dir/junctions_all_temp.rum\n";
               }
            }
            $shellscript = $shellscript . "echo 'making coverage plots' >> $output_dir/$PPlog\n";
            $shellscript = $shellscript . "echo `date` >> $output_dir/$PPlog\n";
            $shellscript = $shellscript . "perl $scripts_dir/rum2cov.pl $output_dir/RUM_Unique.sorted $output_dir/RUM_Unique.cov -name \"$name Unique Mappers\" -stats $output_dir/u_footprint.txt 2>> $output_dir/PostProcessing-errorlog || exit 1\n";
            $shellscript = $shellscript . "echo 'unique mappers coverage plot finished' >> $output_dir/$PPlog\n";
            $shellscript = $shellscript . "echo `date` >> $output_dir/$PPlog\n";
            $shellscript = $shellscript . "perl $scripts_dir/rum2cov.pl $output_dir/RUM_NU.sorted $output_dir/RUM_NU.cov -name \"$name Non-Unique Mappers\"  -stats $output_dir/nu_footprint.txt 2>> $output_dir/PostProcessing-errorlog || exit 1\n";
            $shellscript = $shellscript . "echo 'NU mappers coverage plot finished' >> $output_dir/$PPlog\n";
            $shellscript = $shellscript . "echo `date` >> $output_dir/$PPlog\n";
            if($strandspecific eq 'true') {
                  # breakup RUM_Unique and RUM_NU files into plus and minus
                  $shellscript = $shellscript . "perl $scripts_dir/breakup_RUM_files_by_strand.pl $output_dir/RUM_Unique.sorted $output_dir/RUM_Unique.sorted.plus $output_dir/RUM_Unique.sorted.minus 2>> $output_dir/PostProcessing-errorlog || exit 1\n";
                  $shellscript = $shellscript . "perl $scripts_dir/breakup_RUM_files_by_strand.pl $output_dir/RUM_NU.sorted $output_dir/RUM_NU.sorted.plus $output_dir/RUM_NU.sorted.minus 2>> $output_dir/PostProcessing-errorlog || exit 1\n";
                  # run rum2cov on all four files
                  $shellscript = $shellscript . "perl $scripts_dir/rum2cov.pl $output_dir/RUM_Unique.sorted.plus $output_dir/RUM_Unique.plus.cov -name \"$name Unique Mappers Plus Strand\" 2>> $output_dir/PostProcessing-errorlog || exit 1\n";
                  $shellscript = $shellscript . "perl $scripts_dir/rum2cov.pl $output_dir/RUM_Unique.sorted.minus $output_dir/RUM_Unique.minus.cov -name \"$name Unique Mappers Minus Strand\" 2>> $output_dir/PostProcessing-errorlog || exit 1\n";
                  $shellscript = $shellscript . "perl $scripts_dir/rum2cov.pl $output_dir/RUM_NU.sorted.plus $output_dir/RUM_NU.plus.cov -name \"$name Non-Unique Mappers Plus Strand\" 2>> $output_dir/PostProcessing-errorlog || exit 1\n";
                  $shellscript = $shellscript . "perl $scripts_dir/rum2cov.pl $output_dir/RUM_NU.sorted.minus $output_dir/RUM_NU.minus.cov -name \"$name Non-Unique Mappers Minus Strand\" 2>> $output_dir/PostProcessing-errorlog || exit 1\n";
            }
            $shellscript = $shellscript . "perl $scripts_dir/get_inferred_internal_exons.pl $output_dir/junctions_high-quality.bed $output_dir/RUM_Unique.cov $gene_annot_file -bed $output_dir/inferred_internal_exons.bed > $output_dir/inferred_internal_exons.txt 2>> $output_dir/PostProcessing-errorlog || exit 1\n";
            $shellscript = $shellscript . "perl $scripts_dir/quantifyexons.pl $output_dir/inferred_internal_exons.txt $output_dir/RUM_Unique.sorted $output_dir/RUM_NU.sorted $output_dir/quant.1 -novel -countsonly 2>> $output_dir/PostProcessing-errorlog || exit 1\n";
            $shellscript = $shellscript . "perl $scripts_dir/merge_quants.pl $output_dir 1 $output_dir/novel_exon_quant_temp -header 2>> $output_dir/PostProcessing-errorlog || exit 1\n";
	    $shellscript = $shellscript . "grep -v transcript $output_dir/novel_exon_quant_temp > $output_dir/novel_inferred_internal_exons_quantifications_$name\n";
            $shellscript = $shellscript . "echo post-processing finished >> $output_dir/$PPlog\n";
            $shellscript = $shellscript . "echo `date` >> $output_dir/$PPlog\n";
            if($qsub2 eq "true") {
        	   $shellscript =~ s!2>>\s*[^\s]*!!gs;
        	   $shellscript =~ s!2>\s*[^\s]*!!gs;
            }
            print OUTFILE $shellscript;
        }
        close(OUTFILE);

        if($qsub2 eq "true") {
           $ofile = $output_dir . "/chunk.$i" . ".o";
           $efile = $output_dir . "/errorlog.$i";
           $MEM = $ram . "G";
    	   $Q = `qsub -l mem_free=$MEM,h_vmem=$MEM -o $ofile -e $efile $output_dir/$outfile`;
           $Q =~ /Your job (\d+)/;
           $jobid{$i} = $1;
        } else {
           $jobid{$i} = spawn("/bin/bash", "$output_dir/$outfile");
      }
        print "Chunk $i initiated\n";
        $status{$i} = 1;
    }
    if($numchunks > 1) {
        print "\nAll chunks initiated, now the long wait...\n";
        print "\nI'm going to watch for all chunks to finish, then I will merge everything...\n\n";
        sleep(2);
    } else {
        print "\nThe job has been initiated, now the long wait...\n";
        sleep(2);
    }

    $currenttime = time();
    $lastannouncetime = $currenttime;
    $numannouncements = 0;
    $doneflag = 0;

    for($i=1; $i<=$numchunks; $i++) {
       $efiles_hash{$i} = "";
    }

    for($i=1; $i<=$numchunks; $i++) {
        $number_consecutive_restarts{$i} = 0;
    }

    while($doneflag == 0) {
        sleep(3);

        if($qsub2 eq "false") {

            # For each chunk, get the PID if it is still running, find
            # the pids of all child processes, and add them to the
            # $child hash.
            for my $i (1 .. $numchunks) {
                 $PID = $jobid{$i};
                 next unless int($PID);
                 for my $CID (child_pids($PID)) {
                     $child{$i}{$CID}++;
                 }
            }

            # Now check each child to see if it is still running, and
            # if not delete it from the hash.
            for my $i (1 .. $numchunks) {
                foreach $K (keys %{$child{$i}}) {

                    # If the child pid isn't a pid or it's no longer
                    # running, delete it from my
                    # list.
                    delete $child{$i}{$K} unless can_kill($K);
               }
            }
        }

        $doneflag = 1;
        $numdone = 0;
        for($i=1; $i<=$numchunks; $i++) {
            if($restarted{$i} =~ /\S/) {
                $logfile = "$output_dir/rum.log_chunk.$i.$restarted{$i}";
            } else {
                $logfile = "$output_dir/rum.log_chunk.$i";
            }
            if (-e $logfile) {
    	        $x = `cat $logfile`;
    	        if(!($x =~ /pipeline complete/s)) {
    		    $doneflag = 0;
    	        } else {
        	    $numdone++;
    		    if($status{$i} == 1) {
    		        $status{$i} = 2;
		        print "\n *** Chunk $i has finished.\n";
                        if($i != $numchunks) {
                            delete $jobid{$i};
                        }
		    }
	        }
	    }
    	    else {
	        $doneflag = 0;
	    }
        }
        if($doneflag == 0) {
	    $currenttime = time();
    	    if($currenttime - $lastannouncetime > 3600) {
	        $lastannouncetime = $currenttime;
	        $numannouncements++;
	        if($numannouncements == 1) {
		    if($numdone == 1) {
		        print "\nIt has been $numannouncements hour, $numdone chunk has finished.\n";
		    } else {
		        print "\nIt has been $numannouncements hour, $numdone chunks have finished.\n";
		    }
	        } else {
		    if($numdone == 1) {
		        print "\nIt has been $numannouncements hours, $numdone chunk has finished.\n";
		    } else {
		        print "\nIt has been $numannouncements hours, $numdone chunks have finished.\n";
		    }
	        }
    	    }
        }
        for($i=1; $i<=$numchunks; $i++) {
           $efile = $output_dir . "/errorlog.$i";
           $efile_content = `cat $efile`;
           $efile_content =~ s/stdin: is not a tty[^\n]*\n//sg;
           if(!($efile_content eq $efiles_hash{$i})) {
                 $efile_temp = $efiles_hash{$i};
                 $efiles_hash{$i} = $efile_content;
                 $efile_content =~ s/^$efile_temp//s;
                 $time = `date`;
                 $time =~ s/\s*$//;
                 print ERRORLOG "--------------------------------------------------------------------------\n";
                 print ERRORLOG "The following was reported to chunk $i";
                 print ERRORLOG "'s errorlog (errorlog.$i) around $time:\n\n";
                 print ERRORLOG "$efile_content\n";
                 print ERRORLOG "*** This may be innocuous, having no effect at all, or at worst indicating\nan error that lead to a node restart.\n";
                 print ERRORLOG "*** Or this may be more serious, which sometimes is clear from the message,\nor usually from the rum.error-log when the run finishes.\n";
                 print ERRORLOG "--------------------------------------------------------------------------\n";
             }
        }
        for($i=1; $i<=$numchunks; $i++) {
          # Check here to make sure node still running
                  $DIED = "false";
                  if($restarted{$i} =~ /\S/) {
                      $logfile = "$output_dir/rum.log_chunk.$i.$restarted{$i}";
                  } else {
                      $logfile = "$output_dir/rum.log_chunk.$i";
                  }
                  $x = "";
                  if (-e $logfile) {
        	        $x = `cat $logfile`;
                  }
                  $Jobid = $jobid{$i};
                  if(!($x =~ /pipeline complete/s) || ($x =~ /pipeline complete/s && $i == $numchunks && $status{$i} == 2)) {
                       if($qsub2 eq 'true') {
                            for($t=0; $t<10; $t++) {
                                $X = `qstat -j $Jobid | grep job_number`;
                                if($X =~ /job_number:\s+$Jobid/s) {
                                   $t = 10;
                                } else {
                                   if($t<=7) {
                                        print "Hmm, couldn't get status on job $Jobid, the job might have died, or maybe just the\nstatus failed.  Going to try to get the status again.\n";
                                   }
                                   if($t==8) {
                                        print "Hmm, couldn't get status on job $Jobid, the job might have died, or maybe just the\nstatus failed.  Going to wait 5 minutes and try to get the status again.\n";
                                   }
                                   sleep(3);
                                   if($t == 8) {
                                      sleep(300);  # try one last time waiting five minutes
                                   }
                                }
                            }
                            if(!($X =~ /job_number:\s+$Jobid/s) && (!($x =~ /pipeline complete/s) || ($x =~ /pipeline complete/s && $i == $numchunks && $status{$i} == 2))) {
                                 $DIED = "true";
                                 $X = `qdel $Jobid`;
                            }
                       } else {
                            $PID = $jobid{$i};
                            if (my $child_status = check($PID)) {
                                $DIED = "true";
                                kill_all(keys %{$child{$i}});
                            }
                        }
                       sleep(2);
                       if(-e "$output_dir/$rum.log_chunk.$suffixnew") {
                            $Q = `grep "pipeline complete" $output_dir/$rum.log_chunk.$suffixnew`;
                            if($Q =~ /pipeline complete/) {
                                  $DIED = "false";
                            }
                       }
                       if($DIED eq "true") {
                            $DATE = `date`;
                            $DATE =~ s/^\s+//;
                            $DATE =~ s/\s+$//;
                            print ERRORLOG "\n *** Chunk $i seems to have failed sometime around $DATE!  Trying to restart it...\n";
                            print "\n *** Chunk $i seems to have failed sometime around $DATE!\nDon't panic, I'm going to try to restart it.\n";
                            # check that didn't run out of disk space
                            $mcheck = `df -h $output_dir | grep -vi Avai`;
                            chomp($mcheck);
                            $mcheck =~ s/^\s*//;
                            @mc = split(/\s+/,$mcheck);
                            $mc[3] =~ /(\d+)/;
                            $mfree = $1 + 0;
                            if($mfree == 0) {
                                  print ERRORLOG "\n *** You seem to have run out of disk space: exiting.\n";
                                  print "\n *** You seem to have run out of disk space: exiting.\n";
                                  if(-e "$output_dir/kill_command") {
                                      $K = `cat "$output_dir/kill_command"`;
                                      @a = split(/\n/,$K);
                                      $A = $a[0] . "\n";
                                      $R = `$A`;
                                      print "$R\n";
                                      $A = $a[1] . "\n";
                                      $R = `$A`;
                                      print "$R\n";
                                      exit(0);
                                  }
                                  # I should kill any shell scripts
                                  # with my start time running in this
                                  # directory, then any other
                                  # processes running in this
                                  # directory.
                                  kill_runaway_procs($output_dir, 
                                                     name => $name,
                                                     startime => $starttime);
                                  exit(0);
                            }
                            $ofile = $output_dir . "/chunk.restart.$i" . ".o";
                            $efile = $output_dir . "/chunk.restart.$i" . ".e";
                            $outfile = "$name" . "." . $starttime . "." . $i . ".sh";
                            $FILE = `cat $output_dir/$outfile`;
                            $restarted{$i}++;
                            open(OUT, ">$output_dir/restart.ids");
                            foreach $key (keys %restarted) {
                                print OUT "$key\t$restarted{$key}\n";
                            }
                            close(OUT);
                            # changing the names of the files of this chunk to avoid possible collision with
                            # phantom processes that didn't die properly..

                            # Note, can't modify the postprocessing scripts to reflect the new file names, since it
                            # has already been submmitted.  Instead the postprocessing scripts that need file names
                            # will recover the correct ones from the restart.ids file

                            if(!($i == $numchunks && $status{$i} == 2)) { # otherwise it's postprocessing node in waiting state, don't change names in this case
                                 if($restarted{$i} == 1) {
                                     $J1 = $i;
                                     $J3 = $i;
                                     $FILE =~ s/\.$i/.$i.1/g;
                                     $FILE =~ s/errorlog.$i.\d+/errorlog.$i/g;
                                     $suffixold = $i;
                                     $suffixnew = "$i.1";
                                 } else {
                                     $J1 = $restarted{$i} - 1;
                                     $J2 = $restarted{$i};
                                     $J3 = "$i.$J1";
                                     $FILE =~ s/\.$i\.$J1/.$i.$J2/g;
                                     $FILE =~ s/errorlog.$i.\d+/errorlog.$i/g;
                                     $suffixold = "$i.$J1";
                                     $suffixnew = "$i.$J2";
                                 }
                                 # rename reads and quals files with new suffix
                                 `mv $output_dir/reads.fa.$suffixold $output_dir/reads.fa.$suffixnew`;
                                 if(-e "$output_dir/quals.fa.$suffixold") {
                                    `mv $output_dir/quals.fa.$suffixold $output_dir/quals.fa.$suffixnew`;
                                 }
                                 if(-e "$output_dir/read_names_mapping.$suffixold") {
                                    `mv $output_dir/read_names_mapping.$suffixold $output_dir/read_names_mapping.$suffixnew`;
                                 }

                                 # move things that have already finished to new suffix, so don't have to redo them
                                 # and remove the things that have finished from the shell script $FILE so don't get redone

                                 $LOGFILE = `cat $output_dir/rum.log_chunk.$suffixold`;
                                 `mv $output_dir/rum.log_chunk.$suffixold $output_dir/rum.log_chunk.$suffixnew`;
                                 if($LOGFILE =~ /finished first bowtie/s) {
                                        if(-e "$output_dir/X.$suffixold") {
                                           `mv $output_dir/X.$suffixold $output_dir/X.$suffixnew`;
                                       }
                                       $FILE =~ s/echo .starting.*finished first bowtie run[^\n]*\n//s;
                                 }                                 

                                 if($LOGFILE =~ /finished parsing genome bowtie/s) {
                                       if(-e "$output_dir/GU.$suffixold") {
                                            `mv $output_dir/GU.$suffixold $output_dir/GU.$suffixnew`;
                                       }
                                       if(-e "$output_dir/GNU.$suffixold") {
                                            `mv $output_dir/GNU.$suffixold $output_dir/GNU.$suffixnew`;
                                       }
                                       $FILE =~ s/perl $scripts_dir.make_GU_and_GNU.pl.*finished parsing genome bowtie run[^\n]*\n[^\n]+\n[^\n]+\n//s;
                                 }                                 
                                 if($LOGFILE =~ /finished second bowtie/s) {
                                        if(-e "$output_dir/Y.$suffixold") {
                                             `mv $output_dir/Y.$suffixold $output_dir/Y.$suffixnew`;
                                        }
                                        $FILE =~ s/..transcriptome bowtie starts here.*finished second bowtie run[^\n]*\n//s;
                                 }
                                 if($LOGFILE =~ /finished parsing transcriptome bowtie/s) {
                                        if(-e "$output_dir/TU.$suffixold") {
                                             `mv $output_dir/TU.$suffixold $output_dir/TU.$suffixnew`;
                                        }
                                        if(-e "$output_dir/TNU.$suffixold") {
                                             `mv $output_dir/TNU.$suffixold $output_dir/TNU.$suffixnew`;
                                        }
                                        $FILE =~ s/perl $scripts_dir.make_TU_and_TNU.pl[^\n]*\n[^\n]*\n[^\n]*\n[^\n]*\n//s;
                                 }
                                 if($LOGFILE =~ /finished merging TU and GU/s) {
                                        if(-e "$output_dir/BowtieUnique.$suffixold") {
                                             `mv $output_dir/BowtieUnique.$suffixold $output_dir/BowtieUnique.$suffixnew`;
                                        }
                                        if(-e "$output_dir/CNU.$suffixold") {
                                             `mv $output_dir/CNU.$suffixold $output_dir/CNU.$suffixnew`;
                                        }
                                        $FILE =~ s/..merging starts here.*finished merging TU and GU[^\n]+\n//s;
                                 }
                                 if($LOGFILE =~ /finished merging GNU, TNU and CNU/s) {
                                        if(-e "$output_dir/BowtieNU.$suffixold") {
                                             `mv $output_dir/BowtieNU.$suffixold $output_dir/BowtieNU.$suffixnew`;
                                        }
                                        $FILE =~ s/perl $scripts_dir.merge_GNU_and_TNU_and_CNU.pl[^\n]+\n[^\n]+\n[^\n]+\n[^\n]+\n[^\n]+\n[^\n]+\n[^\n]+\n//s;
                                 }
                                 if($LOGFILE =~ /checkpoint 1/s) {
                                     if($dna eq "true" || $genomeonly eq "true") {
                                             if((-e  "$output_dir/$GU.$i.$suffix_old") && (-e "$output_dir/BowtieUnique.$suffixold")) {
                                                  $s1 = -s "$output_dir/$GU.$i.$suffix_old";
                                                  $s2 = -s "$output_dir/BowtieUnique.$suffixold";
                                                  if($s1 != $s2) {
                                                      $x = `cp $output_dir/$GU.$i.$suffix_old $output_dir/BowtieUnique.$suffixold`;
                                                  }
                                             }
                                             if((-e  "$output_dir/$GNU.$i.$suffix_old") && (-e "$output_dir/BowtieNU.$suffixold")) {
                                                  $s1 = -s "$output_dir/$GNU.$i.$suffix_old";
                                                  $s2 = -s "$output_dir/BowtieNU.$suffixold";
                                                  if($s1 != $s2) {
                                                      $x = `cp $output_dir/$GNU.$i.$suffix_old $output_dir/BowtieNU.$suffixold`;
                                                  }
                                             }
                                             if(-e "$output_dir/BowtieUnique.$suffixold") {
                                                  `mv $output_dir/BowtieUnique.$suffixold $output_dir/BowtieUnique.$suffixnew`;
                                             }
                                             if(-e "$output_dir/BowtieNU.$suffixold") {
                                                  `mv $output_dir/BowtieNU.$suffixold $output_dir/BowtieNU.$suffixnew`;
                                             }
                                             $FILE =~ s/..uncomment the following for dna or genome only mapping.*checkpoint 1[^\n]+\n\n[^\n]+\n[^\n]+\n[^\n]+\n[^\n]+\n//s;  # one less line to remove becuase the CNU line has been revmoed in this case
                                      } else {
                                             $FILE =~ s/..uncomment the following for dna or genome only mapping.*checkpoint 1[^\n]+\n\n[^\n]+\n[^\n]+\n[^\n]+\n[^\n]+\n[^\n]+\n//s;
                                      }
                                 }

                                 if($LOGFILE =~ /finished making R/s) {
                                        if(-e "$output_dir/R.$suffixold") {
                                             `mv $output_dir/R.$suffixold $output_dir/R.$suffixnew`;
                                        }
                                        $FILE =~ s/perl $scripts_dir.make_unmapped_file[^\n]+\n[^\n]+\n//s;
                                 }
                                 if($LOGFILE =~ /finished running BLAT/s) {
                                        if(-e "$output_dir/R.$suffixold.blat") {
                                             `mv $output_dir/R.$suffixold.blat $output_dir/R.$suffixnew.blat`;
                                        }
                                        $bt = $blat_exe;
                                        $bt =~ s!/!.!g;
                                        $FILE =~ s/$bt[^\n]+\n[^\n]+\n//s;
                                 }
                                 if($LOGFILE =~ /finished running mdust/s) {
                                        if(-e "$output_dir/R.mdust.$suffixold") {
                                             `mv $output_dir/R.mdust.$suffixold $output_dir/R.mdust.$suffixnew`;
                                        }
                                        $bt = $mdust_exe;
                                        $bt =~ s!/!.!g;
                                        $FILE =~ s/$bt[^\n]+\n[^\n]+\n//s;
                                 }
                                 if($LOGFILE =~ /finished parsing BLAT/s) {
                                        if(-e "$output_dir/BlatUnique.$suffixold") {
                                             `mv $output_dir/BlatUnique.$suffixold $output_dir/BlatUnique.$suffixnew`;
                                        }
                                        if(-e "$output_dir/BlatNU.$suffixold") {
                                             `mv $output_dir/BlatNU.$suffixold $output_dir/BlatNU.$suffixnew`;
                                        }
                                        $FILE =~ s/perl $scripts_dir.parse_blat_out.pl[^\n]+\n[^\n]+\n[^\n]+\n[^\n]+\n[^\n]+\n[^\n]+\n[^\n]+\n[^\n]+\n//s;
                                 }
                                 if($LOGFILE =~ /finished merging Bowtie and Blat/s) {
                                        if(-e "$output_dir/RUM_Unique_temp.$suffixold") {
                                             `mv $output_dir/RUM_Unique_temp.$suffixold $output_dir/RUM_Unique_temp.$suffixnew`;
                                        }
                                        if(-e "$output_dir/RUM_NU_temp.$suffixold") {
                                             `mv $output_dir/RUM_NU_temp.$suffixold $output_dir/RUM_NU_temp.$suffixnew`;
                                        }
                                        $FILE =~ s/perl $scripts_dir.merge_Bowtie_and_Blat.pl[^\n]+\n[^\n]+\n[^\n]+\n[^\n]+\n[^\n]+\n[^\n]+\n[^\n]+\n[^\n]+\n[^\n]+\n[^\n]+\n//s;
                                 }
                                 if($LOGFILE =~ /finished cleaning up final results/s) {
                                        if(-e "$output_dir/RUM_Unique_temp2.$suffixold") {
                                             `mv $output_dir/RUM_Unique_temp2.$suffixold $output_dir/RUM_Unique_temp2.$suffixnew`;
                                        }
                                        if(-e "$output_dir/RUM_NU_temp.$suffixold") {
                                             `mv $output_dir/RUM_NU_temp2.$suffixold $output_dir/RUM_NU_temp2.$suffixnew`;
                                        }
                                        if(-e "$output_dir/sam_header.$suffixold") {
                                             `mv $output_dir/sam_header.$suffixold $output_dir/sam_header.$suffixnew`;
                                        }
                                        $FILE =~ s/perl $scripts_dir.RUM_finalcleanup.pl[^\n]+\n[^\n]+\n//s;
                                 }
                                 if($LOGFILE =~ /finished sorting NU/s) {
                                        if(-e "$output_dir/RUM_NU_idsorted.$suffixold") {
                                             `mv $output_dir/RUM_NU_idsorted.$suffixold $output_dir/RUM_NU_idsorted.$suffixnew`;
                                        }
                                        $FILE =~ s/perl $scripts_dir.sort_RUM_by_id.pl.*finished sorting NU[^\n]+\n//s;
                                 }
                                 if($LOGFILE =~ /finished removing dups/s) {
                                        if(-e "$output_dir/RUM_NU_temp3.$suffixold") {
                                             `mv $output_dir/RUM_NU_temp3.$suffixold $output_dir/RUM_NU_temp3.$suffixnew`;
                                        }
                                        if($limitNU eq "false") {
                                             if(-e "$output_dir/RUM_NU.$suffixold") {
                                                  `mv $output_dir/RUM_NU.$suffixold $output_dir/RUM_NU.$suffixnew`;
                                             }
                                             $FILE =~ s/perl $scripts_dir.removedups.pl.*finished removing dups[^\n]+\n\n[^\n]+\n//s;
                                        } else {
                                             $FILE =~ s/perl $scripts_dir.removedups.pl.*finished removing dups[^\n]+\n//s;
                                        }
                                 }
                                 if($LOGFILE =~ /finished sorting Unique/s) {
                                        if(-e "$output_dir/RUM_Unique.$suffixold") {
                                             `mv $output_dir/RUM_Unique.$suffixold $output_dir/RUM_Unique.$suffixnew`;
                                        }
                                        $FILE =~ s!perl $scripts_dir/sort_RUM_by_id.pl.*perl $scripts_dir.rum2sam.pl!perl $scripts_dir/rum2sam.pl!s;
                                 }
                                 if($LOGFILE =~ /finished converting to SAM/s) {
                                        if(-e "$output_dir/RUM.sam.$suffixold") {
                                             `mv $output_dir/RUM.sam.$suffixold $output_dir/RUM.sam.$suffixnew`;
                                        }
                                        $FILE =~ s/perl $scripts_dir.rum2sam.pl.*finished converting to SAM[^\n]+\n//s;
                                 }
                                 if($LOGFILE =~ /finished counting the nu mappers/s) {
                                        if(-e "$output_dir/nu_stats.$suffixold") {
                                             `mv $output_dir/nu_stats.$suffixold $output_dir/nu_stats.$suffixnew`;
                                        }
                                        $FILE =~ s/perl $scripts_dir.get_nu_stats.pl.*finished counting the nu mappers[^\n]+\n//s;
                                 }
                                 if($LOGFILE =~ /finished sorting RUM_Unique/s) {
                                        if(-e "$output_dir/RUM_Unique.sorted.$suffixold") {
                                             `mv $output_dir/RUM_Unique.sorted.$suffixold $output_dir/RUM_Unique.sorted.$suffixnew`;
                                        }
                                        if(-e "$output_dir/chr_counts_u.$suffixold") {
                                             `mv $output_dir/chr_counts_u.$suffixold $output_dir/chr_counts_u.$suffixnew`;
                                        }
                                        $FILE =~ s/perl $scripts_dir.sort_RUM_by_location.pl.*finished sorting RUM_Unique[^\n]+\n[^\n]+\n//s;
                                 }
                                 if($LOGFILE =~ /finished sorting RUM_NU/s) {
                                        if(-e "$output_dir/RUM_NU.sorted.$suffixold") {
                                             `mv $output_dir/RUM_NU.sorted.$suffixold $output_dir/RUM_NU.sorted.$suffixnew`;
                                        }
                                        if(-e "$output_dir/chr_counts_nu.$suffixold") {
                                             `mv $output_dir/chr_counts_nu.$suffixold $output_dir/chr_counts_nu.$suffixnew`;
                                        }
                                        $FILE =~ s/perl $scripts_dir.sort_RUM_by_location.pl.*finished sorting RUM_NU[^\n]+\n[^\n]+\n//s;
                                 }
                                 if($LOGFILE =~ /finished quantification/s) {
                                        if(-e "$output_dir/quant.$suffixold" && $strandspecific eq "false") {
                                             `mv $output_dir/quant.$suffixold $output_dir/quant.$suffixnew`;
                                             if(-e "$output_dir/quant.altquant.$suffixold") {
                                                 `mv $output_dir/quant.altquant.$suffixold $output_dir/quant.altquant.$suffixnew`;
                                             }
                                        }
                                        if(-e "$output_dir/quant.ps.$suffixold" && $strandspecific eq "true") {
                                             `mv $output_dir/quant.ps.$suffixold $output_dir/quant.ps.$suffixnew`;
                                             if(-e "$output_dir/quant.ps.altquant.$suffixold") {
                                                   `mv $output_dir/quant.ps.altquant.$suffixold $output_dir/quant.ps.altquant.$suffixnew`;
                                             }
                                        }
                                        if(-e "$output_dir/quant.ms.$suffixold" && $strandspecific eq "true") {
                                             `mv $output_dir/quant.ms.$suffixold $output_dir/quant.ms.$suffixnew`;
                                             if(-e "$output_dir/quant.ms.altquant.$suffixold") {
                                                   `mv $output_dir/quant.ms.altquant.$suffixold $output_dir/quant.ms.altquant.$suffixnew`;
                                             }
                                        }
                                        if(-e "$output_dir/quant.pa.$suffixold" && $strandspecific eq "true") {
                                             `mv $output_dir/quant.pa.$suffixold $output_dir/quant.pa.$suffixnew`;
                                             if(-e "$output_dir/quant.pa.altquant.$suffixold") {
                                                   `mv $output_dir/quant.pa.altquant.$suffixold $output_dir/quant.pa.altquant.$suffixnew`;
                                             }
                                        }
                                        if(-e "$output_dir/quant.ma.$suffixold" && $strandspecific eq "true") {
                                             `mv $output_dir/quant.ma.$suffixold $output_dir/quant.ma.$suffixnew`;
                                             if(-e "$output_dir/quant.ma.altquant.$suffixold") {
                                                   `mv $output_dir/quant.ma.altquant.$suffixold $output_dir/quant.ma.altquant.$suffixnew`;
                                             }
                                        }
                                        $FILE =~ s/perl $scripts_dir.rum2quantifications.pl.*pipeline complete./echo "pipeline complete"/s;
                                 }
                                 open(OUTX, ">$output_dir/$outfile");
                                 print OUTX $FILE;
                                 close(OUTX);
                            }
                            # cache errorlogs and initiate new ones
                            open(OUT, ">>$output_dir/restart_error_log");
                            print OUT "------ chunk $i restarted, here is its error log before it was deleted --------\n";
                            close(OUT);
                            `cat $output_dir/errorlog.$i >> $output_dir/restart_error_log`;
                            `yes|rm $output_dir/errorlog.$i`;
                            open(EOUT, ">$output_dir/errorlog.$i");
                            close(EOUT);

                            $leave_last_chunk_log = "false";
                            if($i == $numchunks) {
                                # this is the post-processing node.  Check if it finished up to the
                                # post-processing, if so then remove that part so as not to repeat it.
                                if($status{$i} == 2) {  # it has finished
                                    $Q = `ps a | grep wait.pl`;
                                    $Q =~ /^\s*(\d+)/;
                                    $PID = $1;
                                    $w = `kill -9 $PID`;
                                    $FILE =~ s/# xxx0.*Postprocessing stuff starts here.../# Postprocessing stuff starts here.../s;
                                    open(OUTFILE, ">$output_dir/$outfile");
                                    print OUTFILE $FILE;
                                    close(OUTFILE);
                                    $restarted{$i}--;
                                    if($restarted{$i} < 1) {
                                        delete $restarted{$i};
                                    }
                                    open(OUT, ">$output_dir/restart.ids");
                                    foreach $key (keys %restarted) {
                                        print OUT "$key\t$restarted{$key}\n";
                                    }
                                    close(OUT);
                                    $leave_last_chunk_log = "true";
                                }
                            }

                            # remove the old files...
                            &deletefiles($output_dir, $J3, $leave_last_chunk_log);

                            sleep(3);
                            $MEM = $ram . "G";
                            $Dflag = 0;
                            if(-e "$output_dir/$rum.log_chunk.$suffixnew") {
                                $Q = `grep "pipeline complete" $output_dir/$rum.log_chunk.$suffixnew`;
                                if($Q =~ /pipeline complete/) {
                                    $Dflag = 1;
                                }
                            }
                            if($Dflag == 0) {
                                if($qsub2 eq "true") {
                                    $Q = `qsub -l mem_free=$MEM,h_vmem=$MEM -o $ofile -e $efile $output_dir/$outfile`;
                                    $Q =~ /Your job (\d+)/;
                                    $jobid{$i} = $1;
                                } else {
                                    $jobid{$i} = spawn("/bin/bash", "$output_dir/$outfile");
                                    
                                }
                            }
                            sleep(3);
                            if($jobid{$i} =~ /^\d+$/ && $Dflag == 0) {
                                  $DATE = `date`;
                                  $DATE =~ s/^\s+//;
                                  $DATE =~ s/\s+$//;
                                  sleep(2);
                                  print ERRORLOG " *** Chunk $i seems to have restarted successfully at $DATE.\n\n";
                                  print " *** OK chunk $i seems to have restarted.\n\n";
                                  $number_consecutive_restarts{$i}=0;
                                  if(-e "$output_dir/$rum.log_chunk.$suffixnew") {
                                       $Q = `grep "pipeline complete" $output_dir/$rum.log_chunk.$suffixnew`;
                                       if($Q =~ /pipeline complete/) {
                                            print ERRORLOG " *** Well, there was really nothing to do, chunk $i seems to have finished.\n\n";
                                            print " *** Well, there was really nothing to do, chunk $i seems to have finished.\n\n";
                                            $doneflag = 1;
                                       }
                                  } else {
                                  }

                            } else {
                                  $number_consecutive_restarts{$i}++;
                                  if($number_consecutive_restarts{$i} > 20) {
                                       print ERRORLOG " *** Hmph, I tried 20 times, I'm going to give up because I'm afraid I'm caught in an infinite loop.  Could be a bug.  If you\ncan't figure it out, write ggrant@pcbi.upenn.edu and let him know.\n\n";
                                       print " *** Hmph, I tried 20 times, I'm going to give up because I'm afraid I'm caught in an infinite loop.  Could be a bug.  If you\ncan't figure it out, write ggrant@pcbi.upenn.edu and let him know.\n\n";
                                       if(-e "$output_dir/kill_command") {
                                           $K = `cat "$output_dir/kill_command"`;
                                           @a = split(/\n/,$K);
                                           $A = $a[0] . "\n";
                                           $R = `$A`;
                                           print "$R\n";
                                           $A = $a[1] . "\n";
                                           $R = `$A`;
                                           print "$R\n";
                                           exit();
                                       }

                                       # I should kill any shell
                                       # scripts running in this
                                       # directory, than any other
                                       # processes running in this
                                       # directory.
                                       kill_runaway_procs($output_dir,
                                                          name => $name,
                                                          starttime => $starttime);
                                        exit(0);
                                  }
                                  print ERRORLOG " *** Hmph, that didn't seem to work.  I'm going to try again in 30 seconds.\nIf this keeps happening then something bigger might be wrong.  If you\ncan't figure it out, write ggrant@pcbi.upenn.edu and let him know.\n\n";
                                  print " *** Hmph, that didn't seem to work.  I'm going to try again in 30 seconds.\nIf this keeps happening then something bigger might be wrong.  If you\ncan't figure it out, write ggrant@pcbi.upenn.edu and let him know.\n\n";
                            }
                      }
                 }
             }
         }
    }


if($postprocess eq "false") {
     print "\nWhew, all chunks have finished.\n\nNext I will merge everything, create the coverage plots and\ncalculate the quantified values, etc.  This could take some time...\n\n";
} else {
     print "\nOK, will now merge everything, create the coverage plots and\ncalculate the quantified values, etc.  This could take some time...\n\n";
}

if($qsub2 eq "true") {
    $efile = $output_dir . "/errorlog.$numchunks";
    open(EFILE, ">>$efile");
    print EFILE "\nPost-Processing Log Starts Here\n";
    close(EFILE);
}

if($nocat eq "false") {
    $date = `date`;
    if(defined $restarted{1}) {
        $R = $restarted{1};
        $x = `cp $output_dir/RUM_Unique.1.$R $output_dir/RUM_Unique`;
        $x = `cp $output_dir/RUM_NU.1.$R $output_dir/RUM_NU`;
    } else {
        $x = `cp $output_dir/RUM_Unique.1 $output_dir/RUM_Unique`;
        $x = `cp $output_dir/RUM_NU.1 $output_dir/RUM_NU`;
    }
    for($i=2; $i<=$numchunks; $i++) {
        if(defined $restarted{$i}) {
            $R = $restarted{$i};
            $x = `cat $output_dir/RUM_Unique.$i.$R >> $output_dir/RUM_Unique`;
            $x = `cat $output_dir/RUM_NU.$i.$R >> $output_dir/RUM_NU`;
        } else {
            $x = `cat $output_dir/RUM_Unique.$i >> $output_dir/RUM_Unique`;
            $x = `cat $output_dir/RUM_NU.$i >> $output_dir/RUM_NU`;
        }
    }
    for($i=1; $i<=$numchunks; $i++) {
       if(defined $restarted{$i}) {
           $R = $restarted{$i};
           if(!(open(SAMHEADER, "$output_dir/sam_header.$i.$R"))) {
              print ERRORLOG "\nERROR: Cannot open '$output_dir/sam_header.$i.$R' for reading.\n\n";
              die "\nERROR: Cannot open '$output_dir/sam_header.$i.$R' for reading.\n\n";
           }
       } else {
           if(!(open(SAMHEADER, "$output_dir/sam_header.$i"))) {
              print ERRORLOG "\nERROR: Cannot open '$output_dir/sam_header.$i' for reading.\n\n";
              die "\nERROR: Cannot open '$output_dir/sam_header.$i' for reading.\n\n";
           }
       }
       while($line = <SAMHEADER>) {
           chomp($line);
           $line =~ /SN:([^\s]+)\s/;
           $samheader{$1}=$line;
       }
       close(SAMHEADER);
    }
    if(!(open(SAMOUT, ">$output_dir/RUM.sam"))) {
        print ERRORLOG "\nERROR: Cannot open '$output_dir/RUM.sam' for writing.\n\n";
        die "\nERROR: Cannot open '$output_dir/RUM.sam' for writing.\n\n";
    }
    foreach $key (sort by_chromosome keys %samheader) {
        $shout = $samheader{$key};
        print SAMOUT "$shout\n";
    }
    close(SAMOUT);
    for($i=1; $i<=$numchunks; $i++) {
       if(defined $restarted{$i}) {
           $R = $restarted{$i};
           $x = `cat $output_dir/RUM.sam.$i.$R >> $output_dir/RUM.sam`;
       } else {
           $x = `cat $output_dir/RUM.sam.$i >> $output_dir/RUM.sam`;
       }
    }
}

print "Finished creating RUM_Unique, RUM_NU and RUM.sam: $date\n";

if($cleanup eq 'true') {
   print "\nCleaning up some temp files...\n\n";
   `yes|rm $output_dir/RUM.sam.* $output_dir/sam_header.*`;
   if($preserve_names eq "true") {
      `yes|rm $output_dir/read_names_mapping.*`;
   }
}

# XXX Need to make a separate shell script now to handle the option -postprocess
#   - not yet implemented..

print "\nStarted postprocessing at $date\n";
print LOGFILE "\nStarted postprocessing at $date\n";

# Write file that wait.pl is watching for, in the shell script for the last chunk.
# Once that is written, wait.pl finishes and the postprocessing will start.

if(!(open(OUTFILE, ">$output_dir/$JID"))) {
    print ERRORLOG "\nERROR: Cannot open '$output_dir/$JID' for writing.\n\n";
    die "\nERROR: Cannot open '$output_dir/$JID' for writing.\n\n";
}
print OUTFILE "$JID\n";
close(OUTFILE);

print "\nWorking, now another wait...\n\n";

$doneflag = 0;

undef %child;

$finished = 0;
$number_consecutive_restarts_pp = 0;
while($doneflag == 0) {
    $doneflag = 1;
    $x = "";
    if (-e "$output_dir/$PPlog") {
	$x = `cat $output_dir/$PPlog`;
	if(!($x =~ /post-processing finished/s)) {
  	    $doneflag = 0;
	}
    } else {
	$doneflag = 0;
    }

# check here for node failure, and restart if necessary


    $DIED = "false";
    if($doneflag == 0) {
        $Jobid = $jobid{$numchunks};

        if($qsub2 eq 'false') {
            for my $CID (child_pids($Jobid)) {
                $child{$CID}++;
            }
        }
        
        foreach $K (keys %child) {
            delete $child{$K} unless can_kill($K);
        }

        if($doneflag == 0) {
           sleep(1);
        }
        if($qsub2 eq 'true') {
             for($t=0; $t<10; $t++) {
                 $X = `qstat -j $Jobid | grep job_number`;
                 if($X =~ /job_number:\s+$Jobid/s) {
                    $t = 10;
                 } else {
                    if($t<=7) {
                        print "Hmm, couldn't get status on job $Jobid, the job might have died, or maybe just the\nstatus failed.  Going to try to get the status again.\n";
                    }
                    if($t==8) {
                        print "Hmm, couldn't get status on job $Jobid, the job might have died, or maybe just the\nstatus failed.  Going to wait 5 minutes and try to get the status again.\n";
                    }
                    sleep(3);
                    if($t == 8) {
                        sleep(300);  # try one last time waiting five minutes
                    }
                 }
             }
        }
        if(-e "$output_dir/$PPlog"){
             $Q = `grep "processing finished" $output_dir/$PPlog`;
             if($Q =~ /processing finished/) {
                $DIED = "false";
                $finished = 1;
             }
        }
        if($finished == 0) {
             if($qsub2 eq "true") {
                 if(!($X =~ /job_number:\s+$Jobid/s)) {
                     $DIED = "true";
                     $X = `qdel $Jobid`;
                   }
             } else {
                 if (my $child_status = check($Jobid)) {
                     $DIED = "true";

                     foreach $CID (keys %child) {
                         $G = `ps a | grep $CID`;
                         $x = `kill -9 $CID`;
#                         print "-------\nKILLED: $CID\n$G\n$x\n-------\n";
                     }
                 }
             }
        }
        if($DIED eq "true") {
            $DATE = `date`;
            $DATE =~ s/^\s+//;
            $DATE =~ s/\s+$//;
            print ERRORLOG "\n *** The post-processing node seems to have failed during post-processing, sometime around $DATE!\nI'm going to try to restart it.\n";
            print "\n *** The post-processing node seems to have failed during post-processing, sometime around $DATE!\nDon't panic, I'm going to try to restart it.\n";

            # check that didn't run out of disk space
            $mcheck = `df -h $output_dir | grep -vi Avai`;
            chomp($mcheck);
            $mcheck =~ s/^\s*//;
            @mc = split(/\s+/,$mcheck);
            $mc[3] =~ /(\d+)/;
            $mfree = $1 + 0;
            if($mfree == 0) {
               print ERRORLOG "\n *** You seem to have run out of disk space: exiting.\n";
               print "\n *** You seem to have run out of disk space: exiting.\n";
               if(-e "$output_dir/kill_command") {
                   $K = `cat "$output_dir/kill_command"`;
                   @a = split(/\n/,$K);
                   $A = $a[0] . "\n";
                   $R = `$A`;
                   print "$R\n";
                   $A = $a[1] . "\n";
                   $R = `$A`;
                   print "$R\n";
                   exit(0);
               }

               kill_runaway_procs($output_dir, 
                                  name => $name, 
                                  starttime => $starttime);
                exit(0);
            }
            $X = `qdel $Jobid`;
            $ofile = $output_dir . "/chunk.restart.$numchunks" . ".o";
            $efile = $output_dir . "/errorlog.restart.$numchunks";
            $outfile = "$name" . "." . $starttime . "." . $numchunks . ".sh";

            # first remove the pre-post-processing stuff from the shell script
            $FILE = `cat $output_dir/$outfile`;
            $FILE =~ s/# xxx0.*Postprocessing stuff starts here.../\n/s;
            $FILE =~ s/perl scripts.wait.pl [^\s]+ \d+[^\n]*//s;

            # futher remove post-processing steps that have finished
            if(-e "$output_dir/$PPlog") {
                $PPlog_contents = `cat $output_dir/$PPlog`;
            } else {
                $PPlog_contents = "";
            }
            $PPlog_contents =~ s/.*Post Processing Restarted At This Point[^\n]*\n//s;

            open(POUT, ">>$output_dir/$PPlog");
            print POUT "------- Post Processing Restarted At This Point ------\n";
            close(POUT);
            if(-e "$output_dir/mapping_stats.txt") {
                $mapping_stats_contents = `cat $output_dir/mapping_stats.txt`;
            } else {
                $mapping_stats_contents = "";
            }
            if($PPlog_contents =~ /merging feature quantifications/s) {
                 $FILE =~ s!^.*merging feature quantifications[^\n]+\n!!s;
                 $FILE =~ s/^[^\n]*\n//s;
            }
            if($PPlog_contents =~ /merging RUM_Unique.sorted files/s) {
                  $FILE =~ s!^.*merging RUM_Unique.sorted files[^\n]+\n!!s;
                  $FILE =~ s/^[^\n]*\n//s;
             }
            if($PPlog_contents =~ /merging RUM_NU.sorted files/s) {
                 $FILE =~ s!^.*merging RUM_NU.sorted files[^\n]+\n!!s;
                 $FILE =~ s/^[^\n]*\n//s;
            }
            if($mapping_stats_contents =~ /RUM_Unique reads per chromosome/s) {
                 $FILE =~ s!^.*RUM_Unique reads per chromosome[^\n]+\n[^\n]+\n!!s;
            }
            if($mapping_stats_contents =~ /RUM_NU reads per chromosome/s) {
                 $FILE =~ s!^.*RUM_NU reads per chromosome[^\n]+\n[^\n]+\n!!s;
            }
            if($PPlog_contents =~ /computing junctions/s) {
                 $FILE =~ s!^.*computing junctions[^\n]+\n!!s;
                 $FILE =~ s/^[^\n]*\n//s;
            }
            if($PPlog_contents =~ /making coverage plots/s) {
                 $FILE =~ s/^.*making coverage plots[^\n]+\n//s;
                 $FILE =~ s/^[^\n]+\n//s;
            }
            if($PPlog_contents =~ /unique mappers coverage plot finished/s) {
                 $FILE =~ s/^.*unique mappers coverage plot finished[^\n]+\n//s;
                 $FILE =~ s/^[^\n]+\n//s;
            }
            if($PPlog_contents =~ /NU mappers coverage plot finished/s) {
                 $FILE =~ s/^.*NU mappers coverage plot finished[^\n]+\n//s;
                 $FILE =~ s/^[^\n]+\n//s;
            }

            open(OUTFILE, ">$output_dir/$outfile");
            print OUTFILE $FILE;
            close(OUTFILE);

            $MEM = $ram . "G";
            if($qsub2 eq "true") {
                 $Q = `qsub -l mem_free=$MEM,h_vmem=$MEM -o $ofile -e $efile $output_dir/$outfile`;
                 $Q =~ /Your job (\d+)/;
                 $jobid{$numchunks} = $1;
            } else {
                $jobid{$numchunks} = spawn("/bin/bash", "$output_dir/$outfile");
            }
            if($FILE =~ /perl/s) {
                 if($jobid{$numchunks} =~ /^\d+$/) {
                       sleep(2);
                       print ERRORLOG " *** OK, post-processing seems to have restarted.\n\n";
                       print " *** OK, post-processing seems to have restarted.\n\n";
                 } else {
                       $number_consecutive_restarts_pp++;
                       if($number_consecutive_restarts_pp > 20) {
                           print ERRORLOG " *** Hmph, I tried 20 times, I'm going to give up because I'm afraid I'm caught in an infinite loop.  Could be a bug.  If you\ncan't figure it out, write ggrant@pcbi.upenn.edu and let him know.\n\n";
                           print " *** Hmph, I tried 20 times, I'm going to give up because I'm afraid I'm caught in an infinite loop.  Could be a bug.  If you\ncan't figure it out, write ggrant@pcbi.upenn.edu and let him know.\n\n";
                           if(-e "$output_dir/kill_command") {
                                $K = `cat "$output_dir/kill_command"`;
                                @a = split(/\n/,$K);
                                $A = $a[0] . "\n";
                                $R = `$A`;
                                print "$R\n";
                                $A = $a[1] . "\n";
                                $R = `$A`;
                                print "$R\n";
                                exit();
                            }
                            $outdir = $output_dir;
                            $str = `ps a | grep $outdir`;
                           # Same, first any shell scripts, then any proces
                           kill_runaway_procs($output_dir,
                                              name => $name, 
                                              starttime => $starttime);
                           exit(0);
                       }

                       print ERRORLOG " *** Hmph, that didn't seem to work.  I'm going to try again in 30 seconds.\nIf this keeps happening then something bigger might be wrong.  If you\ncan't figure it out, write ggrant@pcbi.upenn.edu and let him know.\n\n";
                       print " *** Hmph, that didn't seem to work.  I'm going to try again in 30 seconds.\nIf this keeps happening then something bigger might be wrong.  If you\ncan't figure it out, write ggrant@pcbi.upenn.edu and let him know.\n\n";
                 }
            } else {
                  print ERRORLOG " *** OK, post-processing seems to have restarted, there wasn't anything left to do though.\n\n";
                  print " *** OK, post-processing seems to have restarted, there wasn't anything left to do though.\n\n";
            }
        }
   }
}

$ufpfile = `cat $output_dir/u_footprint.txt`;
chomp($ufpfile);
$ufpfile =~ /(\d+)$/;
$uf = $1;
$nufpfile = `cat $output_dir/nu_footprint.txt`;
chomp($nufpfile);
$nufpfile =~ /(\d+)$/;
$nuf = $1;
$UF = &format_large_int($uf);
$NUF = &format_large_int($nuf);

$UFp = int($uf / $genome_size * 10000) / 100;
$NUFp = int($nuf / $genome_size * 10000) / 100;

$gs4 = &format_large_int($genome_size);
print LOGFILE "genome size: $gs4\n";
print LOGFILE "number of bases covered by unique mappers: $UF ($UFp%)\n";
print LOGFILE "number of bases covered by non-unique mappers: $NUF ($NUFp%)\n\n";

open(INFILE, "$output_dir/mapping_stats.txt");
$newfile = "";
while($line = <INFILE>) {
   chomp($line);
   if($line =~ /chr_name/) {
      next;
   }
   if($line =~ /RUM_Unique reads per chromosome/) {
      $newfile = $newfile . "genome size: $gs4\n";
      $newfile = $newfile . "number of bases covered by unique mappers: $UF ($UFp%)\n";
      $newfile = $newfile . "number of bases covered by non-unique mappers: $NUF ($NUFp%)\n\n";
   }
   $newfile = $newfile . "$line\n";
}
close(INFILE);
open(OUTFILE, ">$output_dir/mapping_stats.txt");
print OUTFILE $newfile;
close(OUTFILE);

# Check RUM_Unique and RUM_Unique.sorted are the same size
$filesize1 = -s "$output_dir/RUM_Unique";
$filesize2 = -s "$output_dir/RUM_Unique.sorted";
if($filesize1 != $filesize2) {
    print ERRORLOG "ERROR: RUM_Unique and RUM_Unique.sorted are not the same size.  This probably indicates a problem.\n";
    print "ERROR: RUM_Unique and RUM_Unique.sorted are not the same size.  This probably indicates a problem.\n";
}

# Check RUM_NU and RUM_NU.sorted are the same size
$filesize1 = -s "$output_dir/RUM_NU";
$filesize2 = -s "$output_dir/RUM_NU.sorted";
if($filesize1 != $filesize2) {
    print ERRORLOG "ERROR: RUM_NU and RUM_NU.sorted are not the same size.  This could indicates a problem.\n";
    print "ERROR: RUM_NU and RUM_NU.sorted are not the same size.  This could indicates a problem.\n";
}

# XXX   More error checks to implement:
#
# Find last chr in RUM_Unique and RUM_NU.
# Make sure thr right one of those last chrs is the last chr in RUM.sam.
# Make sure that last chr is the last chr in RUM_Unique.cov and RUM_NU.cov.
# If any of these fail, report them to ERRORLOG.

$check_if_any_errors_already_reported = `grep -i error $output_dir/rum.error-log`;
if(!($check_if_any_errors_already_reported =~ /\S/)) {
   $noerrors = "true";
} else {
   $noerrors = "false";
}

if($qsub2 eq "false") {
    $E = `cat $output_dir/PostProcessing-errorlog`;
    $E =~ s/^\s*//s;
    $E =~ s/\s*$//s;
} else {
    if(-e "$output_dir/errorlog.restart.$numchunks") {
        $E1 = `cat $output_dir/errorlog.$numchunks`;
        $E1 =~ s/^.*Post-Processing Log Starts Here//s;
        $E = `cat $output_dir/errorlog.restart.$numchunks`;
        $E =~ s/^.*Post-Processing Log Starts Here//s;
        $E = $E1 . "\n" . $E;
    } else {
        $E = `cat $output_dir/errorlog.$numchunks`;
        $E =~ s/^.*Post-Processing Log Starts Here//s;
    }
}
if($E =~ /\S/) {
    print ERRORLOG "\n------- Post Processing Errors -------\n";
    $E =~ s/stdin: is not a tty[^\n]*\n//sg;
    print ERRORLOG "$E\n";
    $noerrors = "false";
}
for($i=1; $i<=$numchunks; $i++) {
    $E = `cat $output_dir/errorlog.$i`;
    $E =~ s/# reads[^\n]+\n//sg;
    $E =~ s/Reported \d+ [^\n]+\n//sg;
    $E =~ s/stdin: is not a tty[^\n]*\n//sg;
    $E =~ s/^\s*//s;
    $E =~ s/\s*$//s;
    if($qsub2 eq "true") {
        $E =~ s/Post-Processing Log Starts Here.*$//s;
        if(-e "$output_dir/errorlog.restart.$i") {
            $E1 = `cat $output_dir/errorlog.restart.$i`;
            $E1 =~ s/Post-Processing Log Starts Here.*$//s;
            $E1 =~ s/# reads[^\n]+\n//sg;
            $E1 =~ s/Reported \d+ [^\n]+\n//sg;
            $E = $E1 . "\n" . $E;
        }
    }
    if($E =~ /\S/) {
       $E =~ s/stdin: is not a tty[^\n]*\n//sg;
       if($E =~ /\S/) {
             print ERRORLOG "\n------- errors from chunk $i -------\n";
             print ERRORLOG "$E\n";
             $noerrors = "false";
       }
    }
   `yes|rm $output_dir/errorlog.$i`;
    if(defined $restarted{$i}) {
        $R = $restarted{$i};
        $E = `grep \"$output_dir\" $output_dir/rum.log_chunk.$i.$R | grep -v finished`;
    } else {
        $E = `grep \"$output_dir\" $output_dir/rum.log_chunk.$i | grep -v finished`;
    }
    $E =~ s/^\s*//s;
    $E =~ s/\s*$//s;
    @a = split(/\n/,$E);
    $flag = 0;
    for($j=0; $j<@a; $j++) {
        @b = split(/\s+/,$a[$j]);
        if($b[4] == 0) {
            $file = $b[@b-1];
            if($flag == 0) {
                print ERRORLOG "\n";
                $flag = 1;
            }
            print ERRORLOG "WARNING: temp file '$file' had size zero.\n  *  Could be no mappers in that step, but this often indicates an error.\n";
            $noerrors = "false";
        }
    }
}
$T1 = `tail $output_dir/RUM_Unique`;
if(!($T1 =~ /\n$/)) {
     print ERRORLOG "ERROR: RUM_Unique does not end with a newline, that probably means it is incomplete.\n";
     print "ERROR: RUM_Unique does not end with a newline, that probably means it is incomplete.\n";
    $noerrors = "false";
}
$T1 = `tail $output_dir/RUM_NU`;
if(!($T1 =~ /\n$/)) {
     print ERRORLOG "ERROR: RUM_NU does not end with a newline, that probably means it is incomplete.\n";
     print "ERROR: RUM_NU does not end with a newline, that probably means it is incomplete.\n";
    $noerrors = "false";
}
$T1 = `tail $output_dir/RUM_Unique.sorted`;
if(!($T1 =~ /\n$/)) {
     print ERRORLOG "ERROR: RUM_Unique.sorted does not end with a newline, that probably means it is incomplete.\n";
     print "ERROR: RUM_Unique.sorted does not end with a newline, that probably means it is incomplete.\n";
    $noerrors = "false";
}
$T1 = `tail $output_dir/RUM_NU.sorted`;
if(!($T1 =~ /\n$/)) {
     print ERRORLOG "ERROR: RUM_NU.sorted does not end with a newline, that probably means it is incomplete.\n";
     print "ERROR: RUM_NU.sorted does not end with a newline, that probably means it is incomplete.\n";
    $noerrors = "false";
}
$T1 = `tail $output_dir/RUM_Unique.cov`;
if(!($T1 =~ /\n$/)) {
     print ERRORLOG "ERROR: RUM_Unique.cov does not end with a newline, that probably means it is incomplete.\n";
     print "ERROR: RUM_Unique.cov does not end with a newline, that probably means it is incomplete.\n";
    $noerrors = "false";
}
$T1 = `tail $output_dir/RUM_NU.cov`;
if(!($T1 =~ /\n$/)) {
     print ERRORLOG "ERROR: RUM_NU.cov does not end with a newline, that probably means it is incomplete.\n";
     print "ERROR: RUM_NU.cov does not end with a newline, that probably means it is incomplete.\n";
    $noerrors = "false";
}
$T1 = `tail $output_dir/RUM.sam`;
if(!($T1 =~ /\n$/)) {
     print ERRORLOG "ERROR: RUM.sam does not end with a newline, that probably means it is incomplete.\n";
     print "ERROR: RUM.sam does not end with a newline, that probably means it is incomplete.\n";
    $noerrors = "false";
}
if($quantify eq "true") {
     $T1 = `tail $output_dir/feature_quantifications_$name`;
     if(!($T1 =~ /\n$/)) {
          print ERRORLOG "ERROR: feature_quantifications_$name does not end with a newline, that probably means it is incomplete.\n";
          print "ERROR: feature_quantifications_$name does not end with a newline, that probably means it is incomplete.\n";
         $noerrors = "false";
     }
}
if($junctions eq "true") {
     $T1 = `tail $output_dir/junctions_all.rum`;
     if(!($T1 =~ /\n$/)) {
          print ERRORLOG "ERROR: junctions_all.rum does not end with a newline, that probably means it is incomplete.\n";
          print "ERROR: junctions_all.rum does not end with a newline, that probably means it is incomplete.\n";
         $noerrors = "false";
     }
     $T1 = `tail $output_dir/junctions_all.bed`;
     if(!($T1 =~ /\n$/)) {
          print ERRORLOG "ERROR: junctions_all.bed does not end with a newline, that probably means it is incomplete.\n";
          print "ERROR: junctions_all.bed does not end with a newline, that probably means it is incomplete.\n";
         $noerrors = "false";
     }
     $T1 = `tail $output_dir/junctions_high-quality.bed`;
     if(!($T1 =~ /\n$/)) {
          print ERRORLOG "ERROR: junctions_high-quality.bed does not end with a newline, that probably means it is incomplete.\n";
          print "ERROR: junctions_high-quality.bed does not end with a newline, that probably means it is incomplete.\n";
         $noerrors = "false";
     }
}

if($noerrors eq "true") {
    print ERRORLOG "\nNo Errors. Very good!\n\n";
}
print ERRORLOG "--------------------------------------\n";

if($cleanup eq 'true') {
   print "\nCleaning up some more temp files...\n\n";
   if(-e "$output_dir/u_footprint.txt") {
      `yes|rm $output_dir/u_footprint.txt`;
   }
   if(-e "$output_dir/nu_footprint.txt") {
      `yes|rm $output_dir/nu_footprint.txt`;
   }
   if(-e "$output_dir/kill_command") {
      `yes|rm $output_dir/kill_command`;
   }
   if(-e "$output_dir/novel_exon_quant_temp") {
       `yes|rm $output_dir/novel_exon_quant_temp`;
   }
   for($i=1; $i<=$numchunks; $i++) {
      if(defined $restarted{$i}) {
         $ext = ".$restarted{$i}";
      } else {
         $ext = "";
      }
      `yes|rm $output_dir/RUM_Unique.$i$ext $output_dir/RUM_NU.$i$ext`;
      `yes|rm $output_dir/RUM_Unique.sorted.$i$ext $output_dir/RUM_NU.sorted.$i$ext`;
      `yes|rm $output_dir/reads.fa.$i$ext`;
      `yes|rm $output_dir/quals.fa.$i$ext`;
      `yes|rm $output_dir/nu_stats.$i$ext`;
   }
   `yes|rm $output_dir/chr_counts*`;
   `yes|rm $output_dir/quant.*`;
   `yes|rm $output_dir/$name.*`;
   if($strandspecific eq 'true') {
      `yes|rm $output_dir/feature_quantifications.ps`;
      `yes|rm $output_dir/feature_quantifications.ms`;
      `yes|rm $output_dir/feature_quantifications.pa`;
      `yes|rm $output_dir/feature_quantifications.ma`;
      if(-e "$output_dir/feature_quantifications.altquant.ps") {
         `yes|rm $output_dir/feature_quantifications.altquant.ps`;
         `yes|rm $output_dir/feature_quantifications.altquant.ms`;
         `yes|rm $output_dir/feature_quantifications.altquant.pa`;
         `yes|rm $output_dir/feature_quantifications.altquant.ma`;
      }

   }
   `yes|rm $output_dir/$JID`;
}

print "\nOkay, all finished.\n\n";

$date = `date`;
print LOGFILE "pipeline finished: $date\n";
close(LOGFILE);
close(ERRORLOG);

sub breakup_file () {
    ($FILE, $numpieces) = @_;

    if(!(open(INFILE, $FILE))) {
       print ERRORLOG "\nERROR: Cannot open '$FILE' for reading.\n\n";
       die "\nERROR: Cannot open '$FILE' for reading.\n\n";
    }
    $tail = `tail -2 $FILE | head -1`;
    $tail =~ /seq.(\d+)/s;
    $numseqs = $1;
    $piecesize = int($numseqs / $numpieces);

    $t = `tail -2 $FILE`;
    $t =~ /seq.(\d+)/s;
    $NS = $1;
    $piecesize2 = &format_large_int($piecesize);
    if(!($FILE =~ /qual/)) {
	if($numchunks > 1) {
	    print LOGFILE "processing in $numchunks pieces of approx $piecesize2 reads each\n";
	} else {
	    $NS2 = &format_large_int($NS);
	    print LOGFILE "processing in one piece of $NS2 reads\n";
	}
    }
    if($piecesize % 2 == 1) {
	$piecesize++;
    }
    $bflag = 0;

    $F2 = $FILE;
    $F2 =~ s!.*/!!;

    if($paired_end eq 'true') {
	$PS = $piecesize * 2;
    } else {
	$PS = $piecesize;
    }

    for($i=1; $i<$numpieces; $i++) {
	$outfilename = $output_dir . "/" . $F2 . "." . $i;

	open(OUTFILE, ">$outfilename");
	for($j=0; $j<$PS; $j++) {
	    $line = <INFILE>;
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
    $outfilename = $output_dir . "/" . $F2 . "." . $numpieces;

    open(OUTFILE, ">$outfilename");
    while($line = <INFILE>) {
	print OUTFILE $line;
    }
    close(OUTFILE);
    return 0;
}

sub merge() {
    $tempfilename1 = $CHR[$cnt] . "_temp.0";
    $tempfilename2 = $CHR[$cnt] . "_temp.1";
    $tempfilename3 = $CHR[$cnt] . "_temp.2";
    open(TEMPMERGEDOUT, ">$tempfilename3");
    open(TEMPIN1, $tempfilename1);
    open(TEMPIN2, $tempfilename2);
    $mergeFLAG = 0;
    getNext1();
    getNext2();
    while($mergeFLAG < 2) {
	chomp($out1);
	chomp($out2);
	if($start1 < $start2) {
	    if($out1 =~ /\S/) {
		print TEMPMERGEDOUT "$out1\n";
	    }
	    getNext1();
	} elsif($start1 == $start2) {
	    if($end1 <= $end2) {
		if($out1 =~ /\S/) {
		    print TEMPMERGEDOUT "$out1\n";
		}
		getNext1();
	    } else {
		if($out2 =~ /\S/) {
		    print TEMPMERGEDOUT "$out2\n";
		}
		getNext2();
	    }
	} else {
	    if($out2 =~ /\S/) {
		print TEMPMERGEDOUT "$out2\n";
	    }
	    getNext2();
	}
    }
    close(TEMPMERGEDOUT);
    `mv $tempfilename3 $tempfilename1`;
    unlink($tempfilename2);
}

sub getNext1 () {
    $line1 = <TEMPIN1>;
    chomp($line1);
    if($line1 eq '') {
	$mergeFLAG++;
	$start1 = 1000000000000;  # effectively infinity, no chromosome should be this large;
	return "";
    }
    @a = split(/\t/,$line1);
    $a[2] =~ /^(\d+)-/;
    $start1 = $1;
    if($a[0] =~ /a/ && $separate eq "false") {
	$a[0] =~ /(\d+)/;
	$seqnum1 = $1;
	$line2 = <TEMPIN1>;
	chomp($line2);
	@b = split(/\t/,$line2);
	$b[0] =~ /(\d+)/;
	$seqnum2 = $1;
	if($seqnum1 == $seqnum2 && $b[0] =~ /b/) {
	    if($a[3] eq "+") {
		$b[2] =~ /-(\d+)$/;
		$end1 = $1;
	    } else {
		$b[2] =~ /^(\d+)-/;
		$start1 = $1;
		$a[2] =~ /-(\d+)$/;
		$end1 = $1;
	    }
	    $out1 = $line1 . "\n" . $line2;
	} else {
	    $a[2] =~ /-(\d+)$/;
	    $end1 = $1;
	    # reset the file handle so the last line read will be read again
	    $len = -1 * (1 + length($line2));
	    seek(TEMPIN1, $len, 1);
	    $out1 = $line1;
	}
    } else {
	$a[2] =~ /-(\d+)$/;
	$end1 = $1;
	$out1 = $line1;
    }
}

sub getNext2 () {
    $line1 = <TEMPIN2>;
    chomp($line1);
    if($line1 eq '') {
	$mergeFLAG++;
	$start2 = 1000000000000;  # effectively infinity, no chromosome should be this large;
	return "";
    }
    @a = split(/\t/,$line1);
    $a[2] =~ /^(\d+)-/;
    $start2 = $1;
    if($a[0] =~ /a/ && $separate eq "false") {
	$a[0] =~ /(\d+)/;
	$seqnum1 = $1;
	$line2 = <TEMPIN2>;
	chomp($line2);
	@b = split(/\t/,$line2);
	$b[0] =~ /(\d+)/;
	$seqnum2 = $1;
	if($seqnum1 == $seqnum2 && $b[0] =~ /b/) {
	    if($a[3] eq "+") {
		$b[2] =~ /-(\d+)$/;
		$end2 = $1;
	    } else {
		$b[2] =~ /^(\d+)-/;
		$start2 = $1;
		$a[2] =~ /-(\d+)$/;
		$end2 = $1;
	    }
	    $out2 = $line1 . "\n" . $line2;
	} else {
	    $a[2] =~ /-(\d+)$/;
	    $end2 = $1;
	    # reset the file handle so the last line read will be read again
	    $len = -1 * (1 + length($line2));
	    seek(TEMPIN2, $len, 1);
	    $out2 = $line1;
	}
    } else {
	$a[2] =~ /-(\d+)$/;
	$end2 = $1;
	$out2 = $line1;
    }
}


sub deletefiles () {
    ($dir, $suffix, $leave_last_log) = @_;

    $dir =~ s!/$!!;
    $suffix =~ s/^\.//;

    $file[0] = "BlatNU.XXX";
    $file[1] = "BlatUnique.XXX";
    $file[2] = "BowtieNU.XXX";
    $file[3] = "BowtieUnique.XXX";
    $file[4] = "chr_counts_nu.XXX";
    $file[5] = "chr_counts_u.XXX";
    $file[6] = "CNU.XXX";
    $file[7] = "GNU.XXX";
    $file[8] = "GU.XXX";
    $file[9] = "quant.XXX";
    $file[10] = "R.XXX";
    $file[11] = "R.mdust.XXX";
    $file[12] = "rum.log_chunk.XXX";
    $file[13] = "RUM_NU.XXX";
    $file[14] = "RUM_NU_idsorted.XXX";
    $file[15] = "RUM_NU.sorted.XXX";
    $file[16] = "RUM_NU_temp.XXX";
    $file[17] = "RUM_NU_temp2.XXX";
    $file[18] = "RUM_NU_temp3.XXX";
    $file[19] = "RUM.sam.XXX";
    $file[20] = "R.XXX.blat";
    $file[21] = "RUM_Unique.XXX";
    $file[22] = "RUM_Unique.sorted.XXX";
    $file[23] = "RUM_Unique_temp.XXX";
    $file[24] = "RUM_Unique_temp2.XXX";
    $file[25] = "sam_header.XXX";
    $file[26] = "TNU.XXX";
    $file[27] = "TU.XXX";
    $file[28] = "X.XXX";
    $file[29] = "Y.XXX";
    $file[30] = "nu_stats.XXX";
    $file[31] = "quant.ps.XXX";
    $file[32] = "quant.ms.XXX";
    $file[33] = "quant.pa.XXX";
    $file[34] = "quant.ma.XXX";

    for($i_d=0; $i_d<@file; $i_d++) {
	if($i_d == 12 && $leave_last_log eq "true") {
	    next;
	}
	$F = $dir . "/" . $file[$i_d];
	$F =~ s/XXX/$suffix/;
	if(-e $F) {
	    `yes|rm $F`;
	}
    }
    return "";
}

