package RUM::CommandLineParser;

use strict;
use warnings;

use Getopt::Long;
use Data::Dumper;

use RUM::Property;
use RUM::Properties;

sub new {
    my ($class) = @_;
    my $self = bless {properties => []}, $class;
    $self->add_prop(
        opt => 'help|h' ,
        desc => 'Get full usage information'
    );
    return $self;
}

sub add_prop {
    my $self = shift;
    if (@_ == 1 && ref($_[0]) =~ /Property/) {
        push @{ $self->{properties} }, $_[0];
    }
    else {
        $self->add_prop(RUM::Property->new(@_));
    }
}

sub properties { @{ shift->{properties} } };

sub parse {
    my ($self) = @_;

    my %getopt;

    my $props = RUM::Properties->new;

    my @positional;

    my @required;

    for my $prop (@{ $self->{properties} } ) {
        
        if ($prop->positional) {
            push @positional, $prop;
        }
        else {
            $getopt{$prop->opt} = sub {
                my ($name, $val) = @_;
                $val = $prop->filter->($val);
                $prop->handler->($props, $name, $val);
            };
        }
    }

    GetOptions(%getopt);

    for my $prop (@positional) {
        $props->set($prop->name, shift(@ARGV));
    }

    if ($props->has('help')) {
        return $props;
    }

    for my $prop (@{ $self->{properties} }) {

        if ($prop->required && !$props->has($prop->name)) {
            $props->errors->add('Missing required argument ' . $prop->options . ': ' . $prop->desc);
        }
        if ($props->has($prop->name)) {
            $prop->check($props, $props->get($prop->name));
        }
    }

    $props->errors->check;

    return $props;
    
}

1;
