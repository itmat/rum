package RUM::Action::Help;

=head1 NAME

RUM::Action::Help - Prints a help message.

=head1 DESCRIPTION

Prints a help message, or a help message about the configuration file
if 'config' is supplied as the first argument.

=over 4

=cut

use strict;
use warnings;

use Pod::Usage;

use RUM::Usage;

use base 'RUM::Base';

=item run

=cut

sub run {
    my ($class) = @_;

    my $action = shift(@ARGV) || "";
    if (my $action_class = $RUM::Script::Main::ACTIONS{$action}) {

        my $file = $action_class;
        $file =~ s/::/\//g;
        $file .= ".pm";
        require $file;
      
        my $pod = $action_class->pod;
        open my $pod_fh, '<', \$pod;
        
        my %options = (

            # Since the user explicitly asked for help, be verbose. 
            -verbose => 2,
            -input => $pod_fh
        );


        # By default Pod::Usage with -verbose set to 2 will run perldoc to
        # print a nicely formatted, paginated help message. However, if
        # you run perldoc as root, it turns on taint checking, and if you
        # run perldoc in a directory where there's a Makefile.PL file,
        # Pod::Perldoc will add some stuff to our @INC that taints it. So
        # basically you can't run perldoc as root in a directory that
        # contains a Makefile.PL file. So if that's the case, tel
        # Pod::Usage not to run perldoc.
#        my $is_root = ! $<;
#        $options{-noperldoc} = 1 if $is_root && -e "Makefile.PL";
        pod2usage(\%options);
    }
    elsif ($action eq 'config') {
        print $RUM::ConfigFile::DOC;
    }
    else {
        RUM::Usage->help;
    }

}

1;

=back
