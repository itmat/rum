package RUM::Script::Base;

use strict;
use warnings;

use Data::Dumper;
use Scalar::Util qw(blessed);
use Pod::Usage;
use Getopt::Long;
use File::Temp;

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
        $self->command_line_parser->parse;
    }
    return $self->{properties};
    
}

sub parse_command_line {
    my ($self) = @_;
    return $self->{properties} = $self->command_line_parser->parse;
}

sub script_name {
    my ($vol, $dir, $file) = File::Spec->splitdir($0);
    return $file;
}

sub pod {
    my ($self) = @_;
    my $pod = "";
    $pod .= "=head1 NAME\n\n";
    $pod .= script_name() . " - " . $self->summary() . "\n\n";
    $pod .= "=head1 SYNOPSIS\n\n";
    $pod .= $self->synopsis;
    $pod .= "\n\n";
    $pod .= "=head1 DESCRIPTION\n\n" . $self->description . "\n\n=head1 ARGUMENTS\n\n";
    
    my $parser = $self->command_line_parser;
    $pod .= "\n\n=over 4\n\n";
    
    for my $prop ($parser->properties()) {
        $pod .= $prop->pod;
    }
    
    $pod .= "=back\n\n";

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
            if ($self->description) {
                print $usage "\nFor full usage information, run $0 -h\n";
            }
            close $usage;
            die $msg;
        }
        else {
            die $@;
        }
    }
    
    if ($props->has('help')) {
        my $usage = File::Temp->new;
        pod2usage({
            -verbose => 2,
            -input => $self->pod,
            -output => $usage,
            -exitval => 'NOEXIT'
        });
        close $usage;
        exec "less", $usage;
    }

    $self->run;
}

sub synopsis {
    my ($self) = @_;
    my $name = $self->script_name;
    my @lines = ("  $name [OPTIONS]");
    for my $prop ($self->command_line_parser->properties) {
        next if ! $prop->required;
        my $res = "";
        if ($prop->positional) {
            $res .= "    " . uc($prop->name);
        }
        else {
            $res .= "    " . $prop->options('|');
            if ($prop->opt =~ /=/) {
                $res .= " " . uc($prop->name);
            }
        }
        push @lines, $res;
        
    }
    return join "\\\n", @lines;

}

sub description { '' }


1;
