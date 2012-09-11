package RUM::Script::MakeGuAndGnu;

no warnings;
use autodie;

use RUM::Usage;
use RUM::Logging;
use RUM::Bowtie;
use Getopt::Long;

use base 'RUM::Script::Base';

our $log = RUM::Logging->get_logger();

$|=1;

sub main {

    use strict;
    my $self = __PACKAGE__->new;

    $self->get_options(

        # Input files
        'index=s'         => \(my $index),
        'query=s'         => \(my $query),

        # Intermediate files
        'bowtie-out=s'    => \(my $bowtie_out),

        # Output files
        "unique=s"        => \(my $outfile1),
        "non-unique=s"    => \(my $outfile2),

        # Other params
        "type=s"          => \(my $type),
        "paired"          => \($self->{paired}),
        "single"          => \($self->{single}),
        'debug'           => \(my $debug),
        "max-pair-dist=s" => \($self->{max_distance_between_paired_reads} = 500000),
        'limit=s'         => \(my $limit),
    );

    $index or RUM::Usage->bad(
        "Please specify an index with --index");

    $query or RUM::Usage->bad(
        "Please specify a query with --query");
    
    $outfile1 or RUM::Usage->bad(
        "Please specify output file for unique mappers with --unique");

    $outfile2 or RUM::Usage->bad(
        "Please specify output file for non-unique mappers with --non-unique");

    ($self->{single} xor $self->{paired}) or RUM::Usage->bad(
        "Please specify exactly one type with either --single or --paired");

    my %bowtie_opts = (
        limit => $limit,
        index => $index,
        query => $query);

    if ($debug) {
        if ($bowtie_out) {
            $bowtie_opts{tee} = $bowtie_out;
        }
        else {
            RUM::Usage->bad("If you give the --debug option, please tell me ".
                            "where to put the bowtie output file, with ".
                            "--bowtie-out");
        }
    }


    open my $gu,    '>', $outfile1;
    open my $gnu,   '>', $outfile2;
    
    my $bowtie = RUM::Bowtie::run_bowtie(%bowtie_opts);
    $self->parse_output($bowtie, $gu, $gnu);
}

sub parse_output {

    my ($self, $bowtie, $gu, $gnu) = @_;

    $log->info("Parsing bowtie output (genome)");
    
    my $reader = RUM::Bowtie::bowtie_mapping_set_reader($bowtie);

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
        if (!$self->{paired}) {
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
                        if ($achr eq $bchr && $astart <= $bstart && $bstart - $astart < $self->{max_distance_between_paired_reads}) {
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
                        if ($achr eq $bchr && $bstart <= $astart && $astart - $bstart < $self->{max_distance_between_paired_reads}) {
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

1;
