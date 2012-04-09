package RUM::Workflows;

use strict;
use warnings;

use Carp;
use Text::Wrap qw(fill wrap);

use RUM::StateMachine;
use RUM::Workflow qw(pre post);
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
    $m->step(
        "Run bowtie on genome",
        [$c->bowtie_bin,
         $c->bowtie_cutoff_opt,
         "--best", 
         "--strata",
         "-f", $c->genome_bowtie,
         $c->reads_fa,
         "-v", 3,
         "--suppress", "6,7,8",
         "-p", 1,
         "--quiet",
         "> ", post($c->genome_bowtie_out)]);
    
    $m->step(
        "Run bowtie on transcriptome",
        [$c->bowtie_bin,
         $c->bowtie_cutoff_opt,
         "--best", 
         "--strata",
         "-f", $c->trans_bowtie,
         $c->reads_fa,
         "-v", 3,
         "--suppress", "6,7,8",
         "-p", 1,
         "--quiet",
         "> ", post($c->trans_bowtie_out)]);
    
    # If we have the genome bowtie output, we can make the unique and
    # non-unique files for it.
    $m->step(
        "Separate unique and non-unique mappers from genome bowtie output",
        ["perl", $c->script("make_GU_and_GNU.pl"), 
         "--unique", post($c->gu),
         "--non-unique", post($c->gnu),
         $c->paired_end_opt(),
         pre($c->genome_bowtie_out)]);
    
    # If we have the transcriptome bowtie output, we can make the
    # unique and non-unique files for it.
    $m->step(
        "Separate unique and non-unique mappers from transcriptome bowtie output",
        ["perl", $c->script("make_TU_and_TNU.pl"), 
         "--unique",        post($c->tu),
         "--non-unique",    post($c->tnu),
         "--bowtie-output", pre($c->trans_bowtie_out),
         "--genes",         $c->annotations,
         $c->paired_end_opt]);
    
    # If we have the non-unique files for both the genome and the
    # transcriptome, we can merge them.
    $m->step(
        "Merge non-unique mappers together",
        ["perl", $c->script("merge_GNU_and_TNU_and_CNU.pl"),
         "--gnu", pre($c->gnu),
         "--tnu", pre($c->tnu),
         "--cnu", pre($c->cnu),
         "--out", post($c->bowtie_nu)]);

    # If we have the unique files for both the genome and the
    # transcriptome, we can merge them.
    my $min_overlap_opt = defined($c->min_overlap)
        ? "--min-overlap".$c->min_overlap : "";
    $m->step(
        "Merge unique mappers together",
        [
            "perl", $c->script("merge_GU_and_TU.pl"),
            "--gu", pre($c->gu),
            "--tu", pre($c->tu),
            "--gnu", pre($c->gnu),
            "--tnu", pre($c->tnu),
            "--bowtie-unique", post($c->bowtie_unique),
            "--cnu",  post($c->cnu),
            $c->paired_end_opt,
            "--read-length", $c->read_length,
            $min_overlap_opt]);
    
    # If we have the merged bowtie unique mappers and the merged
    # bowtie non-unique mappers, we can create the unmapped file.
    $m->step(
        "Make a file containing the unmapped reads, to be passed ".
            "into blat",
        ["perl", $c->script("make_unmapped_file.pl"),
         "--reads", $c->reads_fa,
         "--unique", pre($c->bowtie_unique), 
         "--non-unique", pre($c->bowtie_nu),
         "-o", post($c->bowtie_unmapped),
         $c->paired_end_opt]);
    
    $m->step(
        "Run blat on unmapped reads",
        [$c->blat_bin,
         $c->genome_fa,
         pre($c->bowtie_unmapped),
         post($c->blat_output),
         $c->blat_opts]);
    
    $m->step(
         "Run mdust on unmapped reads",
         [$c->mdust_bin,
          pre($c->bowtie_unmapped),
          " > ",
          post($c->mdust_output)]);
    
    $m->step(
        "Parse blat output",
        ["perl", $c->script("parse_blat_out.pl"),
         "--reads-in",    pre($c->bowtie_unmapped),
         "--blat-in",     pre($c->blat_output), 
         "--mdust-in",    pre($c->mdust_output),
         "--unique-out", post($c->blat_unique),
         "--non-unique-out", post($c->blat_nu),
         $c->max_insertions_opt,
         $c->match_length_cutoff_opt,
         $c->dna_opt]);
    
    $m->step(
        "Merge bowtie and blat results",
        ["perl", $c->script("merge_Bowtie_and_Blat.pl"),
         "--bowtie-unique", pre($c->bowtie_unique),
         "--blat-unique", pre($c->blat_unique),
         "--bowtie-non-unique", pre($c->bowtie_nu),
         "--blat-non-unique", pre($c->blat_nu),
         "--unique-out", post($c->bowtie_blat_unique),
         "--non-unique-out", post($c->bowtie_blat_nu),
         $c->paired_end_opt,
         $c->read_length_opt,
         $c->min_overlap_opt]);
    
    $m->step(
        "Clean up RUM files",
        ["perl", $c->script("RUM_finalcleanup.pl"),
         "--unique-in", pre($c->bowtie_blat_unique),
         "--non-unique-in", pre($c->bowtie_blat_nu),
         "--unique-out", post($c->cleaned_unique),
         "--non-unique-out", post($c->cleaned_nu),
         "--genome", $c->genome_fa,
         "--sam-header-out", post($c->sam_header),
         $c->faok_opt,
         $c->count_mismatches_opt,
         $c->match_length_cutoff_opt]);
    
    $m->step(
        "Sort cleaned non-unique mappers by ID",
        ["perl", $c->script("sort_RUM_by_id.pl"),
         "-o", post($c->rum_nu_id_sorted),
         pre($c->cleaned_nu)]);
    

    $m->step(
        "Remove duplicates from NU",
        
        # TODO: This step is not idempotent it appends to $c->cleaned_unique
        ["perl", $c->script("removedups.pl"),
         "--non-unique-out", post($c->limit_nu_cutoff_opt ? $c->rum_nu_deduped : $c->rum_nu),
         "--unique-out", pre($c->cleaned_unique),
         pre($c->rum_nu_id_sorted)]);

    if ($c->limit_nu_cutoff_opt) {
        $m->step(
            "Limit NU",
            ["perl", $c->script("limit_NU.pl"),
             $c->limit_nu_cutoff_opt,
             "-o", post($c->rum_nu),
             pre($c->rum_nu_deduped)]);
    }
    else {
        $m->step(
            "Move NU file",
            ["mv",
             pre($c->rum_nu_deduped),
             post($c->rum_nu)]);
    }

    $m->step(
        "Produce RUM_Unique",
        ["perl", $c->script("sort_RUM_by_id.pl"),
         pre($c->cleaned_unique),
         "-o", post($c->rum_unique)]);
    
    $m->step(
        "Create SAM file",
        ["perl", $c->script("rum2sam.pl"),
         "--unique-in", pre($c->rum_unique),
         "--non-unique-in", pre($c->rum_nu),
         "--reads-in", $c->reads_fa,
         "--quals-in", $c->quals_file,
         "--sam-out", post($c->sam_file),
         $c->name_mapping_opt]);
    
    $m->step(
        "Create non-unique stats",
        ["perl", $c->script("get_nu_stats.pl"),
          pre($c->sam_file),
         "> ", post($c->nu_stats)]);
    
    $m->step(
        "Sort RUM_Unique by location", 
        ["perl", $c->script("sort_RUM_by_location.pl"),
         $c->ram_opt,
         pre($c->rum_unique),
         "-o", post($c->rum_unique_sorted),
         ">>", post($c->chr_counts_u)]);
    
    $m->step(
        "Sort RUM_NU", 
        ["perl", $c->script("sort_RUM_by_location.pl"),
         $c->ram_opt,
         pre($c->rum_nu),
         "-o", post($c->rum_nu_sorted),
         ">>", $c->chr_counts_nu]);
    
    my @goal = ($c->rum_unique_sorted,
                $c->rum_nu_sorted,
                $c->sam_file,
                $c->nu_stats,
            );
    
    if ($c->strand_specific) {

        for my $strand (qw(p m)) {
            for my $sense (qw(s a)) {
                my $file = $c->quant($strand, $sense);
                push @goal, $file;
                $m->add_command(
                    name => "Generate quants for strand $strand, sense $sense",
                    commands => 
                        [["perl", $c->script("rum2quantifications.pl"),
                          "--genes-in", $c->annotations,
                          "--unique-in", pre($c->rum_unique_sorted),
                          "--non-unique-in", pre($c->rum_nu_sorted),
                          "-o", post($file),
                          "-countsonly",
                          "--strand", $strand,
                          $sense eq 'a' ? "--anti" : ""]]
                    );
                if ($c->alt_quant_model) {
                    my $file = $c->alt_quant($strand, $sense);
                    push @goal, $file;
                    $m->add_command(
                        name => "Generate alt quants for strand $strand, sense $sense",
                        commands => 
                            [["perl", $c->script("rum2quantifications.pl"),
                              "--genes-in", $c->alt_quant_model,
                              "--unique-in", pre($c->rum_unique_sorted),
                              "--non-unique-in", pre($c->rum_nu_sorted),
                              "-o", post($file),
                              "-countsonly",
                              "--strand", $strand,
                              $sense eq 'a' ? "--anti" : ""]]
                        );
                }
            }
        }
    }
    else {
        push @goal, $c->quant;
        $m->add_command(
            name => "Generate quants",
            commands => 
                [["perl", $c->script("rum2quantifications.pl"),
                  "--genes-in", $c->annotations,
                  "--unique-in", pre($c->rum_unique_sorted),
                  "--non-unique-in", pre($c->rum_nu_sorted),
                  "-o", post($c->quant),
                  "-countsonly"]]
            );            
        if ($c->alt_quant_model) {
            push @goal, $c->alt_quant;
            $m->add_command(
                name => "Generate alt quants",
                commands => 
                    [["perl", $c->script("rum2quantifications.pl"),
                      "--genes-in", $c->alt_quant_model,
                      "--unique-in", pre($c->rum_unique_sorted),
                      "--non-unique-in", pre($c->rum_nu_sorted),
                      "-o", post($c->alt_quant),
                      "-countsonly"]]
                );
        }
        
    }

    $m->set_goal(\@goal);

    return $m;
}

sub postprocessing_workflow {

    my ($class, $c) = @_;

    my $name = $c->name;
    my @c = map { $c->for_chunk($_) } (1 .. $c->num_chunks);
    my $w = RUM::Workflow->new();
    my @rum_unique = map { $_->rum_unique_sorted } @c;
    my @rum_nu = map { $_->rum_nu_sorted } @c;

    my @start = (@rum_unique, @rum_nu);
    my @goal = ($c->mapping_stats,
                $c->rum_unique,
                $c->rum_nu,
                $c->rum_unique_cov,
                $c->rum_nu_cov,
                $c->inferred_internal_exons,
                $c->novel_inferred_internal_exons_quantifications);

    $w->step(
        "Merge RUM_Unique.* files",
        ["perl", $c->script("merge_sorted_RUM_files.pl"),
            "-o", post($c->rum_unique),
         map { pre($_) } @rum_unique]);

    $w->step(
        "Merge RUM_NU.* files",
        ["perl", $c->script("merge_sorted_RUM_files.pl"),
         "-o", post($c->rum_nu),
         map { pre($_) } @rum_nu]);

    my @chr_counts_u = map { $_->chr_counts_u } @c;
    my @chr_counts_nu = map { $_->chr_counts_nu } @c;
    push @start, @chr_counts_u, @chr_counts_nu;
    $w->add_command(
        name => "Compute mapping statistics",
        pre => [$c->rum_unique, $c->rum_nu, @chr_counts_u, @chr_counts_nu],
        post => [$c->mapping_stats],
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
                        name => "Merge quants $strand $sense",
                        pre => [@quants],
                        commands => [[
                            "perl", $c->script("merge_quants.pl"),
                            "--chunks", $c->num_chunks,
                            "-o", post($c->quant($strand, $sense)),
                            "--strand", "$strand$sense",
                            $c->output_dir]]);

                    $w->add_command(
                        name => "Merge alt quants $strand $sense",
                        pre => [@alt_quants],
                        commands => [[
                            "perl", $c->script("merge_quants.pl"),
                            "--alt",
                            "--chunks", $c->num_chunks,
                            "-o", post($c->alt_quant($strand, $sense)),
                            "--strand", "$strand$sense",
                            $c->output_dir]]) if $c->alt_quant_model;
                }
            }
            $w->add_command(
                name => "Merge strand-specific quants",
                pre => [@strand_specific],
                commands => [[
                    "perl", $c->script("merge_quants_strandspecific.pl"),
                    @strand_specific,
                    $c->annotations,
                    post($c->quant)]]);

            $w->add_command(
                name => "Merge strand-specific alt quants",
                pre => [@alt_strand_specific],
                commands => [[
                    "perl", $c->script("merge_quants_strandspecific.pl"),
                    @alt_strand_specific,
                    $c->alt_quant,
                    post($c->alt_quant)]]) if $c->alt_quant_model;
        }
        
        else {
            
            my @quants = map { $_->quant } @c; 
            push @start, @quants;
            $w->add_command(
                name => "Merge quants",
                pre => [$c->rum_unique],
                commands => [[
                    "perl", $c->script("merge_quants.pl"),
                    "--chunks", $c->num_chunks,
                    "-o", post($c->quant), 
                    $c->output_dir]]);

            $w->add_command(
                name => "Merge alt quants",
                pre => [$c->rum_unique],
                commands => [[
                    "perl", $c->script("merge_quants.pl"),
                    "--alt",
                    "--chunks", $c->num_chunks,
                    "-o", post($c->alt_quant),
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
            $name .= " for strand $strand" if $strand;
            my $strand_opt = $strand ? "--strand $strand" : "";

            $w->step(
                $name,
                ["perl", $c->script("make_RUM_junctions_file.pl"),
                 "--unique-in", pre($c->rum_unique),
                 "--non-unique-in", pre($c->rum_nu), 
                 "--genome", $c->genome_fa,
                 "--genes", $annotations,
                 "--all-rum-out", post($all_rum),
                 "--all-bed-out", post($all_bed),
                 "--high-bed-out", post($high_bed),
                 "--faok",
                 $strand_opt]);
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
                    $w->step(
                        "Merge junctions ($type, $format)",
                        ["cp", pre($p), post($out)],
                        ["grep -v $remove",
                         pre($m), ">>", post($out)]);
                }
            
        }
        # Junctions, not strand-specific
        else {
            $add_make_junctions->();
        }

        $w->step(
            "Sort junctions (all, rum) by location",
            ["perl", $c->script("sort_by_location.pl"),
             "-o", post($c->junctions_all_rum),
             "--location", 1,
             pre(junctions('all', 'rum'))]);

        $w->step(
            "Sort junctions (all, bed) by location",
            ["perl", $c->script("sort_by_location.pl"),
             "-o", post($c->junctions_all_bed),
             "--chromosome", 1,
             "--start", 2,
             "--end", 3,
             pre(junctions('all', 'bed'))]);

        $w->step(
            "Sort junctions (high-quality, bed) by location",
            ["perl", $c->script("sort_by_location.pl"),
             "-o", post($c->junctions_high_quality_bed),
             "--chromosome", 1,
             "--start", 2,
             "--end", 3,
             pre(junctions('high-quality', 'bed'))]);
    }

    $w->step(
        "Make unique coverage",
        ["perl", $c->script("rum2cov.pl"),
         "-o", post($c->rum_unique_cov),
         "--name", "'$name Unique Mappers'",
         "--stats", post($c->u_footprint),
         pre($c->rum_unique)]);

    $w->step(
        "Make non-unique coverage",
        ["perl", $c->script("rum2cov.pl"),
         "-o", post($c->rum_nu_cov),
         "--name", "'$name Non-Unique Mappers'",
         "--stats", post($c->nu_footprint),
         pre($c->rum_nu)]);
    
    if ($c->strand_specific) {

        my %labels = (Unique => "Unique",
                      NU => "Non-Unique",
                      plus => "Plus",
                      minus => "Minus");

        for my $u (qw(Unique NU)) {

            $w->step(
                "Break up $u file by strand",
                ["perl", $c->script("breakup_RUM_files_by_strand.pl"),
                 pre($c->in_output_dir("RUM_$u")),
                 post($c->in_output_dir("RUM_${u}.sorted.plus")),
                 post($c->in_output_dir("RUM_${u}.sorted.minus"))]);

            for my $strand (qw(plus minus)) {
                my $out = $c->in_output_dir("RUM_${u}.sorted.$strand.cov");
                push @goal, $out;
                my $name = "$name $labels{$u} Mappers $labels{$strand} Strand";
                $w->step(
                    "Make coverage for $u mappers $strand strand",
                    ["perl", $c->script("rum2cov.pl"),
                     pre($c->in_output_dir("RUM_${u}.sorted.$strand")),
                     "-o", post($out),
                     "-name '$name'"]);
            }
        }
    }

    $w->step(
        "Get inferred internal exons",
        ["perl", $c->script("get_inferred_internal_exons.pl"),
         "--junctions", pre($c->junctions_high_quality_bed),
         "--coverage", pre($c->rum_unique_cov),
         "--genes", $c->annotations,
         "--bed", post($c->inferred_internal_exons)]);

    $w->step(
        "Quantify novel exons",
        ["perl", $c->script("quantify_exons.pl"),
         "--exons-in", pre($c->inferred_internal_exons),
         "--unique-in", pre($c->rum_unique),
         "--non-unique-in", pre($c->rum_nu),
         "-o", $c->in_output_dir("quant_novel.1"),
         "--novel", "--counts-only"]);

    $w->step(
        "Merge novel exons",
        ["perl", $c->script("merge_quants.pl"),
         "--chunks", 1,
         "-o", $c->in_output_dir("novel_exon_quant_temp"),
         "--header",
         $c->output_dir],
        ["grep -v transcript",
         $c->in_output_dir("novel_exon_quant_temp"),
         ">", post($c->novel_inferred_internal_exons_quantifications)]);

    $w->step(
        "Merge novel exons",
        ["perl", $c->script("merge_quants.pl"),
         "--chunks", 1,
         "-o", $c->in_output_dir("novel_exon_quant_temp"),
         "--header",
         $c->output_dir],
        ["grep -v transcript",
         $c->in_output_dir("novel_exon_quant_temp"),
         ">", post($c->novel_inferred_internal_exons_quantifications)]);

    my @mapping_stats = map { $_->mapping_stats } @c;
    
    $w->start([@start]);

    $w->set_goal([@goal]);
    return $w;
}

1;

=back

=cut
