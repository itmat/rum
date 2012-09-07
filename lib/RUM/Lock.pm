package RUM::Lock;

use strict;
use warnings;

use Carp;

our $FILE;

sub acquire {
    my ($self, $file) = @_;
    return undef if -e $file;
    $FILE = $file;
    open my $out, ">", $file or croak "Can't open lock file $file: $!";
    print $out $$;
    close $out;
    return 1;
}

sub release {
    if ($FILE) {
        unlink $FILE if $FILE;
        undef $FILE;
    }
}

sub DESTROY {
    release();
}

sub register_sigint_handler {
    $SIG{INT} = $SIG{TERM} = sub {
        my $msg = "Caught SIGTERM, removing lock.";
        warn $msg;
        RUM::Logging->get_logger->info($msg);
        RUM::Lock->release;
        exit 1;
    };

}

1;

=head1 NAME

RUM::Lock - Prevents two rum jobs from running on the same output dir.

=head1 SYNOPSIS

=head1 DESCRIPTION

When the user runs C<rum run>, we should attempt to acquire a lock
file by doing RUM::Lock->acquire("$output_dir/.rum/lock"). Then when
the pipeline is done, we should release the lock by doing
RUM::Lock->release. Note that we use only one global lock file at a
time; this class is not instantiable. Calling release when you do not
actually have the lock does nothing. In cases where the process that
the user ran kicks off other jobs and exits, it is necessary for the
top-most process to pass the lock down to a child process. This is
done by passing the filename as a parameter with the B<--lock> option
to C<rum run>.

=head1 CLASS METHODS

=over 4

=cut


=item RUM::Lock->acquire($filename)

If $filename exists, return undef, otherwise create it and return a
true value. The presence if the file indicates that the lock is held
by "someone".

=cut

=item RUM::Lock->release

Release the lock by removing the file, if I own the lock. If I don't,
do nothing.

=cut

=item RUM::Lock->register_sigint_handler

Register a signal handler that removes the lock file if the process is
killed.

=back
