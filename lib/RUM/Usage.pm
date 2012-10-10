package RUM::Usage;

use strict;
use warnings;
use Pod::Usage;

sub new {
    my ($class, %opts) = @_;
    my ($self) = {};
    $self->{action} = $opts{action};
    $self->{errors} = [];
    bless $self, $class;
}

sub help {

    my ($self) = @_;
    my $action = ref($self) ? $self->{action} : undef;

    # Since the user explicitly asked for help, be verbose. 
    my %options = (-verbose => 2);
    
    # If the user specified an action, show the help for that
    # action. That will be in "rum_runner/$action.pod", on a directory
    # in our path. We need to tell Pod::Usage where our path is so it
    # can find it.
    if ($action) {
        $options{-input} = "rum_runner/$action.pod";
        $options{-pathlist} = \@INC;
    }

    # By default Pod::Usage with -verbose set to 2 will run perldoc to
    # print a nicely formatted, paginated help message. However, if
    # you run perldoc as root, it turns on taint checking, and if you
    # run perldoc in a directory where there's a Makefile.PL file,
    # Pod::Perldoc will add some stuff to our @INC that taints it. So
    # basically you can't run perldoc as root in a directory that
    # contains a Makefile.PL file. So if that's the case, tel
    # Pod::Usage not to run perldoc.
    my $is_root = ! $<;
    $options{-noperldoc} = 1 if $is_root && -e "Makefile.PL";
    pod2usage(\%options);
}

sub man {
   pod2usage({-verbose => 2});
}

sub bad {

    my $self = shift;
    my $msg  = shift || '';

    if (ref($self)) {
        push @{ $self->{errors} }, $msg;
        return;
    }

    my ($package) = caller(0);
    my $log = RUM::Logging->get_logger();
    $log->info("Improper usage of $package->main(): $msg");
    print STDERR "\n";
    pod2usage({
        -verbose => 0,
        -exitval => "NOEXIT"});
    if ($0 =~ /rum_runner$/) {
        print "Please see $0 help for more information.\n";
    }
    else {
        $msg .= "\n\nPlease see $0 --help for more information.\n";
    }

    die "$msg\n";
}

sub check {
    my ($self) = @_;
    my @errors = @{ $self->{errors} };
    if (@errors) {
        my $msg = "Usage errors:\n\n" . join("\n", map { "* $_" } @errors);
        my $log = RUM::Logging->get_logger();
        my ($package) = caller(0);        
        my $action;
        if ($package =~ /RUM::Action::(.*)/) {
            $action = lc $1;
        }

        if ($action) {

            $log->info("Improper usage of $package->main(): $msg");
            pod2usage({
                -message => "\n$msg\n",
                -input => "rum_runner/$action.pod",
                -pathlist => \@INC,
                -verbose => 0,
                -exitval => "NOEXIT"});
            print "Please see $0 help $action for more information\n";
        }
        else {
            __PACKAGE__->bad($msg);
        }
        exit (1);
    }
}

1;

__END__

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

