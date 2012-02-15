package RUM::FileIterator;

use strict;
use warnings;

use Exporter qw(import);
use Carp;

our @EXPORT_OK = qw(file_iterator pop_it peek_it);


sub read_record {
    my ($in, %options) = @_;
    my $separate = $options{separate};
    my $line1 = <$in>;
        
    # When we hit EOF, close the input and return undef for all
    # subsequent values. We're using undef to indicate the end of
    # the iterator.
    unless (defined $line1) {
        close $in;
        return undef;
    }
    
    chomp($line1);
    
    # This is basically the same as before, but rather than
    # storing the values in several global hashes, we're creating
    # a hash for each element in the iterator, keyed on chr,
    # start, end, and entry.
    my %res;
    my @a = split(/\t/,$line1);
    $res{chr} = $a[1];
    $a[2] =~ /^(\d+)-/;
    $res{start} = $1;
    if ($a[0] =~ /a/ && !$separate) {
        $a[0] =~ /(\d+)/;
        my $seqnum1 = $1;
        my $line2 = <$in>;
        chomp($line2);
        my @b = split(/\t/,$line2);
        $b[0] =~ /(\d+)/;
        my $seqnum2 = $1;
        if($seqnum1 == $seqnum2 && $b[0] =~ /b/) {
            if($a[3] eq "+") {
                $b[2] =~ /-(\d+)$/;
                $res{end} = $1;
            } else {
                $b[2] =~ /^(\d+)-/;
                $res{start} = $1;
                $a[2] =~ /-(\d+)$/;
                $res{end} = $1;
            }
            $res{entry} = $line1 . "\n" . $line2;
        } else {
            $a[2] =~ /-(\d+)$/;
            $res{end} = $1;
            # reset the file handle so the last line read will be read again
            my $len = -1 * (1 + length($line2));
            seek($in, $len, 1);
            $res{entry} = $line1;
        }
    } else {
        $a[2] =~ /-(\d+)$/;
        $res{end} = $1;
        $res{entry} = $line1;
    }
    chomp($res{entry});
    
    return \%res;
    
}

sub file_iterator {
    my ($in, %options) = @_;
    my $separate = $options{separate};
    
    # Call $nextval immediately so that a call to peek_it will work right
    # away.
    my $next = read_record($in, %options);
    
    return sub {
        my $cmd = shift() || "pop";
        if ($cmd eq "peek") {
            return $next;
        }
        elsif ($cmd eq "pop") {
            my $last = $next;
            $next = read_record($in, %options);
            return $last;
        }
    }
}

sub peek_it {
    my $it = shift;
    croak "I need an iterator" unless ref($it) =~ /CODE/;
    return $it->("peek");
}

sub pop_it {
    my $it = shift;
    croak "I need an iterator" unless ref($it) =~ /CODE/;
    return $it->("pop");
}

1;
