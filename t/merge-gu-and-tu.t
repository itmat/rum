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
        warn "Aln is $aln\n";
        my @fields = (
            $aln->readid,
            $aln->chromosome,
            $aln->locs->[0][0] . "-" . $aln->locs->[0][1],
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
    $str =~ s/^\n*//;
    open my $fh, '<', \$str;
    return RUM::RUMIO->new(-fh => $fh,
                           strand_last => 1)->to_array;
}

sub test_merge {
    my %options = @_;

    my $script = RUM::Script::MergeGuAndTu->new;
    
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

plan tests => scalar(@tests) * 2;

for my $test ( @tests ) {
    test_merge(%{ $test });
}
