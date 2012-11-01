if($paired eq "false") {
    for(my $chunk=1; $chunk<=$numchunks; $chunk++) {


	my $reads_file = in_chunk_dir($reads_out) . ".$chunk";
	my $quals_file = in_chunk_dir($quals_out) . ".$chunk";
        warn "File is $reads_file\n";
	if($endflag == 1) {
	    $chunk = $numchunks;
	    next;
	}
	open(ROUT, ">$reads_file");
	open(QOUT, ">$quals_file");
	if($map_names eq "true") {
	    $name_mapping_chunk = $name_mapping_file . ".$chunk";
	    open(NAMEMAPPING, ">$name_mapping_chunk");
	}
	if($chunk == $numchunks) {
	    # just to make sure we get everything in the last chunk
	    $numrecords_per_chunk = $numrecords_per_chunk * 100; 
	}
	for(my $i=0; $i<$numrecords_per_chunk; $i++) {
	    $seq_counter++;
	    my $readname = <$INFILE1>;
	    $readname =~ s/^@//;
	    $linecnt++;
	    my $line = <$INFILE1>;
	    $line_hold = $line;
	    $linecnt++;
	    chomp($line);
	    if($line eq '') {
		$i = $numrecords_per_chunk;
		$endflag = 1;
		next;
	    }
	    print ROUT ">seq.$seq_counter";
	    print ROUTALL ">seq.$seq_counter";
	    print ROUT "a\n";
	    print ROUTALL "a\n";
	    if($map_names eq "true") {
		print NAMEMAPPINGALL "seq.$seq_counter";
		print NAMEMAPPINGALL "a\t$readname";
		print NAMEMAPPING "seq.$seq_counter";
		print NAMEMAPPING "a\t$readname";
	    }
	    $line =~ s/\./N/g;
	    $line = uc $line;
	    if($line =~ /[^ACGTN.]/ || !($line =~ /\S/)) {
		die "\nERROR: in script parsefastq.pl: There's something wrong with line $linecnt in file \"$infile1\"\nIt should be a line of sequence but it is:\n$line_hold\n\n";
	    }

	    print ROUT "$line\n";
	    print ROUTALL "$line\n";
	    $line = <$INFILE1>;
	    $linecnt++;
	    $line = <$INFILE1>;
	    $linecnt++;
	    chomp($line);
	    if($line eq '') {
		$i = $numrecords_per_chunk;
		print STDERR "ERROR: in script parsefastq.pl: something is wrong, the file seems to end with an incomplete record...\n";
		exit(0);
	    }
	    print QOUT ">seq.$seq_counter";
	    print QOUTALL ">seq.$seq_counter";
	    print QOUT "a\n";
	    print QOUTALL "a\n";
	    print QOUT "$line\n";
	    print QOUTALL "$line\n";
	}
	close(ROUT);
	close(QOUT);
	if($map_names eq "true") {
	    close(NAMEMAPPING);
	}
    }
}

my $linecnt1=0;
my $linecnt2=0;
if($paired eq "true") {
    for(my $chunk=1; $chunk<=$numchunks; $chunk++) {
	my $reads_file = in_chunk_dir($reads_out) . ".$chunk";
	my $quals_file = in_chunk_dir($quals_out) . ".$chunk";
	if($endflag == 1) {
	    $chunk = $numchunks;
	    next;
	}
	open(ROUT, ">$reads_file");
	open(QOUT, ">$quals_file");
	if($map_names eq "true") {
	    $name_mapping_chunk = $name_mapping_file . ".$chunk";
	    open(NAMEMAPPING, ">$name_mapping_chunk");
	}
	if($chunk == $numchunks) {
	    # just to make sure we get everything in the last chunk
	    $numrecords_per_chunk = $numrecords_per_chunk * 100; 
	}
	for(my $i=0; $i<$numrecords_per_chunk; $i++) {
	    $seq_counter++;
	    my $readname = <$INFILE1>;
            last if ! defined $readname;
	    $readname =~ s/^@//;
	    $linecnt1++;
	    my $line = <$INFILE1>;
	    $line_hold = $line;
	    $linecnt1++;
	    chomp($line);
	    if($line eq '') {
		$i = $numrecords_per_chunk;
		$endflag = 1;
		next;
	    }
	    print ROUT ">seq.$seq_counter";
	    print ROUTALL ">seq.$seq_counter";
	    print ROUT "a\n";
	    print ROUTALL "a\n";
	    if($map_names eq "true") {
		print NAMEMAPPINGALL "seq.$seq_counter";
		print NAMEMAPPINGALL "a\t$readname";
		print NAMEMAPPING "seq.$seq_counter";
		print NAMEMAPPING "a\t$readname";
	    }
	    $line =~ s/\./N/g;
	    $line = uc $line;
	    if($line =~ /[^ACGTN.]/ || !($line =~ /\S/)) {
		print STDERR "\nERROR: in script parsefastq.pl: There's something wrong with line $linecnt1 in file \"$infile1\"\nIt should be a line of sequence but it is:\n$line_hold\n\n";
		exit();
	    }
	    print ROUT "$line\n";
	    print ROUTALL "$line\n";
	    $line = <$INFILE1>;
	    $linecnt1++;
	    $line = <$INFILE1>;
	    $linecnt1++;
	    chomp($line);
	    if($line eq '') {
		$i = $numrecords_per_chunk;
		print STDERR "ERROR: in script parsefastq.pl: something is wrong, the forward file seems to end with an incomplete record...\n";
		exit(0);
	    }
	    print QOUT ">seq.$seq_counter";
	    print QOUTALL ">seq.$seq_counter";
	    print QOUT "b\n";
	    print QOUTALL "b\n";
	    print QOUT "$line\n";
	    print QOUTALL "$line\n";

	    $readname = <$INFILE2>;
	    $readname =~ s/^@//;
	    $linecnt2++;
	    $line = <$INFILE2>;
	    $line_hold = $line;
	    $linecnt2++;
	    chomp($line);
	    if($line eq '') {
		$i = $numrecords_per_chunk;
		print STDERR "ERROR: in script parsefastq.pl: something is wrong, the forward and reverse files are different sizes.\n";
		exit(0);
	    }
	    print ROUT ">seq.$seq_counter";
	    print ROUTALL ">seq.$seq_counter";
	    print ROUT "b\n";
	    print ROUTALL "b\n";
	    if($map_names eq "true") {
		print NAMEMAPPINGALL "seq.$seq_counter";
		print NAMEMAPPINGALL "b\t$readname";
		print NAMEMAPPING "seq.$seq_counter";
		print NAMEMAPPING "b\t$readname";
	    }
	    $line =~ s/\./N/g;
	    if($line =~ /[^ACGTN.]/ || !($line =~ /\S/)) {
		print STDERR "\nERROR: in script parsefastq.pl: There's something wrong with line $linecnt2 in file \"$infile2\"\nIt should be a line of sequence but it is:\n$line_hold\n\n";
		exit();
	    }
	    print ROUT "$line\n";
	    print ROUTALL "$line\n";
	    $line = <$INFILE2>;
	    $linecnt2++;
	    $line = <$INFILE2>;
	    $linecnt2++;
	    chomp($line);
	    if($line eq '') {
		$i = $numrecords_per_chunk;
		print STDERR "ERROR: in script parsefastq.pl: something is wrong, the reverse file seems to end with an incomplete record...\n";
		exit(0);
	    }
	    print QOUT ">seq.$seq_counter";
	    print QOUTALL ">seq.$seq_counter";
	    print QOUT "a\n";
	    print QOUTALL "a\n";
	    print QOUT "$line\n";
	    print QOUTALL "$line\n";
	}
	close(ROUT);
	close(QOUT);
	if($map_names eq "true") {
	    close(NAMEMAPPING);
	}
    }
}

close(ROUTALL);
close(QOUTALL);
