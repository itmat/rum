package RUM::ChunkMachine;

use strict;
use warnings;

use RUM::StateMachine;
use RUM::ChunkConfig;
use FindBin qw($Bin);
FindBin->again();

sub new {
    my ($class, $config) = @_;

    my $self = {};

    my $m = RUM::StateMachine->new();

    my $start          = $m->start;      
    my $genome_bowtie  = $m->flag("genome_bowtie");
    my $trans_bowtie   = $m->flag("genome_transcriptome");
    my $gu             = $m->flag("gu");
    my $gnu            = $m->flag("gnu");
    my $tu             = $m->flag("tu");
    my $tnu            = $m->flag("tnu");
    my $bowtie_unique  = $m->flag("bowtie_unique");
    my $bowtie_nu      = $m->flag("bowtie_nu");
    my $unmapped       = $m->flag("unmapped");

    # From the start state we can run bowtie on either the genome or
    # the transcriptome
    $m->add($start, $genome_bowtie, "run_bowtie_on_genome");
    $m->add($start, $trans_bowtie,  "run_bowtie_on_transcriptome");

    # If we have the genome bowtie output, we can make the unique and
    # non-unique files for it.
    $m->add($genome_bowtie,        $gu | $gnu, "make_gu_and_gnu");

    # If we have the transcriptome bowtie output, we can make the
    # unique and non-unique files for it.
    $m->add($trans_bowtie, $tu | $tnu, "make_tu_and_tnu");

    # If we have the non-unique files for both the genome and the
    # transcriptome, we can merge them.
    $m->add($tnu | $gnu, $bowtie_nu, "merge_gnu_tnu_cnu");

    # If we have the unique files for both the genome and the
    # transcriptome, we can merge them.
    $m->add($tu | $gu, $bowtie_unique, "merge_gu_tu");

    # If we have the merged bowtie unique mappers and the merged
    # bowtie non-unique mappers, we can create the unmapped file.
    $m->add($bowtie_unique | $bowtie_nu,
            $unmapped,
            \&make_unmapped_file);

    $m->set_goal($bowtie_unique | $bowtie_nu);

    $self->{sm} = $m;
    $self->{config} = $config;

    return bless $self, $class;
}

sub make_unmapped_file {
    my ($conf) = @_;
    [["perl", "$Bin/make_unmapped_file.pl",
      "--reads", "READSFILE.CHUNK",
      "--unique", "OUTDIR/BowtieUnique.CHUNK",
      "--non-unique", "OUTDIR/BowtieNU.CHUNK",
      "-o", "OUTDIR/R.CHUNK",
      "--PAIREDEND"]];
}

sub run_bowtie_on_genome {
    my ($chunk) = @_;
        
    [[$chunk->bowtie_bin,
      "-a", 
      "--best", 
      "--strata",
      "-f", $chunk->genome_bowtie,
      $chunk->reads_file,
      "-v", 3,
      "--suppress", "6,7,8",
      "-p", 1,
      "--quiet",
      "> ", $chunk->genome_bowtie_out]];
}      


sub run_bowtie_on_transcriptome {
    my ($chunk) = @_;
        
    [[$chunk->bowtie_bin,
      "-a", 
      "--best", 
      "--strata",
      "-f", $chunk->transcriptome_bowtie,
      $chunk->reads_file,
      "-v", 3,
      "--suppress", "6,7,8",
      "-p", 1,
      "--quiet",
      "> ", $chunk->transcriptome_bowtie_out]];
}      

sub make_gu_and_gnu {
    my ($chunk) = @_;
    [["perl", "$Bin/make_GU_and_GNU.pl", 
      "--unique", $chunk->gu,
      "--non-unique", $chunk->gnu,
      $chunk->paired_end_option(),
      $chunk->genome_bowtie_out()]];
}

sub make_tu_and_tnu {
    my ($chunk) = @_;
    [["perl", "$Bin/make_TU_and_TNU.pl", 
      "--unique",        $chunk->tu,
      "--non-unique",    $chunk->gnu,
      "--bowtie-output", $chunk->genome_bowtie_out,
      "--genes",         $chunk->transcriptome_bowtie,
      $chunk->paired_end_option]];
}

sub merge_gu_tu {
    my ($chunk) = @_;
    [["perl", "$Bin/merge_GU_and_TU.pl",
      "--gu", $chunk->gu,
      "--tu", $chunk->tu,
      "--gnu", $chunk->gnu,
      "--tnu", $chunk->tnu,
      "--bowtie-unique", $chunk->bowtie_unique,
      "--cnu",           $chunk->cnu,
      $chunk->paired_end_option,
      "--read-length", $chunk->read_length,
      "--min-overlap", $chunk->min_overlap]];
}

sub merge_gnu_tnu_cnu {
    my ($chunk) = @_;
    [["perl", "$Bin/merge_GNU_and_TNU_and_CNU.pl",
      "--gnu", $chunk->gnu,
      "--tnu", $chunk->tnu,
      "--cnu", $chunk->cnu,
      "--out", $chunk->bowtie_nu]];
}

sub make_unmapped_file {
    my ($chunk) = @_;
    [["perl", "$Bin/make_unmapped_file.pl",
      "--reads", $chunk->reads_file,
      "--unique", $chunk->bowtie_unique, 
      "--non-unique", $chunk->bowtie_nu,
      "-o", $chunk->bowtie_unmapped,
      $chunk->paired_end_option]];
}

sub shell_script {
    my ($self, $dir) = @_;

    mkdir $dir;

    my $machine = $self->{sm};
    my $plan = $machine->generate;
    
    print "My plan is @$plan\n";

    my $state = $machine->start;

    for my $step (@$plan) {

        my $name = "RUM::ChunkMachine::$step";

        no strict 'refs';
        my $cmds = $name->($self->{config});
        
        print "# $step\n";
        for my $cmd (@$cmds) {
            print "@$cmd\n";
        }

        my $old_state = $state;
        $state = $machine->transition($state, $step);

        my @flags = $machine->flags($state & ~$old_state);
        my @state_files = map "$dir/$_", @flags;
        print "touch @state_files\n";

        print "\n";
    }

}

1;
