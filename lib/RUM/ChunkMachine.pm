package RUM::ChunkMachine;

use strict;
use warnings;

use RUM::StateMachine;
use RUM::ChunkConfig;
use FindBin qw($Bin);
use Text::Wrap qw(fill wrap);
FindBin->again();

sub new {
    my ($class, $config) = @_;

    my $self = {};

    my $m = RUM::StateMachine->new();

    # Flags
    my $start          = $m->start;      
    my $genome_bowtie  = $m->flag("genome_bowtie");
    my $trans_bowtie   = $m->flag("genome_transcriptome");
    my $gu             = $m->flag("gu");
    my $gnu            = $m->flag("gnu");
    my $tu             = $m->flag("tu");
    my $tnu            = $m->flag("tnu");
    my $cnu            = $m->flag("cnu");
    my $bowtie_unique  = $m->flag("bowtie_unique");
    my $bowtie_nu      = $m->flag("bowtie_nu");
    my $unmapped       = $m->flag("unmapped");
    my $blat           = $m->flag("blat");
    my $mdust          = $m->flag("mdust");
    my $blat_unique    = $m->flag("blat_unique");
    my $blat_nu        = $m->flag("blat_nu");
    my $bowtie_blat_unique = $m->flag("bowtie_blat_unique");
    my $bowtie_blat_nu     = $m->flag("bowtie_blat_nu");
    my $cleaned_unique     = $m->flag("cleaned_unique");
    my $cleaned_nu         = $m->flag("cleaned_nu");
    my $sam_header         = $m->flag("sam_header");
    my $sorted_nu          = $m->flag("sorted_nu");
    my $deduped_nu         = $m->flag("deduped_nu");
    my $rum_nu             = $m->flag("rum_nu");
    my $rum_unique         = $m->flag("rum_unique");
    my $sam                = $m->flag("sam");
    my $nu_stats           = $m->flag("nu_stats");
    my $rum_unique_sorted  = $m->flag("rum_unique_sorted");
    my $rum_nu_sorted      = $m->flag("rum_nu_sorted");
    my $chr_counts_u       = $m->flag("chr_counts_u");
    my $chr_counts_nu      = $m->flag("chr_counts_nu");

    # From the start state we can run bowtie on either the genome or
    # the transcriptome
    $m->add(
        "Run bowtie on the genome",
        $start, $genome_bowtie, "run_bowtie_on_genome");

    $m->add(
        "Run bowtie on the transcriptome",
        $start, $trans_bowtie,  "run_bowtie_on_transcriptome");

    # If we have the genome bowtie output, we can make the unique and
    # non-unique files for it.
    $m->add(
        "Separate unique and non-unique mappers from the output of
        running bowtie on the genome",
        $genome_bowtie,        $gu | $gnu, "make_gu_and_gnu");

    # If we have the transcriptome bowtie output, we can make the
    # unique and non-unique files for it.
    $m->add(
        "Separate unique and non-unique mappers from the output of
        running bowtie on the transcriptome",
        $trans_bowtie, $tu | $tnu, "make_tu_and_tnu");

    # If we have the non-unique files for both the genome and the
    # transcriptome, we can merge them.
    $m->add(
        "Take the non-unique and merge them together",
        $tnu | $gnu | $cnu, $bowtie_nu, "merge_gnu_tnu_cnu");

    # If we have the unique files for both the genome and the
    # transcriptome, we can merge them.
    $m->add(
        "Merge the unique mappers together",
        $tu | $gu | $tnu | $gnu, $bowtie_unique | $cnu, "merge_gu_tu");

    # If we have the merged bowtie unique mappers and the merged
    # bowtie non-unique mappers, we can create the unmapped file.
    $m->add(
        "Make a file containing the unmapped reads, to be passed into blat",
        $bowtie_unique | $bowtie_nu,
            $unmapped,
            "make_unmapped_file");

    $m->add(
        "Run blat on the unmapped reads",
        $unmapped, $blat, "run_blat");

    $m->add(
        "Run mdust on th unmapped reads",
        $unmapped, $mdust, "run_mdust");

    $m->add(
        "Parse blat output",
        $blat | $mdust, $blat_unique | $blat_nu, "parse_blat_out");

    $m->add(
        "Merge bowtie and blat results",
        $bowtie_unique | $blat_unique | $bowtie_nu | $blat_nu,
        $bowtie_blat_unique | $bowtie_blat_nu,
        "merge_bowtie_and_blat");

    $m->add(
        "Cleanup",
        $bowtie_blat_unique | $bowtie_blat_nu,
        $cleaned_unique | $cleaned_nu | $sam_header,
        "rum_final_cleanup");

    $m->add(
        "Sort cleaned non-unique mappers by ID",
        $cleaned_nu, $sorted_nu, "sort_non_unique_by_id");
    
    $m->add(
        "Remove duplicates from sorted NU file",
        $sorted_nu | $cleaned_unique, $deduped_nu, "remove_dups");

    $m->add(
        "Produce the RUM_NU file",
        $deduped_nu, $rum_nu, "limit_nu");

    $m->add(
        "Produce the RUM_Unique file",
        $deduped_nu | $cleaned_unique, $rum_unique, "sort_unique_by_id");

    $m->add(
        "Create the sam file",
        $rum_unique | $rum_nu, $sam, "rum2sam");

    $m->add(
        "Create non-unique stats",
        $sam, $nu_stats, "get_nu_stats");

    $m->add(
        "Sort RUM_Unique", 
        $rum_unique, 
        $rum_unique_sorted | $chr_counts_u, 
        "sort_unique_by_location");

    $m->add(
        "Sort RUM_NU", 
        $rum_nu, 
        $rum_nu_sorted | $chr_counts_nu, 
        "sort_nu_by_location");

    $m->set_goal($rum_unique_sorted | $rum_nu_sorted | $sam | $nu_stats);

    $self->{sm} = $m;
    $self->{config} = $config;

    return bless $self, $class;
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
      "-f", $chunk->trans_bowtie,
      $chunk->reads_file,
      "-v", 3,
      "--suppress", "6,7,8",
      "-p", 1,
      "--quiet",
      "> ", $chunk->trans_bowtie_out]];
}      

sub make_gu_and_gnu {
    my ($chunk) = @_;
    [["perl", $chunk->script("make_GU_and_GNU.pl"), 
      "--unique", $chunk->gu,
      "--non-unique", $chunk->gnu,
      $chunk->paired_end_opt(),
      $chunk->genome_bowtie_out()]];
}

sub make_tu_and_tnu {
    my ($chunk) = @_;
    [["perl", $chunk->script("make_TU_and_TNU.pl"), 
      "--unique",        $chunk->tu,
      "--non-unique",    $chunk->tnu,
      "--bowtie-output", $chunk->trans_bowtie_out,
      "--genes",         $chunk->annotations,
      $chunk->paired_end_opt]];
}

sub merge_gu_tu {
    my ($chunk) = @_;
    my @cmd = (

        "perl", $chunk->script("merge_GU_and_TU.pl"),
        "--gu", $chunk->gu,
        "--tu", $chunk->tu,
        "--gnu", $chunk->gnu,
        "--tnu", $chunk->tnu,
        "--bowtie-unique", $chunk->bowtie_unique,
        "--cnu",           $chunk->cnu,
        $chunk->paired_end_opt,
        "--read-length", $chunk->read_length);
    push @cmd, "--min-overlap", $chunk->min_overlap
        if defined($chunk->min_overlap);
    return [[@cmd]];
}

sub merge_gnu_tnu_cnu {
    my ($chunk) = @_;
    [["perl", $chunk->script("merge_GNU_and_TNU_and_CNU.pl"),
      "--gnu", $chunk->gnu,
      "--tnu", $chunk->tnu,
      "--cnu", $chunk->cnu,
      "--out", $chunk->bowtie_nu]];
}

sub make_unmapped_file {
    my ($chunk) = @_;
    [["perl", $chunk->script("make_unmapped_file.pl"),
      "--reads", $chunk->reads_file,
      "--unique", $chunk->bowtie_unique, 
      "--non-unique", $chunk->bowtie_nu,
      "-o", $chunk->bowtie_unmapped,
      $chunk->paired_end_opt]];
}

sub run_blat {
    my ($chunk) = @_;
    [[$chunk->blat_bin,
      $chunk->genome_blat,
      $chunk->bowtie_unmapped,
      $chunk->blat_output,
      $chunk->blat_opts]];
}

sub run_mdust {
    my ($chunk) = @_;
    [[$chunk->mdust_bin,
      $chunk->bowtie_unmapped,
      " > ",
      $chunk->mdust_output]];
}

sub parse_blat_out {

    my ($chunk) = @_;

    [["perl", $chunk->script("parse_blat_out.pl"),
      "--reads-in", $chunk->bowtie_unmapped,
      "--blat-in", $chunk->blat_output, 
      "--mdust-in", $chunk->mdust_output,
      "--unique-out", $chunk->blat_unique,
      "--non-unique-out", $chunk->blat_nu,
      $chunk->max_insertions_opt,
      $chunk->match_length_cutoff_opt,
      $chunk->dna_opt]];
}
sub merge_bowtie_and_blat {
    my ($c) = @_;
    [["perl", $c->script("merge_Bowtie_and_Blat.pl"),
      "--bowtie-unique", $c->bowtie_unique,
      "--blat-unique", $c->blat_unique,
      "--bowtie-non-unique", $c->bowtie_nu,
      "--blat-non-unique", $c->blat_nu,
      "--unique-out", $c->bowtie_blat_unique,
      "--non-unique-out", $c->bowtie_blat_nu,
      $c->paired_end_opt,
      $c->read_length_opt,
      $c->min_overlap_opt]];

}

sub rum_final_cleanup {
    my ($c) = @_;
    [["perl", $c->script("RUM_finalcleanup.pl"),
      "--unique-in", $c->bowtie_blat_unique,
      "--non-unique-in", $c->bowtie_blat_nu,
      "--unique-out", $c->cleaned_unique,
      "--non-unique-out", $c->cleaned_nu,
      "--genome", $c->genome_fa,
      "--sam-header-out", $c->sam_header,
      $c->faok_opt,
      $c->count_mismatches_opt,
      $c->match_length_cutoff_opt]];
}

sub sort_non_unique_by_id {
    my ($c) = @_;
    [["perl", $c->script("sort_RUM_by_id.pl"),
      "-o", $c->rum_nu_id_sorted,
      $c->cleaned_nu]];
}

sub remove_dups {
    # TODO: This step is not idempotent; it appends to $c->cleaned_unique
    my ($c) = @_;
    [["perl", $c->script("removedups.pl"),
      "--non-unique-out", $c->rum_nu_deduped,
      "--unique-out", $c->cleaned_unique,
      $c->rum_nu_id_sorted]];
}

sub limit_nu {
    my ($c) = @_;
    [["perl", $c->script("limit_NU.pl"),
      $c->limit_nu_cutoff_opt,
      "-o", $c->rum_nu,
      $c->rum_nu_deduped]]
}

sub sort_unique_by_id {
    my ($c) = @_;
    [["perl", $c->script("sort_RUM_by_id.pl"),
      $c->cleaned_unique,
      "-o", $c->rum_unique]];
}

sub rum2sam {
    my ($c) = @_;
    [["perl", $c->script("rum2sam.pl"),
      "--unique-in", $c->rum_unique,
      "--non-unique-in", $c->rum_nu,
      "--reads-in", $c->reads_file,
      "--quals-in", $c->quals_file,
      "--sam-out", $c->sam_file,
      $c->name_mapping_opt]]
}

sub get_nu_stats {
    my ($c) = @_;

    [["perl", $c->script("get_nu_stats.pl"),
      $c->sam_file,
      "> ", $c->nu_stats]]
}

sub sort_unique_by_location {
    my ($c) = @_;
    [["perl", $c->script("sort_RUM_by_location.pl"),
      $c->rum_unique,
      "-o", $c->rum_unique_sorted,
      ">>", $c->chr_counts_u]];
}

sub sort_nu_by_location {
    my ($c) = @_;
    [["perl", $c->script("sort_RUM_by_location.pl"),
      $c->rum_nu,
      "-o", $c->rum_nu_sorted,
      ">>", $c->chr_counts_nu]];
}



sub shell_script {
    my ($self, $dir) = @_;

    mkdir $dir;

    my $machine = $self->{sm};
    my $plan = $machine->generate;
    
    my $state = $machine->start;

    my $res;
    for my $step (@$plan) {
        my $comment = "";
        my $name = "RUM::ChunkMachine::$step";

        no strict 'refs';
        my $cmds = $name->($self->{config});

        my $old_state = $state;
        ($state, $comment) = $machine->transition($state, $step);

        $comment =~ s/\n//g;
        $comment = fill('# ', '# ', $comment);
        $res .= "$comment\n";

        my $indent = "";
        my @post = $machine->flags($state & ~$old_state);
        my @files = map "$dir/$_", @post;
        my @tests = join(" || ", map("[ ! -e $_ ]", @files));
                         
        if (@tests) {
            $res .= "if @tests; then\n";
            $indent = "  ";
        }

        for my $cmd (@$cmds) {
            $res .= "$indent@$cmd || exit 1\n";
        }

        if (@files) {
            $res .= "${indent}touch @files\n";
            $res .= "fi\n";
        }
        $res .= "\n";
    }
    return $res;
}

1;
