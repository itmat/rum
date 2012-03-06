###############################################################################
##
## Logging
## 

package RUM::Logger;

use strict;
use warnings;
use FindBin qw($Bin);
FindBin->again();

use Log::Log4perl qw(:no_extra_logdie_message);
Log::Log4perl->init("$Bin/../conf/log.conf");

sub get_logger {
    my ($self, $name) = @_;
    return Log::Log4perl->get_logger($name);
}

