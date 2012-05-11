package RUM::Script::MakeGuAndGnu;

no warnings;
use autodie;

use RUM::Usage;
use RUM::Logging;
use Getopt::Long;

our $log = RUM::Logging->get_logger();

$|=1;

sub same_or_mate {
    my ($x, $y) = @_;
    return $x->is_same_read($y) || $x->is_mate($y);
}



sub main {

    GetOptions(
        "unique=s" => \(my $outfile1),
        "non-unique=s" => \(my $outfile2),
        "type=s"       => \(my $type),
        "paired"     => \(my $paired),
        "single"     => \(my $single),
        "max-pair-dist=s" => \(my $max_distance_between_paired_reads = 500000),
        "help|h"    => sub { RUM::Usage->help },
        "verbose|v" => sub { $log->more_logging(1) },
        "quiet|q"   => sub { $log->less_logging(1) });

    @ARGV == 1 or RUM::Usage->bad(
        "Please specify an input file");
    
    $outfile1 or RUM::Usage->bad(
        "Please specify output file for unique mappers with --unique");

    $outfile2 or RUM::Usage->bad(
        "Please specify output file for non-unique mappers with --non-unique");

    ($single xor $paired) or RUM::Usage->bad(
        "Please specify exactly one type with either --single or --paired");

    $paired_end = $paired ? "true" : "false";

    my $bowtie_in = RUM::BowtieIO->new(-file => $ARGV[0]);
    
    my $it = $bowtie_in->aln_iterator->group_by(\&same_or_mate);

    open OUTFILE1, ">", $outfile1;
    open OUTFILE2, ">", $outfile2;

    while (my $group = $it->()) {

        my %a_reads;
        my %b_reads;

        $num_different_a = 0;

        my $n = @{ $group };

        my $i;
        for ($i = 0; $i<$n && $group->[$i]->is_forward; $i++) {
            $line2 = $group->[$i];

            # If it's not all N's
            local $_ = $line2->seq;
            unless (/^N+$/) {
                my $id     = $line2->readid;
                my $strand = $line2->strand;
                my $chr    = $line2->chromosome;
                my $start = $line2->loc + 1;
                $chr =~ s/:.*//;

                s/^(N+)// and $start += + length($1);
                $seq =~ s/N+$//;
                $end = $start + length - 1; 
            }

            my $key = join("\t", $id, $strand, $chr, $start, $end, $seq);

            $a_reads{$key} ||=
                RUM::Alignment->new(
                    -readid => $id,
                    -strand => $strand,
                    -chr => $chr,
                    -locs => [[$start, $end]],
                    -seq => $seq);

        }

        $num_different_b = 0;
        for (; $i < $n; $i++) {
            my $line2 = $group->[$i];
            local $_ = $line2->seq;
            unless (/^N+$/) {
                my $id     = $line2->readid;
                my $strand = $line2->strand;
                my $chr    = $line2->chromosome;
                my $start = $line2->loc + 1;
                $chr =~ s/:.*//;

                s/^(N+)// and $start += + length($1);
                $seq =~ s/N+$//;
                $end = $start + length - 1; 
            }
            $b_reads{$key} ||=
                RUM::Alignment->new(
                    -readid => $id,
                    -strand => $strand,
                    -chr => $chr,
                    -locs => [[$start, $end]],
                    -seq => $seq);
        }

        # NOTE: the following three if's cover all cases we care about, because if numa > 1 and numb = 0, then that's
        # not really ambiguous, blat might resolve it
        
        if(keys(%a_reads) == 1 && !keys(%b_reads)) { # unique forward match, no reverse
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
                print OUTFILE1 "$key\t$strand\n";
            }
        }
        if(!keys(%a_reads) && keys(%b_reads) == 1) { # unique reverse match, no forward
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
                print OUTFILE1 "$key\t$strand\n";
            }
        }
        if($paired_end eq "false") {
            if(keys(%a_reads) > 1) { 
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
                    print OUTFILE2 "$key\t$strand\n";
                }
            }
        }
        if (keys(%a_reads) && keys(%b_reads) && ($num_different_a * $num_different_b < 1000000)) { 
            # forward and reverse matches, must check for consistency, but not if more than 1,000,000 possibilities,
            # in that case skip...
            my %consistent_mappers;
            foreach $akey (keys %a_reads) {
                foreach $bkey (keys %b_reads) {
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
                        if ($achr eq $bchr && $astart <= $bstart && $bstart - $astart < $max_distance_between_paired_reads) {
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
                        if ($achr eq $bchr && $bstart <= $astart && $astart - $bstart < $max_distance_between_paired_reads) {
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
                print OUTFILE1 $str;
            }
            if ($count > 1) {
                # add something here so that if all consistent mappers agree on some
                # exons, then those exons will still get reported, each on its own line
                foreach $key (keys %consistent_mappers) {
                    print OUTFILE2 $key;
                }
            }
        }
    }
    close(OUTFILE1);
    close(OUTFILE2);
}

1;
