package RUM::Action;

use strict;
use warnings;

use Carp;
use Getopt::Long;
use RUM::Usage;
use base 'RUM::Base';

=head1 NAME

RUM::Action - Base class for Action classes, which implement the logic required by the first argument to rum.

=cut

sub new {
    my ($class, %params) = @_;
    my $self = $class->SUPER::new;

    $self->{name}          = $params{name} or croak "Please give 'name' param";
    $self->{usage_errors}  = RUM::Usage->new(action => $self->{name});

    return bless $self, $class;
}

sub get_options {
    my ($self, %options) = @_;

    GetOptions('output|o=s' => \(my $output_dir),
               "help|h" => sub { $self->usage_errors->help },
               %options);

    $output_dir or $self->usage_errors->bad(
        "The --output or -o option is required for \"rum_runner $self->{name}\"");
    $self->check_usage;

    my $c = RUM::Config->load($output_dir);
    my $did_load;
    if ($c) {
        $self->logsay("Using settings found in " . $c->settings_filename);
        $did_load = 1;
    }
    else {
        $c = RUM::Config->new unless $c;
        $c->set('output_dir', File::Spec->rel2abs($output_dir));
    }
    
    $self->{config} = $c;
}

sub usage_errors { shift->{usage_errors} }

sub check_usage {
    shift->usage_errors->check;
}

1;
