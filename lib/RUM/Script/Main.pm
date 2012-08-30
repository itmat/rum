package RUM::Script::Main;

use strict;
use warnings;

use RUM::Config;
use RUM::Directives;
use RUM::Usage;
use RUM::Workflows;

our %ACTIONS = (
    help     => "RUM::Action::Help",
    '-h'     => "RUM::Action::Help",
    '-help'  => "RUM::Action::Help",
    '--help' => "RUM::Action::Help",
    version  => "RUM::Action::Version",
    status   => "RUM::Action::Status",
    init     => "RUM::Action::Init",
    start    => "RUM::Action::Start",
    restart  => "RUM::Action::Start",
    clean    => "RUM::Action::Clean",
    stop     => "RUM::Action::Stop",
    align    => "RUM::Action::Align",
    profile  => "RUM::Action::Profile",
    kill     => 'RUM::Action::Kill',
    reset    => 'RUM::Action::Reset'
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
