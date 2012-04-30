package RUM::Action::Help;

=head1 NAME

RUM::Action::Help - Prints a help message.

=head1 DESCRIPTION

Prints a help message, or a help message about the configuration file
if 'config' is supplied as the first argument.

=over 4

=cut

use strict;
use warnings;

use Pod::Usage;

use base 'RUM::Base';

=item run

=cut

sub run {
    my ($class) = @_;

    my $action = shift(@ARGV);

    if ($action) {
        pod2usage({-input => "rum_runner/$action.pod",
                  -verbose => 5,
                  -pathlist => \@INC});
    }
    pod2usage(-verbose => 1);
    
}

1;

=back
