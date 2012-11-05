package RUM::Property;

use strict;
use warnings;

use RUM::Usage;
use RUM::UsageErrors;
use Carp;

sub handle {
    my ($props, $opt, $val) = @_;
    $opt =~ s/-/_/g;
    $props->set($opt, $val);
}

sub handle_multi {
    my ($props, $opt, $val) = @_;
    $opt =~ s/-/_/g;
    if (!$props->has($opt)) {
        $props->set($opt, []);
    }
    push @{ $props->get($opt) }, $val;
}

sub new {
    my ($class, %params) = @_;

    my $self = {};
    $self->{opt}        = delete $params{opt}     or croak "Need opt";
    $self->{desc}       = delete $params{desc};
    $self->{filter}     = delete $params{filter}  || sub { shift };
    $self->{handler}    = delete $params{handler};
    $self->{checker}    = delete $params{check}   || sub { return };
    $self->{default}    = delete $params{default};
    $self->{transient}  = delete $params{transient};
    $self->{group}      = delete $params{group};
    $self->{required}   = delete $params{required};
    $self->{positional} = delete $params{positional};
    $self->{choices}    = delete $params{choices};
    $self->{nargs}      = delete $params{nargs} || '';

    if (!$self->{handler}) {
        $self->{handler} = $self->{nargs} eq '+' ? \&handle_multi : \&handle;
    }

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
sub required { shift->{required} }
sub positional { shift->{positional} }
sub choices { @{ shift->{choices} || [] } }
sub nargs { shift->{nargs} }

sub set_required {
    my ($self) = @_;
    $self->{required} = 1;
    return $self;
}

sub options {
    my ($self, $separator) = @_;
    my $opt = $self->opt;

    $separator ||= ' or ';

    if ($self->positional) {
        return $opt;
    }

    $opt =~ s/=.*$//;
    my @opts = split /\|/, $opt;
    @opts = map { length > 1 ? "--$_" : "-$_" } @opts;
    my $opts = join $separator, @opts;
    return $opts;
}

sub pod {
    my ($self) = @_;

    my ($forms, $arg) = split /=/, $self->opt;

    my @forms = split /\|/, $forms;

    my @specs;

    if ($self->positional) {
        push @specs, $self->name;
    }
    else {
        for my $form (@forms) {
            my $spec = sprintf('B<%s%s>',
                               (length($form) == 1 ? '-' : '--'),
                               $form);
            push @specs, $spec;
        }
    }

    my $specs = join ', ', @specs;
    if ($arg) {
        $specs .= ' I<' . $self->name . '>';
    }

    if ($self->choices) {
        $specs .= ' {' . join('|', $self->choices) . '}';
    }

    if ($self->{required}) {
        $specs .= " (required)";
    }

    my $desc = $self->desc || '';
    my $item = "=item $specs\n\n$desc\n\n";

    if (defined($self->default)) {
        $item .= 'Default: ' . $self->default . "\n\n";
    }

    return $item;
}

sub check {
    my ($self, $props, $val) = @_;
    $self->checker->($props, $self, $val);
    if ($self->choices) {
        my @picked = grep { $_ eq $val } $self->choices;
        if (!@picked) {
            $props->errors->add($self->options . ' must be one of ' . join(', ', map { "'$_'" } $self->choices));
        }
    }
}

1;

=head1 NAME

RUM::Property - A RUM command-line option

=over 4

=item RUM::Property->new(%options)

=over 4

=item opt

The option specification, as you would use for Getopt::Long.

=item desc

Help message for the option.

=item filter

Function to apply to the raw value entered by the user. For example \&int to turn it into an int, or sub { open my $in, '<', shift; return $in } to open as a readable filehandle.

=item handler

Function that is called when an option is recognized.

=item checker

Function that is called to validate an option. Called with three arguments: a RUM::Properties object that contains all the options recognized, a RUM::Property object representing this option, and the actual value of the option.

=item default

The default value.

=item transient

True means that the option shouldn't be saved in the job's config file. Defaults to false.

=item group

=item required

True means the option is required.

=item positional

True means the option is not a flag (e.g. --output or -o), but rather a positional command-line argument.

=item choices

If the option has a discrete set of choices, supply those choices here.

=item nargs

Number of arguments to use, for positional arguments.

=back

=item handle($props, $name, $value)

Set $name to $value in the given RUM::Properties object.

=item handle_multi($props, $name, $value)

Append $value to the list of values for $name in the given RUM::Properties object.

=item $prop->check($props, $val)

Validate the given property.

=item $prop->name

Return the name for the property, to be used in usage messages.

=item $prop->options

Return a string representing the options for the property (e.g. "--output|-o"), for usage messages.

=item $prop->pod

Return the POD for the property.

=item $prop->set_required

Set the 'required' flag on the property.

=back
