package RUM::Logger;

=head1 NAME

RUM::Logger - Simple logger for when Log4perl isn't installed

=head1 SYNOPSIS

Please see RUM::Logging.

=head1 DESCRIPTION

RUM::Logging->get_logger() will test to see if Log4perl is installed,
and if so, use its loggers. If not, it will return instances of this
class. This class just mimics some of the simplest features of a
Log4perl logger. If a non-existent method is called on an instance of
this class, we simply warn rather than die. 

=cut

use strict;
use warnings;
use FindBin qw($Bin);
use Carp;

FindBin->again();

our %LOGGERS;

our ($TRACE, $DEBUG, $INFO, $WARN, $ERROR, $FATAL) = (0..6);
our $DEFAULT_THRESHOLD = $INFO;

our @LEVEL_NAMES = qw(TRACE DEBUG INFO WARN ERROR FATAL);

our $MESSAGES;
our $ERRORS;

=head1 CLASS METHODS

=over 4

=item RUM::Logger->init()

Do not call this directly; let RUM::Logging do it. Initialize the
logger by opening the output filehandle.

=cut

sub init {
    my ($class, $log_file, $error_log_file) = @_;

    return unless $log_file && $error_log_file;
    
    unless ($MESSAGES) {
        open $MESSAGES, ">>", $log_file or warn
            "Can't open log file $MESSAGES: $!";
    }
    unless ($ERRORS) {
        open $ERRORS, ">>", $error_log_file or warn
            "Can't open log file $ERRORS: $!";
    }
}

=item RUM::Logger->get_logger()

Do not call this directly; let RUM::Logging do it. Return a logger
with the given name, creating one if one doesn't already exist.

=cut

sub get_logger {
    my ($class, $name) = @_;
    carp "Need a name " unless defined $name;
    $LOGGERS{$name} ||= $class->_new($name);
}

sub _new {
    my ($class, $name) = @_;
    my $self = {};
    $self->{threshold} = $DEFAULT_THRESHOLD;
    $self->{name} = $name;
    return bless $self, $class;
}

=back

=head1 INSTANCE METHODS

=over 4

=item log($level, $msg)

Print the given message if the given level is above my threshold. If
the message came from a RUM::Script::* logger, print it to the screen
as well as the log file, since it was probably intended for user
consumption.

=cut

sub log {
    my ($self, $level, $msg) = @_;
    return unless $MESSAGES;
    my @files;
    if ($level >= $self->{threshold}) {
        push @files, $MESSAGES;
        if ($level >= 3) {
            push @files, $ERRORS;
        }
    }
    else {
        return;
    }
    if (!defined $msg) {
        $msg = "";
    }
    chomp $msg;
    if ($self->{name} =~ /^RUM::Script::/) {    
        print $msg, "\n";
    }
    for my $fh (@files) {
        printf $fh "%s %d %5s %s - %s\n",
            scalar(localtime()), $$, $LEVEL_NAMES[$level], $self->{name}, $msg;
    }
}

=back

=head2 Logging messages

These methods send logging messages at different levels:

=over 4

=item trace($msg)

=item debug($msg)

=item info($msg)

=item warn($msg)

=item error($msg)

=item fatal($msg)

=back

=cut

sub trace { shift->log($TRACE, @_) }
sub debug { shift->log($DEBUG, @_) }
sub info  { shift->log($INFO,  @_) }
sub warn  { shift->log($WARN,  @_) }
sub error { shift->log($ERROR, @_) }
sub fatal { shift->log($FATAL, @_) }

=head2 Logging and exiting

=over 4

=item logdie($msg)

Log a message and die with it.

=cut

sub logdie { 
    my ($self, $msg) = @_;
    $self->fatal($msg);
    die $msg;
}

=back

=head2 Testing the log level

These methods return true if this logger will print messages at or
above a certain level:

=over 4

=item is_trace

=item is_debug

=item is_info

=item is_warn

=item is_error

=item is_fatal

=back

=cut

sub is_trace { shift->{threshold} >= $TRACE }
sub is_debug { shift->{threshold} >= $DEBUG }
sub is_info  { shift->{threshold} >= $INFO  }
sub is_warn  { shift->{threshold} >= $WARN  }
sub is_error { shift->{threshold} >= $ERROR }
sub is_fatal { shift->{threshold} >= $FATAL }

=head2 Adjusting the threshold

=over 4

=item more_logging($delta)

Increment the threshold by $delta.

=item less_logging($delta)

Decrement the threshold by $delta.

=back

=cut

sub less_logging { $_[0]->{threshold} += $_[1] };
sub more_logging { $_[0]->{threshold} -= $_[1] };

our $AUTOLOAD;
sub AUTOLOAD {
    carp "Method $AUTOLOAD does not exist in " . __PACKAGE__ unless $AUTOLOAD eq "RUM::Logger::DESTROY";
}

sub level {
    $_[0]->{threshold};
}

=head1 AUTHOR

Mike DeLaurentis (delaurentis@gmail.com)

=head1 COPYRIGHT

Copyright 2012 University of Pennsylvania

=cut

1;
