#!perl -T

use Test::More tests => 2;
use lib "lib";

BEGIN { use_ok('RUM::Index', qw(modify_fa_to_have_seq_on_one_line)) }

sub modify_fa_to_have_seq_on_one_line_ok {

  my $input = <<INPUT;
>gi|123|ref|123sdf|Foo bar
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG
TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT
INPUT

  my $expected = <<EXPECTED;
>gi|123|ref|123sdf|Foo bar
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT
EXPECTED

  open $infile, "<", \$input;
  open $outfile, ">", \(my $output);

  modify_fa_to_have_seq_on_one_line($infile, $outfile);
  close $infile;

  close $outfile;

  is($output, $expected);
}

modify_fa_to_have_seq_on_one_line_ok();
