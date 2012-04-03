package RUM::Workflows;

use strict;
use warnings;

use Carp;
use Text::Wrap qw(fill wrap);

use RUM::StateMachine;
use RUM::Workflow;
use RUM::Config;
use RUM::Logging;

our $log = RUM::Logging->get_logger;

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

    my $m = RUM::Workflow->new;

    # From the start state we can run bowtie on either the genome or
    # the transcriptome
    $m->add_command(
        name => "run_bowtie_on_genome",
        comment => "Run bowtie on the genome",
        pre => [],
        post => [$c->genome_bowtie_out], 
        commands => [[$c->bowtie_bin,
                  "-a", 
                  "--best", 
                  "--strata",
                  "-f", $c->genome_bowtie,
                  $c->reads_fa,
                  "-v", 3,
                  "--suppress", "6,7,8",
                  "-p", 1,
                  "--quiet",
                  "> ", $m->temp($c->genome_bowtie_out)]]
    );
    
    $m->add_command(
        name =>  "run_bowtie_on_transcriptome",
        comment => "Run bowtie on the transcriptome",
        pre => [],
        post => [$c->trans_bowtie_out], 
        commands => [[$c->bowtie_bin,
                  "-a", 
                  "--best", 
                  "--strata",
                  "-f", $c->trans_bowtie,
                  $c->reads_fa,
                  "-v", 3,
                  "--suppress", "6,7,8",
                  "-p", 1,
                  "--quiet",
                  "> ", $m->temp($c->trans_bowtie_out)]]
    );
    
    # If we have the genome bowtie output, we can make the unique and
    # non-unique files for it.
    $m->add_command(
        name => "make_gu_and_gnu",
        comment => "Separate unique and non-unique mappers from the output ".
            "of running bowtie on the genome",
        pre => [$c->genome_bowtie_out], 
        post => [$c->gu, $c->gnu],
        commands => 
            [["perl", $c->script("make_GU_and_GNU.pl"), 
              "--unique", $m->temp($c->gu),
              "--non-unique", $m->temp($c->gnu),
              $c->paired_end_opt(),
              $c->genome_bowtie_out()]]
        );
    
    # If we have the transcriptome bowtie output, we can make the
    # unique and non-unique files for it.
    $m->add_command(
        name => "make_tu_and_tnu",
        comment => "Separate unique and non-unique mappers from the output ".
            "of running bowtie on the transcriptome",
        pre => [$c->trans_bowtie_out], 
        post => [$c->tu, $c->tnu], 
        commands => 
            [["perl", $c->script("make_TU_and_TNU.pl"), 
              "--unique",        $m->temp($c->tu),
              "--non-unique",    $m->temp($c->tnu),
              "--bowtie-output", $c->trans_bowtie_out,
              "--genes",         $c->annotations,
              $c->paired_end_opt]]
        );
    
    # If we have the non-unique files for both the genome and the
    # transcriptome, we can merge them.
    $m->add_command(
        name => "merge_gnu_tnu_cnu",
        comment => "Take the non-unique and merge them together",
        pre => [$c->tnu, $c->gnu, $c->cnu],
        post => [$c->bowtie_nu], 
        commands => 
            [["perl", $c->script("merge_GNU_and_TNU_and_CNU.pl"),
              "--gnu", $c->gnu,
              "--tnu", $c->tnu,
              "--cnu", $c->cnu,
              "--out", $m->temp($c->bowtie_nu)]]
        );

    # If we have the unique files for both the genome and the
    # transcriptome, we can merge them.
    $m->add_command(
        name => "merge_gu_tu",
        comment => "Merge the unique mappers together",
        pre => [$c->tu, $c->gu, $c->tnu, $c->gnu],
        post => [$c->bowtie_unique, $c->cnu], 
        commands => sub {
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
        commands => 
            [["perl", $c->script("make_unmapped_file.pl"),
              "--reads", $c->reads_fa,
              "--unique", $c->bowtie_unique, 
              "--non-unique", $c->bowtie_nu,
              "-o", $m->temp($c->bowtie_unmapped),
              $c->paired_end_opt]]
        );

    $m->add_command(
        name => "run_blat",
        comment => "Run blat on the unmapped reads",
        pre => [$c->bowtie_unmapped],
        post =>[$c->blat_output],
        commands => 
            [[$c->blat_bin,
              $c->genome_fa,
              $c->bowtie_unmapped,
              $m->temp($c->blat_output),
              $c->blat_opts]]
        );
    
    $m->add_command(
        name => "run_mdust",
        comment => "Run mdust on th unmapped reads",
        pre => [$c->bowtie_unmapped],
        post =>[$c->mdust_output],
        commands => 
            [[$c->mdust_bin,
              $c->bowtie_unmapped,
              " > ",
              $m->temp($c->mdust_output)]]
        );
    
    $m->add_command(
        name => "parse_blat_out",
        comment => "Parse blat output",
        pre => [$c->blat_output, $c->mdust_output], 
        post => [$c->blat_unique, $c->blat_nu], 
        commands => 
            [["perl", $c->script("parse_blat_out.pl"),
              "--reads-in", $c->bowtie_unmapped,
              "--blat-in", $c->blat_output, 
              "--mdust-in", $c->mdust_output,
              "--unique-out", $m->temp($c->blat_unique),
              "--non-unique-out", $m->temp($c->blat_nu),
              $c->max_insertions_opt,
              $c->match_length_cutoff_opt,
              $c->dna_opt]]
        );
    
    $m->add_command(
        name => "merge_bowtie_and_blat",
        comment => "Merge bowtie and blat results",
        pre => [$c->bowtie_unique, $c->blat_unique, $c->bowtie_nu, $c->blat_nu],
        post => [$c->bowtie_blat_unique, $c->bowtie_blat_nu],
        commands => 
            [["perl", $c->script("merge_Bowtie_and_Blat.pl"),
              "--bowtie-unique", $c->bowtie_unique,
              "--blat-unique", $c->blat_unique,
              "--bowtie-non-unique", $c->bowtie_nu,
              "--blat-non-unique", $c->blat_nu,
              "--unique-out", $m->temp($c->bowtie_blat_unique),
              "--non-unique-out", $m->temp($c->bowtie_blat_nu),
              $c->paired_end_opt,
              $c->read_length_opt,
              $c->min_overlap_opt]]
        );
    
    $m->add_command(
        name => "rum_final_cleanup",
        comment => "Cleanup",
        pre => [$c->bowtie_blat_unique, $c->bowtie_blat_nu],
        post => [$c->cleaned_unique, $c->cleaned_nu, $c->sam_header],
        commands => 
            [["perl", $c->script("RUM_finalcleanup.pl"),
              "--unique-in", $c->bowtie_blat_unique,
              "--non-unique-in", $c->bowtie_blat_nu,
              "--unique-out", $m->temp($c->cleaned_unique),
              "--non-unique-out", $m->temp($c->cleaned_nu),
              "--genome", $c->genome_fa,
              "--sam-header-out", $m->temp($c->sam_header),
              $c->faok_opt,
              $c->count_mismatches_opt,
              $c->match_length_cutoff_opt]]
        );
    
    $m->add_command(
        name => "sort_non_unique_by_id",
        comment => "Sort cleaned non-unique mappers by ID",
        pre => [$c->cleaned_nu], 
        post => [$c->rum_nu_id_sorted], 
        commands => 
            [["perl", $c->script("sort_RUM_by_id.pl"),
              "-o", $m->temp($c->rum_nu_id_sorted),
              $c->cleaned_nu]]
        );
    
    $m->add_command(
        name => "remove_dups",
        comment => "Remove duplicates from sorted NU file",
        pre => [$c->rum_nu_id_sorted, $c->cleaned_unique], 
        post => [$c->rum_nu_deduped],
        commands => 
            # TODO: This step is not idempotent it appends to $c->cleaned_unique
            [["perl", $c->script("removedups.pl"),
              "--non-unique-out", $m->temp($c->rum_nu_deduped),
              "--unique-out", $c->cleaned_unique,
              $c->rum_nu_id_sorted]]
        );
    
    $m->add_command(
        name => "limit_nu",
        comment => "Produce the RUM_NU file",
        pre => [$c->rum_nu_deduped],
        post => [$c->rum_nu], 
        commands => 
            [["perl", $c->script("limit_NU.pl"),
              $c->limit_nu_cutoff_opt,
              "-o", $m->temp($c->rum_nu),
              $c->rum_nu_deduped]]
        );
    
    $m->add_command(
        name => "sort_unique_by_id",
        comment => "Produce the RUM_Unique file",
        pre => [$c->cleaned_unique], 
        post => [$c->rum_unique], 
        commands => 
            [["perl", $c->script("sort_RUM_by_id.pl"),
              $c->cleaned_unique,
              "-o", $m->temp($c->rum_unique)]]
        );
    
    $m->add_command(
        name => "rum2sam",
        comment => "Create the sam file",
        pre => [$c->rum_unique, $c->rum_nu],
        post => [$c->sam_file],
        commands => 
            [["perl", $c->script("rum2sam.pl"),
              "--unique-in", $c->rum_unique,
              "--non-unique-in", $c->rum_nu,
              "--reads-in", $c->reads_fa,
              "--quals-in", $c->quals_file,
              "--sam-out", $m->temp($c->sam_file),
              $c->name_mapping_opt]]
        );
    
    $m->add_command(
        name => "get_nu_stats",
        comment => "Create non-unique stats",
        pre => [$c->sam_file],
        post => [$c->nu_stats], 
        commands =>
            [["perl", $c->script("get_nu_stats.pl"),
              $c->sam_file,
              "> ", $m->temp($c->nu_stats)]]
        );
    
    $m->add_command(
        name => "sort_unique_by_location",
        comment     => "Sort RUM_Unique", 
        pre         => [$c->rum_unique], 
        post        => [$c->rum_unique_sorted, $c->chr_counts_u], 
        commands        => 
            [["perl", $c->script("sort_RUM_by_location.pl"),
              $c->rum_unique,
              "-o", $m->temp($c->rum_unique_sorted),
              ">>", $c->chr_counts_u]]
        );
    
    $m->add_command(
        name => "sort_nu_by_location",
        comment     => "Sort RUM_NU", 
        pre         => [$c->rum_nu], 
        post        => [$c->rum_nu_sorted, $c->chr_counts_nu], 
        commands => 
            [["perl", $c->script("sort_RUM_by_location.pl"),
              $c->rum_nu,
              "-o", $m->temp($c->rum_nu_sorted),
              ">>", $c->chr_counts_nu]]
        );
    
    
    my @goal = ($c->rum_unique_sorted,
                $c->rum_nu_sorted,
                $c->sam_file,
                $c->nu_stats);
    
    if ($c->strand_specific) {

        for my $strand (qw(p m)) {
            for my $sense (qw(s a)) {
                my $file = $c->quant($strand, $sense);
                push @goal, $file;
                $m->add_command(
                    name => "quants_$strand$sense",
                    comment => "Generate quants for strand $strand, sense $sense",
                    pre => [$c->rum_nu_sorted, $c->rum_unique_sorted], 
                    post => [$file],
                    commands => 
                        [["perl", $c->script("rum2quantifications.pl"),
                          "--genes-in", $c->annotations,
                          "--unique-in", $c->rum_unique_sorted,
                          "--non-unique-in", $c->rum_nu_sorted,
                          "-o", $m->temp($file),
                          "-countsonly",
                          "--strand", $strand,
                          $sense eq 'a' ? "--anti" : ""]]
                    );                 
            }
        }
    }
    else {
        push @goal, $c->quant;
        $m->add_command(
            name => "quants",
            comment => "Generate quants",
            pre => [$c->rum_nu_sorted, $c->rum_unique_sorted], 
            post => [$c->quant],
            commands => 
                [["perl", $c->script("rum2quantifications.pl"),
                  "--genes-in", $c->annotations,
                  "--unique-in", $c->rum_unique_sorted,
                  "--non-unique-in", $c->rum_nu_sorted,
                  "-o", $m->temp($c->quant),
                  "-countsonly"]]
            );                 
    }

    $m->set_goal(\@goal);

    return $m;
}

sub postprocessing_workflow {

    my ($class, $c) = @_;


    my @c = map { $c->for_chunk($_) } (1 .. $c->num_chunks);
    my $w = RUM::Workflow->new();
    my @rum_unique = map { $_->rum_unique_sorted } @c;
    my @rum_nu = map { $_->rum_nu_sorted } @c;

    my @start = (@rum_unique, @rum_nu);
    my @goal = ($c->mapping_stats,
                $c->rum_unique,
                $c->rum_nu);

    $w->add_command(
        name => "merge_rum_unique",
        pre => \@rum_unique,
        post => [$c->rum_unique],
        comment => "Merge RUM_Unique.* files",
        commands => [[
            "perl", $c->script("merge_sorted_RUM_files.pl"),
            "-o", $w->temp($c->rum_unique),
            @rum_unique
        ]]
    );

    $w->add_command(
        name => "merge_rum_nu",
        pre => \@rum_nu,
        post => [$c->rum_nu],
        comment => "Merge RUM_NU.* files",
        commands => [[
            "perl", $c->script("merge_sorted_RUM_files.pl"),
            "-o", $w->temp($c->rum_nu),
            @rum_nu
        ]]
    );

    my @chr_counts_u = map { $_->chr_counts_u } @c;
    my @chr_counts_nu = map { $_->chr_counts_nu } @c;
    push @start, @chr_counts_u, @chr_counts_nu;
    $w->add_command(
        name => "compute_mapping_statistics",
        pre => [$c->rum_unique, $c->rum_nu, @chr_counts_u, @chr_counts_nu],
        post => [$c->mapping_stats],
        comment => "Compute mapping stats",
        commands => sub {
            my $reads = $c->reads_fa;
            local $_ = `tail -2 $reads`;
            my $max_seq_opt = /seq.(\d+)/s ? "--max-seq $1" : "";
            my $out = $w->temp($c->mapping_stats);
            return [
                ["perl", $c->script("count_reads_mapped.pl"),
                 "--unique-in", $c->rum_unique,
                 "--non-unique-in", $c->rum_nu,
                 "--min-seq", 1,
                 $max_seq_opt,
                 "> ", $w->temp($c->mapping_stats)],
                ["echo '' >> $out"],
                ["echo RUM_Unique reads per chromosome >> $out"],
                ["echo ------------------------------- >> $out"],
                ["perl", $c->script("merge_chr_counts.pl"),
                 "-o $out @chr_counts_u"],

                ["echo '' >> $out"],
                ["echo RUM_NU reads per chromosome >> $out"],
                ["echo --------------------------- >> $out"],
                ["perl", $c->script("merge_chr_counts.pl"),
                 "-o $out @chr_counts_nu"],

                ["perl", $c->script("merge_nu_stats.pl"), "-n", $c->num_chunks, 
                 $c->output_dir, ">> $out"]
            ];
        }
    );


    if ($c->should_quantify) {
        push @goal, $c->quant;
        push @goal, $c->alt_quant if $c->alt_quant_model;

        if ($c->strand_specific) {
            my @strand_specific;
            my @alt_strand_specific;
            for my $sense (qw(s a)) {
                for my $strand (qw(p m)) {
                    
                    my @quants = map { $_->quant($strand, $sense) } @c; 
                    my @alt_quants;

                    push @start, @quants;
                    push @strand_specific, $c->quant($strand, $sense);

                    if ($c->alt_quant) {
                        @alt_quants = map { $_->alt_quant($strand, $sense) } @c;
                        push @start, @alt_quants;
                        push @alt_strand_specific, $c->alt_quant($strand, $sense);
                    }

                    $w->add_command(
                        name => "merge_quants_$strand$sense",
                        pre => [@quants],
                        post => [$c->quant($strand, $sense)],
                        comment => "Merge quants $strand $sense",
                        commands => [[
                            "perl", $c->script("merge_quants.pl"),
                            "--chunks", $c->num_chunks,
                            "-o", $c->quant($strand, $sense),
                            "--strand", "$strand$sense",
                            $c->output_dir]]);

                    $w->add_command(
                        name => "merge_alt_quants_$strand$sense",
                        pre => [@alt_quants],
                        post => [$c->alt_quant($strand, $sense)],
                        comment => "Merge alt quants $strand $sense",
                        commands => [[
                            "perl", $c->script("merge_quants.pl"),
                            "--alt",
                            "--chunks", $c->num_chunks,
                            "-o", $c->quant($strand, $sense),
                            "--strand", "$strand$sense",
                            $c->output_dir]]) if $c->alt_quant_model;
                }
            }
            $w->add_command(
                name => "merge_strand_specific_quants",
                comment => "Merge strand-specific quants",
                pre => [@strand_specific],
                post => [$c->quant],
                commands => [[
                    "perl", $c->script("merge_quants_strandspecific.pl"),
                    @strand_specific,
                    $c->annotations,
                    $w->temp($c->quant)]]);

            $w->add_command(
                name => "merge_strand_specific_alt_quants",
                comment => "Merge strand-specific alt quants",
                pre => [@alt_strand_specific],
                post => [$c->alt_quant],
                commands => [[
                    "perl", $c->script("merge_quants_strandspecific.pl"),
                    @alt_strand_specific,
                    $c->alt_quant,
                    $w->temp($c->alt_quant)]]) if $c->alt_quant_model;
        }
        
        else {

            my @quants = map { $_->quant } @c; 
            push @start, @quants;
            $w->add_command(
                name => "merge_quants",
                pre => [$c->rum_unique],
                post => [$c->quant],
                comment => "Merge quants",
                commands => [[
                    "perl", $c->script("merge_quants.pl"),
                    "--chunks", $c->num_chunks,
                    "-o", $w->temp($c->quant), 
                    $c->output_dir]]);

            $w->add_command(
                name => "merge_alt_quants",
                pre => [$c->rum_unique],
                post => [$c->alt_quant],
                comment => "Merge alt quants",
                commands => [[
                    "perl", $c->script("merge_quants.pl"),
                    "--alt",
                    "--chunks", $c->num_chunks,
                    "-o", $w->temp($c->alt_quant),
                    $c->output_dir]]) if $c->alt_quant_model;
        }
    }
    
    

    if ($c->should_do_junctions) {
        my $annotations = $c->alt_genes || $c->annotations;

        # Closure that takes a strand (p, m, or undef), type (all or
        # high-quality) and format (bed or rum) and returns the path
        # of the junction file
        local *junctions = sub { 
            unshift @_, undef if @_ == 2;
            my ($strand, $type, $format) = @_;

            my $name = $strand ?
                "junctions_${strand}s_$type.$format" :
                    "junctions_${type}_temp.$format";
            return $c->in_output_dir($name);
        };

        # Closure that takes a strand (p, m, or undef) and adds a
        # command that makes a junction file for it
        my $add_make_junctions = sub {
            my $strand = shift;

            my $all_rum = junctions($strand, 'all', 'rum');
            my $all_bed = junctions($strand, 'all', 'bed');
            my $high_bed = junctions($strand, 'high-quality', 'bed');

            my $name = "make_junctions";
            my $comment = "Make junctions file";
            if ($strand) {
                $name .= "_$strand";
                $comment .= " for strand $strand";
            }
            my $strand_opt = $strand ? "--strand $strand" : "";

            $w->add_command(
                name => $name,
                comment => $comment,
                pre => [$c->rum_unique, $c->rum_nu],
                post => [$all_rum, $all_bed, $high_bed],
                commands => [
                    ["perl", $c->script("make_RUM_junctions_file.pl"),
                     "--unique-in", $c->rum_unique,
                     "--non-unique-in", $c->rum_nu, 
                     "--genome", $c->genome_fa,
                     "--genes", $annotations,
                     "--all-rum-out", $w->temp($all_rum),
                     "--all-bed-out", $w->temp($all_bed),
                     "--high-bed-out", $w->temp($high_bed),
                     "--faok",
                     $strand_opt]]);            

        };

   
        if ($c->strand_specific) {
          
            for my $strand (qw(p m)) {
                $add_make_junctions->($strand);
            }

            #                type           format lines to remove from m strand
            for my $config (['all',          'rum', 'long_overlap_nu_reads'],
                            ['all',          'bed', 'rum_junctions_neg-strand'],
                            ['high-quality', 'bed', 'rum_junctions_neg-strand'])
                {
                    my ($type, $format, $remove) = @$config;
                    # Strand-specific input files
                    my $p   = junctions('p', $type, $format);
                    my $m   = junctions('m', $type, $format);

                    # Merged output file
                    my $out = junctions($type, $format);
                    $w->add_command(
                        name => "merge_strand_specific_junctions_${type}_${format}",
                        comment => "Merge strand-specific junctions",
                        pre => [$p, $m],
                        post => [$out],
                        commands => [["cp $p $out"],
                                     ["grep -v $remove $m >> $out"]]
                    );
                }
            
        }
        # Junctions, not strand-specific
        else {
            $add_make_junctions->();
        }

        $w->add_command(
            name => "Sort junctions (all, rum) by location",
            pre => [junctions('all', 'rum')],
            post => [$c->junctions_all_rum],
            commands => [[
                "perl", $c->script("sort_by_location.pl"),
                "-o", $w->temp($c->junctions_all_rum),
                "--location", 1,
                junctions('all', 'rum')]]
        );

        $w->add_command(
            name => "Sort junctions (all, bed) by location",
            pre => [junctions('all', 'bed')],
            post => [$c->junctions_all_bed],
            commands => [[
                "perl", $c->script("sort_by_location.pl"),
                "-o", $w->temp($c->junctions_all_bed),
                "--chromosome", 1,
                "--start", 2,
                "--end", 3,
                junctions('all', 'bed')]]
        );

        $w->add_command(
            name => "Sort junctions (high-quality, bed) by location",
            pre => [junctions('high-quality', 'bed')],
            post => [$c->junctions_high_quality_bed],
            commands => [[
                "perl", $c->script("sort_by_location.pl"),
                "-o", $w->temp($c->junctions_high_quality_bed),
                "--chromosome", 1,
                "--start", 2,
                "--end", 3,
                junctions('high-quality', 'bed')]]
        );
    }


    
    my @mapping_stats = map { $_->mapping_stats } @c;
    
    $w->start([@start]);

    $w->set_goal([@goal]);
    return $w;
}

1;

=back

=cut
