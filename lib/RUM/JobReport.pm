package RUM::JobReport;

use strict;
use warnings;
use autodie;

use base 'RUM::Base';

use Cwd qw(realpath);
use List::Util qw(max);
use FindBin qw($Bin);
use Data::Dumper;
use RUM::Index;

FindBin->again;

sub filehandle {
    my ($self) = @_;
    open my $fh, '>>', $self->config->in_output_dir('rum_job_report.txt');
    return $fh;
}

sub print_header {
    my ($self) = @_;

    my $config = $self->config;

    my $fh = $self->filehandle;

    my $rum_home = realpath("$Bin/../");

print $fh <<"EOF";
RUM Information
===============

 Version: $RUM::Pipeline::VERSION
Released: $RUM::Pipeline::RELEASE_DATE
Location: $rum_home

Job Configuration
=================
EOF

    my @name_table = (
        name                  => 'Job name',
        output_dir            => 'Output directory',
        forward_reads         => 'Forward read file',
        reverse_reads         => 'Reverse read file',

        read_length           => 'Read length',

        index_dir             => 'Index directory',
        genome_bowtie         => 'Bowtie genome index',
        trans_bowtie          => 'Bowtie transcriptome index',
        annotations           => 'Annotations',
        genome_fa             => 'Genome fasta file',
        genome_size           => 'Genome size',

        dna                   => 'DNA mode?',
        genome_only           => 'Genome only (no transcriptome)?',
        junctions             => 'Junctions?',
        preserve_names        => 'Preserve names?',
        quantify              => 'Quantify?',
        strand_specific       => 'Strand-specific?',

        max_insertions        => 'Max insertions',
        min_identity          => 'Min identity',

        chunks                => 'Chunks',

        platform              => 'Platform',
        ram                   => 'RAM available (GB)',
        ram_ok                => undef,
        alt_genes             => 'Alternate gene model',
        alt_quants            => undef,
        bowtie_nu_limit       => 'Limit Bowtie non-unique output?',
        count_mismatches      => 'Count mismatches?',
        input_is_preformatted => undef,
        input_needs_splitting => undef,
        limit_nu_cutoff       => undef,
        nu_limit              => 'Max non-unique mappers per read?',
        min_length            => 'Min alignment length',
        quals_file            => undef,

        blat_max_intron       => 'BLAT max intron',
        blat_min_identity     => 'BLAT min identity',
        blat_only             => 'BLAT only (no bowtie)',
        blat_rep_match        => 'BLAT rep match',
        blat_step_size        => 'BLAT step size',
        blat_tile_size        => 'BLAT tile size',

    );
    my $index = RUM::Index->load($config->index_dir);
    my $bowtie_genome_index = $index->bowtie_genome_index;
    my $bowtie_trans_index = $index->bowtie_transcriptome_index;
    my $annotations = $index->gene_annotations;
    my $read_len = $config->variable_length_reads ? 'variable' : $config->read_length || '';

    my %overrides;
    $overrides{junctions} = $config->should_do_junctions;
    $overrides{quantify} = $config->should_quantify;
    $overrides{read_length} = $read_len;
    $overrides{genome_bowtie} = $bowtie_genome_index;
    $overrides{trans_bowtie} = $bowtie_trans_index;
    $overrides{annotations} = $annotations;
    $overrides{genome_fa} = $index->genome_fasta;
    $overrides{genome_size} = $index->genome_size;


    my %name_for = @name_table;
    
    my @ordered_keys = @name_table[ grep { ! ( $_ % 2 ) } (0 .. $#name_table) ];

    for my $key ($self->config->property_names) {
        if ( ! exists $name_for{$key} ) {
            $name_for{$key} = $key;
            push @ordered_keys, $key;
        }
    }

    my @lengths = grep { $_ } map { defined $_ ? length($_) :0 } values %name_for;
    my $max_len_name = max(@lengths);
        
  PROPERTY: for my $key (@ordered_keys) {
        my $name = $name_for{$key};

        my $val = exists $overrides{$key} ? $overrides{$key} : $self->config->get($key);

        next PROPERTY if ! $name;

        if (ref($val)) {
            $val = Data::Dumper->new([$val])->Indent(0)->Dump if ref($val);
            $val =~ s/\$VAR (?: \d+) \s* = \s*//mx;
        }

        printf $fh "%${max_len_name}s : %s\n", $name, $val || "";
    }

    print $fh <<"EOF";

Milestones
==========

EOF


}

sub print_start_preproc   { shift->print_milestone("Started preprocessing") }
sub print_start_proc      { shift->print_milestone("Started processing") }
sub print_start_postproc  { shift->print_milestone("Started postprocessing") }
sub print_skip_preproc    { shift->print_milestone("Skipped preprocessing") }
sub print_skip_proc       { shift->print_milestone("Skipped processing") }
sub print_skip_postproc   { shift->print_milestone("Skipped postprocessing") }
sub print_finish_preproc  { shift->print_milestone("Finished preprocessing") }
sub print_finish_proc     { shift->print_milestone("Finished processing") }
sub print_finish_postproc { shift->print_milestone("Finished postprocessing") }


sub print_milestone {
    my ($self, $label) = @_;
    my $fh = $self->filehandle;
    printf $fh "%24s: %s", $label, `date`;
}

1;

__END__

=head1 NAME

RUM::JobReport - Prints a summary report for a job

=head1 SYNOPSIS

  use RUM::JobReport;

  # Construct it with a RUM::Config
  my $jr = RUM::JobReport->new($config);

  # Print the report header before running anything
  $jr->print_header;

  # Then print a timestamp whenever you start, finish, or decide to
  # skip a phase:
  $jr->print_start_preproc;
  ...

=head1 CONSTRUCTORS

=over 4

=item RUM::JobReport->new($config)

Create a new job report given a RUM::Config.

=back

=head1 METHODS

=over 4

=item $jr->print_header

Print the report header.

=item $jr->print_start_preproc

=item $jr->print_start_proc

=item $jr->print_start_postproc

Indicate that we've started the specified phase.

=item $jr->print_finish_preproc

=item $jr->print_finish_proc

=item $jr->print_finish_postproc

Indicate that we've finished the specified phase.

=item $jr->print_skip_preproc

=item $jr->print_skip_proc

=item $jr->print_skip_postproc

Indicate that we've decided to skip the specified phase.

=item $jr->print_milestone($milestone)

Print a timestamp for the given milestone, which should be a string.

=item $jr->filehandle

Open and return a writeable filehandle for our report.

=back

=head1 AUTHOR

Mike DeLaurentis (delaurentis@gmail.com)

=head1 COPYRIGHT

Copyright 2012, University of Pennsylvania


