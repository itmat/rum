###############################################################################
##
## Logging
## 

package RUM::Logging;



use strict;
use warnings;
use FindBin qw($Bin);
FindBin->again();

our $LOG4PERL = "Log::Log4perl";
our $LOGGER_CLASS;



sub init {
    $LOGGER_CLASS or init_log4perl() or init_rum_logger();
}

our @LOG4PERL_CONFIGS = (
        $ENV{RUM_LOG_CONFIG} || "",      # RUM_LOG_CONFIG environment variable
        "rum_logging.conf",              # rum_logging.conf in current dir
        "$ENV{HOME}/.rum_logging.conf",  # ~/.rum_logging.conf
        "$Bin/../conf/rum_logging.conf" # config file included in distribution
    );

sub init_log4perl {

    # Try to load Log::Log4perl, and if we can't just return so we
    # fall back to RUM::Logger.
    eval {
        require "Log/Log4perl.pm"; # qw(:no_extra_logdie_message);
    };
    if ($@) {
        warn "You don't seem to have $LOG4PERL installed.";
        return;
    }

    # Now try to initialize Log::Log4perl with a config file.
    my @configs = grep { -r } @LOG4PERL_CONFIGS;
    my $config = $configs[0];
    warn "My configs are @LOG4PERL_CONFIGS\n";
    eval {
        Log::Log4perl->init($config);
        my $log = Log::Log4perl->get_logger();
        $log->debug("Using log4perl config at $config");
    };
    if ($@) {
        warn "Error initializing $LOG4PERL with $config: $!";
    }

    $LOGGER_CLASS = $LOG4PERL;
}

sub init_rum_logger {
    $LOG4PERL = "RUM::Logger";
}

__PACKAGE__->init();

sub get_logger {
    my ($self, $name) = @_;
    unless (defined($name)) {
        my @caller = caller();
        $name = $caller[4];
    }
    return $LOGGER_CLASS->get_logger($name);
}

__PACKAGE__->main() unless caller();
