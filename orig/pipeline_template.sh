#!/bin/sh

# xxx0

# genome bowtie starts here.  Remove from xxx0 to xxx2 for blat only mapping

echo "starting..." > OUTDIR/rum_log.CHUNK
echo `date` `date +%s` >> OUTDIR/rum_log.CHUNK
BOWTIEEXE -a --best --strata -f GENOMEBOWTIE READSFILE.CHUNK -v 3 --suppress 6,7,8 -p 1 > OUTDIR/X.CHUNK
echo "finished first bowtie run" >> OUTDIR/rum_log.CHUNK
echo `date` `date +%s` >> OUTDIR/rum_log.CHUNK
perl SCRIPTSDIR/make_GU_and_GNU.pl OUTDIR/X.CHUNK OUTDIR/GU.CHUNK OUTDIR/GNU.CHUNK PAIREDEND
echo "finished parsing genome bowtie run" >> OUTDIR/rum_log.CHUNK
echo `date` `date +%s` >> OUTDIR/rum_log.CHUNK

# xxx1

# transcriptome bowtie starts here.  Remove from xxx1 to xxx2 for dna mapping

BOWTIEEXE -a --best --strata -f TRANSCRIPTOMEBOWTIE READSFILE.CHUNK -v 3 --suppress 6,7,8 -p 1 > OUTDIR/Y.CHUNK
echo "finished second bowtie run" >> OUTDIR/rum_log.CHUNK
echo `date` `date +%s` >> OUTDIR/rum_log.CHUNK
perl SCRIPTSDIR/make_TU_and_TNU.pl OUTDIR/Y.CHUNK GENEANNOTFILE OUTDIR/TU.CHUNK OUTDIR/TNU.CHUNK PAIREDEND
echo "finished parsing transcriptome bowtie run" >> OUTDIR/rum_log.CHUNK
echo `date` `date +%s` >> OUTDIR/rum_log.CHUNK

perl SCRIPTSDIR/merge_GU_and_TU.pl OUTDIR/GU.CHUNK OUTDIR/TU.CHUNK OUTDIR/GNU.CHUNK OUTDIR/TNU.CHUNK OUTDIR/BowtieUnique.CHUNK OUTDIR/CNU.CHUNK PAIREDEND -readlength READLENGTH
echo "finished merging TU and GU" >> OUTDIR/rum_log.CHUNK
echo `date` `date +%s` >> OUTDIR/rum_log.CHUNK
perl SCRIPTSDIR/merge_GNU_and_TNU_and_CNU.pl OUTDIR/GNU.CHUNK OUTDIR/TNU.CHUNK OUTDIR/CNU.CHUNK OUTDIR/BowtieNU.CHUNK
echo "finished merging GNU, TNU and CNU" >> OUTDIR/rum_log.CHUNK
echo `date` `date +%s` >> OUTDIR/rum_log.CHUNK

# xxx2

# uncomment the following for dna mapping:

# cp OUTDIR/GU.CHUNK OUTDIR/BowtieUnique.CHUNK
# cp OUTDIR/GNU.CHUNK OUTDIR/BowtieNU.CHUNK

perl SCRIPTSDIR/make_unmapped_file.pl READSFILE.CHUNK OUTDIR/BowtieUnique.CHUNK OUTDIR/BowtieNU.CHUNK OUTDIR/R.CHUNK PAIREDEND
echo "finished making R" >> OUTDIR/rum_log.CHUNK
echo `date` `date +%s` >> OUTDIR/rum_log.CHUNK

BLATEXE GENOMEBLAT OUTDIR/R.CHUNK OUTDIR/R.CHUNK.blat -minScore=20 -minIdentity=MINIDENTITY SPEED
echo "finished first BLAT run" >> OUTDIR/rum_log.CHUNK
echo `date` `date +%s` >> OUTDIR/rum_log.CHUNK
MDUSTEXE OUTDIR/R.CHUNK > OUTDIR/R.mdust.CHUNK
echo "finished running mdust on R" >> OUTDIR/rum_log.CHUNK
echo `date` `date +%s` >> OUTDIR/rum_log.CHUNK
perl SCRIPTSDIR/parse_blat_out.pl OUTDIR/R.CHUNK OUTDIR/R.CHUNK.blat OUTDIR/R.mdust.CHUNK OUTDIR/BlatUnique.CHUNK OUTDIR/BlatNU.CHUNK MAXINSERTIONSALLOWED
echo "finished parsing first BLAT run" >> OUTDIR/rum_log.CHUNK
echo `date` `date +%s` >> OUTDIR/rum_log.CHUNK
perl SCRIPTSDIR/merge_Bowtie_and_Blat.pl OUTDIR/BowtieUnique.CHUNK OUTDIR/BlatUnique.CHUNK OUTDIR/BowtieNU.CHUNK OUTDIR/BlatNU.CHUNK OUTDIR/RUM_Unique_temp.CHUNK OUTDIR/RUM_NU_temp.CHUNK PAIREDEND -readlength READLENGTH
echo "finished merging Bowtie and Blat" >> OUTDIR/rum_log.CHUNK
echo `date` `date +%s` >> OUTDIR/rum_log.CHUNK
perl SCRIPTSDIR/RUM_finalcleanup.pl OUTDIR/RUM_Unique_temp.CHUNK OUTDIR/RUM_NU_temp.CHUNK OUTDIR/RUM_Unique_temp2.CHUNK OUTDIR/RUM_NU_temp2.CHUNK GENOMEFA OUTDIR/sam_header.CHUNK -faok COUNTMISMATCHES
echo "finished cleaning up final results" >> OUTDIR/rum_log.CHUNK
echo `date` `date +%s` >> OUTDIR/rum_log.CHUNK
perl SCRIPTSDIR/sort_RUM.pl OUTDIR/RUM_Unique_temp2.CHUNK OUTDIR/RUM_Unique.CHUNK
perl SCRIPTSDIR/limit_NU.pl OUTDIR/RUM_NU_temp2.CHUNK LIMITNUCUTOFF > OUTDIR/RUM_NU_temp3.CHUNK
# the following is correct, temp2 gets replaced with temp3 by RUM_runner.pl if limit_NU option is used
perl SCRIPTSDIR/sort_RUM.pl OUTDIR/RUM_NU_temp2.CHUNK OUTDIR/RUM_NU.CHUNK
echo "finished sorting final results" >> OUTDIR/rum_log.CHUNK
echo `date` `date +%s` >> OUTDIR/rum_log.CHUNK
rm OUTDIR/RUM_Unique_temp.CHUNK
rm OUTDIR/RUM_NU_temp.CHUNK
rm OUTDIR/RUM_Unique_temp2.CHUNK
rm OUTDIR/RUM_NU_temp2.CHUNK
perl SCRIPTSDIR/rum2sam.pl OUTDIR/RUM_Unique.CHUNK OUTDIR/RUM_NU.CHUNK READSFILE.CHUNK QUALSFILE.CHUNK OUTDIR/RUM.sam.CHUNK
echo "finished converting to SAM" >> OUTDIR/rum_log.CHUNK
echo `date` `date +%s` >> OUTDIR/rum_log.CHUNK

echo "pipeline complete" >> OUTDIR/rum_log.CHUNK
echo `date` `date +%s` >> OUTDIR/rum_log.CHUNK
