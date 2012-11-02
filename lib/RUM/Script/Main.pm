package RUM::Script::Main;

use strict;
use warnings;

use RUM::Config;
use RUM::Usage;
use RUM::Workflows;
use Data::Dumper;
use base 'RUM::Script::Base';

our %ACTIONS = (
    help     => "RUM::Action::Help",
    '-h'     => "RUM::Action::Help",
    '-help'  => "RUM::Action::Help",
    '--help' => "RUM::Action::Help",

    version  => "RUM::Action::Version",

    align    => "RUM::Action::Align",
    init     => "RUM::Action::Init",
    status   => "RUM::Action::Status",
    resume   => "RUM::Action::Resume",
    stop     => "RUM::Action::Stop",
    clean    => "RUM::Action::Clean",
    profile  => "RUM::Action::Profile",
    kill     => 'RUM::Action::Kill',
);

sub accepted_options {
    return (RUM::Property->new(
        opt => 'action',
        desc => 'The action for rum_runner to perform',
        choices => [qw(align init status resume stop clean profile kill help version)],
        positional => 1,
        required => 1),
            RUM::Property->new(
                opt => 'help|h',
                desc => 'Get help')
        );
}

sub summary {
    'RNA-Seq Unified Mapper'
}

sub synopsis {
return <<'EOF';

  # Run the RUM pipeline
  rum_runner align        \
    [OPTIONS]             \
    --output *dir*        \
    --index  *index_dir*  \
    --name   *job_name*   \
    --chunks *num_chunks* \
    *forward_reads* [*reverse_reads*]

  # or perform other tasks
  rum_runner clean   -o *dir* [--very]
  rum_runner kill    -o *dir*
  rum_runner resume  -o *dir* [OPTIONS]
  rum_runner status  -o *dir*
  rum_runner stop    -o *dir*
  rum_runner version
  rum_runner help    [ACTION]

EOF
}

sub parse_command_line {
    my ($self) = @_;
    my $action = shift @ARGV;
    my $props = $self->{properties} = RUM::Properties->new([$self->accepted_options]);
    if ($ACTIONS{$action}) {
        $props->set('action', $action);
    }
    else {
        $props->errors->add('Please specify an action');
    }
    $props->errors->check;
    return $props;
}

sub run {
    my ($self) = @_;

    my $props = $self->properties;

    my $action = $props->get('action');

    my $class = $ACTIONS{$action};

    RUM::Script::Base::set_script_command($action);
          
    my $file = $class;
    $file =~ s/::/\//g;
    $file .= ".pm";
    require $file;
    $class->main;
}

sub description {
    return <<'EOF';

Use this program to run the RUM pipeline, as well as to do things like
check the status of a job, kill a job, and clean up after a job.

Every time you run rum_runner you must give it an action that tells it
what to do. When you run the pipeline using C<rum_runner align>,
rum_runner puts all of its output files in one directory, specified by
the B<-o> or B<--output> option.

While the job is running you can check the status by running
C<rum_runner status -o I<dir>>, where I<dir> is the output
directory.

If you need to stop a job but leave all of its output intact so you
can restart it from where it left off, use C<rum_runner stop -o
I<dir>>. You can then resume the job with C<rum_runner resume -o
I<dir>>, and it should start at the step it was on when it was
stopped.

If you realized you started a job with incorrect settings and you want
to kill it and restart it from scratch, you can use C<rum_runner kill
-o I<dir>>. This will stop the job and remove all output files
associated with it, so you can safely run it again with different
settings.

B<Note>: Please run C<rum_runner help align> to see all of the options
you can use when running an alignment.

EOF
}

sub argument_pod {

return <<'EOF';

Every time you run rum_runner, you must provide an action that tells the program what to do:

=over 4

=item B<align>

Run the RUM pipeline (this is usually what you want).

=item B<clean>

Delete intermediate files in the specified output directory. 

=item B<kill>

Stop the job running in the specified output directory and remove all
output files associated with it, so you can restart the job from
scratch with different settings.

=item B<status>

Check the status of a job running in the output directory specified by
-o or --output.

=item B<stop>

Stop the job running in the specified output directory. Note that if
you're running a job in a terminal you also stop it using CTRL-C.

=item B<version>

Print out the version of RUM.

=item B<help> [I<action>]

Print usage information. If I<action> is provided, print help
information specific to that action.

=back

EOF

}
