#!/bin/sh

# xxx0

# genome bowtie starts here.  Remove from xxx0 to xxx2 for blat only mapping

log=SCRIPTSDIR/rum_log

$log starting...
BOWTIEEXE -a --best --strata -f GENOMEBOWTIE READSFILE.CHUNK -v 3 --suppress 6,7,8 -p 1 --quiet > OUTDIR/X.CHUNK || exit 1
$log finished first bowtie run
perl SCRIPTSDIR/make_GU_and_GNU.pl OUTDIR/X.CHUNK --unique OUTDIR/GU.CHUNK --non-unique OUTDIR/GNU.CHUNK --PAIREDEND   || exit 1
$log finished parsing genome bowtie run
$log `ls -l OUTDIR/X.CHUNK`
yes|unlink OUTDIR/X.CHUNK

# xxx1

# transcriptome bowtie starts here.  Remove from xxx1 to xxx2 for dna mapping

BOWTIEEXE -a --best --strata -f TRANSCRIPTOMEBOWTIE READSFILE.CHUNK -v 3 --suppress 6,7,8 -p 1 --quiet > OUTDIR/Y.CHUNK || exit 1
$log finished second bowtie run
perl SCRIPTSDIR/make_TU_and_TNU.pl --bowtie-output OUTDIR/Y.CHUNK --genes GENEANNOTFILE --unique OUTDIR/TU.CHUNK --non-unique OUTDIR/TNU.CHUNK --PAIREDEND   || exit 1
$log finished parsing transcriptome bowtie run
$log `ls -l OUTDIR/Y.CHUNK`
yes|unlink OUTDIR/Y.CHUNK

# merging starts here

perl SCRIPTSDIR/merge_GU_and_TU.pl --gu OUTDIR/GU.CHUNK --tu OUTDIR/TU.CHUNK --gnu OUTDIR/GNU.CHUNK --tnu OUTDIR/TNU.CHUNK --bowtie-unique OUTDIR/BowtieUnique.CHUNK --cnu OUTDIR/CNU.CHUNK --PAIREDEND --read-length READLENGTH --min-overlap MINOVERLAP   || exit 1
$log finished merging TU and GU
perl SCRIPTSDIR/merge_GNU_and_TNU_and_CNU.pl --gnu OUTDIR/GNU.CHUNK --tnu OUTDIR/TNU.CHUNK --cnu OUTDIR/CNU.CHUNK --out OUTDIR/BowtieNU.CHUNK  || exit 1
$log finished merging GNU, TNU and CNU
$log `ls -l OUTDIR/TU.CHUNK`
$log `ls -l OUTDIR/TNU.CHUNK`
$log `ls -l OUTDIR/CNU.CHUNK`
yes|unlink OUTDIR/TU.CHUNK
yes|unlink OUTDIR/TNU.CHUNK

# xxx2

# uncomment the following for dna or genome only mapping:

# cp OUTDIR/GU.CHUNK OUTDIR/BowtieUnique.CHUNK
# cp OUTDIR/GNU.CHUNK OUTDIR/BowtieNU.CHUNK
$log checkpoint 1

$log `ls -l OUTDIR/GU.CHUNK`
$log `ls -l OUTDIR/GNU.CHUNK`
yes|unlink OUTDIR/GU.CHUNK
yes|unlink OUTDIR/GNU.CHUNK
yes|unlink OUTDIR/CNU.CHUNK

perl SCRIPTSDIR/make_unmapped_file.pl --reads READSFILE.CHUNK --unique OUTDIR/BowtieUnique.CHUNK --non-unique OUTDIR/BowtieNU.CHUNK -o OUTDIR/R.CHUNK --PAIREDEND  || exit 1
$log finished making R

BLATEXE GENOMEBLAT OUTDIR/R.CHUNK OUTDIR/R.CHUNK.blat BLATEXEOPTS || exit 1
$log finished running BLAT
MDUSTEXE OUTDIR/R.CHUNK >> OUTDIR/R.mdust.CHUNK || exit 1
$log finished running mdust on R
perl SCRIPTSDIR/parse_blat_out.pl --reads-in OUTDIR/R.CHUNK --blat-in OUTDIR/R.CHUNK.blat --mdust-in OUTDIR/R.mdust.CHUNK --unique-out OUTDIR/BlatUnique.CHUNK --non-unique-out OUTDIR/BlatNU.CHUNK MAXINSERTIONSALLOWED MATCHLENGTHCUTOFF DNA  || exit 1
$log finished parsing BLAT output
$log `ls -l OUTDIR/R.CHUNK`
$log `ls -l OUTDIR/R.CHUNK.blat`
$log `ls -l OUTDIR/R.mdust.CHUNK`
yes|unlink OUTDIR/R.CHUNK
yes|unlink OUTDIR/R.CHUNK.blat
yes|unlink OUTDIR/R.mdust.CHUNK
perl SCRIPTSDIR/merge_Bowtie_and_Blat.pl --bowtie-unique OUTDIR/BowtieUnique.CHUNK --blat-unique OUTDIR/BlatUnique.CHUNK --bowtie-non-unique OUTDIR/BowtieNU.CHUNK --blat-non-unique OUTDIR/BlatNU.CHUNK --unique-out OUTDIR/RUM_Unique_temp.CHUNK --non-unique-out OUTDIR/RUM_NU_temp.CHUNK --PAIREDEND --read-length READLENGTH --min-overlap MINOVERLAP  || exit 1
$log finished merging Bowtie and Blat
$log `ls -l OUTDIR/BowtieUnique.CHUNK`
$log `ls -l OUTDIR/BowtieNU.CHUNK`
$log `ls -l OUTDIR/BlatUnique.CHUNK`
$log `ls -l OUTDIR/BlatNU.CHUNK`
yes|unlink OUTDIR/BowtieUnique.CHUNK
yes|unlink OUTDIR/BlatUnique.CHUNK
yes|unlink OUTDIR/BowtieNU.CHUNK
yes|unlink OUTDIR/BlatNU.CHUNK

perl SCRIPTSDIR/RUM_finalcleanup.pl --unique-in OUTDIR/RUM_Unique_temp.CHUNK --non-unique-in OUTDIR/RUM_NU_temp.CHUNK --unique-out OUTDIR/RUM_Unique_temp2.CHUNK --non-unique-out OUTDIR/RUM_NU_temp2.CHUNK --genome GENOMEFA --sam-header-out OUTDIR/sam_header.CHUNK --faok COUNTMISMATCHES MATCHLENGTHCUTOFF  || exit 1
$log finished cleaning up final results
perl SCRIPTSDIR/sort_RUM_by_id.pl OUTDIR/RUM_NU_temp2.CHUNK -o OUTDIR/RUM_NU_idsorted.CHUNK  || exit 1
$log finished sorting NU
perl SCRIPTSDIR/removedups.pl OUTDIR/RUM_NU_idsorted.CHUNK --non-unique-out OUTDIR/RUM_NU_temp3.CHUNK --unique-out OUTDIR/RUM_Unique_temp2.CHUNK  || exit 1
$log finished removing dups in RUM_NU

perl SCRIPTSDIR/limit_NU.pl OUTDIR/RUM_NU_temp3.CHUNK -n LIMITNUCUTOFF -o OUTDIR/RUM_NU.CHUNK  || exit 1

perl SCRIPTSDIR/sort_RUM_by_id.pl OUTDIR/RUM_Unique_temp2.CHUNK -o OUTDIR/RUM_Unique.CHUNK  || exit 1
$log finished sorting Unique

$log `ls -l OUTDIR/RUM_Unique_temp.CHUNK`
$log `ls -l OUTDIR/RUM_Unique_temp2.CHUNK`
$log `ls -l OUTDIR/RUM_NU_temp.CHUNK`
$log `ls -l OUTDIR/RUM_NU_temp2.CHUNK`
echo '' >> OUTDIR/RUM_NU_temp3.CHUNK
$log `ls -l OUTDIR/RUM_NU_temp3.CHUNK`
$log `ls -l OUTDIR/RUM_NU_idsorted.CHUNK`
yes|unlink OUTDIR/RUM_Unique_temp.CHUNK
yes|unlink OUTDIR/RUM_NU_temp.CHUNK
yes|unlink OUTDIR/RUM_Unique_temp2.CHUNK
yes|unlink OUTDIR/RUM_NU_temp2.CHUNK
yes|unlink OUTDIR/RUM_NU_temp3.CHUNK
yes|unlink OUTDIR/RUM_NU_idsorted.CHUNK
perl SCRIPTSDIR/rum2sam.pl --unique-in OUTDIR/RUM_Unique.CHUNK --non-unique-in OUTDIR/RUM_NU.CHUNK --reads-in READSFILE.CHUNK --quals-in QUALSFILE.CHUNK --sam-out OUTDIR/RUM.sam.CHUNK NAMEMAPPING.CHUNK  || exit 1
$log finished converting to SAM
perl SCRIPTSDIR/get_nu_stats.pl OUTDIR/RUM.sam.CHUNK > OUTDIR/nu_stats.CHUNK  || exit 1
$log finished counting the nu mappers
perl SCRIPTSDIR/sort_RUM_by_location.pl OUTDIR/RUM_Unique.CHUNK -o OUTDIR/RUM_Unique.sorted.CHUNK RAM >> OUTDIR/chr_counts_u.CHUNK  || exit 1
$log finished sorting RUM_Unique
$log `ls -l OUTDIR/RUM_Unique.sorted.CHUNK`
perl SCRIPTSDIR/sort_RUM_by_location.pl OUTDIR/RUM_NU.CHUNK -o OUTDIR/RUM_NU.sorted.CHUNK RAM >> OUTDIR/chr_counts_nu.CHUNK  || exit 1
$log finished sorting RUM_NU
$log `ls -l OUTDIR/RUM_NU.sorted.CHUNK`
perl SCRIPTSDIR/rum2quantifications.pl --genes-in GENEANNOTFILE --unique-in OUTDIR/RUM_Unique.sorted.CHUNK --non-unique-in OUTDIR/RUM_NU.sorted.CHUNK -o OUTDIR/quant.S1s.CHUNK -countsonly STRAND1s  || exit 1
perl SCRIPTSDIR/rum2quantifications.pl --genes-in GENEANNOTFILE --unique-in OUTDIR/RUM_Unique.sorted.CHUNK --non-unique-in OUTDIR/RUM_NU.sorted.CHUNK -o OUTDIR/quant.S2s.CHUNK -countsonly STRAND2s  || exit 1
perl SCRIPTSDIR/rum2quantifications.pl --genes-in GENEANNOTFILE --unique-in OUTDIR/RUM_Unique.sorted.CHUNK --non-unique-in OUTDIR/RUM_NU.sorted.CHUNK -o OUTDIR/quant.S1a.CHUNK -countsonly STRAND1a  || exit 1
perl SCRIPTSDIR/rum2quantifications.pl --genes-in GENEANNOTFILE --unique-in OUTDIR/RUM_Unique.sorted.CHUNK --non-unique-in OUTDIR/RUM_NU.sorted.CHUNK -o OUTDIR/quant.S2a.CHUNK -countsonly STRAND2a  || exit 1

$log finished quantification

$log `ls -l OUTDIR/RUM.sam.CHUNK`
$log `ls -l OUTDIR/RUM_Unique.CHUNK`
$log `ls -l OUTDIR/RUM_NU.CHUNK`
$log `ls -l OUTDIR/RUM.sam.CHUNK`
$log `ls -l OUTDIR/sam_header.CHUNK`
$log `ls -l OUTDIR/quant.S1s.CHUNK`
$log `ls -l OUTDIR/quant.S2s.CHUNK`
$log `ls -l OUTDIR/quant.S1a.CHUNK`
$log `ls -l OUTDIR/quant.S2a.CHUNK`
$log `ls -l OUTDIR/reads.fa.CHUNK`
$log `ls -l OUTDIR/nu_stats.CHUNK`
echo '' >> OUTDIR/quals.fa.CHUNK
$log `ls -l OUTDIR/quals.fa.CHUNK`

$log pipeline complete
