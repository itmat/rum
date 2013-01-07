package RUM::Property;

use strict;
use warnings;

use Data::Dumper;

use RUM::Usage;
use RUM::UsageErrors;
use Carp;
use RUM::Pipeline;

sub handle {
    my ($conf, $opt, $val) = @_;
    $opt =~ s/-/_/g;
    $conf->set($opt, $val);
}

sub new {
    my ($class, %params) = @_;

    my $self = {};
    $self->{opt}       = delete $params{opt}     or croak "Need opt";
    $self->{desc}      = delete $params{desc};
    $self->{filter}    = delete $params{filter}  || sub { shift };
    $self->{handler}   = delete $params{handler} || \&handle;
    $self->{checker}   = delete $params{check}   || sub { return };
    $self->{default}   = delete $params{default};
    $self->{transient} = delete $params{transient};
    $self->{group}     = delete $params{group};

    if (my @extra = keys %params) {
        croak "Extra keys to RUM::Config->new: @extra";
    }

    $self->{name} = $self->{opt};
    $self->{name} =~ s/[=!|].*//;
    $self->{name} =~ s/-/_/g;

    return bless $self, $class;
}


sub opt { shift->{opt} }
sub handler { shift->{handler} }
sub name { shift->{name} }
sub desc { shift->{desc} }
sub filter { shift->{filter} }
sub checker { shift->{checker} }
sub default { shift->{default} }
sub transient { shift->{transient} }

package RUM::Config;

use strict;
use warnings;

use POSIX qw(ceil);
use Carp;
use FindBin qw($Bin);
use File::Spec;
use File::Path qw(mkpath);
use Data::Dumper;
use Scalar::Util qw(blessed);
use Cwd qw(realpath);

use Getopt::Long;
use RUM::Logging;
use RUM::ConfigFile;
use RUM::Pipeline;

our $AUTOLOAD;
our $log = RUM::Logging->get_logger;
FindBin->again;

our $FILENAME = "rum_job_config";


my $DEFAULT = RUM::Config->new;

our %DEFAULTS = (


    # These properties are actually set by the user

    alt_quant_model       => undef,
    alt_quant             => undef,

    count_mismatches      => undef,

    # These are derived from the user-provided properties, and saved
    # to the rum_job_config file

    ram_ok                => undef,
    input_needs_splitting => undef,
    input_is_preformatted => undef,
    paired_end            => undef,

);

sub is_top_level {
    my ($self) = @_;
    return  ! ($self->parent || $self->child);
}

sub should_preprocess {
    my $self = shift;
    return $self->preprocess || (!$self->chunk && 
                                 !$self->process && 
                                 !$self->postprocess);
}

sub should_process {
    my $self = shift;
    return $self->process || $self->chunk || (!$self->preprocess && 
                                              !$self->postprocess);
}


sub should_postprocess {
    my $self = shift;
    return $self->postprocess || (!$self->chunk &&
                                  !$self->preprocess && 
                                  !$self->process);
}

my %PROPERTIES;

sub _add_prop {
    my (%params) = @_;
    my $prop = RUM::Property->new(%params);
    $PROPERTIES{$prop->name} = $prop;
}

sub make_absolute {
    return File::Spec->rel2abs(shift);
}

sub reads {
    my ($self) = @_;
    return grep { $_ } ($self->forward_reads,
                        $self->reverse_reads);
}

sub pod_for_prop {
    my ($self, $name) = @_;
    my $prop = $PROPERTIES{$name};

    my ($forms, $arg) = split /=/, $prop->{opt};

    my @forms = split /\|/, $forms;

    my @specs;

    my $desc = $prop->{desc} || '';

    for my $form (@forms) {
        
        my $spec = sprintf('B<%s%s>',
                           (length($form) == 1 ? '-' : '--'),
                           $form);
        push @specs, $spec;
    }

    my $specs = join ', ', @specs;
    if ($arg) {
        $specs .= ' I<' . $prop->name . '>';
    }

    my $item = "=item $specs\n\n$desc\n\n";

    if (defined($prop->default)) {
        $item .= 'Default: ' . $prop->default . "\n\n";
    }

    return $item;
}

_add_prop(
    opt => 'version',
    desc => 'Version of RUM that was used to generate the config file',
);

_add_prop(
    opt => 'paired-end',
);

_add_prop(
    opt => 'step=s',
    transient => 1
);

_add_prop(
    opt => 'from-step=s',
    transient => 1,
    desc => 'Just run the job from the specified step. The step number can be found next to the step in the output of C<rum_runner status>.'
);

_add_prop(
    opt => 'forward-reads=s',
    filter => \&make_absolute,
    desc => 'Forward reads',
    check => sub {
        my $conf = shift;
        if (!defined($conf->forward_reads)) {
            return ('Please provide one or two read files');
        }
        if (defined($conf->forward_reads) &&
            ! -r $conf->forward_reads) {
            return ('Can\'t read from forward reads file ' .
                    $conf->forward_reads . ": $!");
        }
        else {
            return;
        }
        
    }
);

_add_prop(
    opt => 'reverse-reads=s',
    filter => \&make_absolute,
    desc => 'Reverse reads',
    check => sub {
        my $conf = shift;
        return if ! defined($conf->reverse_reads);
        
        if ($conf->reverse_reads eq $conf->forward_reads) {
            return ('You specified the same file for the forward '.
                    'and reverse reads.');
        }
        elsif (! -r $conf->reverse_reads) {
            return ('Can\'t read from reverse reads file ' .
                    $conf->reverse_reads . ": $!");
        }
        else {
            return;
        }
    }
);

_add_prop(
    opt => 'limit-nu-cutoff=s',
);

_add_prop(
    opt  => 'quiet|q',
    desc => 'Less output than normal',
    transient => 1
);

_add_prop(
    opt  => 'help|h',
    desc => 'Get help',
    transient => 1,
);


_add_prop(
    opt  => 'verbose|v',
    desc => 'More output than normal',
    transient => 1,
);

_add_prop(
    opt  => 'child',
    desc => 'Indicates that this is a child process',
    transient => 1,
);

_add_prop(
    opt  => 'parent',
    desc => 'Indicates that this is a parent process',
    transient => 1,
);

_add_prop(
    opt  => 'lock=s',
    desc => ('Path to the lock file, if this process is '.
             'to inherit the lock from the parent process'),
    filter => \&make_absolute,
    transient => 1,
);
    
_add_prop(
    opt  => 'preprocess',
    desc => 'Just run the preprocessing phase',
    transient => 1,
);

_add_prop(
    opt  => 'process',
    desc => 'Just run the processing phase',
    transient => 1,
);

_add_prop(
    opt  => 'postprocess',
    desc => 'Just run the postprocessing phase',
    transient => 1,
);

_add_prop(
    opt  => 'chunk=i',
    desc => 'Just run the processing phase of the specified chunk.',
    transient => 1,
);
    
_add_prop(
    opt  => 'no-clean',
    desc => 'Don\'t remove intermediate files. Useful when debugging.',
    transient => 1,
);

_add_prop(
    opt  => 'output-dir|o=s',
    desc => 'Output directory for the job.',
    filter => \&make_absolute,
    check => sub {
        my $conf = shift;
        if (!$conf->output_dir) {
            return ('Please specify an output directory with -o or --output');
        }
    }
);


_add_prop(
    opt  => 'index-dir|i=s',
    desc => 'The path to the directory that contains the RUM index for the organism you want to align against.  Please use I<rum_indexes> to install indexes.',

    filter => \&make_absolute,
    check => sub {
        my $conf = shift;
        if (!$conf->index_dir) {
            return ('Please specify an index directory with -i or --index-dir');
        }
        elsif (!RUM::Index->load($conf->index_dir)) {
            return ($conf->index_dir . " does not seem to be a RUM index directory");
        }
        else {
            return;
        }
    }
);

_add_prop(
    opt  => 'name=s',
    desc => 'A string to identify this run. Use only alphanumeric, underscores, and dashes.  No whitespace or other characters.  Must be less than 250 characters.',
    filter => sub  {
        local $_ = shift;
        
        my $name_o = $_;
        s/\s+/_/g;
        s/^[^a-zA-Z0-9_.-]//;
        s/[^a-zA-Z0-9_.-]$//g;
        s/[^a-zA-Z0-9_.-]/_/g;
        
        return $_;
    },


    check => sub {
        my $conf = shift;
        
        if (! $conf->name ) {
            return ('Please specify a job name with --name');
        }
        elsif (length $conf->name > 250) {
            return ('The name must be less than 250 characters');
        }
        else {
            return;
        }
    }
);

_add_prop(
    opt  => 'chunks=s',
    desc => 'Number of pieces to break the job into.  Use 1 chunk unless you are on a cluster, or have multiple cores with lots of RAM.  Have at least one processing core per chunk.  A genome like human will also need about 5 to 6 Gb of RAM per chunk.  Even with a small genome, if you have tens of millions of reads, you will still need a few Gb of RAM to get through the post-processing.',
    check => sub {
        my $conf = shift;
        if ($conf->chunks) {
            return;
        }
        else {
            return ('Please specify the number of chunks to use with --chunks');
        }
    },
);

_add_prop(
    opt  => 'qsub',
    desc => 'Alias for \'--platform SGE --platform-flags "-pe make 2"\'.',
    handler => sub { 
        my $self = shift;
        $self->set('platform', 'SGE');
      },
);

_add_prop(
    opt  => 'platform=s',
    desc => 'The platform to use. Either \'Local\' for running a job locally, or \'SGE\' for Sun Grid Engine.',
    default => 'Local'
);

_add_prop(
    opt => 'platform-flags=s',
    desc => 'Additional flags to give to the job submission program. Use in conjunction with the --platform option. If you are running on Sun Grid Engine and you do not specify --platform-flags, this will default to "-V -pe 2 -l mem_free=RAM,h_vmem=RAM", where RAM is calculated based on the genome size (usually 6 GB for a mammalian genome). If you specify --platform-flags, you may want to specify all of those flags. You can always see what flags are given to qsub by looking at the main rum.log file.',
);

_add_prop(
    opt  => 'alt-genes=s',
    filter => \&make_absolute,
    desc => 'File with gene models to use for calling junctions novel. If not specified will use the gene models file specified in the config file.',
    check => sub {
        my $c = shift;
        if ($c->alt_genes && ! -r $c->alt_genes) {
            return ("Can't read from alt gene file ".$c->alt_genes.": $!");
        }
        else {
            return;
        }
    }
);

_add_prop(
    opt  => 'alt-quants=s',
    filter => \&make_absolute,
    desc => 'Use this file to quantify features in addition to the gene models file specified in the config file.  Both are reported to separate files.',
    check => sub {
        my $c = shift;
        if ($c->alt_quants && ! -r $c->alt_quants) {
            return ("Can't read from alt quant file ".$c->alt_quants.": $!");
        }
        else {
            return;
        }
    }
);

_add_prop(
    opt  => 'blat-only',
    desc => 'Don\'t run bowtie, only blat and the parts of the pipeline that deal with blat results.',
);

_add_prop(
    opt  => 'dna',
    desc => 'Run in dna mode, meaning don\'t map across splice junctions.'
);

_add_prop(
    opt  => 'genome-only',
    desc => 'Do RNA mapping, but without using a transcript database.  Note: there will be no feature quantifications in this mode, because those are based on the transcript database.',
);

_add_prop(
    opt  => 'junctions',
    desc => 'Use this I<if> using the -dna flag and you still want junction calls. If this is set you should have the gene models file specified in the RUM config file (if you have one).  Without the -dna flag junctions generated by default so you don\'t need to set this.'

);

_add_prop(
    opt => 'no-bowtie-nu-limit',
    desc => 'Let bowtie produce an unlimited number of non-unique mappings for each read. This can result in extremely large intermediate files.'
);


_add_prop(
    opt => 'bowtie-nu-limit=s',
    default => 100,
    desc => 'The maximum number of non-unique mappings to let bowtie produce for each read.'
);


_add_prop(
    opt => 'count-mismatches',
    desc => 'Report in the last column the number of mismatches, ignoring insertions.',
);


_add_prop(
    opt => 'input-is-preformatted',
);

_add_prop(
    opt => 'input-needs-splitting',
);

_add_prop(
    opt => 'nu-limit=s',
    desc => 'Limits the number of ambiguous mappers in the final output by removing all reads that map to n locations or more.',

    check => sub {
        my $conf = shift;
        
        if (!defined($conf->nu_limit)) {
            return;
        }

        elsif ($conf->nu_limit =~ /^\d+$/ &&
               $conf->nu_limit > 0) {
            return;
        }
        else {
            return ("--nu-limit must be an integer greater than zero");
        }
    }
);

_add_prop(
    opt => 'max-insertions=s',
    desc => 'Allow at most n insertions in one read. Setting greater than 1 is only allowed for single end reads.  Don\'t raise it unless you know what you are doing, because it can greatly increase the false alignments.',
    default => 1,
    check => sub {
        my $conf = shift;
        if ($conf->forward_reads &&
            $conf->reverse_reads && 
            $conf->max_insertions > 1) {
            return ('For paired-end data, you can\'t set ' .
                    '--max-insertions > 1');
        }
        else {
            return;
        }
    }
);

_add_prop(
    opt => 'min-identity=s',
    desc => 'TODO: Describe me',
);

_add_prop(
    opt => 'min-length=s',
    desc => 'Don\'t report alignments less than this long.  The default = 50 if the readlength >= 80, else = 35 if readlength >= 45 else = 0.8 * readlength.  Don\'t set this too low you will start to pick up a lot of garbage.',
    check => sub {
        my ($conf) = @_;
        my $x = $conf->min_length;

        if ((!defined $x) ||
            $x =~ /^\d+$/ && $x >= 10) {
            return;
        }
        else {
            return ('--min-length must be an integer greater than 9');
        }
    }
);

_add_prop(
    opt => 'preserve-names',
    desc => 'Keep the original read names in the SAM output file.  Note: this doesn\'t work when there are variable length reads.',

    check => sub {
        my $c = shift;
        if ($c->preserve_names && $c->variable_length_reads) {
            return ('Cannot use both --preserve-names and ' .
                    '--variable-read-lengths at the same time. Sorry, we ' .
                    'will fix this eventually.');
        }
    }
);

_add_prop(
    opt => 'quals-file|qual-file=s',
    desc => 'Specify a qualities file separately from a reads file.',
    check => sub {
        my $c = shift;
        if (defined($c->quals_file) && 
            $c->quals_file =~ /\//) {
            return ("do not specify -quals file with a full path, ".
                    "put it in the '". $c->output_dir. "' directory.");
        }
        else {
            return;
        }
    }
);

_add_prop(
    opt => 'quantify',
    desc => 'Use this I<if> using the -dna flag and you still want quantified features.  If this is set you *must* have the gene models file specified in the RUM config file.  Without the -dna flag quantified features are generated by default so you don\'t need to set this.'


);

_add_prop(
    opt => 'ram=s',
    desc => 'On some systems RUM might not be able to determine the amount of RAM you have.  In that case, with this option you can specify the number of Gb of ram you want to dedicate to each chunk.  This is rarely necessary and never necessary if you have at least 6 Gb per chunk.',


);

_add_prop(
    opt => 'ram-ok'
);


_add_prop(
    opt => 'read-length=s',
    desc => 'Specify the length of the reads. By default I will determine it from the input.',
);

_add_prop(
    opt => 'strand-specific',
    desc => 'If the data are strand specific, then you can use this option to generate strand specific coverage plots and quantified values.',
);

_add_prop(
    opt => 'variable-length-reads',
    desc => 'Set this if your reads are not all of the same length.'
);

_add_prop(
    opt => "blat-min-identity|minIdentity=s",
    group => 'blat',
    desc => 'Run blat with the specified value for -minIdentity',
    default => 93,
    check => sub {
        my ($conf) = @_;
        my $x = $conf->blat_min_identity;
        if ((!defined $x) ||
            $x =~ /^\d+$/ && $x <= 100) {
            return;
        }
        else {
            return ('--blat-min-identity or --minIdentity must be an integer ' .
                    'between 0 and 100');
        }
    }
);

_add_prop(
    opt => "blat-tile-size|tileSize=s",
    group => 'blat',
    desc => 'Run blat with the specified value for -tileSize',
    default => 12
);

_add_prop(
    opt => "blat-step-size|stepSize=s",
    group => 'blat',
    desc => 'Run blat with the specified value for -stepSize',
    default => 6
);

_add_prop(
    opt => "blat-rep-match|repMatch=s",
    group => 'blat',
    desc => 'Run blat with the specified value for -repMatch',
    default => 256
);

_add_prop(
    opt => "blat-max-intron|maxIntron=s",
    group => 'blat',
    desc => 'Run blat with the specified value for -maxIntron',
    default => 500000
);

sub is_specified {
    my ($self, $name) = @_;
    return defined $self->{$name};
}

sub parse_command_line {

    my ($self, %params) = @_;

    my $options    = delete $params{options};
    my $positional = delete $params{positional} || [];
    my $nocheck    = delete $params{nocheck};

    my %getopt;

    for my $name (@{ $options }, 'help') {
        my $prop = $PROPERTIES{$name} or croak "No property called '$name'";
        $getopt{$prop->opt} = sub {
            my ($name, $val) = @_;
            $val = $prop->filter->($val);
            $prop->handler->($self, $name, $val);
        };        
    }


    my @errors;

    my $old_warn = $SIG{__WARN__};

    $SIG{__WARN__} = sub {
        push @errors, $_[0];
    };

    my $status = GetOptions(%getopt);
    
    $SIG{__WARN__} = $old_warn;
    
  POSITIONAL: for my $name (@{ $positional }) {
        my $prop = $PROPERTIES{$name} or croak "No property called '$name'";
        last POSITIONAL if ! @ARGV;
        $prop->handler->($self, $prop->name, shift(@ARGV));
    }

    if ($params{load_default}) {
        if ($self->output_dir) {
            if ( $self->is_new ) {
                die "There does not seem to be a RUM job in " . $self->output_dir . "\n";
            }
            $self->load_default;
        }
        else {
            die RUM::UsageErrors->new(
                errors => ['Please specify an output directory with --output or -o']);
        }
    }

    if (! $nocheck ) {

        for my $name (@{ $options }, 
                      @{ $positional }) {
            my $prop = $PROPERTIES{$name} or croak "No property called '$name'";
            my @these_errors = $prop->checker->($self);
            push @errors, grep { $_ } @these_errors;
        }

        if (@ARGV) {
            push @errors, "There were extra command-line arguments: @ARGV";
        }
        
        if (@errors || !$status) {
            die RUM::UsageErrors->new(errors => \@errors)
        }
    }
    
    if ($self->reverse_reads) {
        $self->set('paired_end', 1);
    }
    
    return $self;
}


sub new {

    my ($class, %params) = @_;

    my $is_default = delete $params{default};

    my $self = {};

    if ($is_default) {
        for my $prop (values %PROPERTIES) {
            if (defined (my $v = $prop->default)) {
                $self->{$prop->name} = $v;
            }
        }
    }
    else {
        $self->{_default} = $class->new(default => 1);
    }

    return bless $self, $class;
}

sub script {
    return File::Spec->catfile("$Bin/../bin", $_[1]);
}

sub postproc_dir {
    my ($self, $file) = @_;
    return File::Spec->catfile($self->output_dir, "postproc");
}

sub chunk_dir {
    my ($self) = @_;
    return File::Spec->catfile($self->output_dir, "chunks");
}

sub temp_dir {
    my ($self) = @_;
    return File::Spec->catfile($self->output_dir, "tmp");
}

sub in_output_dir {
    my ($self, $file) = @_;
    my $dir = $self->output_dir;
    return $dir ? File::Spec->catfile($dir, $file) : $file;
}

sub in_chunk_dir {
    my ($self, $name) = @_;
    my $path = File::Spec->catfile($self->output_dir, "chunks", $name);
}

sub in_postproc_dir {
    my ($self, $file) = @_;
    my $dir = $self->postproc_dir;
    mkpath $dir;
    return File::Spec->catfile($dir, $file);
}

sub chunk_file {
    my ($self, $name, $chunk) = @_;
    $chunk or return undef;
    return $self->in_chunk_dir("$name.$chunk");
}

sub opt {
    my ($self, $opt, $arg) = @_;
    return defined($arg) ? ($opt, $arg) : "";
}

sub read_length_opt         { $_[0]->opt("--read-length", $_[0]->read_length) }
sub min_overlap_opt         { $_[0]->opt("--min-overlap", $_[0]->min_length) }
sub max_insertions_opt      { $_[0]->opt("--max-insertions", $_[0]->max_insertions) }
sub match_length_cutoff_opt { $_[0]->opt("--match-length-cutoff", $_[0]->min_length) }
sub limit_nu_cutoff_opt     { $_[0]->opt("--cutoff",        $_[0]->nu_limit) }
sub faok_opt                { $_[0]->faok             ? "--faok" : ":" }
sub count_mismatches_opt    { $_[0]->count_mismatches ? "--count-mismatches" : "" } 
sub paired_end_opt          { $_[0]->paired_end       ? "--paired" : "--single" }
sub dna_opt                 { $_[0]->dna              ? "--dna" : "" }
sub name_mapping_opt   { "" } 
sub ram_opt {
    return $_[0]->ram ? ("--ram", $_[0]->ram || $_[0]->min_ram_gb) : ();
}
sub blat_opts {
    my ($self) = @_;
    my %opts = (
        minIdentity => $self->blat_min_identity,
        tileSize    => $self->blat_tile_size,
        stepSize    => $self->blat_step_size,
        repMatch    => $self->blat_rep_match,
        maxIntron   => $self->blat_max_intron);

    return map("-$_=$opts{$_}", sort keys %opts);
}

sub is_property {
    my $name = shift;
    exists $PROPERTIES{$name};
}

my %paths = (
    forward_reads => 1,
    reverse_reads => 1,
    
);

sub set {
    my ($self, %params) = @_;
    croak "Can't call set on $self" unless ref $self;
    for my $k (keys %params) {
        croak "No such property $k" unless is_property($k);
        $self->{$k} = $params{$k};
    }
    
    return $self;
}


sub save {
    my ($self) = @_;

    $self->set('version', $RUM::Pipeline::VERSION);

    my @specified = grep { $_ ne 'output_dir' && $self->is_specified($_) } $self->property_names;

    my %copy;

    for my $k (keys %{ $self }) {
        if (!$PROPERTIES{$k} ||
            !$PROPERTIES{$k}->transient) {
            $copy{$k} = $self->{$k};
        }
    }

    if (@specified) {
        my $filename = $self->in_output_dir($FILENAME);
        open my $fh, ">", $filename or croak "$filename: $!";
        print $fh Dumper(bless \%copy, __PACKAGE__);
        return 1;
    }
    return 0;
}

sub destroy {
    my ($self) = @_;
    my $filename = $self->in_output_dir($FILENAME);
    unlink $filename;
}

sub is_new {
    my ($self) = @_;

    my $new_filename = $self->in_output_dir($FILENAME);
    my $old_filename = $self->in_output_dir(".rum/job_settings");

    return ! ((-e $new_filename) ||
              (-e $old_filename));
}

sub load_default {
    my ($self) = @_;

    my $filename = $self->in_output_dir($FILENAME);

    if (! -f $filename) {
        warn "It looks like this job was run before with an older version of RUM (2.0.2_06 or earlier), because the job configuration is stored in $filename. I will try to use this older configuration.";

        $filename = $self->in_output_dir(".rum/job_settings");
    }

    $self->{_default} = do $filename;

    my $class = blessed($self);

    ref($self->{_default}) =~ /$class/ or croak "$filename did not return a $class";
    my $output_dir = realpath($self->output_dir);
    my $loaded_dir_orig = $self->{_default}->output_dir;
    my $loaded_dir = realpath($loaded_dir_orig);
    if (!$loaded_dir) {
        croak("I loaded a config file from '$output_dir', and it " .
              "had its output directory set to '$loaded_dir_orig', which does ".
              "not exist. Have you moved the RUM job directory? If so, you ".
              "can manually edit $filename and change the output_dir setting ".
              "to the new output directory");
    }
    if ($loaded_dir eq $output_dir) {
        delete $self->{output_dir};
    }
    else {
        croak("I loaded a config file from ".$output_dir.", and it " .
              "had its output directory set to ".$loaded_dir.". It " .
              "should be the same as the directory I loaded it from. This means " .
              "the config file is corrupt. You should probably start the job again " .
              "from scratch.");
    }

    if (!$self->version) {
        die("You seem to be trying to rerun a job that was set up with an " .
            "older version of RUM (v2.0.2_02 or earlier), which is ".
            "incompatible with the current version ($RUM::Pipeline::VERSION). ".
            "You will need to rerun the job from the beginning using the " .
            "current version of RUM.\n");
    }

    return $self;
}

sub get {
    my ($self, $name) = @_;

    ref($self) or croak "Can't call get on $self";
    is_property($name) or croak "No such property $name";
    
    if (defined $self->{$name}) {
        return $self->{$name};
    }
    elsif ($self->{_default}) {
        return $self->{_default}->get($name);
    }
    else {
        return;
        #croak "Property $name was not set. Config is " . Dumper($self);
    }
}

sub properties {
    sort keys %DEFAULTS;
}

sub settings_filename {
    my ($self) = @_;
    return ($self->in_output_dir($FILENAME));
}

sub lock_file {
    my ($self) = @_;
    $self->in_output_dir("rum_lock");
}

sub min_ram_gb {
    my ($self) = @_;
    my $index = RUM::Index->load($self->index_dir);
    my $genome_size = $index->genome_size;
    defined($genome_size) or croak "Can't get min ram without genome size";
    my $gsz = $genome_size / 1000000000;
    my $min_ram = ceil($gsz * 1.67)+1;
    return $min_ram;
}

sub should_quantify {
    my ($self) = @_;
    return !($self->dna || $self->genome_only) || $self->quantify;
}

sub should_do_junctions {
    my ($self) = @_;
    return !$self->dna || $self->genome_only || $self->junctions;
}

sub u_footprint { shift->in_postproc_dir("u_footprint.txt") }
sub nu_footprint { shift->in_postproc_dir("nu_footprint.txt") }
sub mapping_stats_final {
    $_[0]->in_output_dir("mapping_stats.txt");
}
sub sam_header { 
    my ($self, $chunk) = @_;
    $self->chunk_file("sam_header", $chunk) or $self->in_postproc_dir("sam_header");
}

sub quant {
    my ($self, %opts) = @_;

    my $chunk = $opts{chunk};
    my $strand = $opts{strand};
    my $sense  = $opts{sense};
    if ($strand && $sense) {
        my $name = "quant.$strand$sense";
        return $chunk ? $self->chunk_file($name, $chunk) : $self->in_output_dir($name);
    }

    if ($chunk) {
        return $self->chunk_file("quant", $chunk);
    }
    return $self->in_output_dir("feature_quantifications_" . $self->name);
}

sub alt_quant {
    my ($self, %opts) = @_;
    my $chunk  = $opts{chunk};
    my $strand = $opts{strand} || "";
    my $sense  = $opts{sense}  || "";
    my $name = $self->name;

    if ($chunk) {
        my @parts = ("quant", "$strand$sense", "altquant");
        my $filename = join ".", grep { $_ } @parts;
        return $self->chunk_file($filename, $chunk);
    }
    elsif ($strand && $sense) {
        return $self->in_output_dir("feature_quantifications.altquant.$strand$sense");
    }
    else {
        return $self->in_output_dir("feature_quantifications_$name.altquant");
    }
}
sub novel_inferred_internal_exons_quantifications {
    my ($self) = @_;
    return $self->in_output_dir("novel_inferred_internal_exons_quantifications_"
                                    .$self->name);
}

sub preprocessed_reads {
    return shift->in_output_dir("reads.fa");
}

sub AUTOLOAD {
    confess "Undefined method $AUTOLOAD called on @_" unless ref $_[0];
    my ($self) = @_;

    my @parts = split /::/, $AUTOLOAD;
    my $name = $parts[-1];
    
    return if $name eq "DESTROY";

    return $self->get($name);
}

sub property_names {
    return keys %PROPERTIES;
}

sub property {
    my ($class, $name) = @_;
    return $PROPERTIES{$name};
}

sub step_props {
    return qw(preprocess process postprocess chunk parent child);
}

sub common_props {
    return qw(quiet verbose help);
}

sub job_setting_props {
    return qw(index_dir name qsub
              platform alt_genes alt_quants blat_only dna
              genome_only junctions bowtie_nu_limit
              no_bowtie_nu_limit nu_limit max_insertions
              min_identity min_length preserve_names quals_file
              quantify ram read_length strand_specific
              variable_length_reads blat_min_identity
              blat_tile_size blat_step_size blat_max_intron
              blat_rep_match count_mismatches no_clean
              platform_flags);
}

sub changed_settings {
    my ($self) = @_;
    my @props = $self->job_setting_props;
    my @changed = grep { $self->is_specified($_) } @props;
    return @changed;
}

1;

__END__

=head1 NAME

RUM::Config - Configuration for a RUM job

=head1 CONSTRUCTOR

=over 4

=item new(%options)

Create a new RUM::Config with the given options. %options can contain
mappings from the keys in %DEFAULTS to the values to use for those
keys.

=back

=head1 CLASS METHODS

=over 4

=item script($name)

Return the path to the rum script of the given name.

=back

=head1 OBJECT METHODS

=head2 Directories

These methods return the paths to some directories I need:

=over 4

=item postproc_dir

=item chunk_dir

=item temp_dir

=back

=head2 File paths

These methods return paths to files relative to some of my directories.

=over 4

=item in_output_dir($file)

Return a path to a file with the given name, relative to our output directory.

=item in_chunk_dir($name)

Return a path to a file with the given name, relative to our chunk
directory.

=item in_postproc_dir($file)

Return a path to a file with the given name, relative to our postproc directory.

=item chunk_file

Return a path to a file in our chunk directory, based on the given
filename, with the given chunk as the suffix.

=item opt($opt, $arg)

Return a list of the option and its argument if argument is defined,
otherwise an empty string.

=back

=head2 Getting option lists for scripts

The following methods can be used to get options to pass into sub
programs, based on the configuration:

=over 4

=item read_length_opt

=item min_overlap_opt

=item max_insertions_opt

=item match_length_cutoff_opt

=item limit_nu_cutoff_opt

=item bowtie_cutoff_opt

=item faok_opt

=item count_mismatches_opt

=item paired_end_opt

=item dna_opt

=item blat_opts

=item name_mapping_opt

=item ram_opt

=back

=head2 Serializing the configuration

=over 4

=item $config->settings_filename

Return the name of the file I should be saved to.

=item $config->save

Save the configuration to a file ($output_dir/rum_job_config)

=item RUM::Config->load($dir, $force)

Load a saved RUM::Config file.

=item $config->destroy

Delete the config file.

=back

=head2 Other

=over 4

=item is_property($name)

Return true if the given name is a property that can be configured.

=item set($key, $value)

Set the value of $key to $value.

=item get($name)

Return the value of the property with the given name.

=item properties

Return a list of the names of my properties.

=item lock_file

Return the path to the lock file that should prevent other instances
of the pipeline from running in the same output directory.

=item min_ram_gb

Return the minimum amount of ram that is needed, based on the genome size.

=back

=head2 Derived Values

These values are derived based on properties provided by the user or
the defaults:

=over 4

=item should_quantify

Return true if the pipeline should do quantifications, based on the
values of the I<dna>, I<genome_only>, and I<quantify> properties.

=item should_do_junctions

Return true if the pipeline should do junctions, based on the values
of the I<dna>, I<genome_only>, and I<junctions> properties.

=back

=head2 Output Files

These functions all return the paths to output files.

=over 4

=item u_footprint

=item nu_footprint

=item mapping_stats_final

=item sam_header

=item sam_header($chunk)

=item quant(%options)

=item alt_quant(%options)

Return the filename for a quant file or an alt quant file, optionally
given a chunk, strand, and sense. The following are valid keys for
options:

=over 4

=item chunk

=item strand

=item sense

=back

=item novel_inferred_internal_exons_quantifications

Return the name of the novel inferred internal exons quants file.

=item preprocessed_reads

Return the path to preprocessed reads file (reads.fa in the output
directory).

=item should_preprocess

=item should_process

=item should_postprocess

These methods return true if the corresponding phase of the pipeline
should be run, according to the options the user provided for this
invocation of rum_runner.

=item step_props

Returns the list of property names that all have to do with specifying
a step or phase of the pipeline to run.

=item reads

Return the list of read files that were supplied.

=item property_names

Return the list of names of all the valid properties.

=item property

Return the RUM::Property with the given name.

=item pod_for_prop($property_name)

Returns the POD for the property with the given name.

=item make_absolute($path)

Returns an absolute filename for the given path.

=item parse_command_line

Populate this config object with settings parsed fromt he
command-line, and optionally loaded from a saved config file.

=over 4

=item options

Names of RUM::Config properties that should be parsed from the command line.

=item positional

Names of RUM::Config properties, which should be picked in order from
the remaining command-line options.

=item load_default

If true, load my defaults from the config file saved in the output
directory specified on the command line.

=back

=item job_setting_props 

Return the list of property names that all represent job settings that
should be set during initialization.

=item is_top_level

Return true if this is a "top-level" RUM proces, and not one that was
kicked off by another RUM process.

=item changed_settings

Return a list of names of properties that were changed from the
defaults in this configuration.

=item is_new

Return true if this is a new job, that is, if there is not already a
job configuraiton saved in the output directory.

=item is_specified($prop_name)

Return true if the user specified the given property on the
command-line.

=item common_props

Return a list of property names that should be accepted by every
action.

=back
