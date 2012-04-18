package RUM::Lock;

use strict;
use warnings;

use Carp;

use RUM::Logging;
our $log = RUM::Logging->get_logger;

our $FILE;

sub acquire {
    my ($self, $file) = @_;
    warn "Here I am\n";
    return undef if -e $file;
    $FILE = $file;
    open my $out, ">", $file or croak "Can't open lock file $file: $!";
    print $out $$;
    close $out;
    return 1;
}

sub release {
    if ($FILE) {
        $log->info("Releasing lock $FILE") ;
        unlink $FILE if $FILE;
        undef $FILE;
    }
    else {
        $log->info("No lock file to release");
    }
}

sub DESTROY {
    release();
}

1;
