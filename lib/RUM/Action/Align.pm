package RUM::Action::Align;

use strict;
use warnings;
use autodie;

use Getopt::Long;
use File::Path qw(mkpath);
use Text::Wrap qw(wrap fill);
use Carp;
use Data::Dumper;

use RUM::Action::Clean;
use RUM::Action::Init;
use RUM::Action::Start;

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

RUM::Lock->register_sigint_handler;

sub new { shift->SUPER::new(name => 'align', @_) }

sub accepted_options {
    return (        
        options => [RUM::Config->common_props,
                    RUM::Config->job_setting_props,
                    'chunks', 'output_dir'],
        positional => ['forward_reads', 'reverse_reads']);
}

sub run {
    my ($class) = @_;
    my $self = $class->new;
    my $pipeline = $self->pipeline;
    $self->show_logo;
    $pipeline->initialize;
    $pipeline->start;
}

sub pod_header {
    return <<'EOF';
=head1 NAME

rum_runner align - Run the RUM pipeline.

=head1 SYNOPSIS

  # Start a job
  rum_runner align           
      --index-dir INDEX_DIR  
      --name      JOB_NAME   
      --output    OUTPUT_DIR 
      --chunks    NUM_CHUNKS
      FORWARD_READS [ REVERSE_READS ]
      [ OPTIONS ]

=head1 DESCRIPTION

Runs the RUM pipeline. Use C<rum_runner align> to run a new job in a
new output directory. If you need to resume an existing job, please
see C<rum_runner resume> instead.

You need to specify --index-dir, --output-dir, --name, --chunks, and
one or teo read files for each job. All other parameters are optional,
and are described in detail below.

When you run C<rum_runner align -o I<dir> OPTIONS> on output directory
I<dir>, rum_runner will save the options you ran it with in
I<dir/rum_job_config>. Then if you need to rerun the job for any
reason, you can run C<rum_runner resume -o I<dir>> later and it will
automatically pick up the options you specified originally.

This program writes very large intermediate files.  If you have a
large genome such as mouse or human then it is recommended to run in
chunks on a cluster, or a machine with multiple processors.  Running
with under five million reads per chunk is usually best, and getting
it under a million reads per chunk will speed things considerably.

=head2 BLAT options

You can tweak the BLAT portion of RUM to suit your needs, please see
the --blat-* options below. We have set the defaults to values that we
have found to be a good balance for speed, sensitivity, and temporary
file size.

=head1 FILES

=over 4

=item B<FORWARD> (required)

=item B<REVERSE> (optional)

For unpaired data, the single file of reads.  For paired data the
files of forward and reverse reads. The files can be either fasta or
fastq; RUM will infer the type. RUM will accept raw text files or gzip
compressed files.

=back

EOF

}
