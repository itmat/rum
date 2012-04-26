use Test::More tests => 8;

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
    use_ok('RUM::Workflow', qw(pre post));
}

my $w = RUM::Workflow->new();

$w->add_command(
    name => "code ref of array ref of array refs",
    commands => sub { 
        [["sort", "input", ">", "intermediate"],
         ["uniq", "-c", "intermediate", ">", "output"]]
    }
);

$w->add_command(
    name => "array ref of array refs",
    commands => 
        [["sort", "input", ">", "intermediate"],
         ["uniq", "-c", "intermediate", ">", "output"]]
);


$w->add_command(
    name => "with tags",
    commands => [[
        "sort", pre("input"), ">", post("output")
    ]]
);

is_deeply([$w->commands("array ref of array refs")],
          [["sort", "input", ">", "intermediate"],
           ["uniq", "-c", "intermediate", ">", "output"]],
          "array ref of array refs");

is_deeply([$w->commands("code ref of array ref of array refs")],
          [["sort", "input", ">", "intermediate"],
           ["uniq", "-c", "intermediate", ">", "output"]],
          "code ref of array ref of array refs");

my @cmds = $w->commands("with tags");
is($cmds[0][0], "sort", "with tags");
is($cmds[0][1], "input", "with tags");
is($cmds[0][2], ">", "with tags");
like($cmds[0][3], qr/output/, "with tags");

my $in = "$SHARED_INPUT_DIR/forward64.fq";
$w = RUM::Workflow->new();
my $out = temp_filename(TEMPLATE => "workflow.XXXXXX", UNLINK => 0);

unlink $out;
$w->start([$in]);
$w->step("copy input to output", ["cp", pre($in), post($out)]);
$w->set_goal([$out]);
$w->execute;
ok(-e $out, "Task was executed");
