package RUM::Script::SortByLocation;

use strict;
use warnings;
use autodie;

use RUM::UsageErrors;
use RUM::Logging;
use RUM::Sort qw(cmpChrs);
use RUM::CommandLineParser;

our $log = RUM::Logging->get_logger();

use base 'RUM::Script::Base';

sub summary {
    'Sort a file by location'
}


sub accepted_options {
    return (
        RUM::Property->new(
            opt => 'infile',
            desc => 'Input file',
            required => 1,
            positional => 1),
        RUM::Property->new(
            opt  => 'output|o=s',
            desc => 'Output file',
            required => 1),
        RUM::Property->new(
            opt   => 'location=s',
            desc  => 'Column giving the location in the format "chromosome:start-end"',
            check => \&RUM::CommonProperties::check_int_gte_1
        ),
        RUM::Property->new(
            opt   => 'chromosome=s',
            desc  => 'Column giving the chromosome',
            check => \&RUM::CommonProperties::check_int_gte_1
        ),
        RUM::Property->new(
            opt   => 'start=s',
            desc  => 'Column giving the start position',
            check => \&RUM::CommonProperties::check_int_gte_1
        ),
        RUM::Property->new(
            opt  => 'end=s',
            desc => 'Column giving the end position',
            check => \&RUM::CommonProperties::check_int_gte_1
        ),
        RUM::Property->new(
            opt => 'skip=s',
            desc => 'Number of rows to skip (these rows will be written to the output, but not sorted)',
            check => \&RUM::CommonProperties::check_int_gte_1
        ),
    );
}

sub run {
    my ($self) = @_;
    my $props = $self->properties;

<<<<<<< HEAD
    open my $in,  "<", $infile;
    open my $out, ">", $outfile;
=======
    open my $in,  "<", $props->get('infile');
    open my $out, ">", $props->get('output');
>>>>>>> usage

    for (my $i=0; $i < ($props->get('skip') || 0); $i++) {
        my $line = <$in>;
        print $out $line;
    }

    my %hash;

    while (defined(my $line = <$in>)) {
        chomp($line);
        my @a = split /\t/, $line;
        my ($chr, $start, $end);
<<<<<<< HEAD
        if (defined($location_col)) {
            my $loc = $a[$location_col];
            $loc   =~ /^(.*):(\d+)-(\d+)/;
            $chr   = $1;
=======
        if (defined(my $loc_col = $props->get('location'))) {
            my $loc = $a[$loc_col - 1];
            $loc =~ /^(.*):(\d+)-(\d+)/;
            $chr = $1;
>>>>>>> usage
            $start = $2;
            $end   = $3;
        }
        else {
<<<<<<< HEAD
            $chr   = $a[$chromosome_col];
            $start = $a[$start_col];
            $end   = $a[$end_col];
=======
            $chr   = $a[$props->get('chromosome') - 1];
            $start = $a[$props->get('start') - 1];
            $end   = $a[$props->get('end') - 1];
>>>>>>> usage
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

sub command_line_parser {
    my ($self) = @_;
    my $parser = RUM::CommandLineParser->new;
    for my $opt ($self->accepted_options) {
        $parser->add_prop($opt);
    }
    $parser->add_check(
        sub {
            my ($props) = @_;
            if ($props->has('location')) {
                if ($props->has('chromosome') ||
                    $props->has('start')      ||
                    $props->has('end')) {
                    $props->errors->add("Please specify either --location or --chromosome, --start, and --end");
                }
            }
            else {
                if (! ($props->has('chromosome') &&
                       $props->has('start')      &&
                       $props->has('end'))) {
                    $props->errors->add("Please specify either --location or --chromosome, --start, and --end");
                }
            }
        }
    );
    return $parser;
}

sub synopsis {
    return <<'EOF';
  sort_by_location.pl [OPTIONS] -o <out_file> --location <loc_col> <INPUT>
  sort_by_location.pl [OPTIONS] -o <out_file> --chromosome <chr_col> --start <start_col> --end <end_col> <INPUT>

You must always specify an output file with B<-o> or B<--output>.

If your input file has a single column in the format chr:start-end,
you must give the --location option. If it instead has the chromosome,
start, and end positions in separate columns, you must specify those
options with --chromosome, --start, and --end.
EOF

}

sub description {
    return <<'EOF';
<INPUT> is a tab-delimited file with either one column giving
locations in the format chr:start-end, or with chr, start location,
and end location given in three different columns.
EOF

}

1;
