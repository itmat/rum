package RUM::UsageErrors;

use strict;
use warnings;

use Carp;

sub new {
    my ($class, %params) = @_;
    my $self = {};
    my $errors = delete $params{errors} || [];
    if (ref $errors !~ /^ARRAY/) {
        croak "errors should be an array ref";
    }
    $self->{errors} = $errors;
    return bless $self;
}

sub add {
    my ($self, $msg) = @_;
    push @{ $self->{errors} }, $msg;
}

sub errors {
    return @{ shift->{errors} };
}

sub check {
    my ($self) = @_;
    die $self if $self->errors;
}
1;

__END__

=head1 NAME

RUM::UsageErrors - Exception containing one or more usage errors

=head1 SYNOPSIS

  use RUM::UsageErrors;

  my $errors = RUM::UsageErrors->new(
      errors => ['Invalid option -i',
                 'Argument required for '-o']);

  $errors->add('Some other errors');
  die $errors if $errors->errors;

=head1 METHODS

=over 4

=item RUM::UsageErrors->new(%params)

Construct a new UsageErrors object. Accepts an optional 'errors' param
that may be an array ref of strings, each string representing a
diferent problem with the way the user invoked the program.

=item $errors->add($msg)

Add an error

=item $errors->errors

Return the list of errors added.

=item $errors->check

Die with my $self as the exception if there are any errors, otherwise
do nothing.

=back

