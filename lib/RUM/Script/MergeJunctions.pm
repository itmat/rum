package RUM::Script::MergeJunctions;

=pod

=head1 NAME

RUM::Script::MergeJunctions - Script for merging junction files

=head1 SYNOPSIS

use RUM::Script::MergeJunctions;
RUM::Script::MergeJunctions->main();

=head1 METHODS

=over 4

=cut

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use Carp;
use FindBin qw($Bin);
use RUM::Sort qw(by_location);
use RUM::Script qw(get_options show_usage);

our @MIN_FIELDS = qw(ambiguous signal_not_canonical);
our @MAX_FIELDS = qw(known standard_splice_signal);
our @SUM_FIELDS = qw(score
                     long_overlap_unique_reads
                     short_overlap_unique_reads
                     long_overlap_nu_reads
                     short_overlap_nu_reads);

=item $script->main()

Main method, runs the script. Expects @ARGV to be populated.

=cut

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


=item RUM::Script::MergeJunctions->new()

Make an instance of the script.

=cut

sub new {
    my ($class) = @_;
    my $self = { 
        headers => [],
        data    => {}
    };
    return bless $self, $class;
}

=item $script->read_file($in)

Read the junctions from the given filehandle and accumulate them into
$script->{data}.

=cut

sub read_file {
    my ($self, $fh) = @_;
    local $_ = <$fh>;
    chomp;
    my @keys = split /\t/;
    if (my @expected_headers = @{ $self->{headers} }) {
        my $expected = join(", ", @expected_headers);
        my $got = join(", ", @keys);
        unless ($got eq $expected) {
            carp "File has different headers, expected $expected, got $got";
            return 0;
        }
    }
    else { 
        $self->{headers} = \@keys;
    }

    my $data = $self->{data};
    
    while (defined($_ = <$fh>)) {
        chomp;
        my %rec;
        my @vals = split /\t/;
        unless ($#vals == $#keys) {
            carp("Bad number of fields on line $.: expected" .
                     scalar(@keys) . ", got " . scalar(@vals));
        }

        @rec{@keys} = @vals;

        my $intron = $rec{intron};
        unless ($intron) {
            carp("Missing intron for line $. ");
            next;
        }
        if (my $acc = $data->{$intron}) {

            for my $key (@SUM_FIELDS) {
                $acc->{$key} += $rec{$key};
            }
            
            for my $key (@MIN_FIELDS) {
                my $old = $acc->{$key};
                my $new = $rec{$key};
                if ($old != $new) {
                    carp("$intron on line $. has different values for $key");
                }
                $acc->{$key} = $new < $old ? $new : $old;
            }

            for my $key (@MAX_FIELDS) {
                my $old = $acc->{$key};
                my $new = $rec{$key};
                if ($old != $new) {
                    carp("$intron on line $. has different values for $key");
                }
                $acc->{$key} = $new > $old ? $new : $old;
            }

        }
        else {
            $data->{$intron} = \%rec;
        }
    }
}

=item $script->print_output($out)

Sort $self->{data} by location and print all the records to the given
filehandle.

=cut

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

=back

=cut

1;
