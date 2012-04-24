use strict;
use warnings;

use Test::More tests => 2;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Data::Dumper;
use RUM::Action::Profile;

our $LOG = <<EOF;
2012/04/20 13:58:56 powmac.itmat.upenn.edu 61142 DEBUG RUM.ScriptRunner - START RUM::Script::Main (../bin/rum_runner align --child --output /Users/midel/src/rum/data/out --chunk 2)
foo bar
what
2012/04/20 13:59:09 powmac.itmat.upenn.edu 61168 DEBUG RUM.ScriptRunner - START RUM::Script::MakeTuAndTnu (/Users/midel/src/rum/bin/../bin/make_TU_and_TNU.pl --unique /Users/midel/src/rum/data/out/_tmp_TU.2.720DgbWY --non-unique /Users/midel/src/rum/data/out/_tmp_TNU.2.bhmU76OO --bowtie-output /Users/midel/src/rum/data/out/Y.2 --genes /Users/midel/src/rum/bin/../indexes/Arabidopsis_thaliana_TAIR10_ensembl_gene_info.txt --single)
2012/04/20 13:59:10 powmac.itmat.upenn.edu 61168 DEBUG RUM.ScriptRunner - FINISHED RUM::Script::MakeTuAndTnu (/Users/midel/src/rum/bin/../bin/make_TU_and_TNU.pl --unique /Users/midel/src/rum/data/out/_tmp_TU.2.720DgbWY --non-unique /Users/midel/src/rum/data/out/_tmp_TNU.2.bhmU76OO --bowtie-output /Users/midel/src/rum/data/out/Y.2 --genes /Users/midel/src/rum/bin/../indexes/Arabidopsis_thaliana_TAIR10_ensembl_gene_info.txt --single)
2012/04/20 13:59:10 powmac.itmat.upenn.edu 61170 DEBUG RUM.ScriptRunner - START RUM::Script::MergeGuAndTu (/Users/midel/src/rum/bin/../bin/merge_GU_and_TU.pl --gu /Users/midel/src/rum/data/out/GU.2 --tu /Users/midel/src/rum/data/out/TU.2 --gnu /Users/midel/src/rum/data/out/GNU.2 --tnu /Users/midel/src/rum/data/out/TNU.2 --bowtie-unique /Users/midel/src/rum/data/out/_tmp_BowtieUnique.2.oHSXL3pX --cnu /Users/midel/src/rum/data/out/_tmp_CNU.2.GzODIdsU --single --read-length 75)
2012/04/20 13:59:20 powmac.itmat.upenn.edu 61170 DEBUG RUM.ScriptRunner - FINISHED RUM::Script::MergeGuAndTu (/Users/midel/src/rum/bin/../bin/merge_GU_and_TU.pl --gu /Users/midel/src/rum/data/out/GU.2 --tu /Users/midel/src/rum/data/out/TU.2 --gnu /Users/midel/src/rum/data/out/GNU.2 --tnu /Users/midel/src/rum/data/out/TNU.2 --bowtie-unique /Users/midel/src/rum/data/out/_tmp_BowtieUnique.2.oHSXL3pX --cnu /Users/midel/src/rum/data/out/_tmp_CNU.2.GzODIdsU --single --read-length 75)
2012/04/20 13:59:25 powmac.itmat.upenn.edu 61210 DEBUG RUM.ScriptRunner - START RUM::Script::ParseBlatOut (/Users/midel/src/rum/bin/../bin/parse_blat_out.pl --reads-in /Users/midel/src/rum/data/out/R.2 --blat-in /Users/midel/src/rum/data/out/R.2.blat --mdust-in /Users/midel/src/rum/data/out/R.2.mdust --unique-out /Users/midel/src/rum/data/out/_tmp_BlatUnique.2.nd8Leqkv --non-unique-out /Users/midel/src/rum/data/out/_tmp_BlatNU.2.0h9mj9ae --max-insertions 1)
2012/04/20 13:59:25 powmac.itmat.upenn.edu 61210 DEBUG RUM.ScriptRunner - FINISHED RUM::Script::ParseBlatOut (/Users/midel/src/rum/bin/../bin/parse_blat_out.pl --reads-in /Users/midel/src/rum/data/out/R.2 --blat-in /Users/midel/src/rum/data/out/R.2.blat --mdust-in /Users/midel/src/rum/data/out/R.2.mdust --unique-out /Users/midel/src/rum/data/out/_tmp_BlatUnique.2.nd8Leqkv --non-unique-out /Users/midel/src/rum/data/out/_tmp_BlatNU.2.0h9mj9ae --max-insertions 1)
2012/04/20 13:59:25 powmac.itmat.upenn.edu 61219 DEBUG RUM.ScriptRunner - START RUM::Script::FinalCleanup (/Users/midel/src/rum/bin/../bin/RUM_finalcleanup.pl --unique-in /Users/midel/src/rum/data/out/RUM_Unique_temp.2 --non-unique-in /Users/midel/src/rum/data/out/RUM_NU_temp.2 --unique-out /Users/midel/src/rum/data/out/_tmp_RUM_Unique_temp2.2.vT8GwJy_ --non-unique-out /Users/midel/src/rum/data/out/_tmp_RUM_NU_temp2.2.CMdNpMyV --genome /Users/midel/src/rum/bin/../indexes/Arabidopsis_thaliana_TAIR10_genome_one-line-seqs.fa --sam-header-out /Users/midel/src/rum/data/out/_tmp_sam_header.2.lXuY4GKQ :)
2012/04/20 13:59:28 powmac.itmat.upenn.edu 61219 DEBUG RUM.ScriptRunner - FINISHED RUM::Script::FinalCleanup (/Users/midel/src/rum/bin/../bin/RUM_finalcleanup.pl --unique-in /Users/midel/src/rum/data/out/RUM_Unique_temp.2 --non-unique-in /Users/midel/src/rum/data/out/RUM_NU_temp.2 --unique-out /Users/midel/src/rum/data/out/_tmp_RUM_Unique_temp2.2.vT8GwJy_ --non-unique-out /Users/midel/src/rum/data/out/_tmp_RUM_NU_temp2.2.CMdNpMyV --genome /Users/midel/src/rum/bin/../indexes/Arabidopsis_thaliana_TAIR10_genome_one-line-seqs.fa --sam-header-out /Users/midel/src/rum/data/out/_tmp_sam_header.2.lXuY4GKQ :)
2012/04/20 13:59:28 powmac.itmat.upenn.edu 61250 DEBUG RUM.ScriptRunner - START RUM::Script::SortRumById (/Users/midel/src/rum/bin/../bin/sort_RUM_by_id.pl /Users/midel/src/rum/data/out/RUM_Unique_temp2.2 -o /Users/midel/src/rum/data/out/_tmp_RUM_Unique.2.FDGGqsGi)
2012/04/20 13:59:28 powmac.itmat.upenn.edu 61250 DEBUG RUM.ScriptRunner - FINISHED RUM::Script::SortRumById (/Users/midel/src/rum/bin/../bin/sort_RUM_by_id.pl /Users/midel/src/rum/data/out/RUM_Unique_temp2.2 -o /Users/midel/src/rum/data/out/_tmp_RUM_Unique.2.FDGGqsGi)
2012/04/20 13:59:28 powmac.itmat.upenn.edu 61256 DEBUG RUM.ScriptRunner - START RUM::Script::SortRumByLocation (/Users/midel/src/rum/bin/../bin/sort_RUM_by_location.pl --ram 2 /Users/midel/src/rum/data/out/RUM_Unique.2 -o /Users/midel/src/rum/data/out/_tmp_RUM_Unique.sorted.2.8qEstlyd)
2012/04/20 13:59:28 powmac.itmat.upenn.edu 61256 DEBUG RUM.ScriptRunner - FINISHED RUM::Script::SortRumByLocation (/Users/midel/src/rum/bin/../bin/sort_RUM_by_location.pl --ram 2 /Users/midel/src/rum/data/out/RUM_Unique.2 -o /Users/midel/src/rum/data/out/_tmp_RUM_Unique.sorted.2.8qEstlyd)
2012/04/20 13:59:28 powmac.itmat.upenn.edu 61258 DEBUG RUM.ScriptRunner - START RUM::Script::SortRumById (/Users/midel/src/rum/bin/../bin/sort_RUM_by_id.pl -o /Users/midel/src/rum/data/out/_tmp_RUM_NU_idsorted.2.ARUSnFzR /Users/midel/src/rum/data/out/RUM_NU_temp2.2)
2012/04/20 13:59:28 powmac.itmat.upenn.edu 61258 DEBUG RUM.ScriptRunner - FINISHED RUM::Script::SortRumById (/Users/midel/src/rum/bin/../bin/sort_RUM_by_id.pl -o /Users/midel/src/rum/data/out/_tmp_RUM_NU_idsorted.2.ARUSnFzR /Users/midel/src/rum/data/out/RUM_NU_temp2.2)
2012/04/20 13:59:29 powmac.itmat.upenn.edu 61266 DEBUG RUM.ScriptRunner - START RUM::Script::RumToSam (/Users/midel/src/rum/bin/../bin/rum2sam.pl --unique-in /Users/midel/src/rum/data/out/RUM_Unique.2 --non-unique-in /Users/midel/src/rum/data/out/RUM_NU.2 --reads-in /Users/midel/src/rum/data/out/reads.fa.2 --quals-in /Users/midel/src/rum/data/out/quals.fa.2 --sam-out /Users/midel/src/rum/data/out/_tmp_RUM.sam.2.E_52Dw7x)
2012/04/20 13:59:29 powmac.itmat.upenn.edu 61266 DEBUG RUM.ScriptRunner - FINISHED RUM::Script::RumToSam (/Users/midel/src/rum/bin/../bin/rum2sam.pl --unique-in /Users/midel/src/rum/data/out/RUM_Unique.2 --non-unique-in /Users/midel/src/rum/data/out/RUM_NU.2 --reads-in /Users/midel/src/rum/data/out/reads.fa.2 --quals-in /Users/midel/src/rum/data/out/quals.fa.2 --sam-out /Users/midel/src/rum/data/out/_tmp_RUM.sam.2.E_52Dw7x)
2012/04/20 13:59:43 powmac.itmat.upenn.edu 61142 DEBUG RUM.ScriptRunner - FINISHED RUM::Script::Main (../bin/rum_runner align --child --output /Users/midel/src/rum/data/out --chunk 2)
EOF

my $expected = [
          [
            '121251322736',
            'START',
            'RUM::Script::Main'
          ],
          [
            '121251322749',
            'START',
            'RUM::Script::MakeTuAndTnu'
          ],
          [
            '121251322750',
            'FINISHED',
            'RUM::Script::MakeTuAndTnu'
          ],
          [
            '121251322750',
            'START',
            'RUM::Script::MergeGuAndTu'
          ],
          [
            '121251322760',
            'FINISHED',
            'RUM::Script::MergeGuAndTu'
          ],
          [
            '121251322765',
            'START',
            'RUM::Script::ParseBlatOut'
          ],
          [
            '121251322765',
            'FINISHED',
            'RUM::Script::ParseBlatOut'
          ],
          [
            '121251322765',
            'START',
            'RUM::Script::FinalCleanup'
          ],
          [
            '121251322768',
            'FINISHED',
            'RUM::Script::FinalCleanup'
          ],
          [
            '121251322768',
            'START',
            'RUM::Script::SortRumById'
          ],
          [
            '121251322768',
            'FINISHED',
            'RUM::Script::SortRumById'
          ],
          [
            '121251322768',
            'START',
            'RUM::Script::SortRumByLocation'
          ],
          [
            '121251322768',
            'FINISHED',
            'RUM::Script::SortRumByLocation'
          ],
          [
            '121251322768',
            'START',
            'RUM::Script::SortRumById'
          ],
          [
            '121251322768',
            'FINISHED',
            'RUM::Script::SortRumById'
          ],
          [
            '121251322769',
            'START',
            'RUM::Script::RumToSam'
          ],
          [
            '121251322769',
            'FINISHED',
            'RUM::Script::RumToSam'
          ],
          [
            '121251322783',
            'FINISHED',
            'RUM::Script::Main'
          ]
        ];


open my $log, "<", \$LOG;

my $p = RUM::Action::Profile->new;
my $events = $p->parse_log_file($log);
is_deeply($events, $expected, "Parse log file");

my $times = $p->build_timings($events);
is_deeply($times,
          {
              'RUM::Script::FinalCleanup' => 3,
              'RUM::Script::Main' => 47,
              'RUM::Script::MergeGuAndTu' => 10,
              'RUM::Script::SortRumByLocation' => 0,
              'RUM::Script::RumToSam' => 0,
              'RUM::Script::MakeTuAndTnu' => 1,
              'RUM::Script::SortRumById' => 0,
              'RUM::Script::ParseBlatOut' => 0
          },
          "Build timings");

