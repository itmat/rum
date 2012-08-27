package RUM::Directives;

=head1 NAME

RUM::Directives - Bundle of boolean flags that tell rum_runner what tasks to do

=head1 SYNOPSIS

  my $d = RUM::Directives->new;

  $d->set_<directive>;

  $d->unset_<directive>;

  if ($d-><directive>) {
    ...
  }

=head1 DESCRIPTION

Bundles together a bunch of boolean options that the user can provide.
Some of those options are I<actions>, which tell rum_runner what to
do, and others are I<modifiers>, which change the behavior of an
I<action>. Please see L<rum_runner> for a description of the actions
and modifiers.

=cut


use strict;
use warnings;

use Carp;

our $AUTOLOAD;

# This are just boolean flags that modify the behavior of the
# actions.
our @MODIFIERS = qw(
    quiet
    child
    parent
    preprocess
    process
    postprocess
    all
);

=head1 CONSTRUCTORS

=over 4

=item new

=back

=cut

sub new {
    my ($class) = @_;
    my %self = map { ($_ => undef) } @MODIFIERS;
    $self{all} = 1;
    bless \%self, $class;
}

sub AUTOLOAD {
    my $self = shift;
    
    my @parts = split /::/, $AUTOLOAD;
    local $_ = $parts[-1];
    
    return if $_ eq "DESTROY";

    my $val;

    if (/(set|unset)_(.*)/) {
        $val = $1 eq 'set';
        $_ = $2;
    }

    exists $self->{$_} or croak "No directive called $_";

    if (defined $val) {
        $self->{$_} = $val;
    }
    
    return $self->{$_};
}

