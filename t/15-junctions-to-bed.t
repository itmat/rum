#!perl
# -*- cperl -*-

use Test::More tests => 40;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use strict;
use warnings;

BEGIN { 
  use_ok('RUM::Script::JunctionsToBed');
}

my @header = qw(intron  strand  score   known   standard_splice_signal  
                 signal_not_canonical    ambiguous      
                 long_overlap_unique_reads
                 short_overlap_unique_reads
                 long_overlap_nu_reads
                 short_overlap_nu_reads);

my $input1 = [
    # High quality, known
    ["chr1:100-125", ".",  1, 1,  2,  3,  5,  2,  3,  5,  7],
    
    # Low quality
    ["chr1:100-125", ".",  0, 0,  2,  3,  5,  2,  3,  5,  7],

    # High quality, unknown
    ["chr1:100-125", ".",  1, 0,  2,  3,  5,  2,  3,  5,  7]];

sub format_input {
    my $table = shift;
    my $text = join("\t", @header) . "\n";
    for my $row (@$table) {
        $text .= join("\t", @$row) . "\n";
    }
    return $text;
}

sub make_input {
    my $text = format_input(shift);
    open my $in, "<", \$text;
    return $in;
}

sub line_iterator {
    my $text = shift;
    open my $fh, "<", \$text;
    return sub {
        local $_ = <$fh>;
        return unless defined $_;
        chomp;
        my @row = split /\t/;
        unshift @row, undef;
        return @row;
    }
}

{
    my $script = RUM::Script::JunctionsToBed->new();
    open my $all_fh, ">", \(my $all);
    open my $high_fh, ">", \(my $high);

    $script->read_file(make_input($input1), $all_fh, $high_fh);
    
    close($all_fh);
    close($high_fh);
    
    my $it = line_iterator($all);
    my @row = $it->();
    is($row[1], "chr1", "Field 1 is chromosome");
    is($row[2], 49, "Field 2 is start - 51");
    is($row[3], 175, "Field 3 is end + 50");
    is($row[4], 1, "Field 4 is score");
    is($row[5], 1, "Field 5 is score");
    is($row[6], ".", "Field 6 is strand");
    is($row[7], 49, "Field 7 is start - 51");
    is($row[8], 175, "Field 8 is end + 50");
    is($row[9], "0,0,128", "Field 9 when score is > 0");
    is($row[10], 2, "Field 10 is 2");
    is($row[11], "50,50", "Field 11 is 50,50");
    is($row[12], 76, "Field 12 is end - start + 51");

    @row = $it->();
    is($row[1], "chr1", "Field 1 is chromosome");
    is($row[2], 49, "Field 2 is start - 51");
    is($row[3], 175, "Field 3 is end + 50");
    is($row[4], 17, "Field 4 is overlaps");
    is($row[5], 17, "Field 5 is overlaps");
    is($row[6], ".", "Field 6 is strand");
    is($row[7], 49, "Field 7 is start - 51");
    is($row[8], 175, "Field 8 is end + 50");
    is($row[9], "255,69,0", "Field 9 when score is > 0");
    is($row[10], 2, "Field 10 is 2");
    is($row[11], "50,50", "Field 11 is 50,50");
    is($row[12], 76, "Field 12 is end - start + 51");

    ok($it->(), "Low quality record in all file");

    $it = line_iterator($high);

    @row = $it->();
    is($row[1], "chr1", "Field 1 is chromosome");
    is($row[2], 49, "Field 2 is start - 51");
    is($row[3], 175, "Field 3 is end + 50");
    is($row[4], 1, "Field 4 is score");
    is($row[5], 1, "Field 5 is score");
    is($row[6], ".", "Field 6 is strand");
    is($row[7], 49, "Field 7 is start - 51");
    is($row[8], 175, "Field 8 is end + 50");
    is($row[9], "16,78,139", "Field 9 when score is > 0");
    is($row[10], 2, "Field 10 is 2");
    is($row[11], "50,50", "Field 11 is 50,50");
    is($row[12], 76, "Field 12 is end - start + 51");    

    @row = $it->();
    is($row[9], "0,205,102", "Field 9 when score is > 0");

    ok(!$it->(), "No more records in high quality file");
    
}
