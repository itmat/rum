#!perl
# -*- cperl -*-

use strict;
use warnings;

use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::CoverageMap;

BEGIN { 
    eval "use Test::Exception";
    plan skip_all => "Test::Exception needed" if $@;
    plan tests => 16;
    use_ok('RUM::CoverageMap');
}

my $data = <<EOF;
track type=bedGraph name="A565_BC7 Unique Mappers" description="A565_BC7 Unique Mappers" visibility=full color=255,0,0 priority=10
chr1\t10008\t10048\t1
chr1\t10048\t10063\t2
chr1\t10063\t10109\t3
chr1\t10109\t10110\t2
chr1\t10110\t10116\t1
chr1\t10116\t10144\t2
chr1\t10144\t10145\t1
chr1\t10145\t10149\t2
chr1\t10149\t10173\t1
chr1\t10178\t10223\t1
chr2\t15765\t15841\t5
chr2\t15841\t15859\t4
chr2\t15859\t15866\t3
chr2\t22944\t23034\t1
chr2\t37292\t37295\t1
chr2\t37295\t37308\t2
chr2\t37308\t37357\t3
chr2\t37357\t37366\t2
chr2\t37366\t37367\t1
chr3\t71511\t71609\t5
chr3\t112243\t12344\t
chr3\t161453\t61554\t
chr3\t180506\t80607\t
EOF

open my $in, "<", \$data;
my $covmap = RUM::CoverageMap->new($in);

ok($covmap->read_chromosome("chr1"), "Read right chromosome");

is_deeply($covmap->{map}[0], [10009, 10048, 1], "First record");
is_deeply($covmap->{map}[9], [10179, 10223, 1], "Tenth record");

is_deeply($covmap->coverage_span(10, 19),
          [[10, 0]],
          "Coverage before any spans");
is_deeply($covmap->coverage_span(1000000, 1000009),
          [[10, 0]],
          "Coverage after any spans");
is_deeply($covmap->coverage_span(10005, 10024),
          [[4, 0], [16, 1]], 
          "Some before span, overlapping first span");
is_deeply($covmap->coverage_span(10220, 10229),
          [[4, 1], [6, 0]], 
          "Overlapping last span, some after");
is_deeply($covmap->coverage_span(10010, 10019), [[10, 1]], "All in one span");
is_deeply($covmap->coverage_span(10170, 10179),
          [[4, 1], [5, 0], [1, 1]],
          "Two spans with gap between");

ok( ! $covmap->read_chromosome("chr3"), "Read wrong chromosome");

ok($covmap->read_chromosome("chr2"), "Read right chromosome");

is_deeply($covmap->coverage_span(22900, 23100),
          [[45, 0], [90, 1], [66, 0]],
          "Spanning an internal span");


throws_ok {
    my $bad_span = <<EOF;
track type=bedGraph name="A565_BC7 Unique Mappers" description="foo" 
chr1\t10008\t1234\t1
EOF
    open my $in, "<", \$bad_span;
    my $covmap = RUM::CoverageMap->new($in);
    $covmap->read_chromosome("chr1");
} qr/invalid span/i;


throws_ok {

    my $overlap = <<EOF;
track type=bedGraph name="A565_BC7 Unique Mappers" description="foo" 
chr1\t10\t20\t1
chr1\t15\t25\t2
EOF

    open my $in, "<", \$overlap;
    my $covmap = RUM::CoverageMap->new($in);
    $covmap->read_chromosome("chr1");
} qr/coverage.*overlap/i;

my $non_overlap = <<EOF;
track type=bedGraph name="A565_BC7 Unique Mappers" description="foo" 
chr1\t10\t20\t1
chr2\t15\t25\t2
EOF
open my $non_overlap_in, "<", \$non_overlap;
$covmap = RUM::CoverageMap->new($non_overlap_in);
ok($covmap->read_chromosome("chr1") && $covmap->read_chromosome("chr2"),
   "Don't report overlap on new chromosome");

