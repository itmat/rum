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
    clean    => "RUM::Action::Clean",
    stop     => "RUM::Action::Stop",
    align    => "RUM::Action::Align",
    profile  => "RUM::Action::Profile",
    kill     => 'RUM::Action::Kill'
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

__END__

=head1 NAME

RUM::Script::Main - Main program for rum_runner

=head1 METHODS

=over 4

=item main

Select the action the user wants based on the first argument on the
command line, and run that action.

=back

=head1 AUTHOR

Mike DeLaurentis (delaurentis@gmail.com)

=head1 COPYRIGHT

Copyright 2012, University of Pennsylvania


