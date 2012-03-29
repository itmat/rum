package RUM::Workflows;

use strict;
use warnings;

use Carp;
use Text::Wrap qw(fill wrap);

use RUM::StateMachine;
use RUM::Workflow;
use RUM::Config;

=head1 NAME

RUM::Workflows - Collection of RUM workflows.

=head1 CLASS METHODS

=over 4

=item chunk_workflow($config)

Return the workflow for the chunk with the given RUM::Config.

=cut

sub chunk_workflow {
    my ($class, $config) = @_;
    $config or croak "I need a config";
    my $c = $config;
    my $self = bless {config => $config}, $class;

    my $m = RUM::Workflow->new;

    $self->{sm} = $m;
    $self->{config} = $config;

    # From the start state we can run bowtie on either the genome or
    # the transcriptome
    $m->add_command(
        name => "run_bowtie_on_genome",
        comment => "Run bowtie on the genome",
        pre => [],
        post => [$c->genome_bowtie_out], 
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
              "> ", $m->temp($c->genome_bowtie_out)]];
        });
    
    $m->add_command(
        name =>  "run_bowtie_on_transcriptome",
        comment => "Run bowtie on the transcriptome",
        pre => [],
        post => [$c->trans_bowtie_out], 
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
              "> ", $m->temp($c->trans_bowtie_out)]];
        });

    # If we have the genome bowtie output, we can make the unique and
    # non-unique files for it.
    $m->add_command(
        name => "make_gu_and_gnu",
        comment => "Separate unique and non-unique mappers from the output ".
            "of running bowtie on the genome",
        pre => [$c->genome_bowtie_out], 
        post => [$c->gu, $c->gnu],
        code => sub {
            [["perl", $c->script("make_GU_and_GNU.pl"), 
              "--unique", $m->temp($c->gu),
              "--non-unique", $m->temp($c->gnu),
              $c->paired_end_opt(),
              $c->genome_bowtie_out()]];
        });

    # If we have the transcriptome bowtie output, we can make the
    # unique and non-unique files for it.
    $m->add_command(
        name => "make_tu_and_tnu",
        comment => "Separate unique and non-unique mappers from the output ".
            "of running bowtie on the transcriptome",
        pre => [$c->trans_bowtie_out], 
        post => [$c->tu, $c->tnu], 
        code => sub {
            [["perl", $c->script("make_TU_and_TNU.pl"), 
              "--unique",        $m->temp($c->tu),
              "--non-unique",    $m->temp($c->tnu),
              "--bowtie-output", $c->trans_bowtie_out,
              "--genes",         $c->annotations,
              $c->paired_end_opt]];
        });

    # If we have the non-unique files for both the genome and the
    # transcriptome, we can merge them.
    $m->add_command(
        name => "merge_gnu_tnu_cnu",
        comment => "Take the non-unique and merge them together",
        pre => [$c->tnu, $c->gnu, $c->cnu],
        post => [$c->bowtie_nu], 
        code => sub {
            [["perl", $c->script("merge_GNU_and_TNU_and_CNU.pl"),
              "--gnu", $c->gnu,
              "--tnu", $c->tnu,
              "--cnu", $c->cnu,
              "--out", $m->temp($c->bowtie_nu)]];
        });

    # If we have the unique files for both the genome and the
    # transcriptome, we can merge them.
    $m->add_command(
        name => "merge_gu_tu",
        comment => "Merge the unique mappers together",
        pre => [$c->tu, $c->gu, $c->tnu, $c->gnu],
        post => [$c->bowtie_unique, $c->cnu], 
        code => sub {
            my @cmd = (
                "perl", $c->script("merge_GU_and_TU.pl"),
                "--gu", $c->gu,
                "--tu", $c->tu,
                "--gnu", $c->gnu,
                "--tnu", $c->tnu,
                "--bowtie-unique", $m->temp($c->bowtie_unique),
                "--cnu",           $m->temp($c->cnu),
                $c->paired_end_opt,
                "--read-length", $c->read_length);
            push @cmd, "--min-overlap", $c->min_overlap
                if defined($c->min_overlap);
            return [[@cmd]];
        });

    # If we have the merged bowtie unique mappers and the merged
    # bowtie non-unique mappers, we can create the unmapped file.
    $m->add_command(
        name => "make_unmapped_file",
        comment => "Make a file containing the unmapped reads, to be passed ".
            "into blat",
        pre  => [$c->bowtie_unique, $c->bowtie_nu],
        post => [$c->bowtie_unmapped],
        code => sub {
            [["perl", $c->script("make_unmapped_file.pl"),
              "--reads", $c->reads_fa,
              "--unique", $c->bowtie_unique, 
              "--non-unique", $c->bowtie_nu,
              "-o", $m->temp($c->bowtie_unmapped),
              $c->paired_end_opt]];
        });

    $m->add_command(
        name => "run_blat",
        comment => "Run blat on the unmapped reads",
        pre => [$c->bowtie_unmapped],
        post =>[$c->blat_output],
        code => sub {
            [[$c->blat_bin,
              $c->genome_fa,
              $c->bowtie_unmapped,
              $m->temp($c->blat_output),
              $c->blat_opts]];
        });

    $m->add_command(
        name => "run_mdust",
        comment => "Run mdust on th unmapped reads",
        pre => [$c->bowtie_unmapped],
        post =>[$c->mdust_output],
        code => sub {
            [[$c->mdust_bin,
              $c->bowtie_unmapped,
              " > ",
              $m->temp($c->mdust_output)]];
        });

    $m->add_command(
        name => "parse_blat_out",
        comment => "Parse blat output",
        pre => [$c->blat_output, $c->mdust_output], 
        post => [$c->blat_unique, $c->blat_nu], 
        code => sub {
            [["perl", $c->script("parse_blat_out.pl"),
              "--reads-in", $c->bowtie_unmapped,
              "--blat-in", $c->blat_output, 
              "--mdust-in", $c->mdust_output,
              "--unique-out", $m->temp($c->blat_unique),
              "--non-unique-out", $m->temp($c->blat_nu),
              $c->max_insertions_opt,
              $c->match_length_cutoff_opt,
              $c->dna_opt]];
        });

    $m->add_command(
        name => "merge_bowtie_and_blat",
        comment => "Merge bowtie and blat results",
        pre => [$c->bowtie_unique, $c->blat_unique, $c->bowtie_nu, $c->blat_nu],
        post => [$c->bowtie_blat_unique, $c->bowtie_blat_nu],
        code => sub {
            [["perl", $c->script("merge_Bowtie_and_Blat.pl"),
              "--bowtie-unique", $c->bowtie_unique,
              "--blat-unique", $c->blat_unique,
              "--bowtie-non-unique", $c->bowtie_nu,
              "--blat-non-unique", $c->blat_nu,
              "--unique-out", $m->temp($c->bowtie_blat_unique),
              "--non-unique-out", $m->temp($c->bowtie_blat_nu),
              $c->paired_end_opt,
              $c->read_length_opt,
              $c->min_overlap_opt]];
        });

    $m->add_command(
        name => "rum_final_cleanup",
        comment => "Cleanup",
        pre => [$c->bowtie_blat_unique, $c->bowtie_blat_nu],
        post => [$c->cleaned_unique, $c->cleaned_nu, $c->sam_header],
        code => sub {
            [["perl", $c->script("RUM_finalcleanup.pl"),
              "--unique-in", $c->bowtie_blat_unique,
              "--non-unique-in", $c->bowtie_blat_nu,
              "--unique-out", $m->temp($c->cleaned_unique),
              "--non-unique-out", $m->temp($c->cleaned_nu),
              "--genome", $c->genome_fa,
              "--sam-header-out", $m->temp($c->sam_header),
              $c->faok_opt,
              $c->count_mismatches_opt,
              $c->match_length_cutoff_opt]];
        });

    $m->add_command(
        name => "sort_non_unique_by_id",
        comment => "Sort cleaned non-unique mappers by ID",
        pre => [$c->cleaned_nu], 
        post => [$c->rum_nu_id_sorted], 
        code => sub {
            [["perl", $c->script("sort_RUM_by_id.pl"),
              "-o", $m->temp($c->rum_nu_id_sorted),
              $c->cleaned_nu]];
        });
    
    $m->add_command(
        name => "remove_dups",
        comment => "Remove duplicates from sorted NU file",
        pre => [$c->rum_nu_id_sorted, $c->cleaned_unique], 
        post => [$c->rum_nu_deduped],
        code => sub {
            # TODO: This step is not idempotent; it appends to $c->cleaned_unique
            [["perl", $c->script("removedups.pl"),
              "--non-unique-out", $m->temp($c->rum_nu_deduped),
              "--unique-out", $c->cleaned_unique,
              $c->rum_nu_id_sorted]];
        });

    $m->add_command(
        name => "limit_nu",
        comment => "Produce the RUM_NU file",
        pre => [$c->rum_nu_deduped],
        post => [$c->rum_nu], 
        code => sub {
            [["perl", $c->script("limit_NU.pl"),
              $c->limit_nu_cutoff_opt,
              "-o", $m->temp($c->rum_nu),
              $c->rum_nu_deduped]]
        });

    $m->add_command(
        name => "sort_unique_by_id",
        comment => "Produce the RUM_Unique file",
        pre => [$c->cleaned_unique], 
        post => [$c->rum_unique], 
        code => sub {
            [["perl", $c->script("sort_RUM_by_id.pl"),
              $c->cleaned_unique,
              "-o", $m->temp($c->rum_unique)]];
        });

    $m->add_command(
        name => "rum2sam",
        comment => "Create the sam file",
        pre => [$c->rum_unique, $c->rum_nu],
        post => [$c->sam_file],
        code => sub {
            [["perl", $c->script("rum2sam.pl"),
              "--unique-in", $c->rum_unique,
              "--non-unique-in", $c->rum_nu,
              "--reads-in", $c->reads_fa,
              "--quals-in", $c->quals_file,
              "--sam-out", $m->temp($c->sam_file),
              $c->name_mapping_opt]]
        });

    $m->add_command(
        name => "get_nu_stats",
        comment => "Create non-unique stats",
        pre => [$c->sam_file],
        post => [$c->nu_stats], 
        code => sub {
            [["perl", $c->script("get_nu_stats.pl"),
              $c->sam_file,
              "> ", $m->temp($c->nu_stats)]]
        });

    $m->add_command(
        name => "sort_unique_by_location",
        comment     => "Sort RUM_Unique", 
        pre         => [$c->rum_unique], 
        post        => [$c->rum_unique_sorted, $c->chr_counts_u], 
        code        => sub {
            [["perl", $c->script("sort_RUM_by_location.pl"),
              $c->rum_unique,
              "-o", $m->temp($c->rum_unique_sorted),
              ">>", $c->chr_counts_u]];
        });

    $m->add_command(
        name => "sort_nu_by_location",
        comment     => "Sort RUM_NU", 
        pre         => [$c->rum_nu], 
        post        => [$c->rum_nu_sorted, $c->chr_counts_nu], 
        code => sub {
            [["perl", $c->script("sort_RUM_by_location.pl"),
              $c->rum_nu,
              "-o", $m->temp($c->rum_nu_sorted),
              ">>", $c->chr_counts_nu]];
        });
    
    
    my @goal = ($c->rum_unique_sorted,
                $c->rum_nu_sorted,
                $c->sam_file,
                $c->nu_stats);

    for my $strand (qw(p m)) {
        for my $sense (qw(s a)) {
            my $file = $c->quant($strand, $sense);
            push @goal, $file;
            $m->add_command(
                name => "quants_$strand$sense",
                comment => "Generate quants for strand $strand, sense $sense",
                pre => [$c->rum_nu_sorted, $c->rum_unique_sorted], 
                post => [$file],
                code => sub {
                    [["perl", $c->script("rum2quantifications.pl"),
                      "--genes-in", $c->annotations,
                      "--unique-in", $c->rum_unique_sorted,
                      "--non-unique-in", $c->rum_nu_sorted,
                      "-o", $m->temp($file),
                      "-countsonly",
                      "--strand", $strand,
                      $sense eq 'a' ? "--anti" : ""]];
                });                 
        }
    }

    $m->set_goal(\@goal);

    return $m;
}

1;

=back

=cut
