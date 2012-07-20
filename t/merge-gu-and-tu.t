#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use File::Temp;
use Test::More;
use FindBin qw($Bin);

use lib "$Bin/../lib";

use RUM::Alignment;
use RUM::BowtieIO;
use RUM::RUMIO;
use RUM::Script::MergeGuAndTu;
use RUM::TestUtils;
use Data::Dumper;

my $gu  = "$INPUT_DIR/GU.1";
my $tu  = "$INPUT_DIR/TU.1";
my $gnu = "$INPUT_DIR/GNU.1";
my $tnu = "$INPUT_DIR/TNU.1";

#for my $type (qw(paired single)) {
#    my $bowtie_unique  = temp_filename(TEMPLATE=>"$type-bowtie-unique.XXXXXX");
#    my $cnu = temp_filename(TEMPLATE => "$type-cnu.XXXXXX",
#                        UNLINK => 0);
#    @ARGV = ("--gu", $gu, 
#             "--tu", $tu, 
#             "--gnu", $gnu, 
#             "--tnu", $tnu,
#             "--bowtie-unique", $bowtie_unique, 
#             "--cnu", $cnu, 
#             "--$type");
#    
#    RUM::Script::MergeGuAndTu->main();
#    no_diffs($bowtie_unique, "$EXPECTED_DIR/$type-bowtie-unique", 
#         "$type bowtie unique");
#    no_diffs($cnu, "$EXPECTED_DIR/$type-cnu", "$type cnu");
#}

sub aln_array_ref_to_fh {
    my ($alns) = @_;

    my $str = "";

    for my $aln ( @{ $alns } ) {

        if (ref($aln) =~ /ARRAY/) {
            $aln = RUM::Alignment->new(
                readid => $aln->[0],
                chr    => $aln->[1],
                locs   => $aln->[2],
                seq    => $aln->[3],
                strand => $aln->[4],
            );
        }
        my @fields = (
            $aln->readid,
            $aln->chromosome,
            join(", ", map { "$_->[0]-$_->[1]" } @{ $aln->locs }),
            $aln->seq,
            $aln->strand
        );
        $str .= join("\t", @fields) . "\n";
    }

    open my $in, '<', \$str;
    return $in;
}

sub parse_out {
    my ($str) = @_;
    $str ||= '';
    $str =~ s/^\n*//;
    open my $fh, '<', \$str;
    return RUM::RUMIO->new(-fh => $fh,
                           strand_last => 1)->to_array;
}

sub test_merge {
    my %options = @_;

#    warn "Testing with " . Dumper(\%options);
    my $script = RUM::Script::MergeGuAndTu->new;
    
    if (exists $options{read_length}) {
        $script->{read_length} = $options{read_length};
    }

    $script->{max_pair_dist} = 500000;
    
    for my $in_name (qw(gu tu gnu tnu)) {
        $script->{"${in_name}_in_fh"} = aln_array_ref_to_fh($options{"${in_name}_in"});
    }

    open my $bowtie_unique_out, '>', \(my $unique);
    open my $cnu_out,           '>', \(my $cnu);

    $script->{bowtie_unique_out_fh} = $bowtie_unique_out;
    $script->{cnu_out_fh}           = $cnu_out;

    $script->run;
    my $unique_alns = parse_out($unique);
    my $cnu_alns    = parse_out($cnu);

    # Set the 'raw' field of all the alignments we got to undef, since
    # the alignments the caller passed in to this function won't have
    # a raw field.
    for my $aln (@$unique_alns, @$cnu_alns) {
        $aln->{raw} = undef;
    }

    # The expected values were passed in as array refs. Convert them
    # to RUM::Alignments.
    for my $aln (@{ $options{unique_out} }, @{ $options{cnu_out} }) {
        if (ref($aln) =~ /ARRAY/) {
            $aln = RUM::Alignment->new(
                readid => $aln->[0],
                chr    => $aln->[1],
                locs   => $aln->[2],
                seq    => $aln->[3],
                strand => $aln->[4],
            );
        }
    }
    
    is_deeply($unique_alns, $options{unique_out} || [], "Unique out for $options{name}" || []);
    is_deeply($cnu_alns,    $options{cnu_out}    || [], "    NU out for $options{name}" || []);

}

my @tests;

push @tests, {
    name => "Unique forward mapping against genome",
    gu_in      => [ [ 'seq.1a', 'chr1', [[5, 8]], 'AAAA', '+' ] ],
    unique_out => [ [ 'seq.1a', 'chr1', [[5, 8]], 'AAAA', '+' ] ],
};

push @tests, {
    name => "Unique forward mapping against transcriptome",

    tu_in      => [ [ 'seq.2a', 'chr1', [[5, 8]], 'AAAA', '+' ] ],
    unique_out => [ [ 'seq.2a', 'chr1', [[5, 8]], 'AAAA', '+' ] ],
};

push @tests, {
    name => "Unique forward mapping against genome with ambiguous transcriptome",

    gu_in  => [ [ 'seq.3a', 'chr1', [[5, 8]], 'AAAA', '+' ] ],
    tnu_in => [ [ 'seq.3a', 'chr2', [[5, 8]], 'AAAA', '+' ], 
                [ 'seq.3a', 'chr3', [[5, 8]], 'AAAA', '+' ] ]
};

push @tests, {
    name => "Ambiguous genome, forward transcriptome",
    gnu_in => [ [ 'seq.4a', 'chr2', [[5, 8]], 'AAAA', '+' ], 
                [ 'seq.4a', 'chr3', [[5, 8]], 'AAAA', '+' ] ],
    
    tu_in  => [ [ 'seq.4a', 'chr1', [[5, 8]], 'AAAA', '+' ] ],
};

push @tests, {
    name => "Unique reverse mapping against genome",

    gu_in      => [ [ 'seq.5b', 'chr1', [[5, 8]], 'AAAA', '+' ] ],
    unique_out => [ [ 'seq.5b', 'chr1', [[5, 8]], 'AAAA', '+' ] ],
};

push @tests, {
    name => "Unique reverse mapping against transcriptome",

    tu_in      => [ [ 'seq.6b', 'chr1', [[5, 8]], 'AAAA', '+' ] ],
    unique_out => [ [ 'seq.6b', 'chr1', [[5, 8]], 'AAAA', '+' ] ],
};


push @tests, {
    name => "Unique joined mapping against genome",

    gu_in      => [ [ 'seq.7', 'chr1', [[5, 8]], 'AAAA', '+' ] ],
    unique_out => [ [ 'seq.7', 'chr1', [[5, 8]], 'AAAA', '+' ] ],
};

push @tests, {
    name => "Unique joined mapping against transcriptome",

    tu_in      => [ [ 'seq.8', 'chr1', [[5, 8]], 'AAAA', '+' ] ],
    unique_out => [ [ 'seq.8', 'chr1', [[5, 8]], 'AAAA', '+' ] ],
};


push @tests, {
    name => "Unique overlapping joined transcriptome and genome mappings",

    gu_in      => [ ['seq.9', 'chr1', [[1,75]], ('A' x 75), '+' ] ],
    tu_in      => [ ['seq.9', 'chr1', [[1,75]], ('A' x 75), '+' ] ],
    unique_out => [ ['seq.9', 'chr1', [[1,75]], ('A' x 75), '+' ] ],
};

push @tests, {
    name => "Unique non-overlapping joined transcriptome and genome mappings",

    gu_in   => [ [ 'seq.10', 'chr1', [[1, 75]], ('A' x 75), '+' ] ],
    tu_in   => [ [ 'seq.10', 'chr1', [[51, 125]], ('A' x 75), '+' ] ],
    cnu_out => [ [ 'seq.10', 'chr1', [[1,  75]], ('A' x 75), '+' ],
                 [ 'seq.10', 'chr1', [[51, 125]], ('A' x 75), '+' ] ]
};

push @tests, {
    name => "Unique joined transcriptome and genome mappings, different chrs",

    gu_in   => [ [ 'seq.11', 'chr1', [[1,75]], ('A' x 75), '+' ] ],
    tu_in   => [ [ 'seq.11', 'chr2', [[1,75]], ('A' x 75), '+' ] ],

    cnu_out => [ [ 'seq.11', 'chr1', [[1,75]], ('A' x 75), '+' ],
                 [ 'seq.11', 'chr2', [[1,75]], ('A' x 75), '+' ] ],
};

push @tests, {
    name => "Unique identical forward mappings",

    gu_in      => [ [ 'seq.12a', 'chr1', [[1, 75]], ('A' x 75), '+' ] ],
    tu_in      => [ [ 'seq.12a', 'chr1', [[1, 75]], ('A' x 75), '+' ] ],
    unique_out => [ [ 'seq.12a', 'chr1', [[1, 75]], ('A' x 75), '+' ] ],
};

push @tests, {
    name => "Unique identical reverse mappings",

    gu_in      => [ [ 'seq.13b', 'chr1', [[1, 75]], ('A' x 75), '+' ] ],
    tu_in      => [ [ 'seq.13b', 'chr1', [[1, 75]], ('A' x 75), '+' ] ],
    unique_out => [ [ 'seq.13b', 'chr1', [[1, 75]], ('A' x 75), '+' ] ],
};

push @tests, {
    name => "Unique forward genome, reverse transcriptome",

    gu_in      => [ [ 'seq.14a', 'chr1', [[1, 75]], ('A' x 75), '+' ] ],
    tu_in      => [ [ 'seq.14b', 'chr1', [[1, 75]], ('A' x 75), '+' ] ],
    unique_out => [ [ 'seq.14',  'chr1', [[1, 75]], ('A' x 75), '+' ] ],
};

push @tests, {
    name => "Unique reverse genome, forward transcriptome",

    gu_in      => [ [ 'seq.15b', 'chr1', [[1, 75]], ('A' x 75), '+' ] ],
    tu_in      => [ [ 'seq.15a', 'chr1', [[1, 75]], ('A' x 75), '+' ] ],
    unique_out => [ [ 'seq.15',  'chr1', [[1, 75]], ('A' x 75), '+' ] ],
};

push @tests, {
    name => "Unique forward genome, reverse transcriptome, - strand",

    gu_in      => [ [ 'seq.16a', 'chr1', [[1, 75]], ('A' x 75), '-' ] ],
    tu_in      => [ [ 'seq.16b', 'chr1', [[1, 75]], ('A' x 75), '-' ] ],
    unique_out => [ [ 'seq.16',  'chr1', [[1, 75]], ('A' x 75), '-' ] ],
};

push @tests, {
    name => "Unique reverse genome, forward transcriptome, - strand",

    gu_in      => [ [ 'seq.17b', 'chr1', [[1, 75]], ('A' x 75), '-' ] ],
    tu_in      => [ [ 'seq.17a', 'chr1', [[1, 75]], ('A' x 75), '-' ] ],
    unique_out => [ [ 'seq.17',  'chr1', [[1, 75]], ('A' x 75), '-' ] ],
};


push @tests, {
    name => "Unique forward genome, reverse transcriptome, no overlap",

    gu_in      => [ [ 'seq.18a', 'chr1', [[  1,  75]], ('A' x 75), '+' ] ],
    tu_in      => [ [ 'seq.18b', 'chr1', [[101, 175]], ('A' x 75), '+' ] ],
    unique_out => [ [ 'seq.18a',  'chr1', [[1, 75]],    ('A' x 75), '+' ],
                    [ 'seq.18b', 'chr1', [[101, 175]], ('A' x 75), '+' ] ]
};

push @tests, {
    name => "Unique reverse genome, forward transcriptome, no overlap",

    gu_in      => [ [ 'seq.19b', 'chr1', [[101, 175]], ('A' x 75), '+' ] ],
    tu_in      => [ [ 'seq.19a', 'chr1', [[  1,  75]], ('A' x 75), '+' ] ],
    unique_out => [ [ 'seq.19a',  'chr1', [[1, 75]],    ('A' x 75), '+' ],
                    [ 'seq.19b', 'chr1', [[101, 175]], ('A' x 75), '+' ] ]
};


push @tests, {
    name => "Unique forward genome, reverse transcriptome, no overlap",

    gu_in      => [ [ 'seq.20a', 'chr1',  [[101, 175]], ('A' x 75), '-' ] ],
    tu_in      => [ [ 'seq.20b', 'chr1',  [[  1,  75]], ('A' x 75), '-' ] ],
    unique_out => [ [ 'seq.20a',  'chr1', [[101, 175]], ('A' x 75), '-' ],
                    [ 'seq.20b', 'chr1',  [[  1,  75]], ('A' x 75), '-' ] ]
};

push @tests, {
    name => "Unique reverse genome, forward transcriptome, no overlap",

    gu_in      => [ [ 'seq.21b', 'chr1',  [[  1,  75]], ('A' x 75), '-' ] ],
    tu_in      => [ [ 'seq.21a', 'chr1',  [[101, 175]], ('A' x 75), '-' ] ],
    unique_out => [ [ 'seq.21a',  'chr1', [[101, 175]],    ('A' x 75), '-' ],
                    [ 'seq.21b', 'chr1',  [[  1,  75]], ('A' x 75), '-' ] ]
};

push @tests, {
    name => "Unique forward genome, reverse transcriptome, overlap",

    gu_in      => [ [ 'seq.22a', 'chr1', [[  1,  75]], ('A' x 75), '+' ] ],
    tu_in      => [ [ 'seq.22b', 'chr1', [[ 51, 125]], ('A' x 75), '+' ] ],
    unique_out => [ [ 'seq.22',  'chr1', [[  1, 125]], ('A' x 125), '+' ] ]};


push @tests, {
    name => "Unique unjoined genome, unjoined transcriptome",

    gu_in      => [ [ 'seq.23a', 'chr1', [[  1,  75]], ('A' x 75), '+' ],
                    [ 'seq.23b', 'chr1', [[101, 175]], ('A' x 75), '+' ] ],

    tu_in      => [ [ 'seq.23a', 'chr1', [[201, 275]], ('A' x 75), '+' ],
                    [ 'seq.23b', 'chr1', [[301, 375]], ('A' x 75), '+' ] ],

    cnu_out => [ [ 'seq.23a',  'chr1', [[  1,  75]], ('A' x 75), '+' ],
                 [ 'seq.23b',  'chr1', [[101, 175]], ('A' x 75), '+' ],
                 [ 'seq.23a', 'chr1', [[201, 275]], ('A' x 75), '+' ],
                 [ 'seq.23b', 'chr1', [[301, 375]], ('A' x 75), '+' ] ] };

push @tests, {
    name => "Unique joined genome, unjoined transcriptome",

    gu_in      => [ [ 'seq.24', 'chr1', [[  1,  75]], ('A' x 75), '+' ] ],

    tu_in      => [ [ 'seq.24a', 'chr1', [[201, 275]], ('A' x 75), '+' ],
                    [ 'seq.24b', 'chr1', [[301, 375]], ('A' x 75), '+' ] ],

    cnu_out => [ [ 'seq.24',  'chr1', [[  1,  75]], ('A' x 75), '+' ],
                 [ 'seq.24a', 'chr1', [[201, 275]], ('A' x 75), '+' ],
                 [ 'seq.24b', 'chr1', [[301, 375]], ('A' x 75), '+' ] ] };

push @tests, {
    name => "Unique unjoined genome, joined transcriptome",

    gu_in      => [ [ 'seq.25a', 'chr1', [[201, 275]], ('A' x 75), '+' ],
                    [ 'seq.25b', 'chr1', [[301, 375]], ('A' x 75), '+' ] ],

    tu_in      => [ [ 'seq.25', 'chr1', [[  1,  75]], ('A' x 75), '+' ] ],

    cnu_out => [ [ 'seq.25a', 'chr1', [[201, 275]], ('A' x 75), '+' ],
                 [ 'seq.25b', 'chr1', [[301, 375]], ('A' x 75), '+' ],
                 [ 'seq.25',  'chr1', [[  1,  75]], ('A' x 75), '+' ] ] };

push @tests, {
    name => "Unique joined genome, forward transcriptome",

    gu_in      => [ [ 'seq.26',  'chr1', [[  1,  75]], ('A' x 75), '+' ] ],
    tu_in      => [ [ 'seq.26a', 'chr1', [[  1,  75]], ('A' x 75), '+' ] ],

    unique_out => [ [ 'seq.26', 'chr1', [[  1,  75]], ('A' x 75), '+' ] ],
 };


push @tests, {
    name => "Unique joined genome, reverse transcriptome",

    gu_in      => [ [ 'seq.27',  'chr1', [[  1,  75]], ('A' x 75), '+' ] ],
    tu_in      => [ [ 'seq.27b', 'chr1', [[  1,  75]], ('A' x 75), '+' ] ],

    unique_out => [ [ 'seq.27', 'chr1', [[  1,  75]], ('A' x 75), '+' ] ],
 };


push @tests, {
    name => "Unique forward genome, joined transcriptome",

    gu_in      => [ [ 'seq.28a',  'chr1', [[  1,  75]], ('A' x 75), '+' ] ],
    tu_in      => [ [ 'seq.28',   'chr1', [[  1,  75]], ('A' x 75), '+' ] ],

    unique_out => [ [ 'seq.28', 'chr1', [[  1,  75]], ('A' x 75), '+' ] ],
 };

push @tests, {
    name => "Unique forward genome, unjoined transcriptome",

    gu_in      => [ [ 'seq.29a',  'chr1', [[  1,  75]], ('A' x 75), '+' ] ],
    tu_in      => [ [ 'seq.29a',   'chr1', [[  1,  75]], ('A' x 75), '+' ],
                    [ 'seq.29b',   'chr1', [[101, 175]], ('A' x 75), '+' ],
                ],

    unique_out => [ [ 'seq.29a', 'chr1', [[  1,  75]], ('A' x 75), '+' ],
                    [ 'seq.29b', 'chr1', [[101, 175]], ('A' x 75), '+' ],
                ],
 };

push @tests, {
    name => "Unique forward genome, reverse transcriptome, overlap (part 2)",

    gu_in      => [ [ 'seq.30a', 'chr1', [[  1, 40], [ 61, 100] ], ('A' x 80), '+' ] ],
    tu_in      => [ [ 'seq.30b', 'chr1', [[ 31, 70], [ 91, 130] ], ('C' x 80), '+' ] ],
    unique_out => []
};

push @tests, {
    name => "Unique forward genome, reverse transcriptome, overlap (part 3)",

    gu_in      => [ [ 'seq.31a', 'chr1', [[1, 13], [ 21, 29] ], ('A' x 80), '+' ] ],
    tu_in      => [ [ 'seq.31b', 'chr1', [[1, 13], [ 16, 25] ], ('C' x 80), '+' ] ],
    unique_out => [ [ 'seq.31',  'chr1', [[1, 13], [16, 25]], ('A' x 13) . ':' . ('A' x 10), '+'] ]

};

push @tests, {
    name => "Unique forward genome, reverse transcriptome, overlap (part 4)",

    gu_in      => [ [ 'seq.32a', 'chr1', [[1, 5], [ 21, 29], [31, 35] ], ('A' x 80), '+' ] ],
    tu_in      => [ [ 'seq.32b', 'chr1', [[10, 15], [21, 29], [31, 35] ], ('C' x 80), '+' ] ],
    unique_out => [ [ 'seq.32',  'chr1', [[21, 29], [31, 35]], join(':', ('A' x 9), ('A' x 5)) , '+'] ]

};

push @tests, {
    name => "Unique forward genome, reverse transcriptome, overlap (part 5)",

    gu_in      => [ [ 'seq.33a', 'chr1', [ [12, 17], [19, 20], [21, 29], [31, 35] ], ('A' x 80), '+' ] ],
    tu_in      => [ [ 'seq.33b', 'chr1', [ [10, 15], [17, 19], [21, 29], [31, 35] ], ('C' x 80), '+' ] ],
    unique_out => [ [ 'seq.33',  'chr1', [[19, 20], [21, 29], [31, 35]], join(':', 'A' x 2, 'A' x 9, 'A' x 5) , '+'] ]

};

push @tests, {
    name => "Unique forward genome, reverse transcriptome, overlap (part 6)",

    gu_in      => [ [ 'seq.34a', 'chr1', [ [21, 29], [31, 35], [40,41], [43, 48] ], ('A' x 80), '+' ] ],
    tu_in      => [ [ 'seq.34b', 'chr1', [ [21, 29], [31, 35], [38, 43] ], ('C' x 80), '+' ] ],
    unique_out => [ [ 'seq.34',  'chr1', [[21, 29], [31, 35]], join(':', ('A' x 9), ('A' x 5)) , '+'] ]

};

push @tests, {
    name => "Unique forward genome, reverse transcriptome, overlap (part 7)",

    gu_in      => [ [ 'seq.35a', 'chr1', [ [21, 29], [31, 35], [40,41], [43, 48], [52, 55] ], ('A' x 80), '+' ] ],
    tu_in      => [ [ 'seq.35b', 'chr1', [ [21, 29], [31, 35], [38, 43] ], ('C' x 80), '+' ] ],
    unique_out => [ [ 'seq.35',  'chr1', [[21, 29], [31, 35]], join(':', ('A' x 9), ('A' x 5)) , '+'] ]

};

my %big_test = (
    name => 'Big test',
);

my $order = 0;

for my $test (@tests) {
    $order++;
    for my $key (keys %{ $test }) {
        next if $key eq 'name';
        $big_test{$key} ||= [];
        push @{ $big_test{$key} }, @{ $test->{$key} };
    }
}

push @tests, \%big_test;

##############################################################################
##
## Test the merge function
##

my @merge_tests;

push @merge_tests, [
    ['1-10, 21-30', '41-50, 61-70', 'A' x 20, 'C' x 20],
    ['1-10, 21-30, 41-50, 61-70',   'AAAAAAAAAAAAAAAAAAAACCCCCCCCCCCCCCCCCCCC']];
push @merge_tests, [
    ['1-10, 21-30', '30-39, 51-60','A' x 20,'C' x 20],
    ['1-10, 21-39, 51-60',         'AAAAAAAAAAAAAAAAAAAACCCCCCCCCCCCCCCCCCC']];

push @merge_tests, [
    ['1-10, 21-30', '31-39, 51-60', 'A' x 20, 'C' x 20],
    ['1-10, 21-39, 51-60',          'AAAAAAAAAAAAAAAAAAAACCCCCCCCCCCCCCCCCCCC']];

push @merge_tests, [
    ['1-10, 41-50', '21-30, 61-70', 'A' x 20, 'C' x 20],
    []];

push @merge_tests, [
    ['1-10, 21-30', '30-34, 51-65', 'A' x 20, 'C' x 20],
    ['1-10, 21-34, 51-65',          'AAAAAAAAAAAAAAAAAAAACCCCCCCCCCCCCCCCCCC']];

push @merge_tests, [
    ['1-10, 21-30', '21-30, 41-50', 'A' x 20, 'C' x 20],
    ['1-10, 21-30, 41-50', 'AAAAAAAAAAAAAAAAAAAACCCCCCCCCC']];

push @merge_tests, [
    ['1-10, 21-30', '1-10, 41-50', 'A' x 20, 'C' x 20],
    []];

push @merge_tests, [
    ['1-10, 21-41', '30-39, 51-60', 'A' x 20, 'C' x 20],
    []];

push @merge_tests, [
    ['1-15, 21-25', '1-20', 'A' x 20, 'C' x 20],
    ['1-20', 'AAAAAAAAAAAAAAACCCCC']];


push @merge_tests, [
    ['1-15, 21-25', '1-10, 31-40', 'A' x 20, 'C' x 20],
    []];

push @merge_tests, [
    ['1-10, 21-30', '25-30, 36-50', 'A' x 20, 'C' x 20],
    ['1-10, 21-30, 36-50', 'AAAAAAAAAAAAAAAAAAAACCCCCCCCCCCCCC']];

push @merge_tests, [
    ['2-11, 21-30', '1-5, 36-50', 'A' x 20, 'C' x 20],
    ['2-11, 21-30, 36-50', 'AAAAAAAAAAAAAAAAAAAACCCCCCCCCCCCCCC']];

plan tests => scalar(@tests) * 4 + scalar(@merge_tests);

my $count = 0;
for my $test ( @tests ) {
#    next if $test->{name} !~ /Unique forward mapping against transcriptome/;

    $count++;
    $test->{name} = "$count $test->{name}";
    test_merge(%{ $test });
    my %copy = %{ $test };
    $copy{read_length} = 'v';
    $copy{name} .= ", read-length=v";
    test_merge(%copy);
}

for my $test (@merge_tests) {
    my ($in, $out) = @{ $test };
    my @got = RUM::Script::MergeGuAndTu::merge(@{ $in });
    is_deeply(\@got, $out);
}

