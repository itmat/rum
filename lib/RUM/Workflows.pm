package RUM::Workflows;

use strict;
use warnings;

use Carp;
use Text::Wrap qw(fill wrap);

use RUM::BinDeps;
use RUM::Config;
use RUM::Logging;
use RUM::StateMachine;
use RUM::Workflow qw(pre post);
use Data::Dumper;

our $log = RUM::Logging->get_logger;

sub new {
    my ($class, $config) = @_;

    my $self = {};

    $self->{config} = $config;

    eval {
        $self->{index} = RUM::Index->load($config->index_dir);
    };
    if ($@) {
        warn "$@\n";
    }
    return bless $self, $class;
}

sub chunk_workflow {
    my ($self, $chunk) = @_;
    my $config = $self->{config};

    if (my $w = $self->{chunk_workflows}[$chunk]) {
        return $w;
    }

    $config or croak "I need a config";
    $chunk or croak "I need a chunk";
    my $c = $config;

    my $m = RUM::Workflow->new(name => "Chunk $chunk processing");

    my $index = $self->{index};

    my $bowtie_genome_index = $index ? $index->bowtie_genome_index        : '';
    my $bowtie_trans_index  = $index ? $index->bowtie_transcriptome_index : '';
    my $gene_annotations    = $index ? $index->gene_annotations           : '';
    my $genome_fasta        = $index ? $index->genome_fasta               : '';

    local *chunk_file = sub { $c->chunk_file($_[0], $chunk) };

    my $bowtie_unmapped    = chunk_file("R");
    my $blat_output        = chunk_file("R.blat");
    my $mdust_output       = chunk_file("R.mdust");
    my $blat_unique        = chunk_file("BlatUnique");
    my $blat_nu            = chunk_file("BlatNU");
    my $bowtie_unique      = chunk_file("BowtieUnique");
    my $bowtie_nu          = chunk_file("BowtieNU");
    my $bowtie_blat_unique = chunk_file("RUM_Unique_temp");
    my $bowtie_blat_nu     = chunk_file("RUM_NU_temp");
    my $rum_unique         = chunk_file("RUM_Unique");
    my $rum_nu             = chunk_file("RUM_NU");
    my $reads_fa           = chunk_file("reads.fa");
    my $quals_fa           = chunk_file("quals.fa");
    my $rum_unique_sorted  = chunk_file("RUM_Unique.sorted");
    my $rum_nu_sorted      = chunk_file("RUM_NU.sorted");
    my $chr_counts_u       = chunk_file("chr_counts_u");
    my $chr_counts_nu      = chunk_file("chr_counts_nu");
    my $gu                 = chunk_file("GU");
    my $gnu                = chunk_file("GNU");
    my $tu                 = chunk_file("TU");
    my $tnu                = chunk_file("TNU");
    my $cnu                = chunk_file("CNU");
    my $cleaned_nu         = chunk_file("RUM_NU_temp2");
    my $rum_nu_deduped     = chunk_file("RUM_NU_temp3");
    my $cleaned_unique     = chunk_file("RUM_Unique_temp2");
    my $rum_nu_id_sorted   = chunk_file("RUM_NU_idsorted");
    my $nu_stats           = chunk_file("nu_stats");
    my $sam_file           = chunk_file("RUM.sam");

    my $deps       = RUM::BinDeps->new;
    my $bowtie_bin = $deps->bowtie;
    my $blat_bin   = $deps->blat;
    my $mdust_bin  = $deps->mdust;

    # IF we're running in DNA mode, we don't run bowtie against the
    # transcriptome, so just send the output from make_GU_and_GNU.pl
    # straight to BowtieUnique and BowtieNU.
    if ($c->dna || $c->genome_only) {
        $gu = chunk_file("BowtieUnique");
        $gnu = chunk_file("BowtieNU");
    }
 
    # If we have the genome bowtie output, we can make the unique and
    # non-unique files for it.
    unless ($c->blat_only) {

        my @cmd = (
            'perl', $c->script("make_GU_and_GNU.pl"), 
            "--unique", post($gu),
            "--non-unique", post($gnu),
            $c->paired_end_opt(),
            '--index', $bowtie_genome_index,
            '--query', $reads_fa);

        if (!$config->no_bowtie_nu_limit) {
            my $x = $c->bowtie_nu_limit;
            push @cmd, '--limit', $x;
        }
        if ($c->no_clean) {
            push @cmd, '--debug', '--bowtie-out', chunk_file('bowtie_genome_out');
        }
        $m->step("Run Bowtie on genome", \@cmd);
    }

    unless ($c->dna || $c->blat_only || $c->genome_only) {
        my @cmd = (
            'perl', $c->script('make_TU_and_TNU.pl'),
            '--unique',        post($tu),
            '--non-unique',    post($tnu),
            '--genes',         $gene_annotations,
            $c->paired_end_opt,
            '--index', $bowtie_trans_index,
            '--query', $reads_fa);

        if (!$config->no_bowtie_nu_limit) {
            my $x = $c->bowtie_nu_limit;
            push @cmd, '--limit', $x;
        }
        if ($c->no_clean) {
            push @cmd, '--debug', '--bowtie-out', chunk_file('bowtie_transcriptome_out');
        }
        $m->step('Run Bowtie on transcriptome', \@cmd);
    
        # If we have the non-unique files for both the genome and the
        # transcriptome, we can merge them.
        $m->step(
            'Merge non-unique mappers together',
            ['perl', $c->script('merge_GNU_and_TNU_and_CNU.pl'),
             '--gnu', pre($gnu),
             '--tnu', pre($tnu),
             '--cnu', pre($cnu),
             '--out', post($bowtie_nu)]);
        
        # If we have the unique files for both the genome and the
        # transcriptome, we can merge them.
        $m->step(
            'Merge unique mappers together',
            [
                'perl', $c->script('merge_GU_and_TU.pl'),
                '--gu',  pre($gu),
                '--tu',  pre($tu),
                '--gnu', pre($gnu),
                '--tnu', pre($tnu),
                '--bowtie-unique', post($bowtie_unique),
                '--cnu',  post($cnu),
                $c->paired_end_opt,
                '--read-length', $c->read_length,
                $c->min_overlap_opt]);
    }

    if ($c->blat_only) {
        $m->step(
            'Make empty bowtie output',
            ['touch', post($bowtie_unique)],
            ['touch', post($bowtie_nu)]);
    }
    
    # If we have the merged bowtie unique mappers and the merged
    # bowtie non-unique mappers, we can create the unmapped file.
    $m->step(
        'Make unmapped reads file for blat',
        ['perl', $c->script('make_unmapped_file.pl'),
         '--reads', $reads_fa,
         '--unique', pre($bowtie_unique), 
         '--non-unique', pre($bowtie_nu),
         '-o', post($bowtie_unmapped),
         $c->paired_end_opt]);
    

    # Build BLAT command
    my @blat_cmd = (
        "perl", $c->script("parse_blat_out.pl"),
        "--reads-in",    pre($bowtie_unmapped),
        "--genome",      $genome_fasta,
        "--unique-out", post($blat_unique),
        "--non-unique-out", post($blat_nu));

    my %blat_opts;
    if (defined ($c->min_length)) {
        $blat_opts{'--match-length-cutoff'} = $c->min_length;
    }
    if (defined ($c->max_insertions)) {
        $blat_opts{'--max-insertions'} = $c->max_insertions;
    }

    for my $k (keys %blat_opts) {
        if (defined $blat_opts{$k}) {
            push @blat_cmd, $k, $blat_opts{$k};
        }
    }
    if ($c->no_clean) {
        push @blat_cmd, '--debug', '--blat-out', chunk_file('blat_out');
    }

    push @blat_cmd, '--', $c->blat_opts;

    $m->step("Run BLAT", \@blat_cmd);
    
    $m->step(
        "Merge bowtie and blat results",
        ["perl", $c->script("merge_Bowtie_and_Blat.pl"),
         "--bowtie-unique", pre($bowtie_unique),
         "--blat-unique", pre($blat_unique),
         "--bowtie-non-unique", pre($bowtie_nu),
         "--blat-non-unique", pre($blat_nu),
         "--unique-out", post($bowtie_blat_unique),
         "--non-unique-out", post($bowtie_blat_nu),
         $c->paired_end_opt,
         $c->read_length_opt,
         $c->min_overlap_opt]);

    $m->step(
        "Clean up RUM files",
        ["perl", $c->script("RUM_finalcleanup.pl"),
         "--unique-in", pre($bowtie_blat_unique),
         "--non-unique-in", pre($bowtie_blat_nu),
         "--unique-out", post($cleaned_unique),
         "--non-unique-out", post($cleaned_nu),
         "--genome", $genome_fasta,
         "--sam-header-out", post($c->sam_header($chunk || 1)),
         '--faok',
         $c->count_mismatches_opt,
         $c->match_length_cutoff_opt]);

    $m->step(
        "Sort cleaned non-unique mappers by ID",
        ["perl", $c->script("sort_RUM_by_id.pl"),
         "-o", post($rum_nu_id_sorted),
         pre($cleaned_nu)]);
    
    $m->step(
        "Remove duplicates from NU",
        
        # TODO: This step is not idempotent it appends to $cleaned_unique
        ["perl", $c->script("removedups.pl"),
         "--non-unique-out", post($c->limit_nu_cutoff_opt ? $rum_nu_deduped : $rum_nu),
         "--unique-out", pre($cleaned_unique),
         pre($rum_nu_id_sorted)]);

    if ($c->limit_nu_cutoff_opt) {
        $m->step(
            "Limit NU",
            ["perl", $c->script("limit_NU.pl"),
             $c->limit_nu_cutoff_opt,
             "-o", post($rum_nu),
             pre($rum_nu_deduped)]);
    }

    $m->step(
        "Produce RUM_Unique",
        ["perl", $c->script("sort_RUM_by_id.pl"),
         pre($cleaned_unique),
         "-o", post($rum_unique)]);
    
    $m->step(
        "Create SAM file",
        ["perl", $c->script("rum2sam.pl"),
         "--genome-in", $genome_fasta,
         "--unique-in", pre($rum_unique),
         "--non-unique-in", pre($rum_nu),
         "--reads-in", $reads_fa,
         "--quals-in", $quals_fa,
         "--sam-out", post($sam_file),
         $c->name_mapping_opt]);
    
    $m->step(
        "Create non-unique stats",
        ["perl", $c->script("get_nu_stats.pl"),
          pre($sam_file),
         "> ", post($nu_stats)]);
    
    $m->step(
        "Sort RUM_Unique by location", 
        ["perl", $c->script("sort_RUM_by_location.pl"),
         $c->ram_opt,
         pre($rum_unique),
         "-o", post($rum_unique_sorted),
         "--chr-counts-out", post($chr_counts_u)]);
    
    $m->step(
        "Sort RUM_NU", 
        ["perl", $c->script("sort_RUM_by_location.pl"),
         $c->ram_opt,
         pre($rum_nu),
         "-o", post($rum_nu_sorted),
         "--chr-counts-out", post($chr_counts_nu)]);
    
    my @goal = ($rum_unique_sorted,
                $rum_nu_sorted,
                $rum_unique,
                $rum_nu,
                $sam_file,
                $nu_stats,
                $chr_counts_nu,
                $chr_counts_u,
                $c->sam_header($chunk || 1)
            );
    
    if ($c->strand_specific) {

        for my $strand (qw(p m)) {
            for my $sense (qw(s a)) {
                my $file = $c->quant(strand => $strand, 
                                     sense => $sense,
                                     chunk => $chunk);
                push @goal, $file;
                $m->add_command(
                    name => "Generate quants for strand $strand, sense $sense",
                    commands => 
                        [["perl", $c->script("rum2quantifications.pl"),
                          "--genes-in", $gene_annotations,
                          "--unique-in", pre($rum_unique_sorted),
                          "--non-unique-in", pre($rum_nu_sorted),
                          "-o", post($file),
                          "-countsonly",
                          "--strand", $strand,
                          $sense eq 'a' ? "--anti" : ""]]
                    );
                if ($c->alt_quants) {

                    my $file = $c->alt_quant(strand => $strand, 
                                             sense => $sense,
                                             chunk => $chunk);

                    push @goal, $file;
                    $m->add_command(
                        name => "Generate alt quants for strand $strand, sense $sense",
                        commands => 
                            [["perl", $c->script("rum2quantifications.pl"),
                              "--genes-in", $c->alt_quants,
                              "--unique-in", pre($rum_unique_sorted),
                              "--non-unique-in", pre($rum_nu_sorted),
                              "-o", post($file),
                              "-countsonly",
                              "--strand", $strand,
                              $sense eq 'a' ? "--anti" : ""]]
                        );
                }
            }
        }
    }

    if ($c->should_quantify) {
        push @goal, $c->quant(chunk => $chunk);
        $m->add_command(
            name => "Generate quants",
            commands => 
            [["perl", $c->script("rum2quantifications.pl"),
              "--genes-in", $gene_annotations,
              "--unique-in", pre($rum_unique_sorted),
              "--non-unique-in", pre($rum_nu_sorted),
              "-o", post($c->quant(chunk => $chunk)),
              "-countsonly"]]
        );            
    }
    if ($c->alt_quants) {
        push @goal, $c->alt_quant(chunk => $chunk);

        $m->add_command(
            name => "Generate alt quants",
            commands => 
                [["perl", $c->script("rum2quantifications.pl"),
                  "--genes-in", $c->alt_quants,
                  "--unique-in", pre($rum_unique_sorted),
                  "--non-unique-in", pre($rum_nu_sorted),
                  "-o", post($c->alt_quant(chunk => $chunk)),
                  "-countsonly"]]
            );
    }

    $m->set_goal(\@goal);

    return $self->{chunk_workflows}[$chunk] = $m;
}

sub postprocessing_workflow {

    my ($self) = @_;
    my $c     = $self->{config};
    my $index = $self->{index};

    my $gene_annotations    = $index ? $index->gene_annotations : '';
    my $genome_fasta        = $index ? $index->genome_fasta     : '';
    my $genome_size         = $index ? $index->genome_size      : 0;

    if (my $w = $self->{postprocessing_workflow}) {
        return $w;
    }

    $c or croak "I need a config";

    my $rum_nu         = $c->in_output_dir("RUM_NU");
    my $rum_nu_cov     = $c->in_output_dir("RUM_NU.cov");
    my $rum_unique     = $c->in_output_dir("RUM_Unique");
    my $rum_unique_cov = $c->in_output_dir("RUM_Unique.cov");

    my @chunks = (1 .. $c->chunks || 1);

    my $name = $c->name;
    my $w = RUM::Workflow->new(name => "Postprocessing");

    my @rum_unique_by_id = map { $c->chunk_file("RUM_Unique", $_) } @chunks;
    my @rum_nu_by_id     = map { $c->chunk_file("RUM_NU", $_) } @chunks;

    my @rum_unique    = map { $c->chunk_file("RUM_Unique.sorted", $_) } @chunks;
    my @rum_nu        = map { $c->chunk_file("RUM_NU.sorted", $_) } @chunks;
    my @sam_headers   = map { $c->sam_header($_) } @chunks;
    my @chr_counts_u  = map { $c->chunk_file("chr_counts_u", $_) } @chunks;
    my @chr_counts_nu = map { $c->chunk_file("chr_counts_nu", $_) } @chunks;
    my @nu_stats      = map { $c->chunk_file("nu_stats", $_) } @chunks;

    my $sam_file_fromjunctions = $c->in_output_dir("RUM.sam.fromjunctions");
    my $sam_file = $c->in_output_dir("RUM.sam");
    my @sam_files = map { $c->chunk_file("RUM.sam", $_) } @chunks;


    my @start = (@rum_unique, @rum_nu, @sam_headers, @sam_files, @rum_nu_by_id, @rum_unique_by_id);
    my $mapping_stats               = $c->in_output_dir("mapping_stats_temp.txt");
    my $inferred_internal_exons     = $c->in_output_dir("inferred_internal_exons.bed");
    my $inferred_internal_exons_txt = $c->in_output_dir("inferred_internal_exons.txt");

    my @goal = ($c->mapping_stats_final,
                $rum_unique,
                $rum_nu,
                $rum_unique_cov,
                $rum_nu_cov);
    if ($c->should_do_junctions) {
        push @goal, ($inferred_internal_exons,
                     $inferred_internal_exons_txt);
        push @goal, $c->novel_inferred_internal_exons_quantifications 
            if $c->should_quantify;
    }

    $w->step(
        "Merge RUM_Unique files",
        ["perl", $c->script("merge_sorted_RUM_files.pl"),
            "-o", post($rum_unique),
         map { pre($_) } @rum_unique]);

    $w->step(
        "Merge RUM_NU files",
        ["perl", $c->script("merge_sorted_RUM_files.pl"),
         "-o", post($rum_nu),
         map { pre($_) } @rum_nu]);

    my $reads_fa = $c->chunk_file("reads.fa", $c->chunks);

    push @start, @chr_counts_u, @chr_counts_nu;
    $w->add_command(
        name => "Compute mapping statistics",
        pre => [$rum_unique, $rum_nu, @chr_counts_u, @chr_counts_nu, @rum_unique_by_id, @rum_nu_by_id],
        post => [$mapping_stats],
        commands => sub {
            my $reads = $reads_fa;
            local $_ = `tail -2 $reads`;
            my @max_seq_opt = /seq.(\d+)/s ? ("--max-seq", $1) : ();
            my $out = $w->temp($mapping_stats);
            return [
                ["perl", $c->script("count_reads_mapped.pl"),
                 map(("--unique-in", $_), @rum_unique_by_id),
                 map(("--non-unique-in", $_), @rum_nu_by_id),
                 "--min-seq", 1,
                 @max_seq_opt,
                 ">", $w->temp($mapping_stats)],
                ["echo", ">>", $out],
                ["echo", "RUM_Unique reads per chromosome", ">>", $out],
                ["echo", "-------------------------------", ">>", $out],
                ["perl", $c->script("merge_chr_counts.pl"),
                 "-o", $out, @chr_counts_u],


                ["echo", ">>", $out],
                ["echo", "RUM_NU reads per chromosome", ">>", $out],
                ["echo", "-------------------------------", ">>", $out],
                ["perl", $c->script("merge_chr_counts.pl"),
                 "-o", $out, @chr_counts_nu],

                ["perl", $c->script("merge_nu_stats.pl"), @nu_stats, ">>", $out]
            ];
        }
    );

    if ($c->should_quantify) {
        push @goal, $c->quant;
        push @goal, $c->alt_quant if $c->alt_quants;

        if ($c->strand_specific) {
            my @strand_specific;
            my @alt_strand_specific;
            for my $sense (qw(s a)) {
                for my $strand (qw(p m)) {
                    
                    my %opts = (
                        strand => $strand,
                        sense => $sense
                    );

                    my (@quants, @alt_quants);

                    for my $chunk (@chunks) {
                        push @quants, $c->quant(%opts, chunk => $chunk);
                        push @alt_quants, $c->alt_quant(%opts, chunk => $chunk);
                    }

                    push @start, @quants;
                    push @strand_specific, $c->quant(%opts);

                    if ($c->alt_quant) {
                        @alt_quants = map { $c->alt_quant(%opts, chunk => $_) } @chunks;
                        push @start, @alt_quants;
                        push @alt_strand_specific, $c->alt_quant(%opts);
                    }

                    $w->add_command(
                        name => "Merge quants $strand $sense",
                        pre => [@quants],
                        commands => [[
                            "perl", $c->script("merge_quants.pl"),
                            "--chunks", $c->chunks || 1,
                            "-o", post($c->quant(%opts)),
                            "--strand", "$strand$sense",
                            $c->output_dir . "/chunks"]]);

                    $w->add_command(
                        name => "Merge alt quants $strand $sense",
                        pre => [@alt_quants],
                        commands => [[
                            "perl", $c->script("merge_quants.pl"),
                            "--alt",
                            "--chunks", $c->chunks || 1,
                            "-o", post($c->alt_quant(%opts)),
                            "--strand", "$strand$sense",
                            $c->output_dir . "/chunks"]]) if $c->alt_quants;
                }
            }

            $w->add_command(
                name => "Merge strand-specific quants",
                pre => [@strand_specific],
                commands => [[
                    "perl", $c->script("merge_quants_strandspecific.pl"),
                    @strand_specific,
                    $gene_annotations,
                    post($c->quant)]]);

            $w->add_command(
                name => "Merge strand-specific alt quants",
                pre => [@alt_strand_specific],
                commands => [[
                    "perl", $c->script("merge_quants_strandspecific.pl"),
                    @alt_strand_specific,
                    $c->alt_quant,
                    post($c->alt_quant)]]) if $c->alt_quants;
        }
        
        else {
            my @quants = map { $c->quant(chunk => $_) } @chunks; 
            my @alt_quants = map { $c->alt_quant(chunk => $_) } @chunks; 
            push @start, @quants;
            push @start, @alt_quants if $c->alt_quants;
            my @merge_quants_cmd = (
                "perl", $c->script("merge_quants.pl"));
            push @merge_quants_cmd, '--chunks', $c->chunks || 1;
            push @merge_quants_cmd, '-o', post($c->quant);
            push @merge_quants_cmd, $c->chunk_dir;
            $w->add_command(
                name => "Merge quants",
                pre => [$rum_unique, @quants],
                commands => [\@merge_quants_cmd]);
            
            $w->add_command(
                name => "Merge alt quants",
                pre => [$rum_unique, @alt_quants],
                commands => [[
                    "perl", $c->script("merge_quants.pl"),
                    "--alt",
                    "--chunks", $c->chunks || 1,
                    "-o", post($c->alt_quant),
                    $c->output_dir . "/chunks"]]) if $c->alt_quants;
        }
    }
    my $junctions_all_rum = $c->in_output_dir("junctions_all.rum");
    my $junctions_all_bed = $c->in_output_dir("junctions_all.bed");
    my $junctions_high_quality_bed = 
        $c->in_output_dir("junctions_high-quality.bed");
    
    if ($c->should_do_junctions) {

        push @goal, (
            $junctions_all_rum,
            $junctions_all_bed,
            $junctions_high_quality_bed);

        my $annotations = $c->alt_genes || $gene_annotations;

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
            my @strand_opt = $strand ? ("--strand", $strand) : "";

            $w->step(
                $name,
                ["perl", $c->script("make_RUM_junctions_file.pl"),
                 "--sam-in", pre($sam_file),
                 "--genome", $genome_fasta,
                 "--genes", $annotations,
                 "--all-rum-out", post($all_rum),
                 "--all-bed-out", post($all_bed),
                 "--high-bed-out", post($high_bed),
                 "--sam-out", post($sam_file_fromjunctions),
                 "--faok",
                 @strand_opt]);
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
                        ["grep", "-v", $remove,
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
             "-o", post($junctions_all_rum),
             "--location", 1,
             '--skip', 1,
             pre(junctions('all', 'rum'))]);

        $w->step(
            "Sort junctions (all, bed) by location",
            ["perl", $c->script("sort_by_location.pl"),
             "-o", post($junctions_all_bed),
             '--skip', 1,
             "--chromosome", 1,
             "--start", 2,
             "--end", 3,
             pre(junctions('all', 'bed'))]);

        $w->step(
            "Sort junctions (high-quality, bed) by location",
            ["perl", $c->script("sort_by_location.pl"),
             "-o", post($junctions_high_quality_bed),
             '--skip', 1,
             "--chromosome", 1,
             "--start", 2,
             "--end", 3,
             pre(junctions('high-quality', 'bed'))]);
    }

    $w->step(
        "Make unique coverage",
        ["perl", $c->script("rum2cov.pl"),
         "-o", post($rum_unique_cov),
         "--name", "'$name Unique Mappers'",
         "--stats", post($c->u_footprint),
         pre($rum_unique)]);

    $w->step(
        "Make non-unique coverage",
        ["perl", $c->script("rum2cov.pl"),
         "-o", post($rum_nu_cov),
         "--name", "'$name Non-Unique Mappers'",
         "--stats", post($c->nu_footprint),
         pre($rum_nu)]);
    
    if ($c->strand_specific) {

        my %labels = (Unique => "Unique",
                      NU => "Non-Unique",
                      plus => "Plus",
                      minus => "Minus");

        for my $u (qw(Unique NU)) {

            push @goal, $c->in_output_dir("RUM_${u}.plus");
            push @goal, $c->in_output_dir("RUM_${u}.minus");

            $w->step(
                "Break up $u file by strand",
                ["perl", $c->script("breakup_RUM_files_by_strand.pl"),
                 pre($c->in_output_dir("RUM_$u")),
                 post($c->in_output_dir("RUM_${u}.plus")),
                 post($c->in_output_dir("RUM_${u}.minus"))]);

            for my $strand (qw(plus minus)) {
                my $out = $c->in_output_dir("RUM_${u}.$strand.cov");
                push @goal, $out;
                my $name = "$name $labels{$u} Mappers $labels{$strand} Strand";
                $w->step(
                    "Make coverage for $u mappers $strand strand",
                    ["perl", $c->script("rum2cov.pl"),
                     pre($c->in_output_dir("RUM_${u}.$strand")),
                     "-o", post($out),
                     "--name", $name]);
            }
        }
    }

    if ($c->should_do_junctions) {
        $w->step(
            "Get inferred internal exons",
            ["perl", $c->script("get_inferred_internal_exons.pl"),
             "--junctions", pre($junctions_high_quality_bed),
             "--coverage", pre($rum_unique_cov),
             "--genes", $gene_annotations,
             "--bed", post($inferred_internal_exons),
             "> ", post($inferred_internal_exons_txt)]);
        
        if ($c->should_quantify) {
            $w->step(
                "Quantify novel exons",
                ["perl", $c->script("quantify_exons.pl"),
                 pre($inferred_internal_exons_txt),
                 pre($sam_file),
                 post($c->novel_inferred_internal_exons_quantifications)])
        }
    }
    
    $w->step(
        "Merge SAM headers",
        ["perl", $c->script("rum_merge_sam_headers.pl"),
         "--name", $c->name,
         map(pre($_), @sam_headers), "> ", post($c->sam_header)]);

    $w->step("Concatenate SAM files",
         ["cat", 
          pre($c->sam_header), 
          map(pre($_), @sam_files), 
          ">", post($sam_file)]);

    $w->step(
        "Finish mapping stats",
        ["perl", $c->script("rum_compute_stats.pl"),
         "--u-footprint", pre($c->u_footprint),
         "--nu-footprint", pre($c->nu_footprint),
         "--genome-size", $genome_size,
         pre($mapping_stats),
         ">", post($c->mapping_stats_final)]);
    
    push @goal, $sam_file;
#    push @goal, $reads_fa;
#    push @start, $reads_fa;
    $w->start([@start]);
    $w->set_goal([@goal]);

    return $self->{postprocessing_workflow} = $w;
}


1;

=head1 NAME

RUM::Workflows - Collection of RUM workflows.

=head1 CONSTRUCTORS

=over 4

=item new($config)

Make a new workflow collection based on the given configuration.

=back

=head1 OBJECT METHODS

=over 4

=item $workflows->chunk_workflow($chunk)

Return the RUM::Workflow for the given chunk which should be a number > 0.

=item $workflows->postprocessing_workflow

Return the RUM::Workflow for the postprocessing step.

=back

=cut

