###############################################################################
##
## Logging
## 

package RUM::Logger;

use strict;
use warnings;
use FindBin qw($Bin);
FindBin->again();

our %LOGGERS;

our ($TRACE, $DEBUG, $INFO, $WARN, $ERROR, $FATAL) = (0..6);
our $DEFAULT_THRESHOLD = $INFO;

our $FH;

sub get_logger {
    my ($class, $name) = @_;
    $LOGGERS{$name} ||= $class->new($name);
}

sub new {
    my ($class, $name) = @_;
    my $self = {};
    $self->{threshold} = $DEFAULT_THRESHOLD;
}

sub log {
    my ($self, $level, $msg) = @_;
    if ($level >= $self->{threshold}) {
        chomp $msg;
        print $FH $msg, "\n";
        print $msg, "\n";
    }
}

sub trace { shift->log($TRACE, @_) }
sub debug { shift->log($DEBUG, @_) }
sub info  { shift->log($INFO,  @_) }
sub warn  { shift->log($WARN,  @_) }
sub error { shift->log($ERROR, @_) }
sub fatal { shift->log($FATAL, @_) }

sub is_trace { shift->{threshold} >= $TRACE }
sub is_debug { shift->{threshold} >= $DEBUG }
sub is_info  { shift->{threshold} >= $INFO  }
sub is_warn  { shift->{threshold} >= $WARN  }
sub is_error { shift->{threshold} >= $ERROR }
sub is_fatal { shift->{threshold} >= $FATAL }

1;
