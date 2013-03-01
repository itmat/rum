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
    my ($self) = @_;

    if (!$self->{config}) {
        # Parse the command line and construct a RUM::Config
        eval {
            $self->{config} = RUM::Config->new->parse_command_line(
                $self->accepted_options);
        };
        if (my $errors = $@) {
            my $msg;
            if (ref ($errors) && $errors->isa('RUM::UsageErrors')) {
                for my $error ($errors->errors) {
                    chomp $error;
                    $msg .= "* $error\n";
                }
                my $pod = $self->pod;
                open my $pod_fh, '<', \$pod;
                pod2usage(
                    -input => $pod_fh,
                    -output => \*STDERR,
                    -verbose => 0,
                    -exitval => 'NOEXIT');
            }
            else {
                $msg = $errors;
            }
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

sub show_logo {
    my ($self) = @_;
    my $msg = <<EOF;

RUM Version $RUM::Pipeline::VERSION

$RUM::Pipeline::LOGO
EOF
    $self->say($msg);

}

sub pod_footer {
    
    return "=head1 AUTHORS\n\nGregory Grant (ggrant\@grant.org)\n\nMike DeLaurentis (delaurentis\@gmail.com)\n\n=head1 COPYRIGHT\n\nCopyright 2012, University of Pennsylvania\n";

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
        $pod .= "\n\nThese options are not saved to the job settings file, they only affect the current run.\n\n";
    }

    if (@transient) {
        $pod .= "\n\n=over 4\n\n";
        
        for my $option (@transient) {
            $pod .= RUM::Config->pod_for_prop($option);
        }
        
        $pod .= "=back\n\n";
    }
        

    if (@persistent) {

        if (@persistent > 1) {
            
            $pod .= "These options are saved to the job settings file and will persist across runs.\n\n";
        }
        $pod .= "\n\n=over 4\n\n";
        
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

=back

=back

=head1 AUTHOR

Mike DeLaurentis (delaurentis@gmail.com)

=head1 COPYRIGHT

Copyright University of Pennsylvania, 2012


