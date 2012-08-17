package RUM::Identifiable;

use strict;
use warnings;
use autodie;

use Carp;

sub new {
    my ($class, %params) = @_;
    my $self = {};

    my $readid = delete $params{readid};

    my ($order, $direction);

    # If the caller gave us order and direction, use both of them
    if (exists $params{order} || exists $params{direction}) {

        if ( ! (exists $params{order} && exists $params{direction} ) ) {
            croak "If you supply either order or direction, you must supply both";
        }

        $order = delete $params{order};
        $direction = delete $params{direction};

        if ($order !~ /^\d+$/) {
            croak "If order is supplied, it must be a non-negative integer";
        }
        if ($direction !~ /^[ab]?$/) {
            croak "If direction is supplied, it must be 'a', 'b', or ''";
        }
        if ($readid) {
            $readid =~ s/^seq.(\d+)([ab]?)\s*//g;
        }
    }

    else {
        if ($readid =~ s/^seq.(\d+)([ab]?)\s*//) {
            $order = $1;
            $direction = $2;
        }
    }

    if (defined($order)) {
        my @parts = ("seq.${order}${direction}");
        if ($readid) {
            push @parts, $readid;
        }
        $readid = join ' ', @parts;
    }        

    $self->{readid}    = $readid;
    $self->{order}     = $order;
    $self->{direction} = $direction;

    return bless $self, $class;
}

sub readid { $_[0]->{readid} }

sub order { shift->{order} }

sub is_forward { shift->_direction eq 'a' }

sub is_reverse { shift->_direction eq 'b' }

sub contains_forward {
    shift->_direction ne 'b';
}

sub contains_reverse {
    shift->_direction ne 'a';
}

sub _direction { shift->{direction} }

sub readid_directionless {
    my ($self) = @_;
    local $_ = $self->readid;
    s/^seq.(\d+)(a|b)/seq.$1/;
    return $_;
}

sub is_same_read {
    my ($self, $other) = @_;
    return $self->readid eq $other->readid;
}

sub is_mate {

    my ($self, $other) = @_;

    return ($other &&
            $self->order == $other->order &&
            (($self->is_forward && $other->is_reverse) ||
             ($self->is_reverse && $other->is_forward)));
}

sub is_same_or_mate {
    my ($x, $y) = @_;
    return $x->is_same_read($y) || $x->is_mate($y);
}


sub cmp_read_ids {
    my ($self, $other) = @_;
    my ($self_num)  = $self->readid  =~ /seq\.(\d+)/g;
    my ($other_num) = $other->readid =~ /seq\.(\d+)/g;
    return $self_num <=> $other_num;
}

1;
