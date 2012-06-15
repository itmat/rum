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
        return unless $val;
        
        my @group = ($val);
        
        while ($val = $self->()) {
            last unless $group_fn->($group[0], $val);
            push @group, $val;
        }
        return RUM::Iterator->new(\@group);
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

sub ireduce {
    my $self = shift;
    my $code = shift;

    my @args = @_;

    my $type = Scalar::Util::reftype($code);

    unless($type and $type eq 'CODE') {
        Carp::croak("Not a subroutine reference");
    }
    no strict 'refs';
    
    use vars qw($a $b);
    
    my $caller = caller;
    local(*{$caller."::a"}) = \my $a;
    local(*{$caller."::b"}) = \my $b;
    
    $a = @args ? $args[0] : $self->next_val;

    while ($b = $self->next_val) {
        $a = &{$code}();
    }
    
    return $a;
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

sub append {
    my ($self, $other) = @_;
    my $f = sub {
        my $next = $self->();
        return $next if defined $next; 
        return $other->();
    };
    return blessed($self)->new($f);
}

package RUM::Iterator::Buffered;

use strict;
use warnings;

use Scalar::Util qw(blessed);

use base 'RUM::Iterator';

sub new {
    my ($class, $f) = @_;

    my @buffer;

    my $self = sub {
        my $skip = shift;
        if (defined($skip)) {
            while ($#buffer < $skip) {
                # TODO: If I don't wrap $f->() in scalar(), I get into
                # an infinite loop. Why?
                push @buffer, scalar($f->()); 
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

sub merge {
    my ($self, $cmp, $other, $handle_dup) = @_;

    $handle_dup ||= sub { shift->next_val };

    unless ($other->can('peek')) {
        die "Can only merge with a peekable iterator";
    }

    my $f = sub {
        my $mine   = $self->peek  or return $other->next_val;
        my $theirs = $other->peek or return $self->next_val;
        my $val = $cmp->($mine, $theirs);
        return ($val < 0 ? $self->next_val :
                $val > 0 ? $other->next_val :
                $handle_dup->($self, $other));

    };
    return blessed($self)->new($f);
}

1;
