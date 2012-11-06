package RUM::Script::Base;

use strict;
use warnings;

use Data::Dumper;
use Scalar::Util qw(blessed);
use Pod::Usage;
use Getopt::Long;
use File::Temp;
use RUM::Logging;
use RUM::CommandLineParser;
use RUM::CommonProperties;
use List::Util qw(max);

my $SCRIPT_COMMAND;

sub set_script_command {
    $SCRIPT_COMMAND = shift;
}

sub command_line_parser {
    my ($self) = @_;
    my $parser = RUM::CommandLineParser->new;
    for my $opt ($self->accepted_options) {
        $parser->add_prop($opt);
    }
    return $parser;
}

sub new {
    my ($class, %self) = @_;
    return bless \%self, $class;
}

sub logger {
    my ($self) = @_;
    my $package = blessed($self);
    return $self->{logger} ||= RUM::Logging->get_logger($package);
}

sub get_options {
    my ($self, %options) = @_;

    $options{  'quiet|q'} = sub { $self->logger->less_logging(1) };
    $options{'verbose|v'} = sub { $self->logger->more_logging(1) };
    $options{   'help|h'} = sub { RUM::Usage->help };
    GetOptions(%options);
}

sub option {
    my ($self, $name) = @_;

    return $self->{options}->{$name};
}

sub properties {
    my ($self) = @_;
    if (!$self->{properties}) {
        $self->{properties} = $self->command_line_parser->parse;
    }
    return $self->{properties};
}

sub parse_command_line {
    my ($self) = @_;
    return $self->{properties} = $self->command_line_parser->parse;
}

sub script_name {
    my ($vol, $dir, $file) = File::Spec->splitdir($0);
    my $name = $file || $0;
    if ($SCRIPT_COMMAND) {
        $name .= " $SCRIPT_COMMAND";
    }
    return $name;
}

sub argument_pod {
    my ($self, $verbose) = @_;

    my $pod = '';
    my $parser = $self->command_line_parser;
    $pod .= "=head1 ARGUMENTS\n\n=over 4\n\n";

    my $skipped = 0;
    for my $prop ($parser->properties()) {
        if ($prop->required || $verbose) {
            $pod .= $prop->pod;
        }
        else {
            $skipped++ unless $prop->name eq 'help';
        }
    }

    $pod .= "=back\n\n";

    if ($skipped) {
        $pod .= "(See " . $self->script_name . " -h for more optional arguments)\n\n";
    }

    return $pod;
}

sub pod {
    my ($self, $verbose) = @_;
    my $pod = "";
    $pod .= "=head1 NAME\n\n";
    $pod .= script_name() . " - " . $self->summary() . "\n\n";
    $pod .= "=head1 SYNOPSIS\n\n";
    $pod .= $self->synopsis;
    $pod .= "\n\n";

    if (my $desc = $self->description) {
        $pod .= "=head1 DESCRIPTION\n\n" . $self->description . "\n\n";
    }

    $pod .= $self->argument_pod($verbose);

    $pod .= <<'EOF';

=head1 AUTHORS

Gregory Grant (ggrant@grant.org)

Mike DeLaurentis (delaurentis@gmail.com)

=head1 COPYRIGHT

Copyright 2012 University of Pennsylvania

EOF
    
    open my $pod_fh, '<', \$pod;
    return $pod_fh;
}


sub main {

    my ($class) = @_;

    my $self = $class->new;

    my $props = eval { $self->parse_command_line };
    if ($@) {
        if (ref($@) && ref($@) =~ /RUM::UsageErrors/) {
            my $errors = $@;

            open my $usage, '>', \(my $msg);

            pod2usage({
                -verbose => 1,
                -exitval => "NOEXIT",
                -input => $self->pod,
                -output => $usage
            });
            print $usage "Usage errors:\n\n";
            for my $error ($errors->errors) {
                chomp $error;
                print $usage "  * $error\n";
            }
            print $usage "\nFor full usage information, run $0 -h\n";
            close $usage;
            die $msg;
        }
        else {
            die $@;
        }
    }

    if ($props->has('help')) {
        $self->show_help;
    }

    $self->run;
}

sub show_help {
    my ($self) = @_;
    my $usage = File::Temp->new;
    pod2usage({
        -verbose => 2,
        -input => $self->pod(1),
        -output => $usage,
        -exitval => 'NOEXIT'
    });
    close $usage;
    exec "less", "-eF", $usage;
}

sub synopsis {
    my ($self) = @_;
    my $name = $self->script_name;
    my @lines = ("$name");
    my @optional = grep { ! $_->required && $_->name ne 'help' } $self->command_line_parser->properties;

    if (@optional) {
        $lines[0] .= " [OPTIONS]";
    }

    for my $prop ($self->command_line_parser->properties) {
        my $res = "";
        if ($prop->positional) {
            if (!$prop->required) {
                $res .= '[';
            }
            $res .= uc($prop->name);
            if ($prop->nargs eq '+') {
                $res .= "...";
            }
            if (!$prop->required) {
                $res .= ']';
            }
        }
        else {
            next if ! $prop->required;

            $res .= $prop->options('|');
            if ($prop->opt =~ /=/) {
                $res .= " " . uc($prop->name);
            }
        }
        push @lines, $res;
    }

    my $one_line = join " ", @lines;

    my $result;

    if (length($one_line) > 74) {

        for my $i (1 .. $#lines) {
            $lines[$i] = "  $lines[$i]";
        }

        my @lengths = map { length() } @lines;
        my $longest = max(@lengths) + 1;
        my $format = "  %-${longest}s\\\n";

        my $multiline = sprintf $format, $lines[0];
        for my $i (1 .. $#lines) {
            $multiline .= sprintf $format, $lines[$i];
        }
        $result = $multiline;
    }
    else {
        $result = $one_line;
    }

    if ($self->synopsis_footer) {
        $result .= "\n\n" . $self->synopsis_footer;
    }
    return $result;

}

sub description { '' }
sub synopsis_footer { '' }

1;
