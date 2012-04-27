package RUM::Usage;

=head1 NAME

RUM::Usage - Utilities for printing usage info

=head1 SYNOPSIS

  use RUM::Usage;
  use Getopt::Long;

  # Automatically print help if user gives -h or --help
  GetOptions(
      ...
      "help|h" => \&RUM::Usage::help);

  # Correct the user on their usage of the script
  $some_required_option or RUM::Usage->bad(
      "Please supply a value for --some-required option");


  # Accumulate multiple errors
  my $usage = RUM::Usage->new;
  $foo or $usage->bad("Please give --foo");
  $bar or $usage->bad("Please give --bar");
  $usage->check;

=head1 CLASS METHODS

=over 4

=item help

Print the usage info (though not the full man page).

=item man

Print the full man page.

=item bad($msg)

Correct the user on their usage of the program. Prints the given
message followed by the contents of the SYNOPSIS section.

=back

=head1 OBJECT INTERFACE

If you want to accumulate multiple usage errors and print them all at
one time, use these methods.

=over 4

=item RUM::Usage->new

Create an accumulator for usage issues.

=item $usage->bad($msg)

Add a usage message to the list of problems.

=item $usage->check

If I<bad> was called, exit with all of the messages that were
given. Otherwise return normally.

=back

=head1 AUTHOR

Mike DeLaurentis (delaurentis@gmail.com)

=head1 COPYRIGHT

Copyright 2012 University of Pennsylvania

=cut

use strict;
use warnings;
use Pod::Usage;

sub new {
    my ($class) = @_;
    bless [], $class;
}

sub help {
    pod2usage({-verbose => 1,
               -message => "\nPlease see perldoc $0 for more information.\n"});
}

sub man {
   pod2usage({-verbose => 2});
}

sub bad {
    my ($self, $msg) = @_;

    if (ref($self)) {
        push @{ $self }, $msg;
        return;
    }

    my ($package) = caller(0);
    my $log = RUM::Logging->get_logger();
    $log->fatal("Improper usage of $package->main(): $msg");
    pod2usage({
        -message => "\n$msg\n",
        -verbose => 0,
        -exitval => "NOEXIT"});
    if ($0 =~ /rum$/) {
        print("Please see $0 help for more information.\n");
    }
    else {
        print("Please see $0 --help for more information.\n");
    }

    exit(1);
}

sub check {
    my ($self) = @_;
    if (@$self) {
        my $msg = "Usage errors:\n\n" . join("\n", @$self);
        __PACKAGE__->bad($msg);
    }
}

1;
