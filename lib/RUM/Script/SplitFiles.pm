package RUM::Script::SplitFiles;

use strict;
use warnings;
use autodie;

use RUM::UsageErrors;
use Getopt::Long;

use base 'RUM::Script::Base';

sub main {

    my $self = __PACKAGE__->new;

    $self->get_options(
        "merged-output|o=s" => \($self->{all_out_filename} = undef),
        "output|o=s"        => \($self->{chunk_prefix}     = undef),
        "chunks=s"          => \($self->{chunks}           = undef));

    $self->run;

    my $fwd = shift @ARGV;
    my $rev = shift @ARGV;
}

sub parser {
    my ($filename) = @_;

    open my $in, '<', $filename;

    return sub {
        my $header = <$in>;
        if (! defined $header) {
            return;
        }

        my $sequence = <$in>;
        if (!defined $sequence) {
            die "The input file $filename seems to be incomplete. It ends with header line $header\n";
        }

        return ($header, $sequence);
    }
}

sub run {
    my @fhs;
    for my $chunk (1 .. $self->{chunks}) {
        open my $fh, '>', $self->{output} . ".$chunk";
        push @fhs, $fh;
    }

    while (my ($fwd_header, $fwd_seq) = $fwd->()) {

        $counter++;
        my $fh = $fhs[($counter - 1) % $chunks];

        my $lines;

        if ($rev) {
            my ($rev_header, $rev_seq) = $rev->();
            if (!$rev_header) {
                die "Something is wrong, there are more forward reads than reverse reads.\n";
            }
            $lines = ">seq.${counter}a\n$fwd_seq\n>seq.${counter}b\n$rev_seq\n";
        }
        else {
            $lines = ">seq.$counter\n$fwd_seq\n";
        }
        
        print $fh  $lines;
        print $all $lines;
    }
}

       

    
