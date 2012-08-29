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

sub run {
    my ($class) = @_;

    my $self = $class->new;

    # Initialize the job
    my $init = RUM::Action::Init->new;
    $init->make_config;
    $init->initialize;

    # Run the job

    my $start = RUM::Action::Start->new(config => $init->config);
    $start->start;
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
