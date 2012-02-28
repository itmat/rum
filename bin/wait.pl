use strict;
no warnings;

my ($dir, $jid) = @ARGV;

$dir =~ s!/$!!;

until (-e "$dir/$jid") {
    sleep(10);
}
