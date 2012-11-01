package RUM::Script::SplitReads;

use strict;
use warnings;
use autodie;

use base 'RUM::Script::Base';

sub summary {
    'Splits the input file(s) into chunks'
}

sub accepted_options {
    return (
        RUM::Property->new(
            opt => 'split-dir=s',
            desc => 'Directory to write the split files to. Read files will be written to $split_dir/reads.fa.$chunk. If input is fastq, quality files will be written to $split_dir/quals.fa.$chunk. If --preserve-names is specified, name mappings will be written to $split_dir/read_names.$chunk.',
            required => 1
        ),
        RUM::Property->new(
            opt => 'all-dir=s',
            desc => 'Directory to write the files containing all the reads to, in $all_dir/reads.fa. If input is fastq, qualities will be written to $all_dir/quals.fa. If --preserve-ames is specified, read name mappings will be written to $all_dir/read_names.$chunk.',
            required => 1
        ),
        RUM::Property->new(
            opt => 'preserve-names',
            desc => 'Produce name mapping files'
        ),
        RUM::Property->new(
            opt => 'chunks=s',
            desc => 'Number of chunks to create',
            required => 1,
            check => \&RUM::CommonProperties::check_int_gte_1),
        RUM::Property->new(
            opt => 'forward',
            desc => 'File containing forward reads',
            positional => 1,
            required => 1),
        RUM::Property->new(
            opt => 'reverse',
            desc => 'File containing reverse reads, if reads are paired',
            positional => 1)
      );
}

sub parser {
    my ($filename) = @_;
    if (!$filename) {
        return;
    }
    open my $in, '<', $filename;

    return sub {
        my $header = <$in>;
        if (! defined $header) {
            return;
        }

        my $sequence = <$in>;
        if (!defined $sequence) {
            die "The input file $filename seems to be incomplete. It ends with header line $header\n";
        }

        chomp $header;
        chomp $sequence;
        $header =~ s/^>//;

        return ($header, $sequence);
    };
}

sub all_dir   { shift->properties->get('all_dir') }
sub split_dir { shift->properties->get('split_dir') }

sub filename {
    my ($self, $base, $extension, $chunk) = @_;
    if ($chunk) {
        return File::Spec->catfile($self->split_dir, "$base.$extension.$chunk");
    }
    else {
        return File::Spec->catfile($self->all_dir, "$base.$extension");
    }
}

sub name_filename {
    my ($self, $chunk) = @_;
    if ($chunk) {
        return File::Spec->catfile($self->split_dir, "reads.fa.$chunk");
    }
    else {
        return File::Spec->catfile($self->all_dir, "reads.fa");
    }
}

sub read_handlers {
    my ($self) = @_;
    open my $all_read_fh, '>', $self->filename('reads', 'fa');
    my @handlers;
    for my $chunk ($self->chunk_numbers) {
        open my $chunk_read_fh, '>', $self->filename('reads', 'fa', $chunk);
        push @handlers, sub {
            my ($num, $dir, $seq) = @_;
            my $line = ">seq.$num$dir\n$seq\n";
            print $chunk_read_fh $line;
            print $all_read_fh   $line;
        };
    }
    return @handlers;
}

sub qual_handlers {
    my ($self) = @_;

    open my $all_fh, '>', $self->filename('quals', 'fa');
    my @handlers;
    for my $chunk ($self->chunk_numbers) {
        open my $chunk_fh, '>', $self->filename('quals', 'fa', $chunk);
        push @handlers, sub {
            my ($num, $dir, $seq) = @_;
            my $line = ">seq.$num$dir\n$seq\n";
            print $chunk_fh $line;
            print $all_fh   $line;
        };
    }
    return @handlers;
}

sub name_handlers {

    my ($self) = @_;

    if (!$self->properties->get('preserve_names')) {
        warn "Not doing names";
        return;
    }
    warn "Doing names";
    my @handlers;
    open my $all_fh, '>', $self->filename('read_names', 'tab');
    for my $chunk ($self->chunk_numbers) {
        open my $chunk_fh, '>', $self->filename('read_names', 'tab', $chunk);
        push @handlers, sub {
            my ($num, $direction, $name) = @_;
            my $line = "seq.$num$direction\t$name\n";
            print $chunk_fh $line;
            print $all_fh   $line;
        };
    }
    return @handlers;
}

sub chunk_numbers {
    my ($self) = @_;
    return (1 .. $self->properties->get('chunks'));
}

sub run {

    my ($self) = @_;

    my $props = $self->properties;

    my $chunks = $props->get('chunks');

    my $fwd = parser($props->get('forward'));
    my $rev = parser($props->get('reverse'));

    my @read_handlers = $self->read_handlers;
    my @name_handlers = $self->name_handlers;
    my @qual_handlers;# = $self->qual_handlers;

    my $handler = sub {
        my ($seq_num, $dir,
            $read_header, $read,
            $qual_header, $qual) = @_;
        my $i = ($seq_num - 1) % $chunks;

        # This will print the header and sequence to the "all reads"
        # file and the reads file for the appropriate chunk.
        $read_handlers[$i]->($seq_num, $dir, $read);

        # If we have qualities, print the qualities to the "all quals"
        # file and the quals file for this chunk.
        if (@qual_handlers) {
            $qual_handlers[$i]->($seq_num, $dir, $qual);
        }
        # Likewise if we are printing name mappings
        if (@name_handlers) {
            $name_handlers[$i]->($seq_num, $dir, $read_header);
        }
    };

    my $seq_num = 0;
    while (my @rec = $fwd->()) {
        $seq_num++;
        $handler->($seq_num, 'a', @rec);

        if ($rev) {
            @rec = $rev->();
            if (!@rec) {
                die "Something is wrong, there are more forward reads than reverse reads.\n";
            }
            $handler->($seq_num, 'b', @rec);
        }
    }
}

1;
