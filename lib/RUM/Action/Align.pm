package RUM::Action::Align;

use strict;
use warnings;
use autodie;

use Getopt::Long qw(:config pass_through);
use File::Path qw(mkpath);
use Text::Wrap qw(wrap fill);
use Carp;
use Data::Dumper;

use RUM::Action::Clean;

use RUM::Logging;
use RUM::Workflows;
use RUM::Usage;
use RUM::Pipeline;
use RUM::Common qw(format_large_int min_match_length);
use RUM::Lock;
use RUM::JobReport;
use RUM::SystemCheck;

use base 'RUM::Action';

our $log = RUM::Logging->get_logger;
our $LOGO;

$SIG{INT} = $SIG{TERM} = sub {
    my $msg = "Caught SIGTERM, removing lock.";
    warn $msg;
    $log->info($msg);
    RUM::Lock->release;
    exit 1;
};

sub new { shift->SUPER::new(name => 'align', @_) }

sub run {
    my ($class) = @_;
    my $self = $class->new;

    # Parse the command line and construct a RUM::Config
    my $c = $self->make_config;

    $self->check_config;
    $self->check_deps;

    RUM::SystemCheck::check_gamma(
        config => $c);

    $self->setup;
    $self->get_lock;
    $self->show_logo;
    
    my $platform_name = $c->platform;
    my $local = $platform_name =~ /Local/;
    
    if ($local) {
        RUM::SystemCheck::check_ram(
            config => $c,
            say => sub { $self->logsay(@_) });
    }
    else {
        $self->say(
            "You are running this job on a $platform_name cluster. ",
            "I am going to assume each node has sufficient RAM for this. ",
            "If you are running a mammalian genome then you should have at ",
            "least 6 Gigs per node");
    }

    $self->config->save unless $c->child;
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



sub make_config {
    my ($self) = @_;

    my $usage = RUM::Usage->new('action' => 'align');
    warn "In make_config\n";
    my $config = RUM::Config->new->from_command_line;

    my @reads;
    while (local $_ = shift @ARGV) {
        if (/^-/) {
            $usage->bad("Unrecognized option $_");
        }
        else {
            push @reads, File::Spec->rel2abs($_);
        }
    }

    warn "I got reads @reads\n";
    if (@reads) {
        $config->set('reads', [@reads]);
    }

    if ($config->lock_file) {
        $log->info("Got lock_file argument (" .
                   $config->lock_file . ")");
        $RUM::Lock::FILE = $config->lock_file;
    }


    $usage->check;
    return $self->{config} = $config;
}


sub check_config {
    my ($self, $action) = @_;

    my $usage = RUM::Usage->new(action => $action);

    my $c = $self->config;
    $c->output_dir or $usage->bad(
        "Please specify an output directory with --output or -o");
    
    # Job name
    if ($c->name) {
        length($c->name) <= 250 or $usage->bad(
            "The name must be less than 250 characters");
        $c->set('name', fix_name($c->name));
    }
    else {
        $usage->bad("Please specify a name with --name");
    }

    $c->index_dir or $usage->bad(
        "Please specify a rum index directory with --index-dir or -i");
    $c->load_rum_config_file if $c->index_dir;

    my $reads = $c->reads;

    if ($reads) {
        @$reads == 1 || @$reads == 2 or $usage->bad(
            "Please provide one or two read files. You provided " .
            join(", ", @$reads));
    }
    else {
        $usage->bad("Please provide one or two read files.");
    }


    if ($reads && @$reads == 2) {
        $reads->[0] ne $reads->[1] or $usage->bad(
        "You specified the same file for the forward and reverse reads, ".
            "must be an error");

        $c->max_insertions <= 1 or $usage->bad(
            "For paired-end data, you cannot set --max-insertions-per-read".
                " to be greater than 1.");
    }

    if (defined($c->user_quals)) {
        $c->quals_file =~ /\// or $usage->bad(
            "do not specify -quals file with a full path, ".
                "put it in the '". $c->output_dir."' directory.");
    }

    $c->min_identity =~ /^\d+$/ && $c->min_identity <= 100 or $usage->bad(
        "--min-identity must be an integer between zero and 100. You
        have given '".$c->min_identity."'.");


    if (defined($c->min_length)) {
        $c->min_length =~ /^\d+$/ && $c->min_length >= 10 or $usage->bad(
            "--min-length must be an integer >= 10. You have given '".
                $c->min_length."'.");
    }
    
    if (defined($c->nu_limit)) {
        $c->nu_limit =~ /^\d+$/ && $c->nu_limit > 0 or $usage->bad(
            "--limit-nu must be an integer greater than zero. You have given '".
                $c->nu_limit."'.");
    }

    $c->preserve_names && $c->variable_length_reads and $usage->bad(
        "Cannot use both --preserve-names and --variable-read-lengths at ".
            "the same time. Sorry, we will fix this eventually.");

    local $_ = $c->blat_min_identity;
    /^\d+$/ && $_ <= 100 or $usage->bad(
        "--blat-min-identity or --minIdentity must be an integer between ".
            "0 and 100.");

    $c->chunks or $usage->bad(
        "Please tell me how many chunks to split the input into with the "
        . "--chunks option.");

    $usage->check;
    
    if ($c->alt_genes) {
        -r $c->alt_genes or die
            "Can't read from alt gene file ".$c->alt_genes.": $!";
    }

    if ($c->alt_quant_model) {
        -r $c->alt_quant_model or die
            "Can't read from ".$c->alt_quant_model.": $!";
    }

    # If we haven't yet split the input file, make sure that the raw
    # read files exist.
    if ( ! -r $c->preprocessed_reads ) {
        for my $fname (@{ $reads || [] }) {
            -r $fname or die "Can't read from read file $fname";
        }
    }
}

sub check_deps {

    my ($self) = @_;
    local $_;
    my $deps = RUM::BinDeps->new;
    my @deps = ($deps->bowtie, $deps->blat, $deps->mdust);
    my @missing;
    for (@deps) {
        -x or push @missing, $_;
    }
    my $dependency_doesnt = @missing == 1 ? "dependency doesn't" : "dependencies don't";
    my $it = @missing == 1 ? "it" : "them";

    if (@missing) {
        die(
            "The following binary $dependency_doesnt exist:\n\n" .
            join("", map(" * $_\n", @missing)) .
            "\n" . 
            "Please install $it by running \"perl Makefile.PL\"\n");
    }
}

sub get_lock {
    my ($self) = @_;
    my $c = $self->config;
    return if $c->parent || $c->child;

    my $dir = $c->output_dir;
    my $lock = $c->lock_file;
    $log->info("Acquiring lock");
    RUM::Lock->acquire($lock) or die
          "It seems like rum_runner may already be running in $dir. You can try running \"$0 kill\" to stop it. If you #are sure there's nothing running in $dir, remove $lock and try again.\n";
}

sub setup {
    my ($self) = @_;
    my $output_dir = $self->config->output_dir;
    my $c = $self->config;
    my @dirs = (
        $c->output_dir,
        $c->output_dir . "/.rum",
        $c->chunk_dir
    );
    for my $dir (@dirs) {
        unless (-d $dir) {
            mkpath($dir) or die "mkdir $dir: $!";
        }
    }
}

sub show_logo {
    my ($self) = @_;
    my $msg = <<EOF;

RUM Version $RUM::Pipeline::VERSION

$LOGO
EOF
#    $self->say($msg);

}

sub fix_name {
    local $_ = shift;

    my $name_o = $_;
    s/\s+/_/g;
    s/^[^a-zA-Z0-9_.-]//;
    s/[^a-zA-Z0-9_.-]$//g;
    s/[^a-zA-Z0-9_.-]/_/g;
    
    return $_;
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

sub changed_settings_msg {
    my ($self, $filename) = @_;
    my $msg = <<"EOF";

I found job settings in $filename, but you specified different
settings on the command line. Changing the settings on a job that has
already been partially run can result in unexpected behavior. If you
want to use the saved settings, please don't provide any extra options
on the command line, other than options that specify a specific phase
or chunk (--preprocess, --process, --postprocess, --chunk). If you
want to start the job over from scratch, you can do so by deleting the
settings file ($filename). If you really want to change the settings,
you can add a --force flag and try again.

EOF
    return fill('', '', $msg) . "\n";
    
}

__END__

=head1 NAME

RUM::Action::Align - Align reads using the RUM Pipeline.

=head1 DESCRIPTION

This action is the one that actually runs the RUM Pipeline.

=head1 CONSTRUCTOR

=over 4

=item RUM::Action::Align->new

=back

=head1 METHODS

=over 4

=item run

The top-level function in this class. Parses the command-line options,
checks the configuration and warns the user if it's invalid, does some
setup tasks, then runs the pipeline.

=item get_options

Parse @ARGV and build a RUM::Config from it. Also set some flags in
$self->{directives} based on some boolean options.

=item check_deps

=item check_config

Check my RUM::Config for errors. Calls RUM::Usage->bad (which exits)
if there are any errors.

=item check_deps

Check to make sure the dependencies (bowtie, blat, mdust) exist,
and die with an error message if they don't.

=item available_ram

Attempt to figure out how much ram is available, and return it.

=item get_lock

Attempts to get a lock on the $output_dir/.rum/lock file. Dies with a
warning message if the lock is held by someone else. Otherwise returns
normally, and RUM::Lock::FILE will be set to the filename.

=item setup

Creates the output directory and .rum subdirectory.

=item show_logo

Print out the RUM logo.

=item fix_name

Remove unwanted characters from the name.

=item check_gamma

Die if we seem to be running on gamma.

=item check_ram

Make sure there seems to be enough ram, based on the size of the
genome.

=item prompt_not_enough_ram

Prompt the user to ask if we should proceed even though there doesn't
seem to be enough RAM per chunk. Exits if the user doesn't say yes.

=item changed_settings_msg

Return a message indicating that the user changed some settings.

=back

=head1 AUTHORS

Gregory Grant (ggrant@grant.org)

Mike DeLaurentis (delaurentis@gmail.com)

=head1 COPYRIGHT

Copyright 2012, University of Pennsylvania
