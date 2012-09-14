use strict;
use warnings;
use Test::More;

# Ensure a recent version of Test::Pod::Coverage
my $min_tpc = 1.08;
eval "use Test::Pod::Coverage $min_tpc";
plan skip_all => "Test::Pod::Coverage $min_tpc required for testing POD coverage"
    if $@;

# Test::Pod::Coverage doesn't require a minimum Pod::Coverage version,
# but older versions don't recognize some common documentation styles
my $min_pc = 0.18;
eval "use Pod::Coverage $min_pc";
plan skip_all => "Pod::Coverage $min_pc required for testing POD coverage"
    if $@;

# Skip any modules that start with RUM::Script::, as these are
# typically documented in their *.pl file. Also skip RUM::Config, as
# it has a lot of tiny methods that are not worth documenting right
# now and are self-explanatory.
my @modules = grep {

    /RUM::Script::RumToCov/ || !/^RUM::(Script::|Action)/
} all_modules();

plan tests => scalar(@modules);

#plan skip_all => "Skip pod covereage for now";

for my $module (@modules) {
    pod_coverage_ok($module);
}

#all_pod_coverage_ok();

