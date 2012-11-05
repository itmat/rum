package RUM::Script::MakeGuAndGnu;

use warnings;
use autodie;

use RUM::Usage;
use RUM::Logging;
use RUM::Bowtie;
use Getopt::Long;
use RUM::CommandLineParser;
use RUM::CommonProperties;

use base 'RUM::Script::Base';

our $log = RUM::Logging->get_logger();

$|=1;

sub summary {
    "Run bowtie against the genome index";
}

sub command_line_parser {
    my ($self) = @_;
    my $parser = RUM::CommandLineParser->new;

    $parser->add_prop(
        opt => 'index=s',
        desc => 'Bowtie genome index',
        required => 1
    );
    $parser->add_prop(
        opt => 'query=s',
        desc => 'FASTA file containing the reads',
        required => 1
    );
    $parser->add_prop(
        opt => 'unique-out=s',
        desc => 'Output file for unique mappers',
        required => 1
    );
    $parser->add_prop(
        opt => 'non-unique-out=s',
        desc => 'Output file for non-unique mappers',
        required => 1
    );
    $parser->add_prop(RUM::CommonProperties->read_type);
    $parser->add_prop(RUM::CommonProperties->max_pair_dist);
    $parser->add_prop(
        opt => 'debug',
        desc => 'Save the output from bowtie for debugging purposes'
    );
    $parser->add_prop(
        opt => 'limit=s',
        desc => 'Limit argument for bowtie');

    $parser->add_prop(
        opt => 'bowtie-out=s',
        desc => 'File to write intermediate bowtie output to'
    );
    return $parser;
    
}



sub run {
    use strict;
    my ($self) = @_;

    my $props = $self->properties;

    my %bowtie_opts = (
        limit => $props->get('limit'),
        index => $props->get('index'),
        query => $props->get('query'));

    if ($props->get('debug')) {
        if (my $bowtie_out = $props->get('bowtie_out')) {
            $bowtie_opts{tee} = $bowtie_out;
        }
        else {
            RUM::Usage->bad("If you give the --debug option, please tell me ".
                            "where to put the bowtie output file, with ".
                            "--bowtie-out");
        }
    }

    open my $gu,  '>', $props->get('unique_out');
    open my $gnu, '>', $props->get('non_unique_out');

    my $bowtie = RUM::Bowtie::run_bowtie(%bowtie_opts);
    $self->parse_output($bowtie, $gu, $gnu);
}

sub parse_output {

    my ($self, $bowtie, $gu, $gnu) = @_;
    $log->info("Parsing bowtie output (genome)");

    my $reader = RUM::Bowtie::bowtie_mapping_set_reader($bowtie);

    my $props = $self->properties;

  READ: while (my ($forward, $reverse) = $reader->()) {
        my @seqs_a = @{ $forward };
        my @seqs_b = @{ $reverse };

        my $numa = @seqs_a;
        my $numb = @seqs_b;

        undef %a_reads;
        undef %b_reads;

        my $line = $seqs_a[0];
        $seqs_a[0] =~ /seq\.(\d+)/ or $seqs_b[0] =~ /seq\.(\d+)/;
        my $num = $1;

        if($numa > 0 || $numb > 0) {
            $num_different_a = 0;
            for($i=0; $i<$numa; $i++) {
                $line2 = $seqs_a[$i];
                if(!($line2 =~ /^N+$/)) {
                    @a = split(/\t/,$line2);
                    $id = $a[0];
                    $strand = $a[1];
                    $chr = $a[2];
                    $chr =~ s/:.*//;
                    $start = $a[3]+1;
                    $seq = $a[4];
                    if($seq =~ /^(N+)/) {
                        $seq =~ s/^(N+)//;
                        $Nprefix = $1;
                        @x = split(//,$Nprefix);
                        $start = $start + @x;
                    }
                    $seq =~ s/N+$//;
                    @x = split(//,$seq);
                    $seqlength = @x;
                    $end = $start + $seqlength - 1; 
                }
                $a_reads{"$id\t$strand\t$chr\t$start\t$end\t$seq"}++;
                if($a_reads{"$id\t$strand\t$chr\t$start\t$end\t$seq"} == 1) {
                    $num_different_a++;
                }
            }
            $num_different_b = 0;
            for($i=0; $i<$numb; $i++) {
                $line2 = $seqs_b[$i];
                if(!($line2 =~ /^N+$/)) {
                    @a = split(/\t/,$line2);
                    $id = $a[0];
                    $strand = $a[1];
                    $chr = $a[2];
                    $chr =~ s/:.*//;
                    $start = $a[3]+1;
                    $seq = $a[4];
                    if($seq =~ /^(N+)/) {
                        $seq =~ s/^(N+)//;
                        $Nprefix = $1;
                        @x = split(//,$Nprefix);
                        $start = $start + @x;
                    }
                    $seq =~ s/N+$//;
                    @x = split(//,$seq);
                    $seqlength = @x;
                    $end = $start + $seqlength - 1; 
                }
                $b_reads{"$id\t$strand\t$chr\t$start\t$end\t$seq"}++;
                if($b_reads{"$id\t$strand\t$chr\t$start\t$end\t$seq"} == 1) {
                    $num_different_b++;
                }
            }
        }
        # NOTE: the following three if's cover all cases we care about, because if numa > 1 and numb = 0, then that's
        # not really ambiguous, blat might resolve it
        
        if($num_different_a == 1 && $num_different_b == 0) { # unique forward match, no reverse
            foreach $key (keys %a_reads) {
                $key =~ /^[^\t]+\t(.)\t/;
                $strand = $1;
                $key =~ s/\t\+//;
                $key =~ s/\t-//;
                $key =~ /^[^\t]+\t[^\t]+\t([^\t]+\t[^\t]+)\t/;
                $xx = $1;
                $yy = $xx;
                $xx =~ s/\t/-/;  # this puts the dash between the start and end
                $key =~ s/$yy/$xx/;
                print $gu "$key\t$strand\n";
            }
        }
        if($num_different_a == 0 && $num_different_b == 1) { # unique reverse match, no forward
            foreach $key (keys %b_reads) {
                $key =~ /^[^\t]+\t(.)\t/;
                $strand = $1;
                if($strand eq "+") {  # got to reverse this because it's the reverse read,
                    # because we are reporting strand of forward in all cases
                    $strand = "-";
                } else {
                    $strand = "+";
                }
                $key =~ s/\t\+//;
                $key =~ s/\t-//;
                $key =~ /^[^\t]+\t[^\t]+\t([^\t]+\t[^\t]+)\t/;
                $xx = $1;
                $yy = $xx;
                $xx =~ s/\t/-/;  # this puts the dash between the start and end
                $key =~ s/$yy/$xx/;
                print $gu "$key\t$strand\n";
            }
        }
        if ($props->get('type') ne 'paired') {
            if($num_different_a > 1) { 
                foreach $key (keys %a_reads) {
                    $key =~ /^[^\t]+\t(.)\t/;
                    $strand = $1;
                    $key =~ s/\t\+//;
                    $key =~ s/\t-//;
                    $key =~ /^[^\t]+\t[^\t]+\t([^\t]+\t[^\t]+)\t/;
                    $xx = $1;
                    $yy = $xx;
                    $xx =~ s/\t/-/;  # this puts the dash between the start and end
                    $key =~ s/$yy/$xx/;
                    print $gnu "$key\t$strand\n";
                }
            }
        }
        if(($num_different_a > 0 && $num_different_b > 0) && ($num_different_a * $num_different_b < 1000000)) { 
            # forward and reverse matches, must check for consistency, but not if more than 1,000,000 possibilities,
            # in that case skip...
            undef %consistent_mappers;
            for my $a_key_in (keys %a_reads) {
                
                foreach $bkey (keys %b_reads) {
                    my $akey = $a_key_in;
                    @a = split(/\t/,$akey);
                    $aid = $a[0];
                    $astrand = $a[1];
                    $achr = $a[2];
                    $astart = $a[3];
                    $aend = $a[4];
                    $aseq = $a[5];
                    @a = split(/\t/,$bkey);
                    $bstrand = $a[1];
                    $bchr = $a[2];
                    $bstart = $a[3];
                    $bend = $a[4];
                    $bseq = $a[5];
                    if ($astrand eq "+" && $bstrand eq "-") {
                        if ($achr eq $bchr && $astart <= $bstart && $bstart - $astart < $props->get('max_pair_dist')) {
                            if ($bstart > $aend + 1) {
                                $akey =~ s/\t\+//;
                                $akey =~ s/\t-//;
                                $bkey =~ s/\t\+//;
                                $bkey =~ s/\t-//;
                                $akey =~ /^[^\t]+\t[^\t]+\t([^\t]+\t[^\t]+)\t/;
                                $xx = $1;
                                $yy = $xx;
                                $xx =~ s/\t/-/;
                                $akey =~ s/$yy/$xx/;
                                $bkey =~ /^[^\t]+\t[^\t]+\t([^\t]+\t[^\t]+)\t/;
                                $xx = $1;
                                $yy = $xx;
                                $xx =~ s/\t/-/;
                                $bkey =~ s/$yy/$xx/;
                                $consistent_mappers{"$akey\t$astrand\n$bkey\t$astrand\n"}++;
                            } else {
                                $overlap = $aend - $bstart + 1;
                                @sq = split(//,$bseq);
                                $joined_seq = $aseq;
                                for ($i=$overlap; $i<@sq; $i++) {
                                    $joined_seq = $joined_seq . $sq[$i];
                                }
                                $aid =~ s/a//;
                                if ($bend >= $aend) {
                                    $consistent_mappers{"$aid\t$achr\t$astart-$bend\t$joined_seq\t$astrand\n"}++;
                                } else {
                                    $consistent_mappers{"$aid\t$achr\t$astart-$aend\t$joined_seq\t$astrand\n"}++;
                                }
                            }
                        }
                    }
                    if ($astrand eq "-" && $bstrand eq "+") {
                        if ($achr eq $bchr && $bstart <= $astart && $astart - $bstart < $props->get('max_pair_dist')) {
                            if ($astart > $bend + 1) {
                                $akey =~ s/\t\+//;
                                $akey =~ s/\t-//;
                                $bkey =~ s/\t\+//;
                                $bkey =~ s/\t-//;
                                $akey =~ /^[^\t]+\t[^\t]+\t([^\t]+\t[^\t]+)\t/;
                                $xx = $1;
                                $yy = $xx;
                                $xx =~ s/\t/-/;
                                $akey =~ s/$yy/$xx/;
                                $bkey =~ /^[^\t]+\t[^\t]+\t([^\t]+\t[^\t]+)\t/;
                                $xx = $1;
                                $yy = $xx;
                                $xx =~ s/\t/-/;
                                $bkey =~ s/$yy/$xx/;
                                $consistent_mappers{"$akey\t$astrand\n$bkey\t$astrand\n"}++;
                            } else {
                                $overlap = $bend - $astart + 1;
                                @sq = split(//,$bseq);
                                $joined_seq = "";
                                for ($i=0; $i<@sq-$overlap; $i++) {
                                    $joined_seq = $joined_seq . $sq[$i];
                                }
                                $joined_seq = $joined_seq . $aseq;
                                $aid =~ s/a//;
                                if ($bstart <= $astart) {
                                    $consistent_mappers{"$aid\t$achr\t$bstart-$aend\t$joined_seq\t$astrand\n"}++;
                                } else {
                                    $consistent_mappers{"$aid\t$achr\t$astart-$aend\t$joined_seq\t$astrand\n"}++;
                                }
                            }
                        }
                    }
                }
            }
            $count = 0;
            foreach $key (keys %consistent_mappers) {
                $count++;
                $str = $key;
            }
            if ($count == 1) {
                print $gu $str;
            }
            if ($count > 1) {
                # add something here so that if all consistent mappers agree on some
                # exons, then those exons will still get reported, each on its own line
                foreach $key (keys %consistent_mappers) {
                    print $gnu $key;
                }
            }
        }
    }

}

sub synopsis {
    return <<'EOF';
  make_GU_and_GNU.pl [OPTIONS]         \
    --unique     <gu_filename>         \
    --non-unique <gnu_filename>        \
    --type {single|paired}             \
    --index      <bowtie_genome_index> \
    --query      <reads_file>
EOF
    
}

sub description {
    return <<'EOF';

=head2 Input

This script takes the output of a bowtie mapping against the genome, which has
been sorted by sort_bowtie.pl, and parses it to have the four columns:

=over 4

=item 1. read name

=item 2. chromosome

=item 3. span

=item 4. sequence

=back

A line of the (input) bowtie file should look like:

  seq.1a   -   chr14   1031657   CACCTAATCATACAAGTTTGGCTAGTGGAAAA

Sequence names are expected to be of the form seq.Na where N in an
integer greater than 0.  The 'a' signifies this is a 'forward' read,
and 'b' signifies 'reverse' reads.  The file may consist of all
forward reads (single-end data), or it may have both forward and
reverse reads (paired-end data).  Even if single-end the sequence
names still must end with an 'a'.

=head2 Output

The line above is modified by the script to be:

  seq.1a   chr14   1031658-1031689   CACCTAATCATACAAGTTTGGCTAGTGGAAAA

In the case of single-end reads, if there is a unique such line for
seq.1a then it is written to the file specified by <gu_filename>.  If
there are multiple lines for seq.1a then they are all written to the
file specified by <gnu_filename>.

In the case of paired-end reads the script tries to match up entries
for seq.1a and seq.1b consistently, which means:

=over 4

=item 1. both reads are on the same chromosome

=item 2. the two reads map in opposite orientations

=item 3. the start of reads are further apart than ends of reads and
no further apart than $max_distance_between_paired_reads

=back

If the two reads do not overlap then the consistent mapper is
represented by two consecutive lines, the forward (a) read first and
the reverse (b) read second.  If the two reads overlap then the two
lines are merged into one line and the a/b designation is removed.

If there is a unique consistent mapper it is written to the file
specified by <gu_filename>.  If there are multiple consistent mappers
they are all written to the file specified by <gnu_filename>.  If only
the forward or reverse read map then it does not write anything.

EOF

}


1;
