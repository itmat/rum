package RUM::Script::MergeJunctions;

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use Carp;
use FindBin qw($Bin);
use RUM::Sort qw(by_location);
use RUM::Script qw(get_options show_usage);

our @SAME_FIELDS = qw(known
                      standard_splice_signal
                      signal_not_canonical 
                      ambiguous);

our @FIELDS_TO_SUM = qw(score
                        long_overlap_unique_reads
                        short_overlap_unique_reads
                        long_overlap_nu_reads
                        short_overlap_nu_reads);

sub main {
    get_options(
        "output|o=s" => \(my $output_filename));
    show_usage() unless $output_filename;

    my $self = __PACKAGE__->new();
    for my $filename (@ARGV) {
        print "Reading $filename\n";
        open my $in, "<", $filename 
            or croak "Can't open $filename for reading: $!";
        $self->read_file($in);
    }
    open my $out, ">", $output_filename
        or croak "Can't open $output_filename for writing: $!";
    $self->print_output($out);
}


sub new {
    my ($class) = @_;
    my $self = { 
        headers => [],
        data    => {}
    };
    return bless $self, $class;
}

sub read_file {
    my ($self, $fh) = @_;
    local $_ = <$fh>;
    chomp;
    my @keys = split /\t/;
    if (my @expected_headers = @{ $self->{headers} }) {
        unless ("@expected_headers" eq "@keys") {
            my $msg = sprintf(
                "File has different headers, expected %s, got %s; skipping.",
                join(", ", @expected_headers),
                join(", ", @keys));
            croak $msg;
        }
    }
    else { 
        $self->{headers} = \@keys;
    }

    my $data = $self->{data};
    
    my $line_num = 0;
    while (defined($_ = <$fh>)) {
        $line_num++;
        chomp;
        my %rec;
        my @vals = split /\t/;
        unless ($#vals == $#keys) {
            carp("Bad number of fields on line " . $line_num .
                     ": expected " . scalar(@keys) . ", got " . scalar(@vals));
        }

        @rec{@keys} = @vals;

        my $intron = $rec{intron};
        unless ($intron) {
            carp("Missing intron for line " . $line_num);
            next;
        }
        if (my $acc = $data->{$intron}) {

            for my $key (@FIELDS_TO_SUM) {
                $acc->{$key} += $rec{$key};
            }

            my @different = grep { $acc->{$_} != $rec{$_} } @SAME_FIELDS;

            if (@different) {
                warn("$intron has different values for these fields: @different");
            }
        }
        else {
            $data->{$intron} = \%rec;
        }
    }
}

sub print_output {
    my ($self, $fh) = @_;
    local $_;
    my @locations;
    my @headers = @{ $self->{headers} };
    my $data = $self->{data};
    for (keys %{ $data }) {
        my ($chr, $start, $end) = /^(.*):(\d*)-(\d*)$/g
            or carp "Invalid location: $_";
        push @locations, { chr => $chr, start => $start, end => $end };
    }

    print "Sorting by location\n";
    @locations = sort by_location @locations;

    print "Writing output\n";
    print $fh join("\t", @headers), "\n";
    for my $loc (@locations) {
        my ($chr, $start, $stop) = @$loc{qw(chr start end)};
        my $key = "$chr:$start-$stop";
        my $row = $data->{$key};
        print $fh join("\t", @$row{@headers}), "\n";
    }
}
