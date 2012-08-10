package RUM::Script::GetNuStats;

use strict;
use autodie;
no warnings;

use File::Copy;
use RUM::Usage;
use base 'RUM::Script::Base';

sub main {
    my $self = __PACKAGE__->new;
    $self->get_options("output|o=s" => \(my $outfile));

    my $samfile = $ARGV[0] or RUM::Usage->bad(
        "Please provide a sam file");
    open my $infile, '<', $samfile;

    my $out;
    if ($outfile) {
        open $out, ">", $outfile;
    }
    else {
        $out = *STDOUT;
    }
    
    my $doing = "seq.0";
    while (defined(my $line = <$infile>)) {
        if($line =~ /LN:\d+/) {
            next;
        } else {
            last;
        }
    }

    my %hash;
    while(defined(my $line = <$infile>)) {
        $line =~ /^(\S+)\t.*IH:i:(\d+)\s/;
        my $id = $1;
        my $cnt = $2;
        if(!($line =~ /IH:i:\d+/)) {
            $doing = $id;
            next;
        }
        #    print "id=$id\n";
        #    print "cnt=$cnt\n";
        if($doing eq $id) {
            next;
        } else {
            $doing = $id;
            $hash{$cnt}++;
        }
    }
    
    print $out "num_locs\tnum_reads\n";
    for my $cnt (sort {$a<=>$b} keys %hash) {
        print $out "$cnt\t$hash{$cnt}\n";
    }
    return 0;
}

1;

=head1 NAME

RUM::Script::GetNuStats - Print the count of non-unique mappers by
number of locations mapped.

=head1 METHODS

=over 4

=item main

The main program.

=back

=head1 AUTHOR

Mike DeLaurentis (delaurentis@gmail.com)

=head1 COPYRIGHT

Copyright 2012, University of Pennsylvania


