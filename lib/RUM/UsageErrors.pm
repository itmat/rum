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
1;
