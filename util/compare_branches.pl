#!/usr/bin/env perl 

use strict;
use warnings;
use autodie qw(:all);

use Getopt::Long;
use File::Copy;
use File::Temp;

my @files = (
    {
        name => "RUM.sam",
        transform => chain(\&remove_id_prefix_and_sort,
                           \&strip_hi_field),
        compare => \&diff
    },
    {
        name => "RUM_NU",
        transform => \&remove_id_prefix_and_sort,
        compare => \&diff
    },
    {
        name => "RUM_Unique",
        transform => \&remove_id_prefix_and_sort,
        compare => \&diff
    },
    {
        name => "RUM_Unique.cov",
        transform => skip_headers(1),
        compare => \&diff
    },
    {
        name => "RUM_NU.cov",
        transform => skip_headers(1),
        compare => \&diff
    },
    {
        name => sub { "feature_quantifications_$_[0]" },
        transform => \&copy,
        compare => \&diff
    },
    {
        name => "inferred_internal_exons.txt",
        transform => \&copy,
        compare => \&diff
    },
    {
        name => "inferred_internal_exons.bed",
        transform => \&copy,
        compare => \&diff
    },
    {
        name => "junctions_all.rum",
        transform => \&copy,
        compare => \&diff
    },
    {
        name => "junctions_all.bed",
        transform => \&copy,
        compare => \&diff
    },
    {
        name => "junctions_high-quality.bed",
        transform => \&copy,
        compare => \&diff
    },
    {
        name => "mapping_stats.txt",
        transform => \&copy,
        compare => \&diff
    },
    {
        name => sub { "novel_inferred_internal_exons_quantifications_$_[0]" },
        transform => \&copy,
        compare => \&diff
    },
    
);

sub name {
    my ($file, $branch) = @_;
    my $name = $file->{name};
    return ref($name) ? $name->($branch) : $name;
}

sub main {
    GetOptions(
        "old=s", \(my $old),
        "new=s", \(my $new));

    if ( ! -d transformed_dir()) {
        mkdir transformed_dir();
    }

    if ( ! -d diff_dir()) {
        mkdir diff_dir();
    }
         
    for my $branch ($old, $new) {
        run_rum($branch);
        my $transformed_dir = transformed_dir($branch);
        if ( ! -d transformed_dir($branch)) {
            mkdir transformed_dir($branch);
        }

        for my $file (@files) {
            my $name = name($file, $branch);
            my $raw = output_dir($branch) . "/$name";
            my $transformed = transformed_dir($branch) . "/$name";
            print "Transforming $raw to $transformed\n";
            $file->{transform}->($raw, $transformed);
        }
    }

    for my $file (@files) {
        my $name     = name($file, '*');
        my $compare  = $file->{compare};
        my $old_file = transformed_dir($old) . '/' . name($file, $old);
        my $new_file = transformed_dir($new) . '/' . name($file, $new);
        my $diff_file = diff_dir() . "/$name";
        print "Comparing $old_file and $new_file\n";
        $compare->($old_file, $new_file, $diff_file);
    }
}

sub skip_headers {
    my ($num_lines) = @_;
    return sub {
        open my $in, '<', shift;
        open my $out, '>', shift;
        for my $line_num (1 .. $num_lines) {
            <$in>;
        }
        while (my $line = <$in>) {
            print $out $line;
        }
    };
}

sub chain {
    my (@transforms) = @_;

    return sub {
        my ($in_filename , $out_filename) = @_;
        my @temp_files = map { File::Temp->new->filename } (0 .. $#transforms - 1);
        my @filenames = ($in_filename, @temp_files, $out_filename);
        for my $i (0 .. $#transforms) {
            print "  transforming $filenames[$i] to $filenames[$i+1]\n";
            $transforms[$i]->($filenames[$i], $filenames[$i + 1]);
        }
    };
}

sub code_dir {
    my ($branch) = @_;
    return "rum/$branch";
}

sub output_dir {
    my ($branch) = @_;
    return "out/$branch";
}

sub transformed_dir {
    my ($branch) = @_;
    return $branch ? "transformed/$branch" : 'transformed';
}

sub diff_dir {
    "diffs";
}

sub strip_hi_field {
    my ($in_filename, $out_filename) = @_;
    open my $in, '<', $in_filename;
    open my $out, '>', $out_filename;
    while (my $line = <$in>) {
        $line =~ s/\tHI:i:\d*// or warn "Didn't find HI field on $line\n";
        print $out $line;
    }
}

sub run_rum {
    my ($branch) = @_;
    my $dir = code_dir($branch);
    my $data_dir = output_dir($branch);
    if ( ! -d $dir ) {
        system 'git', 'clone', 'https://github.com/PGFI/rum.git', $dir;
        system "cd $dir; git checkout $branch; perl Makefile.PL";
    }
    if ( ! -e sam_file($data_dir)) {
        system "perl $dir/bin/rum_runner align -o $data_dir @ARGV --name $branch";
    }
}

sub sam_file { shift . "/RUM.sam" }
sub rum_unique_file { shift . "/RUM_Unique" }
sub rum_nu_file { shift . "/RUM_NU" }

sub remove_id_prefix_and_sort {
    my ($in_filename, $out_filename) = @_;
    open my $in,  '<', $in_filename;
    open my $out, '>', $out_filename;
    my @lines = (<$in>);
    for my $line (@lines) {
        $line =~ s/ .*?\t/\t/;
    }
    for my $line (sort @lines) {
        print $out $line;
    }    
}

sub diff {
    my ($old, $new, $out) = @_;
    my $status = system [0, 1], "diff $old $new > $out";
    if ($status) {
        warn "  They differ\n";
    }
}

main;
