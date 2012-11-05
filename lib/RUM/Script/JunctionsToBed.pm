package RUM::Script::JunctionsToBed;

use strict;
use warnings;
use autodie;

use Carp;
use RUM::Logging;

use base 'RUM::Script::Base';

my @OVERLAP_FIELDS = qw(long_overlap_unique_reads
                        short_overlap_unique_reads
                        long_overlap_nu_reads
                        short_overlap_nu_reads);

our $log = RUM::Logging->get_logger();

sub summary {
    'Convert junctions_all.rum to bed format'
}

sub description {
    return <<'EOF';
Converts a junctions_all.rum file into two files in bed format. All
records from the input are written to F<ALL>. Only high-quality
records are written to F<HQ>. F<INPUT> should be a tab-delimited file
with the following fields:

=over 4

=item * intron

=item * strand

=item * score

=item * known

=item * standard_splice_signal

=item * signal_not_canonical

=item * ambiguous      

=item * long_overlap_unique_reads

=item * short_overlap_unique_reads

=item * long_overlap_nu_reads

=item * short_overlap_nu_reads

=back
EOF

}

sub accepted_options {
    return (
        RUM::Property->new(
            opt => 'all|a=s',
            desc => 'Write all junctions here',
            required => 1),
        RUM::Property->new(
            opt => 'high-quality=s',
            desc => 'Write high quality junctions here',
            required => 1),
        RUM::Property->new(
            opt => 'infile',
            desc => 'The junctions_all rum file',
            positional => 1,
            required => 1));
}

sub run {

    my ($self) = @_;
    my $props = $self->properties;
    my $in_filename  = $props->get('infile');
    my $all_filename = $props->get('all');
    my $hq_filename  = $props->get('high_quality');

    open my $all_out, ">", $all_filename;
    open my $hq_out,  ">", $hq_filename;
    open my $in,      "<", $in_filename;
    print "Reading $in_filename\n";

    $self->read_file($in, $all_out, $hq_out);
}


=item RUM::Script::MergeJunctions->new()

Make an instance of the script.

=cut

sub new {
    my ($class) = @_;
    my $self = { };
    return bless $self, $class;
}

=item $script->read_file($in)

Read the junctions from the given filehandle and accumulate them into
$script->{data}.

=cut

sub read_file {
    my ($self, $fh, $all_out, $hq_out) = @_;
    local $_ = <$fh>;
    chomp;
    my @header = split /\t/;

    while (defined($_ = <$fh>)) {
        chomp;

        # Make sure we have the right number of fields
        my @vals = split /\t/;
        unless ($#vals == $#header) {
            carp("Bad number of fields on line $.: expected" .
                     scalar(@header) . ", got " . scalar(@vals));
            next;
        }

        my %rec;
        @rec{@header} = @vals;

        my $intron = $rec{intron};
        my $score  = $rec{score};
        my $known  = $rec{known};

        # Parse chromosome, start, and end from the intron
        unless ($intron) {
            carp("Missing intron for line $. ");
            next;
        }
        my ($chr, $start, $end) = $intron =~ /^(.*):(\d*)-(\d*)$/g
            or carp "Invalid location: $_";
        
        # Add up the values for all the fields that count overlaps.
        my $overlaps = 0;
        for my $key (@OVERLAP_FIELDS) {
            $overlaps += $rec{$key};
        }
        
        my @row;

        # 1) chr
        $row[1] = $chr;
            
        # 2) start - 51
        $row[2] = $start - 51;
            
        # 3) end + 50
        $row[3] = $end + 50;
        
        # 4) Two Cases:
        #   if score = 0: sum of last four cols of .rum file
        #   if score > 1: same as score column (col 3) in .rum file
        $row[4] = $score || $overlaps;

        # 5) same as 4 above.  i.e. cols 4 and 5 of the .bed file
        # are equal
        $row[5] = $score || $overlaps;

        # 6) strand (col 6 of .rum file)
        $row[6] = $rec{strand};

        # 7) identical to column 2.  i.e. cols 2 and 7 of .bed
        # file are equal
        $row[7] = $start - 51;

        # 8) identical to column 3.  i.e. cols 3 and 8 of .bed
        # file are equal
        $row[8] = $end   + 50;

        # 9) 255,69,0 if score (col 3 of .rum file) = 0
        #    0,0,128  if score (col 3 of .rum file) > 0
        $row[9] = $score ? "0,0,128" : "255,69,0";

        # 10) 2
        $row[10] = 2;

        # 11) 50,50
        $row[11] = "50,50";

        # 12) end - start + 51
        $row[12] = $end - $start + 51;


        # We were starting at 1, so get rid of the 0th value
        print $all_out join("\t", @row[1..$#row]), "\n";
        
        if ($score) {
            # col 4 and 5: equal to col 3 of .rum file
            $row[4] = $score;
            $row[5] = $score;
            $row[9] = $known ? "16,78,139" : "0,205,102";
            print $hq_out join("\t", @row[1..$#row]), "\n";
        }
    }
}

=back

=cut

1;
