package RUM::Pipeline;

use strict;
no warnings;



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

