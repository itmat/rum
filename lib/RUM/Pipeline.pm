package RUM::Pipeline;

use strict;
no warnings;

use Carp;
use RUM::SystemCheck;

use base 'RUM::Base';

use File::Path qw(mkpath);

=pod

=head1 NAME

RUM::Pipeline - RNASeq Unified Mapper Pipeline

=head1 VERSION

Version 2.0.2_01

=cut

our $VERSION = 'v2.0.2_01';
our $RELEASE_DATE = "August 2, 2012";

our $LOGO = <<'EOF';
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                 _   _   _   _   _   _    _
               // \// \// \// \// \// \/
              //\_//\_//\_//\_//\_//\_//
        o_O__O_ o
       | ====== |       .-----------.
       `--------'       |||||||||||||
        || ~~ ||        |-----------|
        || ~~ ||        | .-------. |
        ||----||        ! | UPENN | !
       //      \\        \`-------'/
      // /!  !\ \\        \_  O  _/
     !!__________!!         \   /
     ||  ~~~~~~  ||          `-'
     || _        ||
     |||_|| ||\/|||
     ||| \|_||  |||
     ||          ||
     ||  ~~~~~~  ||
     ||__________||
.----|||        |||------------------.
     ||\\      //||                 /|
     |============|                //
     `------------'               //
---------------------------------'/
---------------------------------'
  ____________________________________________________________
- The RNA-Seq Unified Mapper (RUM) Pipeline has been initiated -
  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
EOF

sub assert_new_job {
    my $self = shift;


}

sub initialize {
    my ($self) = @_;

    my $c = $self->config;

    if ( ! $c->is_new ) {
        die("It looks like there's already a job initialized in " .
            $c->output_dir);
    }
    
    RUM::SystemCheck::check_deps;
    RUM::SystemCheck::check_gamma(
        config => $c);
    
    $self->setup;
    #    $self->get_lock;
    
    my $platform      = $self->platform;
    my $platform_name = $c->platform;
    my $local = $platform_name =~ /Local/;
    
    if ($local) {
        RUM::SystemCheck::check_ram(
            config => $c,
            say => sub { $self->logsay(@_) });
    }
    else {
        $self->say(
            "You are running this job on a $platform_name cluster. ",
            "I am going to assume each node has sufficient RAM for this. ",
            "If you are running a mammalian genome then you should have at ",
            "least 6 Gigs per node");
    }

    $self->say("Saving job configuration");
    $self->config->save;
    return $self->config;
}


sub setup {
    my ($self) = @_;
    my $output_dir = $self->config->output_dir;
    my $c = $self->config;
    my @dirs = (
        $c->output_dir,
        $c->output_dir . "/.rum",
        $c->chunk_dir
    );
    for my $dir (@dirs) {
        unless (-d $dir) {
            mkpath($dir) or die "mkdir $dir: $!";
        }
    }
}

sub reset_job {
    my ($self) = @_;

    my $config = $self->config;

    my $workflows = RUM::Workflows->new($config);

    my $wanted_step = $config->step || 0;

    my $processing_steps;
    
    $self->say("Resetting to step $wanted_step\n");

    for my $chunk (1 .. $config->chunks) {
        my $workflow = $workflows->chunk_workflow($chunk);
        $processing_steps = $self->reset_workflow($workflow, $wanted_step);
    }

    $self->reset_workflow($workflows->postprocessing_workflow, $wanted_step - $processing_steps);
}

sub reset_workflow {
    my ($self, $workflow, $wanted_step) = @_;

    my %keep;
    my $plan = $workflow->state_machine->plan or croak "Can't build a plan";
    my @plan = @{ $plan };
    my $state = $workflow->state_machine->start;
    my $step = 0;
    for my $e (@plan) {
        $step++;
        $state = $workflow->state_machine->transition($state, $e);
        if ($step <= $wanted_step) {
            for my $file ($state->flags) {
                $keep{$file} = 1;
            }
        }
        
    }
    
    my @remove = grep { !$keep{$_} } $state->flags;
    
    unlink @remove;
    return $step;
}



