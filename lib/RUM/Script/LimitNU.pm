package RUM::Script::LimitNU;

use strict;
use warnings;
use autodie;

use File::Copy;
use RUM::Usage;
use RUM::Logging;
use RUM::CommonProperties;

use base 'RUM::Script::Base';

our $log = RUM::Logging->get_logger();


sub summary {
    'Remove non-unique mappers that appear more than a specified number of times'
}

sub description {
    return <<'EOF';
Filters a non-unique mapper file so that alignments for reads for
which the either the forward, or reverse if it is paired-end, appear
more than <cutoff> times file are removed.  Alignments of the joined
reads count as one forward and one reverse.
EOF

}

sub accepted_options {
    return (
        RUM::Property->new(
            opt => 'output|o=s',
            desc => 'The output file',
            required => 1),
        RUM::Property->new(
            opt => 'input',
            desc => 'The input RUM_NU file',
            positional => 1,
            required => 1),
        RUM::Property->new(
            opt => 'cutoff|n=s',
            desc => 'The threshold',
            check => \&RUM::CommonProperties::check_int_gte_0,
            default => 0)
    );
}

sub run {
    my ($self) = @_;
    my $props = $self->properties;
    my $infile_name  = $props->get('input');
    my $outfile_name = $props->get('output');
    my $cutoff       = $props->get('cutoff');

    if (!$cutoff) {
        $log->info("Not filtering out mappers");
        copy($infile_name, $outfile_name);
        return 0;
    }

    $log->info("Filtering out mappers that appear $cutoff times or more");

    my (%hash_a, %hash_b);

    open my $infile, "<", $infile_name;
    open my $outfile, ">", $outfile_name;

    while (defined (my $line = <$infile>)) {
        $line =~ /seq.(\d+)([^\d])/;
        my $seqnum = $1;
        my $type = $2;
        if($type eq "a" || $type eq "\t") {
            $hash_a{$seqnum}++;
        }
        if($type eq "b" || $type eq "\t") {
            $hash_b{$seqnum}++;
        }
    }

    seek($infile, 0, 0);
    while(defined (my $line = <$infile>)) {
        $line =~ /seq.(\d+)[^\d]/;
        my $seqnum = $1;
        if(($hash_a{$seqnum}||0) <= $cutoff && 
           ($hash_b{$seqnum}||0) <= $cutoff) {
            print $outfile $line;
        }
    }
}

