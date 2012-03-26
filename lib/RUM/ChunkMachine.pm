package RUM::ChunkMachine;

use strict;
use warnings;
use Carp;
use RUM::StateMachine;
use RUM::CommandMachine;
use RUM::Config;
use Text::Wrap qw(fill wrap);



sub new {
    my ($class, $config) = @_;
    $config or croak "I need a config";
    my $c = $config;
    my $self = bless {config => $config}, $class;

    my $m = RUM::CommandMachine->new($config->state_dir);

    # Flags
    my $start              = $m->start;      
    my $genome_bowtie      = $m->flag("genome_bowtie");
    my $trans_bowtie       = $m->flag("genome_transcriptome");
    my $gu                 = $m->flag("gu");
    my $gnu                = $m->flag("gnu");
    my $tu                 = $m->flag("tu");
    my $tnu                = $m->flag("tnu");
    my $cnu                = $m->flag("cnu");
    my $bowtie_unique      = $m->flag("bowtie_unique");
    my $bowtie_nu          = $m->flag("bowtie_nu");
    my $unmapped           = $m->flag("unmapped");
    my $blat               = $m->flag("blat");
    my $mdust              = $m->flag("mdust");
    my $blat_unique        = $m->flag("blat_unique");
    my $blat_nu            = $m->flag("blat_nu");
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

    $self->{sm} = $m;
    $self->{config} = $config;

    my %quants_flags;
    my $all_quants = 0;
    for my $strand ('p', 'm') {
        for my $sense ('s', 'a') {
            $quants_flags{$strand}{$sense} = $m->flag("quants_$strand$sense");
            $all_quants |= $quants_flags{$strand}{$sense};
        }
    }

    # From the start state we can run bowtie on either the genome or
    # the transcriptome
    $m->add_transition(
        instruction => "run_bowtie_on_genome",
        comment => "Run bowtie on the genome",
        pre => $start, 
        post => $genome_bowtie, 
        code => sub {
            [[$c->bowtie_bin,
              "-a", 
              "--best", 
              "--strata",
              "-f", $c->genome_bowtie,
              $c->reads_fa,
              "-v", 3,
              "--suppress", "6,7,8",
              "-p", 1,
              "--quiet",
              "> ", $c->genome_bowtie_out]];
        });
    
    $m->add_transition(
        instruction =>  "run_bowtie_on_transcriptome",
        comment => "Run bowtie on the transcriptome",
        pre => $start, 
        post => $trans_bowtie, 
        code => sub {
            [[$c->bowtie_bin,
              "-a", 
              "--best", 
              "--strata",
              "-f", $c->trans_bowtie,
              $c->reads_fa,
              "-v", 3,
              "--suppress", "6,7,8",
              "-p", 1,
              "--quiet",
              "> ", $c->trans_bowtie_out]];
        });

    # If we have the genome bowtie output, we can make the unique and
    # non-unique files for it.
    $m->add_transition(
        instruction => "make_gu_and_gnu",
        comment => "Separate unique and non-unique mappers from the output ".
            "of running bowtie on the genome",
        pre => $genome_bowtie, 
        post => $gu | $gnu, 
        code => sub {
            [["perl", $c->script("make_GU_and_GNU.pl"), 
              "--unique", $c->gu,
              "--non-unique", $c->gnu,
              $c->paired_end_opt(),
              $c->genome_bowtie_out()]];
        });

    # If we have the transcriptome bowtie output, we can make the
    # unique and non-unique files for it.
    $m->add_transition(
        instruction => "make_tu_and_tnu",
        comment => "Separate unique and non-unique mappers from the output ".
            "of running bowtie on the transcriptome",
        pre => $trans_bowtie, 
        post => $tu | $tnu, 
        code => sub {
            [["perl", $c->script("make_TU_and_TNU.pl"), 
              "--unique",        $c->tu,
              "--non-unique",    $c->tnu,
              "--bowtie-output", $c->trans_bowtie_out,
              "--genes",         $c->annotations,
              $c->paired_end_opt]];
        });

    # If we have the non-unique files for both the genome and the
    # transcriptome, we can merge them.
    $m->add_transition(
        instruction => "merge_gnu_tnu_cnu",
        comment => "Take the non-unique and merge them together",
        pre => $tnu | $gnu | $cnu, 
        post => $bowtie_nu, 
        code => sub {
            [["perl", $c->script("merge_GNU_and_TNU_and_CNU.pl"),
              "--gnu", $c->gnu,
              "--tnu", $c->tnu,
              "--cnu", $c->cnu,
              "--out", $c->bowtie_nu]];
        });

    # If we have the unique files for both the genome and the
    # transcriptome, we can merge them.
    $m->add_transition(
        instruction => "merge_gu_tu",
        comment => "Merge the unique mappers together",
        pre => $tu | $gu | $tnu | $gnu, 
        post => $bowtie_unique | $cnu, 
        code => sub {
            my @cmd = (
                
                "perl", $c->script("merge_GU_and_TU.pl"),
                "--gu", $c->gu,
                "--tu", $c->tu,
                "--gnu", $c->gnu,
                "--tnu", $c->tnu,
                "--bowtie-unique", $c->bowtie_unique,
                "--cnu",           $c->cnu,
                $c->paired_end_opt,
                "--read-length", $c->read_length);
            push @cmd, "--min-overlap", $c->min_overlap
                if defined($c->min_overlap);
            return [[@cmd]];
        });

    # If we have the merged bowtie unique mappers and the merged
    # bowtie non-unique mappers, we can create the unmapped file.
    $m->add_transition(
        instruction =>             "make_unmapped_file",
        comment => "Make a file containing the unmapped reads, to be passed ".
            "into blat",
        pre => $bowtie_unique | $bowtie_nu,
        post =>             $unmapped,
        code => sub {
            [["perl", $c->script("make_unmapped_file.pl"),
              "--reads", $c->reads_fa,
              "--unique", $c->bowtie_unique, 
              "--non-unique", $c->bowtie_nu,
              "-o", $c->bowtie_unmapped,
              $c->paired_end_opt]];
        });

    $m->add_transition(
        instruction => "run_blat",
        comment => "Run blat on the unmapped reads",
        pre => $unmapped, 
        post => $blat, 
        code => sub {
            [[$c->blat_bin,
              $c->genome_fa,
              $c->bowtie_unmapped,
              $c->blat_output,
              $c->blat_opts]];
        });

    $m->add_transition(
        instruction => "run_mdust",
        comment => "Run mdust on th unmapped reads",
        pre => $unmapped, 
        post => $mdust, 
        code => sub {
            [[$c->mdust_bin,
              $c->bowtie_unmapped,
              " > ",
              $c->mdust_output]];
        });

    $m->add_transition(
        instruction => "parse_blat_out",
        comment => "Parse blat output",
        pre => $blat | $mdust, 
        post => $blat_unique | $blat_nu, 
        code => sub {
            [["perl", $c->script("parse_blat_out.pl"),
              "--reads-in", $c->bowtie_unmapped,
              "--blat-in", $c->blat_output, 
              "--mdust-in", $c->mdust_output,
              "--unique-out", $c->blat_unique,
              "--non-unique-out", $c->blat_nu,
              $c->max_insertions_opt,
              $c->match_length_cutoff_opt,
              $c->dna_opt]];
        });

    $m->add_transition(
        instruction =>         "merge_bowtie_and_blat",
        comment => "Merge bowtie and blat results",
        pre => $bowtie_unique | $blat_unique | $bowtie_nu | $blat_nu,
        post =>         $bowtie_blat_unique | $bowtie_blat_nu,
        code => sub {
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
        });

    $m->add_transition(
        instruction =>         "rum_final_cleanup",
        comment => "Cleanup",
        pre => $bowtie_blat_unique | $bowtie_blat_nu,
        post =>         $cleaned_unique | $cleaned_nu | $sam_header,
        code => sub {
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
        });

    $m->add_transition(
        instruction => "sort_non_unique_by_id",
        comment => "Sort cleaned non-unique mappers by ID",
        pre => $cleaned_nu, 
        post => $sorted_nu, 
        code => sub {
            [["perl", $c->script("sort_RUM_by_id.pl"),
              "-o", $c->rum_nu_id_sorted,
              $c->cleaned_nu]];
        });
    
    $m->add_transition(
        instruction => "remove_dups",
        comment => "Remove duplicates from sorted NU file",
        pre => $sorted_nu | $cleaned_unique, 
        post => $deduped_nu, 
        code => sub {
            # TODO: This step is not idempotent; it appends to $c->cleaned_unique
            [["perl", $c->script("removedups.pl"),
              "--non-unique-out", $c->rum_nu_deduped,
              "--unique-out", $c->cleaned_unique,
              $c->rum_nu_id_sorted]];
        });

    $m->add_transition(
        instruction => "limit_nu",
        comment => "Produce the RUM_NU file",
        pre => $deduped_nu, 
        post => $rum_nu, 
        code => sub {
            [["perl", $c->script("limit_NU.pl"),
              $c->limit_nu_cutoff_opt,
              "-o", $c->rum_nu,
              $c->rum_nu_deduped]]
        });

    $m->add_transition(
        instruction => "sort_unique_by_id",
        comment => "Produce the RUM_Unique file",
        pre => $deduped_nu | $cleaned_unique, 
        post => $rum_unique, 
        code => sub {
            [["perl", $c->script("sort_RUM_by_id.pl"),
              $c->cleaned_unique,
              "-o", $c->rum_unique]];
        });

    $m->add_transition(
        instruction => "rum2sam",
        instruction => "get_nu_stats",
        comment => "Create the sam file",
        pre => $rum_unique | $rum_nu,
        post => $sam,
        code => sub {
            [["perl", $c->script("rum2sam.pl"),
              "--unique-in", $c->rum_unique,
              "--non-unique-in", $c->rum_nu,
              "--reads-in", $c->reads_fa,
              "--quals-in", $c->quals_file,
              "--sam-out", $c->sam_file,
              $c->name_mapping_opt]]
        });

    $m->add_transition(
        instruction => "sort_unique_by_location",
        comment => "Create non-unique stats",
        pre => $sam,
        post => $nu_stats, 
        code => sub {
            [["perl", $c->script("get_nu_stats.pl"),
              $c->sam_file,
              "> ", $c->nu_stats]]
        });

    $m->add_transition(
        instruction => "sort_nu_by_location",
        comment     => "Sort RUM_Unique", 
        pre         => $rum_unique, 
        post        => $rum_unique_sorted | $chr_counts_u, 
        code        => sub {
            [["perl", $c->script("sort_RUM_by_location.pl"),
              $c->rum_unique,
              "-o", $c->rum_unique_sorted,
              ">>", $c->chr_counts_u]];
        });

    $m->add_transition(
        instruction => "sort_rum_nu",
        comment     => "Sort RUM_NU", 
        pre         => $rum_nu, 
        post        => $rum_nu_sorted | $chr_counts_nu, 
        code => sub {
            [["perl", $c->script("sort_RUM_by_location.pl"),
              $c->rum_nu,
              "-o", $c->rum_nu_sorted,
              ">>", $c->chr_counts_nu]];
        });
    
    
    for my $strand (keys %quants_flags) {
        for my $sense (keys %{ $quants_flags{$strand} }) {
            $m->add_transition(
                instruction => "quants_$strand$sense",
                comment => "Generate quants for strand $strand, sense $sense",
                pre => $rum_nu_sorted | $rum_unique_sorted, 
                post => $quants_flags{$strand}{$sense},
                code => sub {
                    [["perl", $c->script("rum2quantifications.pl"),
                      "--genes-in", $c->annotations,
                      "--unique-in", $c->rum_unique_sorted,
                      "--non-unique-in", $c->rum_nu_sorted,
                      "-o", $c->quant($strand, $sense),
                      "-countsonly",
                      "--strand", $strand,
                      $sense eq 'a' ? "--anti" : ""]];
                });                 
        }
    }

    $m->set_goal($all_quants | $rum_unique_sorted | $rum_nu_sorted | $sam | $nu_stats);

    return $self;
}

sub shell_script {
    $_[0]->{sm}->shell_script($_[1]);
}

sub execute {
    $_[0]->{sm}->execute($_[1]);
}

sub step_comment {
    $_[0]->{sm}->step_comment($_[1])
}

sub state_report {
    $_[0]->{sm}->state_report()
}

1;
