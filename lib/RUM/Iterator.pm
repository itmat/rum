package RUM::Iterator;

use strict;
use warnings;

use Carp;
use Scalar::Util qw(blessed);

sub new {
    my ($class, $x) = @_;
    
    my $f;

    if (ref($x) =~ /^ARRAY/) {
        my $i = 0;
        $f = sub { $i <= $#$x ? $x->[$i++] : undef };
    }
    
    elsif (ref($x) =~ /^CODE/) {
        $f = $x;
    }

    else {
        croak "Don't know how to iterate over $x";
    }

    bless $f, $class;
}

sub group_by {
    my ($self, $group_fn) = @_;
    
    my $val = $self->();
    
    my $it = sub {
        return undef unless $val;
        
        my @group = ($val);
        
        while ($val = $self->()) {
            last unless $group_fn->($group[0], $val);
            push @group, $val;
        }
       return \@group;
    };


    return RUM::Iterator->new($it);
}

sub next_val {
    my ($self) = @_;
    $self->();
}

sub take {
    my ($self) = @_;
    $self->();
}

sub peekable {
    my ($self) = @_;
    return RUM::Iterator::Buffered->new($self);
}

sub to_array {
    my ($self) = @_;
    my @result;
    while (defined(my $item = $self->())) {
        push @result, $item;
    }
    return \@result;
}

sub imap {
    my $self = shift;
    my $f    = shift;
    my $next_item = sub {
        my $item = $self->();
        return defined($item) ? $f->($item) : undef;
    };
    return blessed($self)->new($next_item);
}

sub igrep {
    my $self = shift;
    my $f    = shift;
    my $next_item = sub {
        my $item;
        do { $item = $self->() } until ((!defined($item)) || $f->($item));
        return $item;
    };
    return blessed($self)->new($next_item);

}


package RUM::Iterator::Buffered;

use strict;
use warnings;

use base 'RUM::Iterator';

sub new {
    my ($class, $f) = @_;

    my @buffer;

    my $self = sub {
        my $skip = shift;
        if (defined($skip)) {
            while ($#buffer < $skip) {
                push @buffer, $f->();
            }
            return $buffer[$skip];
        }
        elsif (@buffer) {
            return shift @buffer;
        }
        else {
            $f->();
        }
    };
   
    bless $self, $class;
}

sub peek {
    my $self = shift;
    my $steps = shift || 0;
    $self->($steps);
}

1;
