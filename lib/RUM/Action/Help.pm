package RUM::Action::Help;

use strict;
use warnings;

use base 'RUM::Script::Base';

sub accepted_options { }

sub run {
    my ($self) = @_;

    my $action = shift(@ARGV) || "";

    if (my $action_class = $RUM::Script::Main::ACTIONS{$action}) {

        my $file = $action_class;
        $file =~ s/::/\//g;
        $file .= ".pm";
        require $file;
        $action_class->show_help;
    }
    else {
        RUM::Usage->help;
    }

}

1;

=back
