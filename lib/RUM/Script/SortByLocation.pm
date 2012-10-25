package RUM::Script::SortByLocation;

use strict;
use warnings;

use Data::Dumper;

use RUM::UsageErrors;
use RUM::Logging;
use RUM::Sort qw(cmpChrs);
use RUM::CommandLineParser;

our $log = RUM::Logging->get_logger();

sub check_int_gte_1 {
    my ($props, $prop, $val) = @_;
    if (defined($val)) {
        if ($val !~ /^\d+$/ ||
            int($val) < 1) {
            $props->errors->add($prop->options . " must be an integer greater than 1");
        }
    }
}

sub main {

    my $parser = RUM::CommandLineParser->new;

    $parser->add_prop(
        opt  => 'output|o=s',
        desc => 'Output file',
        required => 1);

    $parser->add_prop(
        opt   => 'location=s',
        desc  => 'Column giving the location in the format "chromosome:start-end"',
        check => \&check_int_gte_1
    );

    $parser->add_prop(
        opt   => 'chromosome=s',
        desc  => 'Column giving the chromosome',
        check => \&check_int_gte_1
    );

    $parser->add_prop(
        opt   => 'start=s',
        desc  => 'Column giving the start position',
        check => \&check_int_gte_1,
    );

    $parser->add_prop(
        opt  => 'end=s',
        desc => 'Column giving the end position',
        check => \&check_int_gte_1,
    );

    $parser->add_prop(
        opt => 'skip=s',
        desc => 'Number of rows to skip (these rows will be written to the output, but not sorted)',
        check => \&check_int_gte_1,
    );

    $parser->add_prop(
        opt => 'infile',
        desc => 'Input file',
        required => 1,
        positional => 1
    );
    
    my $props = $parser->parse;
    
    my $errors = RUM::UsageErrors->new;
    
    if ($props->has('location')) {
        if ($props->has('chromosome') ||
            $props->has('start')      ||
            $props->has('end')) {
            $errors->add("Please specify either --location or --chromosome, --start, and --end");
        }
    }
    else {
        if (! ($props->has('chromosome') &&
               $props->has('start')      &&
               $props->has('end'))) {
            $errors->add("Please specify either --location or --chromosome, --start, and --end");
        }
    }
    $errors->check;

    open my $in,  "<", $props->get('infile');
    open my $out, ">", $props->get('output');

    for (my $i=0; $i < ($props->get('skip') || 0); $i++) {
        my $line = <$in>;
        print $out $line;
    }

    my %hash;

    while (defined(my $line = <$in>)) {
        chomp($line);
        my @a = split(/\t/,$line);
        my ($chr, $start, $end);
        if (defined(my $loc_col = $props->get('location'))) {
            my $loc = $a[$loc_col - 1];
            $loc =~ /^(.*):(\d+)-(\d+)/;
            $chr = $1;
            $start = $2;
            $end = $3;
        }
        else {
            $chr   = $a[$props->get('chromosome') - 1];
            $start = $a[$props->get('start') - 1];
            $end   = $a[$props->get('end') - 1];
        }
        $hash{$chr}{$line}[0] = $start;
        $hash{$chr}{$line}[1] = $end;
    }
    close($in);

    for my $chr (sort {cmpChrs($a,$b)} keys %hash) {
        for my $line (sort {
            $hash{$chr}{$a}[0]<=>$hash{$chr}{$b}[0] ||
                $hash{$chr}{$a}[1]<=>$hash{$chr}{$b}[1]
            } keys %{$hash{$chr}}) {
            chomp($line);
            if ($line =~ /\S/) {
                print $out "$line\n";
            }
        }
    }
}

1;
