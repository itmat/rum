#!/usr/bin/env perl 

use strict;
use warnings;
use autodie;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Config;

sub from_prop {
    my ($prop_name) = @_;
    return sub {
        my ($c) = @_;
        return $c->get($prop_name);
    }
}

sub from_index {
    my ($key) = @_;
    return sub {
        my ($c) = @_;
        my $index = RUM::Index->load($c->index_dir);
        return $index->{$key};
    }
}

sub species {
    my ($config) = @_;
    return lc RUM::Index->load($config->index_dir)->{latin_name};
}

my %acc_by_species = (
    'homo sapiens'             =>  9606,
    'saccharomyces cerevisiae' =>  4932,
    'mus musculus'             => 10090,
    'danio rerio'              =>  7955,
    'drosophila melanogaster'  =>  7227,
    'anopheles gambiae'        =>  7165,
    'caenorhabditis elegans'   =>  6239,
    'rattus norvegicus'        => 10116,
    'sus scrofa'               =>  9823,
    'canis lupus familiaris'   =>  9615,
    'pan troglodytes'          =>  9598,
    'macaca mulatta'           =>  9544,
    'gallus gallus'            =>  9031,
    'plasmodium falciparum'    =>  5833,
    'arabidopsis thaliana'     =>  3702,
);


sub accession_number {
    my ($config) = @_;
    return $acc_by_species{species($config)} || '';
}

sub parse_alignment_counts {
    my ($config) = @_;
    my $mapping_stats_filename = $config->in_output_dir('mapping_stats.txt');
    open(my $in, '<', $mapping_stats_filename);
    my ($unique, $non_unique);

    while (defined(my $line = <$in>)) {
        $line =~ s/,//g;
        if ($line =~ /^(UNIQUE MAPPERS|At least one of forward or reverse mapped):\s*(\d+)/) {
            $unique = $2;
        } 
        elsif ($line =~ /^(NON-UNIQUE MAPPERS|Total number consistent ambiguous):\s*(\d+)/) {
            $non_unique = $2;
        } 
    }
    if (!defined $unique) {
        warn "I couldn't find UNIQUE MAPPERS";
    }
    if (!defined $non_unique) {
        warn "I couldn't find NON-UNIQUE MAPPERS";
    }
    return ($unique, $non_unique);
}

sub unique_alignments {
    my ($config) = @_;
    my ($unique, $non_unique) = parse_alignment_counts($config);
    return $unique;
}

sub all_alignments {
    my ($config) = @_;
    my ($unique, $non_unique) = parse_alignment_counts($config);
    return $unique + $non_unique;
}

sub derived_file {
    my ($config, $filename) = @_;
    return $filename;
}

my @fields = (

    ['Parameter Value[RUM_version]',        from_prop('version')],
    ['Parameter Value[index_dir]',          from_prop('index_dir')],
    ['Parameter Value[name]',               from_prop('name')],
    ['Parameter Value[chunks]',             from_prop('chunks')],
    ['Parameter Value[forward_reads]',      from_prop('forward_reads')],
    ['Parameter Value[reverse_reads]',      from_prop('reverse_reads')],
    ['Term Source REF',                     sub { 'NCBITaxon' } ],
    ['Term Accession Number',               \&accession_number],
    ['Parameter Value[alt_genes]',          from_prop('alt_genes')],
    ['Parameter Value[alt_quants]',         from_prop('alt_quants')],
    ['Parameter Value[blat_only]',          from_prop('blat_only')],
    ['Parameter Value[count_mismatches]',   from_prop('count_mismatches')],
    ['Parameter Value[dna]',                from_prop('dna')],
    ['Parameter Value[genome_only]',        from_prop('genome_only')],
    ['Parameter Value[bowtie_nu_limit_nu]', from_prop('bowtie_nu_limit')],
    ['Parameter Value[nu_limit]',           from_prop('nu_limit')],
    ['Parameter Value[max_insertions]',     from_prop('max_insertions')],
    ['Parameter Value[min_identity]',       from_prop('min_identity')],
    ['Parameter Value[min_length]',         from_prop('min_length')],
    ['Parameter Value[preserve_names]',     from_prop('preserve_names')],
    ['Parameter Value[strand_specific]',    from_prop('strand_specific')],
    ['Parameter Value[blat_min_identity]',  from_prop('blat_min_identity')],
    ['Parameter Value[blat_tile_size]',     from_prop('blat_tile_size')],
    ['Parameter Value[blat_step_size]',     from_prop('blat_step_size')],
    ['Parameter Value[blat_rep_match]',     from_prop('blat_rep_match')],
    ['Parameter Value[blat_max_intron]',    from_prop('blat_max_intron')],
    ['Derived Data File',                   \&derived_file],
    ['Comment[Aligned reads]',              \&all_alignments],
    ['Comment[uniquely aligned reads]',     \&unique_alignments]

);


my @props = grep { $_ ne 'forward_reads' &&
                   $_ ne 'reverse_reads' } RUM::Config->property_names;

@props = RUM::Config->property_names;

my $config = eval {
    RUM::Config->new->parse_command_line(load_default => 1,
                                         options => \@props,
                                         nocheck => 1);
};

if (my $errors = $@) {
    my $msg;
    if (ref($errors) && $errors->isa('RUM::UsageErrors')) {
        $msg = "";
        for my $error ($errors->errors) {
            chomp $error;
            $msg .= "* $error\n";
        }
    }
    else {
        $msg = "\n$errors\n";
    }
    die $msg;
}


opendir my $dir, $config->output_dir;

my @headers = map { $_->[0] } @fields;

print join("\t", @headers), "\n";

for my $filename ( readdir $dir ) {

    next if -d $filename;

    my @values;

    for my $field (@fields) {
        my ($header, $fn) = @{ $field };
        $fn ||= sub { };
        my $val = $fn->($config, $filename);
        $val = '' unless defined $val;
        push @values, $val;
    }
    print join("\t", @values), "\n";
}


