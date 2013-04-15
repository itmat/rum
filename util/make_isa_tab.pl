#!/usr/bin/env perl 

use strict;
use warnings;
use autodie;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use RUM::Config;
use Data::Dumper;


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
    my $species = lc RUM::Index->load($config->index_dir)->{latin_name};
    return $acc_by_species{$species};
}

sub parse_alignment_counts {
    my ($config) = @_;
    my $mapping_stats_filename = $config->in_output_dir('mapping_stats.txt');
    my $in = open('<', $mapping_stats);
    
}

my @fields = (

    ['Parameter Value[RUM_version]',            from_prop('version')],
    ['Parameter Value[RUM_index]',              from_prop('index_dir')],
    ['Parameter Value[species]',                from_index('latin_name')],
    ['Term Source REF',                         sub { 'NCBITaxon' } ],
    ['Term Accession Number',                  \&accession_number],
    ['Parameter Value[alt_genes]',              from_prop('alt_genes')],
    ['Parameter Value[alt_quant]',              from_prop('alt_quants')],
    ['Parameter Value[blat_only]',              from_prop('blat_only')],
    ['Parameter Value[count_mismatches]',       from_prop('count_mismatches')],
    ['Parameter Value[dna]',                    from_prop('dna')],
    ['Parameter Value[genome_only]',            from_prop('genome_only')],
    ['Parameter Value[limit_bowtie_nu]',        from_prop('bowtie_nu_limit')],
    ['Parameter Value[limit_nu]',               from_prop('nu_limit')],
    ['Parameter Value[max_insertions_per_read]',from_prop('max_insertions')],
    ['Parameter Value[min_identity]',           from_prop('min_identity')],
    ['Parameter Value[min_length]',             from_prop('min_length')],
    ['Parameter Value[preserve_name]',          from_prop('preserve_names')],
    ['Parameter Value[strand_specific]',        from_prop('strand_specific')],
    ['Parameter Value[blat_minIdentity]',       from_prop('blat_min_identity')],
    ['Parameter Value[blat_tileSize]',          from_prop('blat_tile_size')],
    ['Parameter Value[blat_stepSize]',          from_prop('blat_step_size')],
    ['Parameter Value[blat_repMatch]',          from_prop('blat_rep_match')],
    ['Parameter Value[blat_maxIntron]',         from_prop('blat_max_intron')],
    ['Derived Data File',                       ],
    ['Characteristics[Aligned reads]',          ],
    ['Characteristics[uniquely aligned reads]', ]

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

#print "[job]\n";
#for my $name ($config->property_names) {
#    if (defined(my $value = $config->get($name))) {
#        print $name, "=", $config->get($name), "\n";
#    }
#}


print "\n\n[index]\n";
my $index = RUM::Index->load($config->index_dir);
for my $k (keys %{ $index }) {
    if (defined (my $v = $index->{$k})) {
        print "$k=$v\n";
    }
}



for my $field (@fields) {
    my ($header, $fn) = @{ $field };
    my $value = $fn->($config) if defined $fn;
    $value = '' unless defined $value;
    print "$header: $value\n";
}
