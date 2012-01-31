$dir = $ARGV[0];
$JID = $ARGV[1];
$dir =~ s!/$!!;

$doneflag = 0;
while($doneflag == 0) {
    $doneflag = 1;
    if(!(-e "$dir/$JID")) {
	$doneflag = 0;
    }
    if($doneflag == 0) {
	sleep(10);
    }
}
