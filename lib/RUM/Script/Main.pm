package RUM::Script::Main;

use strict;
use warnings;

use RUM::Config;
use RUM::Usage;
use RUM::Workflows;

our %ACTIONS = (
    help     => "RUM::Action::Help",
    '-h'     => "RUM::Action::Help",
    '-help'  => "RUM::Action::Help",
    '--help' => "RUM::Action::Help",

    version  => "RUM::Action::Version",

    align    => "RUM::Action::Align",
    init     => "RUM::Action::Init",
    status   => "RUM::Action::Status",
    resume   => "RUM::Action::Resume",
    stop     => "RUM::Action::Stop",
    clean    => "RUM::Action::Clean",
    profile  => "RUM::Action::Profile",
    kill     => 'RUM::Action::Kill',
);

sub main {
    my ($class) = @_;

    my $action = shift(@ARGV) || "";

    if (!$action) {
        RUM::Usage->bad("Please specify an action");
    }

    elsif (my $class = $ACTIONS{$action}) {
        my $file = $class;
        $file =~ s/::/\//g;
        $file .= ".pm";
        require $file;
        $class->run;
    }
    else {
        RUM::Usage->bad("Unknown action '$action'");
    }
}
