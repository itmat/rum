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
        "chunks=s"              => \($self->{chunks}),
        "all-reads=s"           => \($self->{all_reads_filename}),
        "all-quals=s"           => \($self->{all_quals_filename}),
        "chunk-quals-format=s"  => \($self->{chunk_quals_format}),
        "chunk-reads-format=s"  => \($self->{chunk_reads_format}),
        "quals!"                => \($self->{quals}),
    );

    my @filenames = @ARGV;

    my $usage = RUM::Usage->new;
    
    if (!$self->{chunks}) {
        $usage->bad('Please tell me how many chunks to create with --chunks');
    }
    if (!$self->{all_reads_filename}) {
        $usage->bad('Please tell me where to write all reads with --all-reads');
    }
    if (!$self->{chunk_reads_format}) {
        $usage->bad('Please give me a format for the read files with --chunk-reads-format');
    }
    if ( ! (@filenames == 1 ||
            @filenames == 2 ) ) {
        $usage->bad('Please give one or two read files on the command line');
    }
    $usage->check;
    
    $self->{filenames} = \@filenames;
    
    $self->split_reads;
}


sub new {
    my ($class, %params) = @_;
    
    my $self = $class->SUPER::new;
    $self->{chunks}                = delete $params{chunks};
    $self->{all_reads_filename}    = delete $params{all_reads_filename};
    $self->{all_quals_filename}    = delete $params{all_quals_filename};
    $self->{chunk_reads_format}    = delete $params{chunk_reads_format};
    $self->{chunk_quals_format}    = delete $params{chunk_quals_format};
    $self->{before_chunk_callback} = delete $params{before_chunk_callback};
    $self->{filenames}             = delete $params{filenames} || [];
    $self->{has_quals}             = delete $params{has_quals};

    return $self;
}

sub split_reads {

    my ($self, %params) = @_;
    my $chunks                =    $self->{chunks};
    my $before_chunk_callback =    $self->{before_chunk_callback};
    my @filenames             = @{ $self->{filenames} || [] };
    my $has_quals             =    $self->{has_quals};

    if (!defined($has_quals)) {
        $self->logger->info("quals was not defined, so I'll ".
                            "try to determine whether the input is fastq.");
        $has_quals = $filenames[0] =~ /\.(fq|fastq)$/;
        $self->logger->info('Input does' . ($has_quals ? ' ' : ' not ') . 
                            'appear to be fastq');
    }

    my $fmt = $has_quals ? 'fastq' : 'fasta';
    my @fhs = map { open my $fh, '<', $_; $fh } @filenames;
    my @iters = map { RUM::SeqIO->new(-fh => $_, fmt => $fmt) } @fhs;
    
    my $total_size = -s $fhs[0];
    my $size_per_chunk = $total_size / $chunks;
    
    my @boundaries = map { $size_per_chunk * $_ } (1 .. $chunks);
    
    my $seq_num = 0;
    
    open my $all_fh, '>', $self->{all_reads_filename};
    my $all_out = RUM::SeqIO->new(-fh => $all_fh);
    my $all_quals_out;
    if ($has_quals) {
        $self->logger->info('Treating file as FASTQ');
        if (!$self->{all_quals_filename} || 
            !$self->{chunk_quals_format}) {
            die("The input file has qualities by I don't know where " .
                "to write the qualities to.");
        }

        open my $quals_fh, '>', $self->{all_quals_filename};
        $all_quals_out = RUM::SeqIO->new(-fh => $quals_fh);
    }
    else {
        $self->logger->info('Treating file as FASTA');
    }
    my %num_fwd_reads_for_length;
    my %num_rev_reads_for_length;

  CHUNK: for my $chunk (1 .. $chunks) {
        my $stop = $chunk * $size_per_chunk;
        my $reads_out_filename = sprintf $self->{chunk_reads_format}, $chunk;
        if ($before_chunk_callback) {
            $before_chunk_callback->(chunk => $chunk,
                                     filename => $reads_out_filename,
                                     first_read => $seq_num + 1);
        }

        open my $chunk_fh, '>', $reads_out_filename;
        my $chunk_out = RUM::SeqIO->new(-fh => $chunk_fh);

        my @quals_out;

        if ($has_quals) {
            my $quals_out_filename = sprintf $self->{chunk_quals_format}, $chunk;
            open my $chunk_quals_fh, '>', $quals_out_filename;
            my $chunk_quals_out = RUM::SeqIO->new(-fh => $chunk_quals_fh);
            @quals_out = ($all_quals_out, $chunk_quals_out);
        }

        my @seq_out = ($all_out, $chunk_out);

      READ: while (my $fwd = $iters[0]->next_val) {
            $seq_num++;

            my @recs = ($fwd->copy(order => $seq_num, direction => 'a'));
            $num_fwd_reads_for_length{length $fwd->seq}++;

            if (@filenames == 2) {
                my $rev = $iters[1]->next_val->copy(order => $seq_num, direction => 'b');
                push @recs, $rev;
                $num_rev_reads_for_length{length $rev->seq}++;
            }

            for my $out (@seq_out) {
                for my $rec (@recs) {
                    $out->write_seq($rec);
                }
            }

            for my $out (@quals_out) {
                for my $rec (@recs) {
                    $out->write_qual_as_seq($rec);
                }
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

