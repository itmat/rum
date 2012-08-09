package RUM::Script::SplitReads;

use strict;
use warnings;

use RUM::Usage;
use RUM::SeqIO;

use List::Util qw(min max sum);
use base 'RUM::Script::Base';

sub main {

    my $self = __PACKAGE__->new;

    $self->get_options(
        "chunks=s"           => \(my $chunks),
        "all-reads=s"        => \(my $all_reads_filename),
        "all-quals=s"        => \(my $all_quals_filename),
        "chunk-reads-format=s" => \(my $chunk_reads_format),
        "chunk-quals-format=s" => \(my $chunk_quals_format)
    );

    my @filenames = @ARGV;

    my $usage = RUM::Usage->new;
    
    if (!$chunks) {
        $usage->bad('Please tell me how many chunks to create with --chunks');
    }
    if (!$all_reads_filename) {
        $usage->bad('Please tell me where to write all reads with --all-reads');
    }
    if (!$chunk_reads_format) {
        $usage->bad('Please give me a format for the read files with --chunk-reads-format');
    }
    if (!@filenames) {
        $usage->bad('Please give one or two read files on the command line');
    }

    $usage->check;

    split_reads(
        chunks => $chunks,
        all_reads_filename => $all_reads_filename,
        all_quals_filename => $all_quals_filename,
        chunk_reads_format => $chunk_reads_format,
        chunk_quals_format => $chunk_quals_format,
        filenames          => \@filenames);

}

sub split_reads {

    my (%params) = @_;

    my $chunks = delete $params{chunks};
    my $all_reads_filename = delete $params{all_reads_filename};
    my $all_quals_filename = delete $params{all_quals_filename};
    my $chunk_reads_format = delete $params{chunk_reads_format};
    my $chunk_quals_format = delete $params{chunk_quals_format};
    my $before_chunk_callback = delete $params{before_chunk_callback};
    my @filenames          = @{ delete $params{filenames} || [] };

    my @fhs = map { open my $fh, '<', $_; $fh } @filenames;
    my @iters = map { RUM::SeqIO->new(-fh => $_) } @fhs;
    
    my $total_size = -s $fhs[0];
    my $size_per_chunk = $total_size / $chunks;
    
    my @boundaries = map { $size_per_chunk * $_ } (1 .. $chunks);
    
    my $seq_num = 0;
    
    open my $all_fh, '>', $all_reads_filename;

    my %num_fwd_reads_for_length;
    my %num_rev_reads_for_length;

  CHUNK: for my $chunk (1 .. $chunks) {
        my $stop = $chunk * $size_per_chunk;
        my $out_filename = sprintf $chunk_reads_format, $chunk;
        if ($before_chunk_callback) {
            $before_chunk_callback->(chunk => $chunk,
                                     filename => $out_filename,
                                     first_read => $seq_num + 1);
        }

        open my $chunk_fh, '>', $out_filename;
        my $out = RUM::SeqIO->new(-fh => $chunk_fh);
        
      READ: while (my $fwd = $iters[0]->next_val) {
            $seq_num++;

            printf $chunk_fh ">%s|seq.%da\n%s\n", $fwd->readid, $seq_num, $fwd->seq;
            printf $all_fh   ">%s|seq.%da\n%s\n", $fwd->readid, $seq_num, $fwd->seq;
            $num_fwd_reads_for_length{length $fwd->seq}++;

            if (@filenames == 2) {
                my $rev = $iters[1]->next_val;
                $num_rev_reads_for_length{length $rev->seq}++;
                printf $chunk_fh ">%s|seq.%db\n%s\n", $rev->readid, $seq_num, $rev->seq;
                printf $all_fh   ">%s|seq.%db\n%s\n", $rev->readid, $seq_num, $rev->seq;
            }
            next CHUNK if tell($fhs[0]) > $stop && $chunk != $chunks;
        }
    }
    
    my @lengths = (keys(%num_fwd_reads_for_length),
                   keys(%num_rev_reads_for_length));

    my $max_len = max @lengths;
    my $min_len = min @lengths;

    printf "%11s   %13s   %13s\n", "Read length", "Num fwd reads", "Num rev reads";

    for my $len ($min_len .. $max_len) {
        my $num_fwd = $num_fwd_reads_for_length{$len} || 0;
        my $num_rev = $num_rev_reads_for_length{$len} || 0;
        printf "%11d   %13d   %13d\n", $len, $num_fwd, $num_rev;
    }

    my $total_fwd = sum(values(%num_fwd_reads_for_length)) || 0;
    my $total_rev = sum(values(%num_rev_reads_for_length)) || 0;
    print '-' x 43, "\n";
    printf "%11s   %13d   %13d\n", "Total", $total_fwd, $total_rev;
}    
    
1;

=head1 NAME

RUM::Script::SplitReads - Split the input files into chunks

=head1 METHODS

=over 4

=item main

Parses command line, validates arguments, split reads.

=item split_reads(%params)

Splits the files, which should be described by the given %params:

=over 4

=item chunks

Number of chunks to create.

all_reads_filename

Filename to write all of the reads to. This will contain just the
reads (not the qualities) from the input file, and both directions if
the input data is paired-end. All read ids will have a sequence number
and direction appended.

all_quals_filename

Filename to write all the quality strings to.

chunk_reads_format

Format as expected by sprintf to create the read file for each
chunk. Should contain a '%d' field.

chunk_quals_format

Format as expected by sprintf to create the quals file for each
chunk. Should contain a '%d' field.

filenames

=back
