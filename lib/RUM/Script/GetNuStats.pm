package RUM::Script::GetNuStats;

use strict;
no warnings;
use autodie;

use File::Copy;
use RUM::Logging;
use Getopt::Long;

our $log = RUM::Logging->get_logger();

use base 'RUM::Script::Base';

sub summary {
    'Read a sam file and print counts for non-unique mappers'
}

sub accepted_options {
    return (
        RUM::Property->new(
            opt => 'output|o=s', 
            desc => 'The output file.',
            required => 1),
        RUM::Property->new(
            opt => 'samfile',
            desc => 'SAM input file',
            required => 1,
            positional => 1)
      );
}

sub run {
    my ($self) = @_;
    my $props = $self->properties;
    my $outfile = $props->get('output');
    my $samfile = $props->get('samfile');

    open INFILE, '<', $samfile;

    my $out;
    if ($outfile) {
        open $out, ">", $outfile;
    }
    else {
        $out = *STDOUT;
    }

    my $doing = "seq.0";
    while (defined(my $line = <INFILE>)) {
        if($line =~ /LN:\d+/) {
            next;
        } else {
            last;
        }
    }

    my %hash;
    while(defined(my $line = <INFILE>)) {
        $line =~ /^(\S+)\t.*IH:i:(\d+)\s/;
        my $id = $1;
        my $cnt = $2;
        if(!($line =~ /IH:i:\d+/)) {
            $doing = $id;
            next;
        }
        #    print "id=$id\n";
        #    print "cnt=$cnt\n";
        if ($doing eq $id) {
            next;
        } else {
            $doing = $id;
            $hash{$cnt}++;
        }
    }
    close(INFILE);

    print $out "num_locs\tnum_reads\n";
    for my $cnt (sort {$a<=>$b} keys %hash) {
        print $out "$cnt\t$hash{$cnt}\n";
    }
    return 0;
}
