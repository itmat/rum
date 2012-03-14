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

use Carp;
use RUM::Sort qw(by_chromosome);
use RUM::Usage;
use RUM::Logging;
use Getopt::Long;

our @MIN_FIELDS = qw(ambiguous signal_not_canonical);
our @MAX_FIELDS = qw(known standard_splice_signal);
our @SUM_FIELDS = qw(score
                     long_overlap_unique_reads
                     short_overlap_unique_reads
                     long_overlap_nu_reads
                     short_overlap_nu_reads);

our $log = RUM::Logging->get_logger();

=item $script->main()

Main method, runs the script. Expects @ARGV to be populated.

=cut

sub main {
    GetOptions(
        "output|o=s" => \(my $output_filename),
        "help|h"    => sub { RUM::Usage->help },
        "verbose|v" => sub { $log->more_logging(1) },
        "quiet|q"   => sub { $log->less_logging(1) });
    $output_filename or RUM::Usage->bad(
        "Please provide an output file with -o or --output");

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
        data    => {},
        diffs   => {}
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
            carp "File has different headers: expected $expected, got $got; skipping.";
            return 0;
        }
    }
    else { 
        $self->{headers} = \@keys;
    }

    my $data = $self->{data};
    my $diffs = $self->{diffs};

    my %stats = (old => 0, new => 0);

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

        my ($chr, $start, $end) = $intron =~ /^(.*):(\d*)-(\d*)$/g
            or carp "Invalid location: $_";

#        $data->{$chr} ||= {};
#        $data->{$chr}->{$start} ||= {};
        my $acc = $data->{$chr}->{$start}->{$end} ||= {};

        if (keys %$acc) {
            $stats{old}++;
            for my $key (@SUM_FIELDS) {
                $acc->{$key} += $rec{$key};
            }
            
            for my $key (@MIN_FIELDS) {
                my $old = $acc->{$key};
                my $new = $rec{$key};
                if ($old != $new) {
                    $log->debug("$intron on line $. has different values for $key");
                    $diffs->{$key}->{$intron} = 1;
                    $acc->{$key} = $new < $old ? $new : $old;
                }
            }

            for my $key (@MAX_FIELDS) {
                my $old = $acc->{$key};
                my $new = $rec{$key};
                if ($old != $new) {
                    $diffs->{$key}->{$intron} = 1;
                    $log->debug("$intron on line $. has different values for $key");
                    $acc->{$key} = $new > $old ? $new : $old;
                }
            }
        }
        else {
            $stats{new}++;
            %$acc = %rec;
        }

    }
    return %stats;
}

=item $script->print_output($out)

Sort $self->{data} by location and print all the records to the given
filehandle.

=cut

sub print_output {
    my ($self, $fh) = @_;
    my @headers = @{ $self->{headers} };

    my $data = $self->{data};

    print $fh join("\t", @headers), "\n";

    my $count = 0;

    print "Sorting chromosomes\n" if $self->{verbose};
    for my $chr (sort by_chromosome keys %{ $data }) {
        my $with_chr = $data->{$chr};
        print "  Sorting by start for $chr\n" if $self->{verbose};
        for my $start (sort { $a <=> $b } keys %{ $with_chr } ) {
            my $with_start = $with_chr->{$start};
            for my $end (sort { $a <=> $b } keys %{ $with_start } ) {
                my $row = $with_start->{$end};
                $count++;
                print $fh join("\t", @$row{@headers}), "\n";
            }
        }
    }

    my %diffs = %{ $self->{diffs} };
    
    if (keys %diffs) {
        print "\nThere were some records that had different values for fields\n".
            "that should not differ:\n";
        
        printf "%30s %10s %s\n", "Field", "Records", "Percent";
        for my $key (keys %diffs) {
            my $diffs = scalar keys %{ $diffs{$key} };
            printf "%30s %10d (%.2f%%)\n", $key, $diffs, 100.0 * $diffs / $count;
        }
    }


}

=back

=cut

1;
