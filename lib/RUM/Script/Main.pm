package RUM::Script::Main;

use strict;
use warnings;

our %ACTIONS = (
    help => "RUM::Action::Help",
    '-h' => "RUM::Action::Help",
    '-help' => "RUM::Action::Help",
    '--help' => "RUM::Action::Help",
    version => "RUM::Action::Version",
    status  => "RUM::Action::Status",
    diagram => "RUM::Action::Diagram",
    clean   => "RUM::Action::Clean",
    kill    => "RUM::Action::Kill",
    run     => "RUM::Action::Run"
);

sub main {
    my ($class) = @_;

    my $action = shift(@ARGV) || "";

    if (!$action) {
        die "Please specify an action\n";
    }

    elsif (my $class = $ACTIONS{$action}) {
        my $file = $class;
        $file =~ s/::/\//g;
        $file .= ".pm";
        require $file;
        $class->run;
    }
    else {
        die "Unknown action '$action'\n";
    }
}
