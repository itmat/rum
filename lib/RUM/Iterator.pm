package RUM::Iterator;

use strict;
use warnings;

<<<<<<< Updated upstream
use Carp;

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
=======
sub new {
    my ($class, $f) = @_;
    
    my $val = $f->();
    my $self = sub {
        $f->();
    };
    bless $self, $class;
}

sub groupby {
    my ($group_fn) = @_;

    my $val = $it->();

    my $it = sub {
        return unless $val;

        my @group = ($val);

        while ($val = $it->()) {
            if ($group_fn->($group[0], $val)) {
                push @group, $val;
            }
>>>>>>> Stashed changes
        }

        return \@group;
    };

<<<<<<< Updated upstream
    return RUM::Iterator->new($it);
}

sub take {
    my ($self) = @_;
    $self->();
}

sub peekable {
    my ($self) = @_;
    return RUM::Iterator::Buffered->new($self);
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
=======
    bless $it, $class;
}
>>>>>>> Stashed changes
