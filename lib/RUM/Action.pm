package RUM::Action;

use strict;
use warnings;

use Carp;
use Getopt::Long;
use RUM::Logging;
use RUM::UsageErrors;
use Data::Dumper;
use base 'RUM::Script::Base';

my $log = RUM::Logging->get_logger;

sub new {
    my ($class, %params) = @_;
    my $self = $class->SUPER::new;

    $self->{config} = $params{config};
    $self->{name}   = $params{name} || 'foo' or croak "Please give 'name' param";
    $self->{loaded_config} = undef;
    return $self;
}

sub config {
    shift->load_config;
}

sub load_config {
    my ($self) = @_;

    if (!$self->{config}) {

        my $props = $self->properties;
        # Parse the command line and construct a RUM::Config
        my $config = $self->{config} = RUM::Config->new(properties => $props);

        if ($self->load_default) {
            if ($config->output_dir) {
                if ( $config->is_new ) {
                    die "There does not seem to be a RUM job in " . $config->output_dir . "\n";
                }
                $config->load_default;
            }
            else {
                die RUM::UsageErrors->new(
                    errors => ['Please specify an output directory with --output or -o']);
            }
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
    print $msg;

}

sub pod_footer {
    
    return "=head1 AUTHORS\n\nGregory Grant (ggrant\@grant.org)\n\nMike DeLaurentis (delaurentis\@gmail.com)\n\n=head1 COPYRIGHT\n\nCopyright 2012, University of Pennsylvania\n";

}

sub pod_ {
    my ($class) = @_;

    my $pod = $class->pod_header;

    $pod .= "=head1 OPTIONS\n\n";

    my @options = $class->accepted_options;

    my %options = map { ($_->name => $_) } @options;

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


