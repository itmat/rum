use Test::More tests => 13;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Repository;
use RUM::TestUtils;
use RUM::WorkflowRunner;
use File::Path;
use File::Temp qw(tempdir);
use strict;
use warnings;

BEGIN { 
    use_ok('RUM::Workflow');
    use_ok('RUM::WorkflowRunner');
}

my $w = RUM::Workflow->new();
my $tmpdir = File::Temp->newdir;
my $step1 = "$tmpdir/step1";
my $step2 = "$tmpdir/step2";

$w->add_command(
    name => "step1",
    pre => [],
    post => [$step1],
    comment => "Echo some words to a file",
    code => sub { [[]] });

$w->add_command(
    name => "step2",
    pre => [],
    post => [$step2],
    comment => "Echo some words to a file",
    code => sub { [[]] });


{
    my $runner = RUM::WorkflowRunner->new($w, sub { });
    $RUM::WorkflowRunner::MAX_STARTS_PER_STATE = 2;
    
    ok($runner->run(), "First run in start state");
    ok($runner->run(), "Second run in start state");
    ok(!$runner->run(), "Won't start third time in same state");
}


{
    my $runner = RUM::WorkflowRunner->new($w, sub { });
    $RUM::WorkflowRunner::MAX_STARTS_PER_STATE = 2;
    
    ok($runner->run(), "First run in start state");
    ok($runner->run(), "Second run in start state");
    open my $out, ">", $step1;
    close $out;
    ok($runner->run(), "First start in second state");
    ok($runner->run(), "Second start in second state");
    ok(!$runner->run(), "Won't start third time in same state");
}


{
    my $runner = RUM::WorkflowRunner->new($w, sub { });
    $RUM::WorkflowRunner::MAX_STARTS_PER_STATE = 5;
    $RUM::WorkflowRunner::MAX_STARTS = 2;
    
    ok($runner->run(), "First run in start state");
    open my $out, ">", $step1;
    close $out;
    ok($runner->run(), "First start in second state");
    ok(!$runner->run(), "Won't start third time");
}
