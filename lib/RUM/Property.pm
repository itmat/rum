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
    $self->{handler}    = delete $params{handler} || \&handle;
    $self->{checker}    = delete $params{check}   || sub { return };
    $self->{default}    = delete $params{default};
    $self->{transient}  = delete $params{transient};
    $self->{group}      = delete $params{group};
    $self->{required}   = delete $params{required};
    $self->{positional} = delete $params{positional};
    $self->{choices}    = delete $params{choices};
    
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
    $self->checker->($self, $props, $val);
    if ($self->choices) {
        my @picked = grep { $_ eq $val } $self->choices;
        if (!@picked) {
            $props->errors->add($self->options . ' must be one of ' . join(', ', map { "'$_'" } $self->choices));
        }
    }
}

1;
