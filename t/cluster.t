#!perl
# -*- cperl -*-

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Data::Dumper;
use Test::More;
use RUM::Config;
use RUM::Platform::Cluster;
use RUM::TestUtils;

BEGIN { 
    my @libs = qw(Test::Exception
                  Test::MockObject
                  Test::MockObject::Extends);
    my @missing;
    for my $lib (@libs) {
        eval "use $lib";
        push @missing, $lib if $@;
    }
    push @missing, "Arabidopsis index" if ! -e $GENOME_FA;
    plan skip_all => "@missing needed" if @missing;
    plan tests => 186;
}


$RUM::Platform::Cluster::CLUSTER_CHECK_INTERVAL=0;

our %DEFAULTS = (name    => 'cluster.t',
                 chunks  => 1,
                 index_dir => $INDEX_DIR);

sub config { RUM::Config->new->set(%DEFAULTS) }

sub cluster {
    Test::MockObject::Extends->new(
        RUM::Platform::Cluster->new(config));
}

################################################################################
###
### Preprocessing
###

# Make sure we can submit the preprocessing task
{
    my $cluster = cluster;
    $cluster->set_true('submit_preproc');
    $cluster->preprocess;
    ok $cluster->called('submit_preproc'), "Preprocess was submitted";
}

################################################################################
###
### Processing
###

# Make sure we can process a single chunk in the happy path. This
# should mimic a run where the workflow completes very quickly without
# any failures.
{
    my $cluster = cluster;
    $cluster->set_true('submit_proc', 'update_status');
    $cluster->mock('chunk_workflow' => sub {
                       Test::MockObject->new->mock('is_complete' => sub { 1 });
                   },
               );

    $cluster->clear;
    $cluster->process;
    
    my $pos = 1;

    $cluster->called_pos_ok(++$pos, 'submit_proc',  "submit the process");
    $cluster->called_args_pos_is($pos, 2, undef, "with no chunks,");
    $cluster->called_pos_ok(++$pos, 'update_status', 'update its status,');
    ok ! $cluster->call_pos(++$pos), "Stopped";
}


# Make sure we can process a specified chunk
{
    my $config = RUM::Config->new(%DEFAULTS);
    my $cluster = Test::MockObject::Extends->new(
        RUM::Platform::Cluster->new($config));
    $cluster->set_true('submit_proc');

    $cluster->process(3);
    
    my $pos = 0;
    $cluster->called_pos_ok(++$pos, 'submit_proc',  "submit the process");
    $cluster->called_args_pos_is($pos, 2, 3, "with the chunk argument,");
    ok ! $cluster->call_pos(++$pos), "Stopped";
}

# Make sure we can process a single chunk in the happy path. This
# should mimic a run where the first time we check on the workflow
# it's not done but the second time it is.
{
    my $cluster = cluster;
    my $done = 0;

    $cluster->set_true('submit_proc', 'proc_ok', 'update_status');
    $cluster->mock('chunk_workflow' => sub {
                       Test::MockObject->new->mock('is_complete' => sub { $done++ });
                   });

    my $results = $cluster->process;

    my $pos = 1;

    $cluster->called_pos_ok(++$pos, 'submit_proc', 'submit the process');
    $cluster->called_args_pos_is($pos, 2, undef, "with no chunks,");
    $cluster->called_pos_ok(++$pos, 'update_status', 'update its status,');
    $cluster->called_pos_ok(++$pos, 'proc_ok', "check if proc was ok,");
    $cluster->called_pos_ok(++$pos, 'update_status', 'update status again,');
    ok ! $cluster->call_pos(++$pos), 'and stop.';
    ok $results->[1],"Chunk should succeed";
}

# Make sure we can process a single chunk that fails once.
{
    my $cluster = cluster;
    my $done = 0;
    my $ok = 0;

    my @is_complete = (0, 0, 0, 0, 0, 0, 0, 1);
    my @proc_ok     = (0, 0, 0, 0, 0, 1);

    $cluster->set_true('submit_proc', 'proc_ok', 'update_status');
    $cluster->mock('chunk_workflow' => sub {
                       Test::MockObject->new->mock('is_complete' => sub { shift @is_complete })
                             ->mock('state' => sub { RUM::State->new });
                   });
    $cluster->mock('proc_ok' => sub { shift @proc_ok  });
    my $pos = 2;
    
    $cluster->clear;
    my $results = $cluster->process;

    $pos = 0;
    while ($cluster->call_pos($pos + 1) eq 'chunk_workflow') {
        $pos++;
    }

    $cluster->called_pos_ok(++$pos, 'submit_proc', 'submit the process');
    $cluster->called_args_pos_is($pos, 2, undef, "with no chunks");

    # Check on it five times
    for (1 .. $RUM::Platform::Cluster::NUM_CHECKS_BEFORE_RESTART) {
        $cluster->called_pos_ok(++$pos, 'update_status', 'update its status,');
        $cluster->called_pos_ok(++$pos, 'proc_ok', "check if the proc is ok,");
    }

    $cluster->called_pos_ok(++$pos, 'submit_proc', 'submit it again,');
    
    for (1 .. 2) {
        $cluster->called_pos_ok(++$pos, 'update_status', 'update its status again,');
        $cluster->called_pos_ok(++$pos, 'proc_ok', "check if the proc is ok,");
        
    }
    $cluster->called_pos_ok(++$pos, 'update_status', 'update its status,');
    ok ! $cluster->call_pos(++$pos), 'and stop.';
    ok $results->[1], "Chunk should succeed";
}

# Make sure we give up on a single chunk that fails too many times.
{
    my $cluster = cluster;
    my $done = 0;
    my $ok = 0;

    $cluster->set_true('submit_proc', 'proc_ok', 'update_status');
    $cluster->mock('chunk_workflow' => sub {
                       Test::MockObject->new->set_false('is_complete')
                             ->mock('state' => sub { RUM::State->new });
                   });
    $cluster->set_false('proc_ok');
    my $pos = 1;
    my $results = $cluster->process;

    $cluster->called_pos_ok(++$pos, 'submit_proc', 'submit the process');
    $cluster->called_args_pos_is($pos, 2, undef, "with no chunks");

    for my $i (1 .. $RUM::WorkflowRunner::MAX_STARTS_PER_STATE + 1) {
    
        # Check on it five times
        for my $j (1 .. $RUM::Platform::Cluster::NUM_CHECKS_BEFORE_RESTART) {
            $cluster->called_pos_ok(++$pos, 'update_status', 'update its status,');
            $cluster->called_pos_ok(++$pos, 'proc_ok', "check if the proc is ok,");
        }

        if ($i <= $RUM::WorkflowRunner::MAX_STARTS_PER_STATE) {
            $cluster->called_pos_ok(++$pos, 'submit_proc', 'submit the process');
            $cluster->called_args_pos_is($pos, 2, 1, "with chunk 1");
        }
        
    }

    ok ! $cluster->call_pos(++$pos), 'and stop.';
    ok ! $results->[1], "Chunk should fail";
}


################################################################################
###
### Postprocessing
###

# Make sure we can do the happy path of postprocessing.
{
    my $cluster = cluster;
    $cluster->set_true('submit_postproc', 'update_status');
    $cluster->mock('postprocessing_workflow' => sub {
                       Test::MockObject->new->set_true('is_complete')
                             ->mock('state' => sub { RUM::State->new });
                   });

    my $result = $cluster->postprocess;

    my $pos = 1;
    $cluster->called_pos_ok(++$pos, 'update_status', 'update its status,');
    $cluster->called_pos_ok(++$pos, 'submit_postproc',  "submit postprocessing");
    $cluster->called_pos_ok(++$pos, 'update_status', 'update its status,');
    ok ! $cluster->call_pos(++$pos), "Stopped";
    ok $result, "Postprocessing succeeded.";
}

# Make sure we do postprocessing when it is not done the first time we
# check but it is the second time.
{
    my $cluster = cluster;
    my $done = 0;

    $cluster->set_true('submit_postproc', 'postproc_ok', 'update_status');
    $cluster->mock('postprocessing_workflow' => sub {
                       Test::MockObject->new->mock('is_complete' => sub { $done++ })
                             ->mock('state' => sub { RUM::State->new })});

    my $result = $cluster->postprocess;

    my $pos = 1;
    $cluster->called_pos_ok(++$pos, 'update_status', 'update its status,');
    $cluster->called_pos_ok(++$pos, 'submit_postproc', 'submit postprocessing');
    $cluster->called_pos_ok(++$pos, 'update_status', 'update its status,');
    $cluster->called_pos_ok(++$pos, 'postproc_ok', "check if postproc was ok,");
    $cluster->called_pos_ok(++$pos, 'update_status', 'update status again,');
    ok ! $cluster->call_pos(++$pos), 'and stop.';
    ok $result, "Postprocessing succeeded.";
}

# Make sure we do postprocessing when it fails once.
{
    my $cluster = cluster;
    my $done = 0;
    my $ok = 0;

    $cluster->set_true('submit_postproc', 'postproc_ok', 'update_status');
    $cluster->mock('postprocessing_workflow' => sub {
                       Test::MockObject->new->mock('is_complete' => sub { $done++ })
                             ->mock('state' => sub { RUM::State->new });
                   });
    $cluster->mock('postproc_ok' => sub {
                       $ok++
                   });
    my $pos = 1;

    my $result = $cluster->postprocess;
    $cluster->called_pos_ok(++$pos, 'update_status', 'update its status,');
    $cluster->called_pos_ok(++$pos, 'submit_postproc', 'submit postprocessing');
    $cluster->called_pos_ok(++$pos, 'update_status', 'update its status,');
    $cluster->called_pos_ok(++$pos, 'postproc_ok', "check if the proc is ok,");
    $cluster->called_pos_ok(++$pos, 'submit_postproc', 'submit it again,');
    $cluster->called_pos_ok(++$pos, 'update_status', 'update its status again,');
    ok ! $cluster->call_pos(++$pos), 'and stop.';
    ok $result, "Postprocessing should succeed";
}


# Make sure we give up on a single chunk that fails too many times.
{
    my $cluster = cluster;

    $cluster->set_true('submit_postproc', 'postproc_ok', 'update_status');
    $cluster->mock('postprocessing_workflow' => sub {
                       Test::MockObject->new->set_false('is_complete')
                             ->mock('state' => sub { RUM::State->new });
                   });
    $cluster->set_false('postproc_ok');
    my $pos = 1;

    my $result = $cluster->postprocess;
    $cluster->called_pos_ok(++$pos, 'update_status', 'update its status,');
    $cluster->called_pos_ok(++$pos, 'submit_postproc', 'submit the postprocess');
    $cluster->called_args_pos_is($pos, 2, undef, "with no chunks");
    $cluster->called_pos_ok(++$pos, 'update_status', 'update its status,');
    $cluster->called_pos_ok(++$pos, 'postproc_ok', "check if the postproc is ok,");
    $cluster->called_pos_ok(++$pos, 'submit_postproc', 'submit it again,');
    $cluster->called_pos_ok(++$pos, 'update_status', 'update its status again,');
    $cluster->called_pos_ok(++$pos, 'postproc_ok', "check if the postproc is ok,");
    $cluster->called_pos_ok(++$pos, 'submit_postproc', 'submit it again,');
    $cluster->called_pos_ok(++$pos, 'update_status', 'update its status again,');
    $cluster->called_pos_ok(++$pos, 'postproc_ok', "check if the postproc is ok,");
    $cluster->called_pos_ok(++$pos, 'submit_postproc', 'submit it again,');
    $cluster->called_pos_ok(++$pos, 'update_status', 'update its status again,');
    $cluster->called_pos_ok(++$pos, 'postproc_ok', "check if the postproc is ok,");
    $cluster->called_pos_ok(++$pos, 'submit_postproc', 'submit it again,');
    $cluster->called_pos_ok(++$pos, 'update_status', 'update its status again,');
    $cluster->called_pos_ok(++$pos, 'postproc_ok', "check if the postproc is ok,");
    $cluster->called_pos_ok(++$pos, 'submit_postproc', 'submit it again,');
    $cluster->called_pos_ok(++$pos, 'update_status', 'update its status again,');
    $cluster->called_pos_ok(++$pos, 'postproc_ok', "check if the postproc is ok,");
    $cluster->called_pos_ok(++$pos, 'submit_postproc', 'submit it again,');
    $cluster->called_pos_ok(++$pos, 'update_status', 'update its status again,');
    $cluster->called_pos_ok(++$pos, 'postproc_ok', "check if the postproc is ok,");
    ok ! $cluster->call_pos(++$pos), 'and stop.';
    ok ! $result, "Postproc should fail";
}

################################################################################
###
### Unimplemented methods
###

my $cluster = RUM::Platform::Cluster->new(config);
throws_ok { $cluster->submit_preproc } qr/not implemented/i, "submit_preproc not implemented";
throws_ok { $cluster->submit_proc } qr/not implemented/i, "submit_proc not implemented";
throws_ok { $cluster->submit_postproc } qr/not implemented/i, "submit_postproc not implemented";

throws_ok { $cluster->update_status } qr/not implemented/i, "update_status not implemented";
throws_ok { $cluster->proc_ok } qr/not implemented/i, "proc_ok not implemented";
throws_ok { $cluster->postproc_ok } qr/not implemented/i, "postproc_ok not implemented";

################################################################################
###
### Getting workflows
###

{
    my $cluster = cluster;
    ok $cluster->chunk_workflow(1)->isa("RUM::Workflow"), 
        "Get chunk workflow";
    ok $cluster->postprocessing_workflow->isa("RUM::Workflow"), 
        "Get postproc workflow";
}

