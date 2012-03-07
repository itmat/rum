###############################################################################
##
## Logging
## 

package RUM::Logger;

use strict;
use warnings;
use FindBin qw($Bin);
use Carp;

FindBin->again();

our %LOGGERS;

our ($TRACE, $DEBUG, $INFO, $WARN, $ERROR, $FATAL) = (0..6);
our $DEFAULT_THRESHOLD = $INFO;

our @LEVEL_NAMES = qw(TRACE DEBUG INFO WARN ERROR FATAL);

our $FH;

sub init {
    open $FH, ">>", "rum.log" unless $FH;
}

sub get_logger {
    my ($class, $name) = @_;
    $LOGGERS{$name} ||= $class->new($name);
}

sub new {
    my ($class, $name) = @_;
    my $self = {};
    $self->{threshold} = $DEFAULT_THRESHOLD;
    $self->{name} = $name;
    return bless $self, $class;
}

sub log {
    my ($self, $level, $msg) = @_;
    if ($level >= $self->{threshold}) {
        chomp $msg;
        if ($self->{name} =~ /^RUM::Script::/) {    
            print $msg, "\n";
        }
        printf $FH "%s %d %5s %s - %s\n",
            scalar(localtime()), $$, $LEVEL_NAMES[$level], $self->{name}, $msg;

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

sub logdie { 
    my ($self, $msg) = @_;
    $self->fatal($msg);
    die $msg;
}

sub less_logging { $_[0]->{threshold} += $_[1] };
sub more_logging { $_[0]->{threshold} -= $_[1] };

our $AUTOLOAD;
sub AUTOLOAD {
    carp "Method $AUTOLOAD does not exist in " . __PACKAGE__ unless $AUTOLOAD eq "RUM::Logger::DESTROY";
}

1;
