package RUM::Lock;

use strict;
use warnings;
use Carp;
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
    unlink $FILE if $FILE;
    undef $FILE;
}

sub DESTROY {
    release();
}

1;
