package RUM::Alignment;

use strict;
use warnings;

use Carp;

use base 'RUM::Identifiable';

sub new {
    my ($class, %params) = @_;
    my $self = {};

    for my $field (qw(readid chr strand seq)) {
        defined($self->{$field} = delete $params{$field}) 
        or croak "Need $field";
    }
    $self->{raw} = delete $params{raw};


    my $locs = delete $params{locs};
    my $loc  = delete $params{loc};

    if ($loc) {
        croak q{Please provide either 'loc' or 'locs'} if $locs;
        $locs = [[$loc, undef]];
    }

    if ($locs) {
        $self->{locs} = $locs;
    }
    else {
        croak q{Please provide either 'loc' or 'locs'} if $locs;
    }

    return bless $self, $class;
}

sub copy {
    my ($self, %params) = @_;
    my %copy = %{ $self };
    while (my ($k, $v) = each %params) {
        $copy{$k} = $v;
    }
    return __PACKAGE__->new(%copy);
}

sub chromosome { $_[0]->{chr} } 
sub locs       { $_[0]->{locs} }
sub loc        { $_[0]->{loc} } 
sub strand     { $_[0]->{strand} }
sub seq        { $_[0]->{seq} } 
sub starts     { [ map { $_->[0] } @{ $_[0]->{locs} } ] }
sub raw        { $_[0]->{raw} }

sub start { $_[0]->locs->[0][0] }
sub end {
    my ($self) = @_;
    my $nlocs = @{ $self->locs };
    return $self->locs->[$nlocs - 1][1];
}

sub order {
    my ($self) = @_;
    $self->readid =~ /seq.(\d+)/ and return $1;
}

sub as_forward {
    my ($self) = @_;
    my $readid = $self->readid;
    $readid =~ s/(a|b)$//;
    return $self->copy(readid => $readid . "a");
}

sub as_reverse {
    my ($self) = @_;
    my $readid = $self->readid;
    $readid =~ s/(a|b)$//;
    return $self->copy(readid => $readid . "b");
}

sub as_unified {
    my ($self) = @_;
    my $readid = $self->readid;
    $readid =~ s/(a|b)$//;
    return $self->copy(readid => $readid);
}

sub same_direction {
    my ($self, $other) = @_;
    return (($self->is_forward && $other->is_forward) ||
            ($self->is_reverse && $other->is_reverse));
}

sub opposite_direction {
    my ($self, $other) = @_;
    return (($self->is_forward && $other->is_reverse) ||
            ($self->is_reverse && $other->is_forward));
}

sub is_single {
    my @alns = @_;
    return @alns == 1 && ($alns[0]->is_forward || $alns[0]->is_reverse);
}
1;
