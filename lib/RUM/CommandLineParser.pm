package RUM::CommandLineParser;

use strict;
use warnings;

use Getopt::Long;
use Data::Dumper;

use RUM::Property;
use RUM::Properties;

sub new {
    my ($class) = @_;
    return bless {properties => []}, $class;
}

sub add_prop {
    my ($self, %params) = @_;
    my $prop = RUM::Property->new(%params);
    push @{ $self->{properties} }, $prop;
}

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

    for my $prop (@{ $self->{properties} }) {

        if ($prop->required && !$props->has($prop->name)) {
            $props->errors->add('Missing required argument ' . $prop->options . ': ' . $prop->desc);
        }
        if ($props->has($prop->name)) {
            $prop->checker->($props, $prop, $props->get($prop->name));
        }
    }

    $props->errors->check;

    return $props;
    
}

1;
