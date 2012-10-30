package RUM::Script::MergeJunctions;

use strict;
use warnings;
use autodie;

use Carp;
use RUM::Sort qw(by_chromosome);
use RUM::Logging;

use base 'RUM::Script::Base';

our @MIN_FIELDS = qw(ambiguous signal_not_canonical);
our @MAX_FIELDS = qw(known standard_splice_signal);
our @SUM_FIELDS = qw(score
                     long_overlap_unique_reads
                     short_overlap_unique_reads
                     long_overlap_nu_reads
                     short_overlap_nu_reads);

our $log = RUM::Logging->get_logger();

sub summary {
    'Merge junctions_*.rum files together'
}

sub description {
    return <<'EOF';
Takes n input files and produces 1 output file. Input files must be
tab-delimited and must have the following columns:

=over 4

=item intron

=item strand

=item score

=item known

=item standard_splice_signal

=item signal_not_canonical

=item ambiguous      

=item long_overlap_unique_reads

=item short_overlap_unique_reads

=item long_overlap_nu_reads

=item short_overlap_nu_reads

=back

Reads in all the input files and produces a merged output file, where
there is a record for each intron that appeared in any of the input
files. For rows in the input that have the same intron, the new values
of I<score>, I<long_overlap_unique_reads>,
I<short_overlap_unique_reads>, I<long_overlap_nu_reads>, and
I<short_overlap_nu_reads> are the sum of the corresponding fields for
those records in the input data.
EOF

}

sub accepted_options {
    return (
        RUM::Property->new(
            opt => 'output|o=s',
            desc => 'The locatation to write the output data to',
            required => 1,
        ),
        RUM::Property->new(
            opt => 'input',
            desc => 'Input file',
            required => 1,
            positional => 1,
            nargs => '+')
    );
}

sub new {
    my ($self) = @_;
    my $props = $self->properties;
    my $output_filename = $props->get('output');

    for my $filename (@{ $props->get('input') }) {
        print "Reading $filename\n";
        open my $in, "<", $filename;
        $self->read_file($in);
    }
    open my $out, ">", $output_filename;
    $self->print_output($out);
}

sub new {
    my ($class) = @_;
    my $self = $class->SUPER::new;
    $self->{headers} = [];
    $self->{data}    = {};
    $self->{diffs}   = {};
    return $self;
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
