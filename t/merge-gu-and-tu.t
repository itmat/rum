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

    for my $aln (@$unique_alns, @$cnu_alns) {
        $aln->{raw} = undef;
    }
    
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
    
    is_deeply($unique_alns, $options{unique_out} || [], $options{name} || []);
    is_deeply($cnu_alns,    $options{cnu_out}    || [], $options{name} || []);

}

my @tests;

push @tests, {
    name => "Unique forward mapping against genome",

    gu_in      => [ [ 'seq.1a', 'chr1', [[5, 8]], 'AAAA', '+' ] ],
    unique_out => [ [ 'seq.1a', 'chr1', [[5, 8]], 'AAAA', '+' ] ],
};

push @tests, {
    name => "Unique forward mapping against transcriptome",

    tu_in      => [ [ 'seq.1a', 'chr1', [[5, 8]], 'AAAA', '+' ] ],
    unique_out => [ [ 'seq.1a', 'chr1', [[5, 8]], 'AAAA', '+' ] ],
};

push @tests, {
    name => "Unique forward mapping against genome with ambiguous transcriptome",

    gu_in  => [ [ 'seq.1a', 'chr1', [[5, 8]], 'AAAA', '+' ] ],
    tnu_in => [ [ 'seq.1a', 'chr2', [[5, 8]], 'AAAA', '+' ], 
                     [ 'seq.1a', 'chr3', [[5, 8]], 'AAAA', '+' ] ]
};

push @tests, {
    name => "Ambiguous genome, forward transcriptome",
    gnu_in => [ [ 'seq.1a', 'chr2', [[5, 8]], 'AAAA', '+' ], 
                     [ 'seq.1a', 'chr3', [[5, 8]], 'AAAA', '+' ] ],

    tu_in  => [ [ 'seq.1a', 'chr1', [[5, 8]], 'AAAA', '+' ] ],
};

push @tests, {
    name => "Unique reverse mapping against genome",

    gu_in      => [ [ 'seq.1b', 'chr1', [[5, 8]], 'AAAA', '+' ] ],
    unique_out => [ [ 'seq.1b', 'chr1', [[5, 8]], 'AAAA', '+' ] ],
};

push @tests, {
    name => "Unique reverse mapping against transcriptome",

    tu_in      => [ [ 'seq.1b', 'chr1', [[5, 8]], 'AAAA', '+' ] ],
    unique_out => [ [ 'seq.1b', 'chr1', [[5, 8]], 'AAAA', '+' ] ],
};


push @tests, {
    name => "Unique joined mapping against genome",

    gu_in      => [ [ 'seq.1', 'chr1', [[5, 8]], 'AAAA', '+' ] ],
    unique_out => [ [ 'seq.1', 'chr1', [[5, 8]], 'AAAA', '+' ] ],
};

push @tests, {
    name => "Unique joined mapping against transcriptome",

    tu_in      => [ [ 'seq.1', 'chr1', [[5, 8]], 'AAAA', '+' ] ],
    unique_out => [ [ 'seq.1', 'chr1', [[5, 8]], 'AAAA', '+' ] ],
};


push @tests, {
    name => "Unique overlapping joined transcriptome and genome mappings",

    gu_in      => [ ['seq.1', 'chr1', [[1,75]], ('A' x 75), '+' ] ],
    tu_in      => [ ['seq.1', 'chr1', [[1,75]], ('A' x 75), '+' ] ],
    unique_out => [ ['seq.1', 'chr1', [[1,75]], ('A' x 75), '+' ] ],
};

push @tests, {
    name => "Unique non-overlapping joined transcriptome and genome mappings",

    gu_in   => [ [ 'seq.1', 'chr1', [[1, 75]], ('A' x 75), '+' ] ],
    tu_in   => [ [ 'seq.1', 'chr1', [[51, 125]], ('A' x 75), '+' ] ],
    cnu_out => [ [ 'seq.1', 'chr1', [[1,  75]], ('A' x 75), '+' ],
                 [ 'seq.1', 'chr1', [[51, 125]], ('A' x 75), '+' ] ]
};

push @tests, {
    name => "Unique joined transcriptome and genome mappings, different chrs",

    gu_in   => [ [ 'seq.1', 'chr1', [[1,75]], ('A' x 75), '+' ] ],
    tu_in   => [ [ 'seq.1', 'chr2', [[1,75]], ('A' x 75), '+' ] ],

    cnu_out => [ [ 'seq.1', 'chr1', [[1,75]], ('A' x 75), '+' ],
                 [ 'seq.1', 'chr2', [[1,75]], ('A' x 75), '+' ] ],
};

push @tests, {
    name => "Unique identical forward mappings",

    gu_in      => [ [ 'seq.1a', 'chr1', [[1, 75]], ('A' x 75), '+' ] ],
    tu_in      => [ [ 'seq.1a', 'chr1', [[1, 75]], ('A' x 75), '+' ] ],
    unique_out => [ [ 'seq.1a', 'chr1', [[1, 75]], ('A' x 75), '+' ] ],
};

push @tests, {
    name => "Unique identical reverse mappings",

    gu_in      => [ [ 'seq.1b', 'chr1', [[1, 75]], ('A' x 75), '+' ] ],
    tu_in      => [ [ 'seq.1b', 'chr1', [[1, 75]], ('A' x 75), '+' ] ],
    unique_out => [ [ 'seq.1b', 'chr1', [[1, 75]], ('A' x 75), '+' ] ],
};

push @tests, {
    name => "Unique forward genome, reverse transcriptome",

    gu_in      => [ [ 'seq.1a', 'chr1', [[1, 75]], ('A' x 75), '+' ] ],
    tu_in      => [ [ 'seq.1b', 'chr1', [[1, 75]], ('A' x 75), '+' ] ],
    unique_out => [ [ 'seq.1',  'chr1', [[1, 75]], ('A' x 75), '+' ] ],
};

push @tests, {
    name => "Unique reverse genome, forward transcriptome",

    gu_in      => [ [ 'seq.1b', 'chr1', [[1, 75]], ('A' x 75), '+' ] ],
    tu_in      => [ [ 'seq.1a', 'chr1', [[1, 75]], ('A' x 75), '+' ] ],
    unique_out => [ [ 'seq.1',  'chr1', [[1, 75]], ('A' x 75), '+' ] ],
};

push @tests, {
    name => "Unique forward genome, reverse transcriptome, - strand",

    gu_in      => [ [ 'seq.1a', 'chr1', [[1, 75]], ('A' x 75), '-' ] ],
    tu_in      => [ [ 'seq.1b', 'chr1', [[1, 75]], ('A' x 75), '-' ] ],
    unique_out => [ [ 'seq.1',  'chr1', [[1, 75]], ('A' x 75), '-' ] ],
};

push @tests, {
    name => "Unique reverse genome, forward transcriptome, - strand",

    gu_in      => [ [ 'seq.1b', 'chr1', [[1, 75]], ('A' x 75), '-' ] ],
    tu_in      => [ [ 'seq.1a', 'chr1', [[1, 75]], ('A' x 75), '-' ] ],
    unique_out => [ [ 'seq.1',  'chr1', [[1, 75]], ('A' x 75), '-' ] ],
};


push @tests, {
    name => "Unique forward genome, reverse transcriptome, no overlap",

    gu_in      => [ [ 'seq.1a', 'chr1', [[  1,  75]], ('A' x 75), '+' ] ],
    tu_in      => [ [ 'seq.1b', 'chr1', [[101, 175]], ('A' x 75), '+' ] ],
    unique_out => [ [ 'seq.1a',  'chr1', [[1, 75]],    ('A' x 75), '+' ],
                    [ 'seq.1b', 'chr1', [[101, 175]], ('A' x 75), '+' ] ]
};

push @tests, {
    name => "Unique reverse genome, forward transcriptome, no overlap",

    gu_in      => [ [ 'seq.1b', 'chr1', [[101, 175]], ('A' x 75), '+' ] ],
    tu_in      => [ [ 'seq.1a', 'chr1', [[  1,  75]], ('A' x 75), '+' ] ],
    unique_out => [ [ 'seq.1a',  'chr1', [[1, 75]],    ('A' x 75), '+' ],
                    [ 'seq.1b', 'chr1', [[101, 175]], ('A' x 75), '+' ] ]
};


push @tests, {
    name => "Unique forward genome, reverse transcriptome, no overlap",

    gu_in      => [ [ 'seq.1a', 'chr1',  [[101, 175]], ('A' x 75), '-' ] ],
    tu_in      => [ [ 'seq.1b', 'chr1',  [[  1,  75]], ('A' x 75), '-' ] ],
    unique_out => [ [ 'seq.1a',  'chr1', [[101, 175]], ('A' x 75), '-' ],
                    [ 'seq.1b', 'chr1',  [[  1,  75]], ('A' x 75), '-' ] ]
};

push @tests, {
    name => "Unique reverse genome, forward transcriptome, no overlap",

    gu_in      => [ [ 'seq.1b', 'chr1',  [[  1,  75]], ('A' x 75), '-' ] ],
    tu_in      => [ [ 'seq.1a', 'chr1',  [[101, 175]], ('A' x 75), '-' ] ],
    unique_out => [ [ 'seq.1a',  'chr1', [[101, 175]],    ('A' x 75), '-' ],
                    [ 'seq.1b', 'chr1',  [[  1,  75]], ('A' x 75), '-' ] ]
};

push @tests, {
    name => "Unique forward genome, reverse transcriptome, overlap",

    gu_in      => [ [ 'seq.1a', 'chr1', [[  1,  75]], ('A' x 75), '+' ] ],
    tu_in      => [ [ 'seq.1b', 'chr1', [[ 51, 125]], ('A' x 75), '+' ] ],
    unique_out => [ [ 'seq.1',  'chr1', [[  1, 125]], ('A' x 125), '+' ] ]};


push @tests, {
    name => "Unique unjoined genome, unjoined transcriptome",

    gu_in      => [ [ 'seq.1a', 'chr1', [[  1,  75]], ('A' x 75), '+' ],
                    [ 'seq.1b', 'chr1', [[101, 175]], ('A' x 75), '+' ] ],

    tu_in      => [ [ 'seq.1a', 'chr1', [[201, 275]], ('A' x 75), '+' ],
                    [ 'seq.1b', 'chr1', [[301, 375]], ('A' x 75), '+' ] ],

    cnu_out => [ [ 'seq.1a',  'chr1', [[  1,  75]], ('A' x 75), '+' ],
                 [ 'seq.1b',  'chr1', [[101, 175]], ('A' x 75), '+' ],
                 [ 'seq.1a', 'chr1', [[201, 275]], ('A' x 75), '+' ],
                 [ 'seq.1b', 'chr1', [[301, 375]], ('A' x 75), '+' ] ] };

push @tests, {
    name => "Unique joined genome, unjoined transcriptome",

    gu_in      => [ [ 'seq.1', 'chr1', [[  1,  75]], ('A' x 75), '+' ] ],

    tu_in      => [ [ 'seq.1a', 'chr1', [[201, 275]], ('A' x 75), '+' ],
                    [ 'seq.1b', 'chr1', [[301, 375]], ('A' x 75), '+' ] ],

    cnu_out => [ [ 'seq.1',  'chr1', [[  1,  75]], ('A' x 75), '+' ],
                 [ 'seq.1a', 'chr1', [[201, 275]], ('A' x 75), '+' ],
                 [ 'seq.1b', 'chr1', [[301, 375]], ('A' x 75), '+' ] ] };

push @tests, {
    name => "Unique unjoined genome, joined transcriptome",

    gu_in      => [ [ 'seq.1a', 'chr1', [[201, 275]], ('A' x 75), '+' ],
                    [ 'seq.1b', 'chr1', [[301, 375]], ('A' x 75), '+' ] ],

    tu_in      => [ [ 'seq.1', 'chr1', [[  1,  75]], ('A' x 75), '+' ] ],

    cnu_out => [ [ 'seq.1a', 'chr1', [[201, 275]], ('A' x 75), '+' ],
                 [ 'seq.1b', 'chr1', [[301, 375]], ('A' x 75), '+' ],
                 [ 'seq.1',  'chr1', [[  1,  75]], ('A' x 75), '+' ] ] };

push @tests, {
    name => "Unique joined genome, forward transcriptome",

    gu_in      => [ [ 'seq.1',  'chr1', [[  1,  75]], ('A' x 75), '+' ] ],
    tu_in      => [ [ 'seq.1a', 'chr1', [[  1,  75]], ('A' x 75), '+' ] ],

    unique_out => [ [ 'seq.1', 'chr1', [[  1,  75]], ('A' x 75), '+' ] ],
 };


push @tests, {
    name => "Unique joined genome, reverse transcriptome",

    gu_in      => [ [ 'seq.1',  'chr1', [[  1,  75]], ('A' x 75), '+' ] ],
    tu_in      => [ [ 'seq.1b', 'chr1', [[  1,  75]], ('A' x 75), '+' ] ],

    unique_out => [ [ 'seq.1', 'chr1', [[  1,  75]], ('A' x 75), '+' ] ],
 };


push @tests, {
    name => "Unique forward genome, joined transcriptome",

    gu_in      => [ [ 'seq.1a',  'chr1', [[  1,  75]], ('A' x 75), '+' ] ],
    tu_in      => [ [ 'seq.1',   'chr1', [[  1,  75]], ('A' x 75), '+' ] ],

    unique_out => [ [ 'seq.1', 'chr1', [[  1,  75]], ('A' x 75), '+' ] ],
 };

push @tests, {
    name => "Unique forward genome, unjoined transcriptome",

    gu_in      => [ [ 'seq.1a',  'chr1', [[  1,  75]], ('A' x 75), '+' ] ],
    tu_in      => [ [ 'seq.1a',   'chr1', [[  1,  75]], ('A' x 75), '+' ],
                    [ 'seq.1b',   'chr1', [[101, 175]], ('A' x 75), '+' ],
                ],

    unique_out => [ [ 'seq.1a', 'chr1', [[  1,  75]], ('A' x 75), '+' ],
                    [ 'seq.1b', 'chr1', [[101, 175]], ('A' x 75), '+' ],
                ],
 };

push @tests, {
    name => "Unique forward genome, reverse transcriptome, overlap",

    gu_in      => [ [ 'seq.1a', 'chr1', [[  1, 40], [ 61, 100] ], ('A' x 80), '+' ] ],
    tu_in      => [ [ 'seq.1b', 'chr1', [[ 31, 70], [ 91, 130] ], ('A' x 80), '+' ] ],
    unique_out => [ [ 'seq.1',  'chr1', [[ 2, 40], [61], [31, 70], [91, 130]], ('A' x 39) . '::' . ('A' x 40) . ':' . ('A' x 40), '+'] ]

};


plan tests => scalar(@tests) * 4;

for my $test ( @tests ) {
    test_merge(%{ $test });
    my %copy = %{ $test };
    $copy{read_length} = 'v';
    test_merge(%copy);
}
