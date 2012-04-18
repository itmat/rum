package RUM::Script::Main;

use strict;
use warnings;

use RUM::Action::Help;
use RUM::Action::Version;
use RUM::Action::Status;
use RUM::Action::Diagram;
use RUM::Action::Clean;
use RUM::Action::Kill;
use RUM::Usage;
use RUM::Directives;
use RUM::Config;
use RUM::Workflows;
use RUM::Script::Runner;

our %ACTIONS = (
    help => "RUM::Action::Help",
    version => "RUM::Action::Version",
    status  => "RUM::Action::Status",
    diagram => "RUM::Action::Diagram",
    clean   => "RUM::Action::Clean",
    kill    => "RUM::Action::Kill",
    run     => "RUM::Script::Runner"
);

sub main {
    my ($class) = @_;

    my $action = shift(@ARGV) || "";

    if (!$action) {
        RUM::Usage->bad("Please specify an action");
    }

    elsif (my $class = $ACTIONS{$action}) {
        $class->run;
    }
    else {
        RUM::Usage->bad("Unknown action '$action'");
    }
}
