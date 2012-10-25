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

sub new {
    my ($class, %params) = @_;

    my $self = {};
    $self->{opt}       = delete $params{opt}     or croak "Need opt";
    $self->{desc}      = delete $params{desc};
    $self->{filter}    = delete $params{filter}  || sub { shift };
    $self->{handler}   = delete $params{handler} || \&handle;
    $self->{checker}   = delete $params{check}   || sub { return };
    $self->{default}   = delete $params{default};
    $self->{transient} = delete $params{transient};
    $self->{group}     = delete $params{group};
    $self->{required}  = delete $params{required};
    $self->{positional}  = delete $params{positional};

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

sub options {
    my $opt = shift->opt;
    $opt =~ s/=.*$//;
    my @opts = split /\|/, $opt;
    @opts = map { length > 1 ? "--$_" : "-$_" } @opts;
    my $opts = join " or ", @opts;
    return $opts;
}

1;
