package RUM::Script::RumToSam;

no warnings;

use File::Copy;
use RUM::Usage;
use RUM::Logging;
use Getopt::Long;
use RUM::Common qw(addJunctionsToSeq reversecomplement spansTotalLength);
our $log = RUM::Logging->get_logger();
$|=1;

sub main {

    $map_names = "false";

    GetOptions(
        "suppress1" => \(my $suppress1),
        "suppress2" => \(my $suppress2),
        "suppress3" => \(my $suppress3),
        "sam-out=s" => \(my $sam_outfile),
        "quals-in=s" => \(my $qual_file),
        "reads-in=s" => \(my $reads_file),
        "non-unique-in=s" => \(my $rum_nu_file),
        "unique-in=s" => \(my $rum_unique_file),
        "name-mapping=s" => \(my $name_mapping_file),
        "help|h"    => sub { RUM::Usage->help },
        "verbose|v" => sub { $log->more_logging(1) },
        "quiet|q"   => sub { $log->less_logging(1) });

    $sam_outfile or RUM::Usage->bad(
        "Please specify an output file with --sam-out");
    $reads_file or RUM::Usage->bad(
        "Please specify a reads file with --reads-in");

    if ($name_mapping_file) {
        $map_names = "true";
        open(NAMEMAPPING, $name_mapping_file) or die "ERROR: in script parsefastq.pl, cannot open \"$name_mapping_file\" for reading.\n\n";
        while ($line = <NAMEMAPPING>) {
            chomp($line);
            @a = split(/\t/,$line);
            $namemapping{$a[0]} = $a[1];
        }
        close(NAMEMAPPING);
    }

    open(INFILE, $reads_file);
    $line = <INFILE>;
    chomp($line);
    $line =~ /seq.(\d+)/;
    $firstseqnum = $1;
    $line = <INFILE>;
    chomp($line);
    $readlength = length($line);
    unless ($qual_file) {
        $QUAL{$readlength} = ".";
    }
    $line = <INFILE>;
    chomp($line);
    $line =~ /seq.\d+(.)/;
    $type = $1;
    if ($type eq 'b') {
        $paired = "true";
    } else {
        $paired = "false";
    }
    close(INFILE);
    $x = `tail -2 $reads_file | head -1`;
    $x =~ /seq.(\d+)/;
    $lastseqnum = $1;

    $bitflag[0] = "the read is paired in sequencing";
    $bitflag[1] = "the read is mapped in a proper pair";
    $bitflag[2] = "the query sequence itself is unmapped";
    $bitflag[3] = "the mate is unmapped";
    $bitflag[4] = "strand of the query";
    $bitflag[5] = "strand of the mate";
    $bitflag[6] = "the read is the first read in a pair";
    $bitflag[7] = "the read is the second read in a pair";
    $bitflag[8] = "the alignment is not primary";
    $bitflag[9] = "the read fails platform/vendor quality checks";
    $bitflag[10] = "the read is either a PCR duplicate or an optical duplicate";

    if ($rum_unique_file) {
        open(RUMU, $rum_unique_file) or die "\nERROR: in script rum2sam.pl: cannot open the file '$rum_unique_file' for reading\n\n";
    }
    if ($rum_nu_file) {
        open(RUMNU, $rum_nu_file) or die "\nERROR: in script rum2sam.pl: cannot open the file '$rum_nu_file' for reading\n\n";
    }
    open(READS, $reads_file) or die "\nERROR: in script rum2sam.pl: cannot open the file '$reads_file' for reading\n\n";

    # checking that the first line in RUMU really looks like it should:

    if ($rum_unique_file) {
        $line = <RUMU>;
        close(RUMU);
        @a = split(/\t/,$line);
        $flag = 0;
        if (!($a[0] =~ /^seq.\d+[ab]?/)) {
            $flag = 1;
        }
        if ($a[2] =~ /[^\d-, ]/) {
            $flag = 1;
        }
        if (!($a[3] eq "+" || $a[3] eq "-")) {
            $flag = 1;
        }
        if (!($a[4] =~ /^[ACGTN:+]+$/)) {
            $flag = 1;
        }
        if ($flag == 1) {
            die "\nERROR: in script rum2sam.pl: the first line of the file '$rum_unique_file' is misformatted,\nit does not look like a RUM output file.\n";
        }
        open(RUMU, $rum_unique_file) or die "\nERROR: in script rum2sam.pl: cannot open the file '$rum_unique_file' for reading\n\n";
    }
    if ($rum_nu_file) {
        $line = <RUMNU>;
        close(RUMNU);
        @a = split(/\t/,$line);
        $flag = 0;
        if (!($a[0] =~ /^seq.\d+[ab]?/)) {
            $flag = 1;
        }
        if ($a[2] =~ /[^\d-, ]/) {
            $flag = 1;
        }
        if (!($a[3] eq "+" || $a[3] eq "-")) {
            $flag = 1;
        }
        if (!($a[4] =~ /^[ACGTN:+]+$/)) {
            $flag = 1;
        }
        if ($flag == 1) {
            die "\nERROR: in script rum2sam.pl: the first line of the file '$rum_nu_file' is misformatted,\nit does not look like a RUM output file.\n";
        }
        open(RUMNU, $rum_nu_file) or die "\nERROR: in script rum2sam.pl: cannot open the file '$rum_nu_file' for reading\n\n";
    }

    if ($qual_file) {
        open(QUALS, $qual_file);
    }
    open(SAM, ">$sam_outfile");

    for ($seqnum = $firstseqnum; $seqnum <= $lastseqnum; $seqnum++) {

        undef @FORWARD;
        undef @REVERSE;
        undef @JOINED;
        $num_mappers = 0;

        $forward_read = <READS>;
        $forward_read = <READS>;
        chomp($forward_read);
        $forward_read_hold = $forward_read;
        $readlength_forward = length($forward_read);
        if ((!$qual_file) && !($QUAL{$readlength_forward} =~ /\S/)) {
            $QUAL{$readlength_forward} = ".";
        }
        if ($paired eq "true") {
            $reverse_read = <READS>;
            $reverse_read = <READS>;
            chomp($reverse_read);
            $reverse_read_hold = $reverse_read;
            $readlength_reverse = length($reverse_read);
            if ((!$qual_file) && !($QUAL{$readlength_reverse} =~ /\S/)) {
                $QUAL{$readlength_reverse} = ".";
            }
        }

        if ($qual_file) {
            $forward_qual = <QUALS>;
            $forward_qual = <QUALS>;
            chomp($forward_qual);
            if ($paired eq "true") {
                $reverse_qual = <QUALS>;
                $reverse_qual = <QUALS>;
                chomp($reverse_qual);
            }
        } else {
            $forward_qual = $QUAL{$readlength_forward};
            $reverse_qual = $QUAL{$readlength_reverse};
        }

        $unique_mapper_found = "false";
        $non_unique_mappers_found = "false";
        $rum_u_forward = "";
        $rum_u_reverse = "";
        $rum_u_joined = "";
        $FORWARD[0] = "";
        $REVERSE[0] = "";
        $JOINED[0] = "";
        if ($rum_unique_file) {
            $flag = 0;
        } else {
            $flag = 1;
        }
        while ($flag == 0) {
            $line = <RUMU>;
            chomp($line);
            $type = "";
            if ($line =~ /seq.(\d+)(.)/) {
                $sn = $1;
                $type = $2;
            }
            if ($sn == $seqnum && $type eq "a") {
                $rum_u_forward = $line;
                $unique_mapper_found = "true";
                $FORWARD[0] = $rum_u_forward;
                $num_mappers = 1;
            }
            if ($sn == $seqnum && $type eq "b") {
                $rum_u_reverse = $line;
                $unique_mapper_found = "true";
                $REVERSE[0] = $rum_u_reverse;
                $num_mappers = 1;
            }
            if ($sn == $seqnum && $type eq "\t") {
                $rum_u_joined = $line;
                $unique_mapper_found = "true";
                $JOINED[0] = $rum_u_joined;
                $num_mappers = 1;
            }
            if ($sn > $seqnum) {
                $len = -1 * (1 + length($line));
                seek(RUMU, $len, 1);
                $flag = 1;
            }
            if ($line eq '') {
                $flag = 1;
            }
        }
        if ($unique_mapper_found eq "false" && $rum_nu_file) {
            $flag = 0;
            $num_mappers = 0;
            $last_type_found = "";
            while ($flag == 0) {
                $line = <RUMNU>;
                chomp($line);
                $type = "";
                if ($line =~ /seq.(\d+)(.)/) {
                    $sn = $1;
                    $type = $2;
                }
                if ($sn == $seqnum && $type eq "a") {
                    if ($last_type_found eq "a") {
                        $REVERSE[$num_mappers] = "";
                        $num_mappers++;
                    }
                    $JOINED[$num_mappers] = "";
                    $non_unique_mappers_found = "true";
                    $FORWARD[$num_mappers] = $line;
                    $last_type_found = "a";
                }
                if ($sn == $seqnum && $type eq "b") {
                    if ($last_type_found eq "b") {
                        $FORWARD[$num_mappers] = "";
                    }
                    $JOINED[$num_mappers] = "";
                    $non_unique_mappers_found = "true";
                    $REVERSE[$num_mappers] = $line;
                    $last_type_found = "b";
                    $num_mappers++;
                }
                if ($sn == $seqnum && $type eq "\t") {
                    $non_unique_mappers_found = "true";
                    $JOINED[$num_mappers] = $line;
                    $FORWARD[$num_mappers] = "";
                    $REVERSE[$num_mappers] = "";
                    $num_mappers++;
                }
                if ($sn > $seqnum) {
                    if ($last_type_found eq "a") {
                        $REVERSE[$num_mappers] = "";
                        $JOINED[$num_mappers] = "";
                        $num_mappers++;
                    }
                    $len = -1 * (1 + length($line));
                    seek(RUMNU, $len, 1);
                    $flag = 1;
                }
                if ($line eq '') {
                    if ($last_type_found eq "a") {
                        $REVERSE[$num_mappers] = "";
                        $JOINED[$num_mappers] = "";
                        $num_mappers++;
                    }
                    $flag = 1;
                }
            }
        }

        if ($unique_mapper_found eq "true" || $non_unique_mappers_found eq "true") {
            for ($mapper=0; $mapper<$num_mappers; $mapper++) {
                $rum_u_forward = $FORWARD[$mapper];
                $rum_u_reverse = $REVERSE[$mapper];
                $rum_u_joined = $JOINED[$mapper];
	    
	    
                # SET THE BITSCORE
	    
                $bitscore_f = 0;
                $bitscore_r = 0;
                if ($paired eq "true") {
                    $bitscore_f = 65;
                    $bitscore_r = 129;
                    if (!($rum_u_joined =~ /\S/)) {
                        if (!($rum_u_forward =~ /\S/) && !($rum_u_reverse =~ /\S/)) {
                            $bitscore_r = $bitscore_r + 12;
                            $bitscore_f = $bitscore_f + 12;
                        }
                        if ($rum_u_forward =~ /\S/ && !($rum_u_reverse =~ /\S/)) {
                            $bitscore_r = $bitscore_r + 4;
                            $bitscore_f = $bitscore_f + 8;
                        }
                        if ($rum_u_reverse =~ /\S/ && !($rum_u_forward =~ /\S/)) {
                            $bitscore_f = $bitscore_f + 4;
                            $bitscore_r = $bitscore_r + 8;
                        }
                    }
                } else {
                    $bitscore = 0;
                }
                if (($rum_u_forward =~ /\S/ && $rum_u_reverse =~ /\S/) || $rum_u_joined =~ /\S/) {
                    $bitscore_f = $bitscore_f + 2;
                    $bitscore_r = $bitscore_r + 2;
                }
	    
                $joined = "false";
                if ($rum_u_joined =~ /\S/) {
                    # FORWARD AND REVERSE MAPPED, AND THEY ARE JOINED, GATHER INFO
                    $joined = "true";
                    undef @piecelength;
                    @ruj = split(/\t/,$rum_u_joined);
                    $ruj[4] =~ s/://g;
                    @PL = split(/\+/,$ruj[4]);
                    $piecelength[0] = length($PL[0]);
                    for ($pl=1; $pl<@PL; $pl++) {
                        $piecelength[$pl] = length($PL[$pl]) + $piecelength[$pl-1];
                    }
                    @ruj = split(/\t/,$rum_u_joined);
                    if ($ruj[3] eq "-") {
                        $upstream_read = $reverse_read_hold;
                        $readlength_upstream = $readlength_reverse;
                        $readlength_downstream = $readlength_forward;
                    } else {
                        $upstream_read = $forward_read_hold;
                        $readlength_upstream = $readlength_forward;
                        $readlength_downstream = $readlength_reverse;
                    }
                    $x = $upstream_read;
                    $ruj[4] =~ s/://g;
                    $ruj[4] =~ s/\+//g;
                    $y = $ruj[4];
                    $prefix_offset_upstream = 0;
                    $L = length($x);
                    $count=0;
                    $suffix_offset_upstream = 0;
                    $LEN = 0;
                    $LENflag = 0;
                    $LEN_current_best=0;
                    while ($LENflag == 0) {
                        $LENflag = 1;
                        until ($y =~ /^$x/) {
                            $x =~ s/^.//;
                            $count++;
                            $prefix_offset_upstream++;
                        }
                        $LEN = $L - $count;
                        if ($LEN >= $LEN_current_best) {
                            $suffix_offset_upstream_current_best = $suffix_offset_upstream;
                            $prefix_offset_upstream_current_best = $prefix_offset_upstream;
                            $LEN_current_best = $LEN;
                        }
                        if ($LEN < $readlength_upstream) {
                            $LENflag = 0;
                            $x = $upstream_read;
                            $suffix_offset_upstream++;
                            for ($j=0; $j<$suffix_offset_upstream; $j++) {
                                $x =~ s/.$//;
                            }
                            $prefix_offset_upstream = 0;
                            $count = 0;
                            $L = length($x);
                            if ($L < 1) {
                                last;
                            }
                        }
                    }
		
                    $prefix_offset_upstream = $prefix_offset_upstream_current_best;
                    $suffix_offset_upstream = $suffix_offset_upstream_current_best;
		
                    $UR = $upstream_read;
                    $replace = "";
                    for ($i=0; $i<$suffix_offset_upstream; $i++) {
                        $UR =~ s/.$//;
                        $replace = $replace . "X";
                    }
                    $UR2 = $UR;
                    $UR = $UR . $replace;
		
                    $plen = $readlength_upstream - $prefix_offset_upstream - $suffix_offset_upstream;
                    $pl=0;
                    $RC = 0;
                    $matchlength = $piecelength[0];

                    while ($piecelength[$pl] + $prefix_offset_upstream < $readlength_upstream - $suffix_offset_upstream) {
                        $plen = $plen - ($piecelength[$pl+1] - $piecelength[$pl]);
                        if ($piecelength[$pl+1] > $readlength_upstream) { # insertion went past the end of the read,
                            # so overcorrected, this fixes that
                            $plen = $plen + ($piecelength[$pl+1] - $readlength_upstream);
                        }
                        substr($UR2, $piecelength[$pl]+$RC+$prefix_offset_upstream, 0, "+");
                        $RC++;
                        $XX = $piecelength[$pl+1]+$RC+$prefix_offset_upstream;
                        $YY = length($UR2);
                        if ($XX <= $YY) {
                            substr($UR2, $piecelength[$pl+1]+$RC+$prefix_offset_upstream, 0, "+");
                        } else { # individual alignments don't have insertions at the ends,
                            # so removing it because it'll mess things up downstream
                            if ($UR2 =~ s/\+([^\+]+)$//) {
                                $suffix_offset_upstream = $suffix_offset_upstream + length($1);
                            }
                        }
                        if ($UR2 =~ s/\+([^\+]+)\+$//) { # just in case there's still an insertion at the end...
                            $suffix_offset_upstream = $suffix_offset_upstream + length($1);
                        }
                        $RC++;
                        $pl=$pl+2;
                        $matchlength = $matchlength + $piecelength[$pl] - $piecelength[$pl-1];
                    }

                    for ($i=0; $i<$prefix_offset_upstream; $i++) {
                        $UR2 =~ s/^.//;
                    }
                    $upstream_spans = &getprefix($ruj[2], $plen);
		
                    if ($ruj[3] eq "-") {
                        $downstream_read = reversecomplement($forward_read_hold);
                        $bitscore_f = $bitscore_f + 16;
                        $bitscore_r = $bitscore_r + 32;
                    } else {
                        $downstream_read = reversecomplement($reverse_read_hold);
                        $bitscore_r = $bitscore_r + 16;
                        $bitscore_f = $bitscore_f + 32;
                    }
                    $x = $downstream_read;
                    $y = $ruj[4];
                    $suffix_offset_downstream = 0;
                    $L = length($x);
                    $count=0;
                    $prefix_offset_downstream = 0;
                    $LEN = 0;
                    $LENflag = 0;
                    $LEN_current_best=0;
                    $tried_mismatch = "false";
                    while ($LENflag == 0) {
                        $LENflag = 1;
                        until (($y =~ /$x$/ && !($x =~ /^\./))|| length($x)==0) {
                            $x =~ s/.$//;
                            $count++;
                            $suffix_offset_downstream++;
                        }
                        $LEN = $L - $count;
                        if ($LEN >= $LEN_current_best) {
                            $suffix_offset_downstream_current_best = $suffix_offset_downstream;
                            $prefix_offset_downstream_current_best = $prefix_offset_downstream;
                            $LEN_current_best = $LEN;
                        }
                        if ($LEN < $readlength_downstream) {
                            $LENflag = 0;
                            $x = $downstream_read;
                            $prefix_offset_downstream++;
                            for ($j=0; $j<$prefix_offset_downstream; $j++) {
                                $x =~ s/^.//;
                            }
                            $suffix_offset_downstream = 0;
                            $count = 0;
                            $L = length($x);
                            if ($L < 1) {
                                last;
                            }
                        }
                    }
                    $max_length_of_alignment = $readlength_downstream - $suffix_offset_downstream_current_best;
                    if (length($ruj[4]) < $max_length_of_alignment) {
                        $max_length_of_alignment = length($ruj[4]);
                    }
                    $x = $downstream_read;
                    for ($j=0; $j<$suffix_offset_downstream_current_best; $j++) {
                        $x =~ s/.$//;
                    }		
                    $removed_extra = 0;
                    until (length($x) <= $max_length_of_alignment) {
                        $x =~ s/^.//;
                        $removed_extra++;
                    }
                    $y = substr($ruj[4], -1*length($x));
                    $random_walk = 0;
                    $current_max = 0;
                    $current_max_arg = length($x)+1;
                    for ($i=length($x)-1; $i>=0; $i--) {
                        if (substr($x,$i,1) eq substr($y,$i,1)) {
                            $random_walk++;
                        } else {
                            $random_walk--;
                        }
                        if ($random_walk > $current_max) {
                            $current_max = $random_walk;
                            $current_max_arg = $i;
                        }
                    }
                    $prefix_offset_downstream_current_best = $removed_extra + $current_max_arg;
		
                    $prefix_offset_downstream = $prefix_offset_downstream_current_best;
                    $suffix_offset_downstream = $suffix_offset_downstream_current_best;
		
                    $DR = $downstream_read;
                    $replace = "";
                    for ($i=0; $i<$prefix_offset_downstream; $i++) {
                        $DR =~ s/^.//;
                        $replace = $replace . "X";
                    }
                    $DR2 = $DR;
                    $DR = $replace . $DR;
		
                    $offset = length($ruj[4]) + $prefix_offset_upstream + $suffix_offset_downstream - length($DR);
		
                    $OFFSET = $readlength_downstream - length($ruj[4]) - $suffix_offset_downstream;
                    $P = "";
                    if ($OFFSET < 0) {
                        $OFFSET = 0;
                    }
                    for ($i=0; $i<$OFFSET; $i++) {
                        $P = $P . " ";
                    }
                    $plen = $readlength_downstream - $prefix_offset_downstream - $suffix_offset_downstream;
		
                    $RC = 0;
                    $pl=0;

                    until ($piecelength[$pl] > $offset + $prefix_offset_downstream - $prefix_offset_upstream || $pl >= @piecelength) {
                        $pl++;
                    }
		
                    # the first three if's here deal with the case that there's an insertion right at 
                    # the begginging of the downstream read, either starting at the start of the read,
                    # or ending just before it, or overlapping the end.
                    if ($pl == 0 && $piecelength[0] == $offset - $prefix_offset_upstream) {
                        substr($DR2, $piecelength[$pl+1]-$piecelength[$pl], 0, "+");
                        $DR2 = "+" . $DR2;
                    } elsif (($pl == 1 && $piecelength[1] == $offset - $prefix_offset_upstream) || ($pl >= @piecelength)) {
                        # do nothing
                    } elsif ($pl % 2 == 1) {
                        substr($DR2, $piecelength[$pl]-$offset+$RC-$prefix_offset_downstream+$prefix_offset_upstream, 0, "+");
                        $pl++;
                        $DR2 = "+" . $DR2;
                        $RC=$RC+2;
                    } 
                    while ($piecelength[$pl] >= $offset + $prefix_offset_downstream - $prefix_offset_upstream && $pl < @piecelength-1) {
                        $plen = $plen - ($piecelength[$pl+1] - $piecelength[$pl]);
                        substr($DR2, $piecelength[$pl]-$offset+$RC-$prefix_offset_downstream+$prefix_offset_upstream, 0, "+");
                        $RC++;
                        substr($DR2, $piecelength[$pl+1]-$offset+$RC-$prefix_offset_downstream+$prefix_offset_upstream, 0, "+");
                        $RC++;
                        $pl=$pl+2;
                    }
                    $DR2 =~ s/^\+([^\+]+)\+//; # individual alignments don't have insertions at the ends,
                    # so removing it because it'll mess things up downstream
                    $prefix_offset_downstream = $prefix_offset_downstream + length($1);
                    $plen = $plen - length($1);
		
                    for ($i=0; $i<$suffix_offset_downstream; $i++) {
                        $DR2 =~ s/.$//;
                    }
		
                    $downstream_spans = &getsuffix($ruj[2], $plen);
		
                    $UR2 = &addJunctionsToSeq($UR2, $upstream_spans);
                    $DR2 = &addJunctionsToSeq($DR2, $downstream_spans);
                    if ($ruj[3] eq "+") {
                        $rum_u_forward = $seqnum . "a\t$ruj[1]\t" . $upstream_spans . "\t+\t" . $UR2;
                        $rum_u_reverse = $seqnum . "b\t$ruj[1]\t" . $downstream_spans . "\t+\t" . $DR2;
                    }
                    if ($ruj[3] eq "-") {
                        $rum_u_forward = $seqnum . "a\t$ruj[1]\t" . $downstream_spans . "\t-\t" . $DR2;
                        $rum_u_reverse = $seqnum . "b\t$ruj[1]\t" . $upstream_spans . "\t-\t" . $UR2;
                    }
		
                }
	    
                if ($rum_u_forward =~ /\S/) {
                    # COLLECT INFO FROM FORWARD RUM RECORD
                    # note: this might be a joined read for which the surrogate forward was created above
		
                    @ruf = split(/\t/,$rum_u_forward);
                    @SEQ = split(/:/, $ruf[4]);
		
                    $ruf[4] =~ s/://g;
                    $ruf[4] =~ s/\+//g;
                    $rum_u_forward_length = length($ruf[4]);
                    if ($ruf[3] eq "-") {
                        $forward_read = reversecomplement($forward_read_hold);
                        if (!($rum_u_joined =~ /\S/)) {
                            $bitscore_f = $bitscore_f + 16;
                            $bitscore_r = $bitscore_r + 32;
                            if (!($rum_u_reverse =~ /\S/)) {
                                $bitscore_r = $bitscore_r + 16;
                            }
                        }
                    } else {
                        $forward_read = $forward_read_hold;
                    }
                    if ($rum_u_joined =~ /\S/) {
                        if ($ruf[3] eq "+") {
                            $prefix_offset_forward = $prefix_offset_upstream;
                            $suffix_offset_forward = $suffix_offset_upstream;
                        } else {
                            $prefix_offset_forward = $prefix_offset_downstream;
                            $suffix_offset_forward = $suffix_offset_downstream;
                        }
                    } else {
                        $prefix_offset_forward = 0;
                        if ($rum_u_forward_length < $readlength_forward) {
                            $x = $forward_read;
                            $y = $ruf[4];
                            $Flag=0;
                            while ($Flag == 0) {
                                $Flag = 1;
                                until ($x =~ /^$y/) {
                                    $x =~ s/^.//;
                                    $prefix_offset_forward++;
                                    if ($x eq '') {
                                        $Flag=0;
                                        $x = reversecomplement($forward_read);
                                        $prefix_offset_forward = 0;
                                    }
                                }
                            }
                        }
                    }
                    $CIGAR_f = "";
                    if ($prefix_offset_forward > 0) {
                        $CIGAR_f = $prefix_offset_forward . "S";
                    }
                    @aspans = split(/, /,$ruf[2]);
                    $running_length = 0;
		
                    for ($i=0; $i<@aspans; $i++) {
                        @C1 = split(/-/,$aspans[$i]);
                        $L = $C1[1] - $C1[0] + 1;
                        undef @piecelength;
                        @PL = split(/\+/,$SEQ[$i]);
                        $piecelength[0] = length($PL[0]);
                        for ($pl=1; $pl<@PL; $pl++) {
                            $piecelength[$pl] = length($PL[$pl]) + $piecelength[$pl-1];
                        }
		    
                        if ($i==0) {
                            $CIGAR_f = $CIGAR_f . $piecelength[0] . "M";
                        } else {
                            @C2 = split(/-/,$aspans[$i-1]);
                            $skipped = $C1[0] - $C2[1] - 1;
                            if ($skipped >= 15) {
                                $CIGAR_f = $CIGAR_f . $skipped . "N" . $piecelength[0] . "M";
                            } else {
                                $CIGAR_f = $CIGAR_f . $skipped . "D" . $piecelength[0] . "M";
                            }
                        }
		    
                        # code for insertions follows
		    
                        if (@piecelength > 1) {
                            for ($pl_cnt=0; $pl_cnt<@piecelength-1; $pl_cnt=$pl_cnt+2) {
                                if ($pl_cnt == 0) {
                                    $pref_length = $piecelength[$pl_cnt];
                                } else {
                                    $pref_length = $piecelength[$pl_cnt] - $piecelength[$pl_cnt-1];
                                }
                                $insertion_length = $piecelength[$pl_cnt+1] - $piecelength[$pl_cnt];
                                $suff_length = $piecelength[$pl_cnt+2] - $piecelength[$pl_cnt+1];
                                $CIGAR_f = $CIGAR_f . $insertion_length . "I" . $suff_length . "M";
                                $running_length = $running_length + $insertion_length;
                            }
                        }
                        $running_length = $running_length + $L;
                    }
                    $right_clip_size_f = $readlength_forward - $running_length - $prefix_offset_forward;
                    if ($right_clip_size_f > 0) {
                        if ($rum_u_forward =~ /\+$/) {
                            $CIGAR_f = $CIGAR_f . $right_clip_size_f . "I";
                        } else {
                            $CIGAR_f = $CIGAR_f . $right_clip_size_f . "S";
                        }
                    }
                }
	    
	    
                if ($rum_u_reverse =~ /\S/) {
		
                    # COLLECT INFO FROM REVERSE RUM RECORD
                    # note: this might be a joined read for which the surrogate forward was created above
		
                    @rur = split(/\t/,$rum_u_reverse);
                    @SEQ = split(/:/, $rur[4]);
		
                    $rur[4] =~ s/://g;
                    $rur[4] =~ s/\+//g;
                    $rum_u_reverse_length = length($rur[4]);
                    if ($rur[3] eq "+") {
                        $reverse_read = reversecomplement($reverse_read_hold);
                        if (!($rum_u_joined =~ /\S/)) {
                            $bitscore_r = $bitscore_r + 16;
                            $bitscore_f = $bitscore_f + 32;
                            if (!($rum_u_forward =~ /\S/)) {
                                $bitscore_f = $bitscore_f + 16;
                            }
                        }
                    } else {
                        $reverse_read = $reverse_read_hold;
                    }
		
                    if ($rum_u_joined =~ /\S/) {
                        if ($ruf[3] eq "+") {
                            $prefix_offset_reverse = $prefix_offset_downstream;
                            $suffix_offset_reverse = $suffix_offset_downstream;
                        } else {
                            $prefix_offset_reverse = $prefix_offset_upstream;
                            $suffix_offset_reverse = $suffix_offset_upstream;
                        }
                    } else {
                        $prefix_offset_reverse = 0;
                        if ($rum_u_reverse_length < $readlength_reverse) {
                            $x = $reverse_read;
                            $y = $rur[4];
                            $Flag=0;
                            while ($Flag == 0) {
                                $Flag = 1;
                                until ($x =~ /^$y/ || $Flag == 0) {
                                    $x =~ s/^.//;
                                    $prefix_offset_reverse++;
                                    if ($x eq '') {
                                        $Flag=0;
                                        $x = reversecomplement($reverse_read);
                                        $prefix_offset_reverse = 0;
                                    }
                                }
                            }
                        }
                    }
		
                    $CIGAR_r = "";
                    if ($prefix_offset_reverse > 0) {
                        $CIGAR_r = $prefix_offset_reverse . "S";
                    }
                    @bspans = split(/, /,$rur[2]);
                    $running_length = 0;
		
                    for ($i=0; $i<@bspans; $i++) {
                        @C1 = split(/-/,$bspans[$i]);
                        $L = $C1[1] - $C1[0] + 1;
                        undef @piecelength;
                        @PL = split(/\+/,$SEQ[$i]);
                        $piecelength[0] = length($PL[0]);
                        for ($pl=1; $pl<@PL; $pl++) {
                            $piecelength[$pl] = length($PL[$pl]) + $piecelength[$pl-1];
                        }
		    
                        if ($i==0) {
                            $CIGAR_r = $CIGAR_r . $piecelength[0] . "M";
                        } else {
                            @C2 = split(/-/,$bspans[$i-1]);
                            $skipped = $C1[0] - $C2[1] - 1;
                            if ($skipped >= 15) {
                                $CIGAR_r = $CIGAR_r . $skipped . "N" . $piecelength[0] . "M";
                            } else {
                                $CIGAR_r = $CIGAR_r . $skipped . "D" . $piecelength[0] . "M";
                            }
                        }
		    
                        # code for insertions follows
		    
                        if (@piecelength > 1) {
                            for ($pl_cnt=0; $pl_cnt<@piecelength-1; $pl_cnt=$pl_cnt+2) {
                                if ($pl_cnt == 0) {
                                    $pref_length = $piecelength[$pl_cnt];
                                } else {
                                    $pref_length = $piecelength[$pl_cnt] - $piecelength[$pl_cnt-1];
                                }
                                $insertion_length = $piecelength[$pl_cnt+1] - $piecelength[$pl_cnt];
                                $suff_length = $piecelength[$pl_cnt+2] - $piecelength[$pl_cnt+1];
                                $CIGAR_r = $CIGAR_r . $insertion_length . "I" . $suff_length . "M";
                                $running_length = $running_length + $insertion_length;
                            }
                        }
                        $running_length = $running_length + $L;
                    }
		
                    $right_clip_size_r = $readlength_reverse - $running_length - $prefix_offset_reverse;
                    if ($right_clip_size_r > 0) {
                        if ($rum_u_reverse =~ /\+$/) {
                            $CIGAR_r = $CIGAR_r . $right_clip_size_r . "I";
                        } else {
                            $CIGAR_r = $CIGAR_r . $right_clip_size_r . "S";
                        }
                    }
                }
	    
	    
                # COMPUTE IDIST
	    
                $idist_f = 0;
                $idist_r = 0;
	    
                if ($ruf[2] =~ /^(\d+)-/) {
                    $start_forward = $1;
                } else {
                    $start_forward = "*";
                }
                if ($ruf[2] =~ /-(\d+)$/) {
                    $end_forward = $1;
                } else {
                    $end_forward = "*";
                }
                if ($rur[2] =~ /^(\d+)-/) {
                    $start_reverse = $1;
                } else {
                    $start_reverse = "*";
                }
                if ($rur[2] =~ /-(\d+)$/) {
                    $end_reverse = $1;
                } else {
                    $end_reverse = "*";
                }
                if ($rum_u_forward =~ /\S/ && !($rum_u_reverse =~ /\S/)) {
                    $start_reverse = $start_forward;
                    $end_reverse = $start_forward;
                }
                if ($rum_u_reverse =~ /\S/ && !($rum_u_forward =~ /\S/)) {
                    $start_forward = $start_reverse;
                    $end_forward = $start_reverse;
                }
                if ($rum_u_forward =~ /\S/ && $rum_u_reverse =~ /\S/) {
                    if ($ruf[3] eq "+") {
                        $idist_f = $end_reverse - $start_forward;
                    } else {
                        $idist_f = $end_forward - $start_reverse;
                    }
                    $idist_r = -1 * $idist_f;
                }
	    
	    
                # PRINTING OUT SAM RECORD STARTS HERE
	    
                # FORWARD:
	    
                $forward_record = "";
                if ($map_names eq "true") {
                    $tmp = "seq.$seqnum" . "a";
                    $forward_record = $forward_record . $namemapping{$tmp};
                } else {
                    $forward_record = $forward_record . "seq.$seqnum";
                }
                $forward_record = $forward_record . "\t$bitscore_f";
	    
                if (!($rum_u_forward =~ /\S/) && $rum_u_reverse =~ /\S/) { # forward unmapped, reverse mapped
                    $forward_record = $forward_record . "\t$rur[1]\t$start_reverse\t255\t*\t=\t$start_reverse\t0\t$forward_read\t$forward_qual";
                }
                if ($rum_u_forward =~ /\S/ || $rum_u_joined =~ /\S/) { # forward mapped
                    $forward_record = $forward_record . "\t$ruf[1]\t$start_forward\t255\t$CIGAR_f\t";
                    if ($paired eq "true") {
                        if ($rum_u_reverse =~ /\S/) { # paired and reverse mapped
                            $forward_record = $forward_record . "=\t$start_reverse\t$idist_f\t$forward_read\t$forward_qual";
                        } else { # reverse didn't map
                            $forward_record = $forward_record . "=\t$start_forward\t0\t$forward_read\t$forward_qual";
                        }
                    } else {    # not paired end
                        $forward_record = $forward_record . "*\t0\t0\t$forward_read\t$forward_qual";
                    }
                }
                if ($joined eq "true") {
                    $forward_record = $forward_record . "\tXO:A:T";
                } else {
                    $forward_record = $forward_record . "\tXO:A:F";
                }

                $MM = $mapper+1;
                $forward_record = $forward_record . "\tIH:i:$num_mappers\tHI:i:$MM";

                $forward_record = $forward_record . "\n";
                if ($suppress2 && $forward_record =~ /\*\t=/) {
                    # do nothing
                } elsif ($suppress3 && ($forward_record =~ /\*\t=/ || $reverse_record =~ /\*\t=/)) {
                    # do nothing
                } else {
                    print SAM $forward_record;
                }
	    
                # REVERSE
	    
                if ($paired eq "true") {
                    $reverse_record = "";
                    if ($map_names eq "true") {
                        $tmp = "seq.$seqnum" . "b";
                        $reverse_record = $reverse_record . $namemapping{$tmp};
                    } else {
                        $reverse_record = $reverse_record . "seq.$seqnum";
                    }
                    $reverse_record = $reverse_record . "\t$bitscore_r";
                    if (!($rum_u_reverse =~ /\S/) && $rum_u_forward =~ /\S/) { # reverse unmapped, forward mapped
                        $reverse_record = $reverse_record . "\t$ruf[1]\t$start_forward\t255\t*\t=\t$start_forward\t0\t$reverse_read\t$reverse_qual";
                    }
                    if ($rum_u_reverse =~ /\S/ || $rum_u_joined =~ /\S/) { # reverse mapped
                        $reverse_record = $reverse_record . "\t$rur[1]\t$start_reverse\t255\t$CIGAR_r\t=";
                        if ($rum_u_forward =~ /\S/) { # forward mapped
                            $reverse_record = $reverse_record . "\t$start_forward\t$idist_r\t$reverse_read\t$reverse_qual";
                        } else { # forward didn't map
                            $reverse_record = $reverse_record . "\t$start_reverse\t0\t$reverse_read\t$reverse_qual";		
                        }
                    }
                    if ($joined eq "true") {
                        $reverse_record = $reverse_record . "\tXO:A:T";
                    } else {
                        $reverse_record = $reverse_record . "\tXO:A:F";
                    }
                    $MM = $mapper+1;
                    $reverse_record = $reverse_record . "\tIH:i:$num_mappers\tHI:i:$MM";

                    $reverse_record = $reverse_record . "\n";
                    if ($suppress2 && $reverse_record =~ /\*\t=/) {
                        # do nothing
                    } elsif ($suppress3 && ($forward_record =~ /\*\t=/ || $reverse_record =~ /\*\t=/)) {
                        # do nothing
                    } else {
                        print SAM $reverse_record;
                    }
                }
            }
        }

        if ($unique_mapper_found eq "false" && $non_unique_mappers_found eq "false") {
            # neither forward nor reverse map
            if ($paired eq "false") {
                if ($map_names eq "true") {
                    $tmp = "seq.$seqnum" . "a";
                    $record = $namemapping{$tmp};
                } else {
                    $record = "seq.$seqnum";
                }
                $record = $record . "\t4\t*\t0\t255\t*\t*\t0\t0\t$forward_read\t$forward_qual\n";
                unless ($suppress1 || $suppress2 || $suppress3) {
                    print SAM $record;
                }
            } else {
                if ($map_names eq "true") {
                    $tmp = "seq.$seqnum" . "a";
                    $record = $namemapping{$tmp};
                } else {
                    $record = "seq.$seqnum";
                }
                $record = $record . "\t77\t*\t0\t255\t*\t*\t0\t0\t$forward_read\t$forward_qual\n";
                if ($map_names eq "true") {
                    $tmp = "seq.$seqnum" . "b";
                    $record = $record . $namemapping{$tmp};
                } else {
                    $record = $record . "seq.$seqnum";
                }
                $record = $record . "\t141\t*\t0\t255\t*\t*\t0\t0\t$reverse_read\t$reverse_qual\n";
                unless ($suppress1 || $suppress2 || $suppress3) {
                    print SAM $record;
                }
            }
        }
    }
}

sub getsuffix () {
    ($spans, $suffixlength) = @_;

    $prefixlength = &spansTotalLength($spans) - $suffixlength;
    $newspans = "";
    @OS = split(/, /, $spans);
    $running_length=0;
    for ($os=0; $os<@OS; $os++) {
	@B = split(/-/, $OS[$os]);
	$running_length = $running_length + $B[1] - $B[0] + 1;
	if ($running_length > $prefixlength) {
	    $STRT = $B[1] - ($running_length - $prefixlength) + 1;
	    $newspans = $STRT . "-" . $B[1];
	    $BB = $B[1];
	    $spans = $spans . ", ";
	    $spans =~ s/^.*-$BB, //;
	    if ($spans =~ /\S/) {
		$newspans = $newspans . ", " . $spans;
	    }
	    $newspans =~ s/^\s*,\s*//;
	    $newspans =~ s/\s*,\s*$//;
	    return $newspans;
	}
    }
}

sub getprefix () {
    ($spans, $prefixlength) = @_;

    $newspans = "";
    @OS = split(/, /, $spans);
    $running_length=0;
    for ($os=0; $os<@OS; $os++) {
	@B = split(/-/, $OS[$os]);
	$running_length = $running_length + $B[1] - $B[0] + 1;
	if ($running_length >= $prefixlength) {
	    $END = $B[1] - ($running_length - $prefixlength);
	    if ($newspans =~ /\S/) {
		$newspans =  $newspans . ", " . $B[0] . "-" . $END;
	    } else {
		$newspans = $B[0] . "-" . $END;
	    }
	    $newspans =~ s/^\s*,\s*//;
	    $newspans =~ s/\s*,\s*$//;
	    return $newspans;
	} else {
	    if ($newspans =~ /\S/) {
		$newspans = $newspans . ", " . $B[0] . "-" . $B[1];
	    } else {
		$newspans = $B[0] . "-" . $B[1];
	    }
	}
    }
}

sub cigar2mismatches () {
    ($chr_c, $start_c, $cigar_c, $seq_c) = @_;

    $seq2_c = $seq_c;
    $MD = "";
    $current_loc_c = $start_c;
    $offset_c = 0;
    while($cigar_c =~ /^(\d+)([^\d])/) {
	$num_c = $1;
	$type_c = $2;
	if($type_c eq 'M') {
	    $E_c = $current_loc_c + $num_c - 1;
	    $offset_c = $offset_c + $num_c;
	    $genomeseq_c = substr($GENOMESEQ{$chr_c}, $current_loc_c - 1, $num_c);
	    $current_loc_c = $E_c;
	    $readseq_c = substr($seq2_c, 0, $num_c);
	    $seq2_c =~ s/^$readseq_c//;
	    @A_c = split(//,$readseq_c);
	    @B_c = split(//,$genomeseq_c);
	    $cnt_c = 0;
	    for($i_c=0; $i_c<@A_c; $i_c++) {
		if($A_c[$i_c] ne $B_c[$i_c]) {
		    if($i_c==0 && $type_prev eq "D") {
			$MD = $MD . "0" . $B_c[$i_c];
		    } else {
			if($cnt_c > 0) {
			    $MD =~ s/(\d*)$//;
			    $x_c = $1 + 0;
			    $cnt_c = $cnt_c + $x_c;
			    $MD = $MD . $cnt_c . $B_c[$i_c];
			} else {
			    $MD = $MD . $B_c[$i_c];
			}
		    }
		    $cnt_c = 0;
		} else {
		    $cnt_c++;
		    if($i_c == @A_c - 1) {
			$MD =~ s/(\d*)$//;
			$x_c = $1 + 0;
			$cnt_c = $cnt_c + $x_c;
			$MD = $MD . $cnt_c;
		    }
		}
	    }
	}
	if($type_c eq 'D' || $type_c eq 'N') {
	    if($type_c eq 'D') {
		$genomeseq_c = substr($GENOMESEQ{$chr_c}, $current_loc_c - 1, $num_c);
		$MD = $MD . "^" . $genomeseq_c;
	    }
	    $current_loc_c = $current_loc_c + $num_c + 1;
	}
	if($type_c eq 'S') {
	    if($cigar_c =~ /^\d+S\d/) {
		for($i_c=0; $i_c<$num_c; $i_c++) {
		    $seq_c =~ s/^.//;
		    $seq2_c =~ s/^.//;
		}
	    } elsif($cigar_c =~ /\d+S$/) {
		for($i_c=0; $i_c<$num_c; $i_c++) {
		    $seq_c =~ s/.$//;
		    $seq2_c =~ s/.$//;
		}
	    }
	}
	if($type_c eq 'I') {
	    $current_loc_c++;
	    substr($seq_c, $offset_c, 0, "+");
	    $offset_c = $offset_c  + $num_c + 1;
	    substr($seq_c, $offset_c, 0, "+");
	    $offset_c = $offset_c + 1;
	    for($i_c=0; $i_c<$num_c; $i_c++) {
		$seq2_c =~ s/^.//;
	    }
	}
	$cigar_c =~ s/^\d+[^\d]//;
	$type_prev = $type_c;
	
    }
    return $MD;
}
