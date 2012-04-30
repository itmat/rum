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

    my %actions = map { ( $_ => 1 ) } qw(align clean kill status version help);

    my $action = shift(@ARGV) || "";
    if ($actions{$action}) {
        RUM::Usage->new(action => $action)->help;
    }
    elsif ($action eq 'config') {
        print $RUM::ConfigFile::DOC;
    }
    else {
        RUM::Usage->help;
    }

}

1;

=back
