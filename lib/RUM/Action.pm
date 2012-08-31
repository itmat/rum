package RUM::Action;

use strict;
use warnings;

use Carp;
use Getopt::Long;
use RUM::Usage;
use RUM::Logging;
use RUM::UsageErrors;
use Pod::Usage;
use base 'RUM::Base';

my $log = RUM::Logging->get_logger;

sub new {
    my ($class, %params) = @_;
    my $self = $class->SUPER::new;

    $self->{config} = $params{config};
    $self->{name}   = $params{name} or croak "Please give 'name' param";
    $self->{usage_errors}  = RUM::Usage->new(action => $self->{name});
    $self->{loaded_config} = undef;
    
    return bless $self, $class;
}

sub load_config {
    my ($self, %options) = @_;

    if (!$self->{config}) {
        # Parse the command line and construct a RUM::Config
        eval {
            $self->{config} = RUM::Config->new->parse_command_line(
                $self->accepted_options);
        };
        if (my $errors = $@) {
            my $msg;
            if ($errors->isa('RUM::UsageErrors')) {
                for my $error ($errors->errors) {
                    chomp $error;
                    $msg .= "* $error\n";
                }
            }
            else {
                $msg = $errors;
            }
            my $pod = $self->pod;
            open my $pod_fh, '<', \$pod;
            pod2usage(
                -input => $pod_fh,
                -output => \*STDERR,
                -verbose => 0,
                -exitval => 'NOEXIT');
            die "\n$msg\n";
        }
    }

    return $self->{config};
}

sub pipeline {
    my ($self) = @_;
    if (!$self->{pipeline}) {
        $self->{pipeline} = RUM::Pipeline->new($self->load_config);
    }
    return $self->{pipeline};
}

sub usage_errors { shift->{usage_errors} }

sub check_usage {
    shift->usage_errors->check;
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


sub show_logo {
    my ($self) = @_;
    my $msg = <<EOF;

RUM Version $RUM::Pipeline::VERSION

$RUM::Pipeline::LOGO
EOF
    $self->say($msg);

}

sub pod_footer {
    
    return << 'EOF';

=head1 AUTHORS

Gregory Grant (ggrant@grant.org)

Mike DeLaurentis (delaurentis@gmail.com)

=head1 COPYRIGHT

Copyright 2012, University of Pennsylvania

EOF

}

sub pod {
    my ($class) = @_;

    my $pod = $class->pod_header;

    $pod .= "=head1 OPTIONS\n\n";

    my %options = $class->accepted_options;

    my @named      = sort @{ $options{options} || [] };

    my @transient  = grep { RUM::Config->property($_)->transient }   @named;
    my @persistent = grep { ! RUM::Config->property($_)->transient } @named;
    
    if (@transient && @persistent > 1) {
        $pod .= <<'EOF';

These options are not saved to the job settings file, they only affect
the current run.

EOF
        $pod .= <<'EOF';
        
=over 4

EOF
        
        
        for my $option (@transient) {
            $pod .= RUM::Config->pod_for_prop($option);
        }
        
        $pod .= "=back\n\n";

    }
        

    if (@persistent) {

        if (@persistent > 1) {

        $pod .= <<'EOF';

These options are saved to the job settings file and will persist
across runs.

EOF
    }
        $pod .= <<'EOF';
        
=over 4

EOF
        
        for my $option (@persistent) {
            $pod .= RUM::Config->pod_for_prop($option);
        }
        
        $pod .= "=back\n\n";

    }
        

    $pod .= $class->pod_footer;

    return $pod;
}

1;

__END__

=head1 NAME

RUM::Action - Base class for Action classes, which implement the logic
required by the first argument to rum.

=head1 METHODS

=over 4

=item RUM::Action->new(%params)

Accepts the following params:

=over 4

=item name (required)

The name of the action: command the user uses to invoke the action,
e.g. "align" in "rum_runner align".

=item config (optional)

The RUM::Configuration. If not supplied, will be left undefined, and
may be loaded based on the B<--output> option when I<get_options> is
called.

=back

=item $action->get_options(%options)

Parse command line options. %options should be a hash in the format
expected by Getopt::Long::GetOptions. This method provides a few
additional options.

=over 4

=item * 

B<-h> and B<--help> are added, and if the user specifies one of them,
this method prints a usage message and exits.

=item *

B<-o> and B<--output> are added, and the user most provide the output
directory using one of those options unless they specify B<-h> or
B<--help>.

=back

=item $action->usage_errors

Return the RUM::Usage object associated with this action. It can be
used to accumulate usage errors, and then calling
$action->usage_errors->check_usage will die with an appropriate
message if usage is bad.

=item $action->check_usage

Equivalent to $action->usage_errors->check_usage;

=back

=head1 AUTHOR

Mike DeLaurentis (delaurentis@gmail.com)

=head1 COPYRIGHT

Copyright University of Pennsylvania, 2012


