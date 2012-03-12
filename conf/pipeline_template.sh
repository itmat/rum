#!/bin/sh

# xxx0

# genome bowtie starts here.  Remove from xxx0 to xxx2 for blat only mapping

echo "starting..." `date` `date +%s` > OUTDIR/rum.log_chunk.CHUNK
BOWTIEEXE -a --best --strata -f GENOMEBOWTIE READSFILE.CHUNK -v 3 --suppress 6,7,8 -p 1 --quiet > OUTDIR/X.CHUNK || exit 1
echo "finished first bowtie run" `date` `date +%s` >> OUTDIR/rum.log_chunk.CHUNK
perl SCRIPTSDIR/make_GU_and_GNU.pl OUTDIR/X.CHUNK --unique OUTDIR/GU.CHUNK --non-unique OUTDIR/GNU.CHUNK --PAIREDEND  2>> ERRORFILE.CHUNK || exit 1
echo "finished parsing genome bowtie run" `date` `date +%s` >> OUTDIR/rum.log_chunk.CHUNK
ls -l OUTDIR/X.CHUNK >> OUTDIR/rum.log_chunk.CHUNK
yes|unlink OUTDIR/X.CHUNK

# xxx1

# transcriptome bowtie starts here.  Remove from xxx1 to xxx2 for dna mapping

BOWTIEEXE -a --best --strata -f TRANSCRIPTOMEBOWTIE READSFILE.CHUNK -v 3 --suppress 6,7,8 -p 1 --quiet > OUTDIR/Y.CHUNK || exit 1
echo "finished second bowtie run" `date` `date +%s` >> OUTDIR/rum.log_chunk.CHUNK
perl SCRIPTSDIR/make_TU_and_TNU.pl --bowtie-output OUTDIR/Y.CHUNK --genes GENEANNOTFILE --unique OUTDIR/TU.CHUNK --non-unique OUTDIR/TNU.CHUNK --PAIREDEND  2>> ERRORFILE.CHUNK || exit 1
echo "finished parsing transcriptome bowtie run" `date` `date +%s` >> OUTDIR/rum.log_chunk.CHUNK
ls -l OUTDIR/Y.CHUNK >> OUTDIR/rum.log_chunk.CHUNK
yes|unlink OUTDIR/Y.CHUNK

# merging starts here

perl SCRIPTSDIR/merge_GU_and_TU.pl --gu OUTDIR/GU.CHUNK --tu OUTDIR/TU.CHUNK --gnu OUTDIR/GNU.CHUNK --tnu OUTDIR/TNU.CHUNK --bowtie-unique OUTDIR/BowtieUnique.CHUNK --cnu OUTDIR/CNU.CHUNK --PAIREDEND --read-length READLENGTH --min-overlap MINOVERLAP  2>> ERRORFILE.CHUNK || exit 1
echo "finished merging TU and GU" `date` `date +%s` >> OUTDIR/rum.log_chunk.CHUNK
perl SCRIPTSDIR/merge_GNU_and_TNU_and_CNU.pl --gnu OUTDIR/GNU.CHUNK --tnu OUTDIR/TNU.CHUNK --cnu OUTDIR/CNU.CHUNK --out OUTDIR/BowtieNU.CHUNK 2>> ERRORFILE.CHUNK || exit 1
echo "finished merging GNU, TNU and CNU" `date` `date +%s` >> OUTDIR/rum.log_chunk.CHUNK
ls -l OUTDIR/TU.CHUNK >> OUTDIR/rum.log_chunk.CHUNK
ls -l OUTDIR/TNU.CHUNK >> OUTDIR/rum.log_chunk.CHUNK
ls -l OUTDIR/CNU.CHUNK >> OUTDIR/rum.log_chunk.CHUNK
yes|unlink OUTDIR/TU.CHUNK
yes|unlink OUTDIR/TNU.CHUNK

# xxx2

# uncomment the following for dna or genome only mapping:

# cp OUTDIR/GU.CHUNK OUTDIR/BowtieUnique.CHUNK
# cp OUTDIR/GNU.CHUNK OUTDIR/BowtieNU.CHUNK
echo "checkpoint 1" `date` `date +%s` >> OUTDIR/rum.log_chunk.CHUNK

ls -l OUTDIR/GU.CHUNK >> OUTDIR/rum.log_chunk.CHUNK
ls -l OUTDIR/GNU.CHUNK >> OUTDIR/rum.log_chunk.CHUNK
yes|unlink OUTDIR/GU.CHUNK
yes|unlink OUTDIR/GNU.CHUNK
yes|unlink OUTDIR/CNU.CHUNK

perl SCRIPTSDIR/make_unmapped_file.pl --reads READSFILE.CHUNK --unique OUTDIR/BowtieUnique.CHUNK --non-unique OUTDIR/BowtieNU.CHUNK -o OUTDIR/R.CHUNK --PAIREDEND 2>> ERRORFILE.CHUNK || exit 1
echo "finished making R" `date` `date +%s` >> OUTDIR/rum.log_chunk.CHUNK

BLATEXE GENOMEBLAT OUTDIR/R.CHUNK OUTDIR/R.CHUNK.blat BLATEXEOPTS || exit 1
echo "finished running BLAT" `date` `date +%s` >> OUTDIR/rum.log_chunk.CHUNK
MDUSTEXE OUTDIR/R.CHUNK >> OUTDIR/R.mdust.CHUNK || exit 1
echo "finished running mdust on R" `date` `date +%s` >> OUTDIR/rum.log_chunk.CHUNK
perl SCRIPTSDIR/parse_blat_out.pl --reads-in OUTDIR/R.CHUNK --blat-in OUTDIR/R.CHUNK.blat --mdust-in OUTDIR/R.mdust.CHUNK --unique-out OUTDIR/BlatUnique.CHUNK --non-unique-out OUTDIR/BlatNU.CHUNK MAXINSERTIONSALLOWED MATCHLENGTHCUTOFF DNA 2>> ERRORFILE.CHUNK || exit 1
echo "finished parsing BLAT output" `date` `date +%s` >> OUTDIR/rum.log_chunk.CHUNK
ls -l OUTDIR/R.CHUNK >> OUTDIR/rum.log_chunk.CHUNK
ls -l OUTDIR/R.CHUNK.blat >> OUTDIR/rum.log_chunk.CHUNK
ls -l OUTDIR/R.mdust.CHUNK >> OUTDIR/rum.log_chunk.CHUNK
yes|unlink OUTDIR/R.CHUNK
yes|unlink OUTDIR/R.CHUNK.blat
yes|unlink OUTDIR/R.mdust.CHUNK
echo perl SCRIPTSDIR/merge_Bowtie_and_Blat.pl OUTDIR/BowtieUnique.CHUNK OUTDIR/BlatUnique.CHUNK OUTDIR/BowtieNU.CHUNK OUTDIR/BlatNU.CHUNK OUTDIR/RUM_Unique_temp.CHUNK OUTDIR/RUM_NU_temp.CHUNK PAIREDEND -readlength READLENGTH -minoverlap MINOVERLAP > merge_bowtie_and_blat
perl SCRIPTSDIR/merge_Bowtie_and_Blat.pl --bowtie-unique OUTDIR/BowtieUnique.CHUNK --blat-unique OUTDIR/BlatUnique.CHUNK --bowtie-non-unique OUTDIR/BowtieNU.CHUNK --blat-non-unique OUTDIR/BlatNU.CHUNK --unique-out OUTDIR/RUM_Unique_temp.CHUNK --non-unique-out OUTDIR/RUM_NU_temp.CHUNK --PAIREDEND --read-length READLENGTH --min-overlap MINOVERLAP 2>> ERRORFILE.CHUNK || exit 1
echo "finished merging Bowtie and Blat" `date` `date +%s` >> OUTDIR/rum.log_chunk.CHUNK
ls -l OUTDIR/BowtieUnique.CHUNK >> OUTDIR/rum.log_chunk.CHUNK
ls -l OUTDIR/BowtieNU.CHUNK >> OUTDIR/rum.log_chunk.CHUNK
ls -l OUTDIR/BlatUnique.CHUNK >> OUTDIR/rum.log_chunk.CHUNK
ls -l OUTDIR/BlatNU.CHUNK >> OUTDIR/rum.log_chunk.CHUNK
yes|unlink OUTDIR/BowtieUnique.CHUNK
yes|unlink OUTDIR/BlatUnique.CHUNK
yes|unlink OUTDIR/BowtieNU.CHUNK
yes|unlink OUTDIR/BlatNU.CHUNK

perl SCRIPTSDIR/RUM_finalcleanup.pl --unique-in OUTDIR/RUM_Unique_temp.CHUNK --non-unique-in OUTDIR/RUM_NU_temp.CHUNK --unique-out OUTDIR/RUM_Unique_temp2.CHUNK --non-unique-out OUTDIR/RUM_NU_temp2.CHUNK --genome GENOMEFA --sam-header-out OUTDIR/sam_header.CHUNK --faok COUNTMISMATCHES MATCHLENGTHCUTOFF 2>> ERRORFILE.CHUNK || exit 1
echo "finished cleaning up final results" `date` `date +%s` >> OUTDIR/rum.log_chunk.CHUNK
perl SCRIPTSDIR/sort_RUM_by_id.pl OUTDIR/RUM_NU_temp2.CHUNK -o OUTDIR/RUM_NU_idsorted.CHUNK 2>> ERRORFILE.CHUNK || exit 1
echo "finished sorting NU" `date` `date +%s` >> OUTDIR/rum.log_chunk.CHUNK
perl SCRIPTSDIR/removedups.pl OUTDIR/RUM_NU_idsorted.CHUNK OUTDIR/RUM_NU_temp3.CHUNK OUTDIR/RUM_Unique_temp2.CHUNK 2>> ERRORFILE.CHUNK || exit 1
echo "finished removing dups in RUM_NU" `date` `date +%s` >> OUTDIR/rum.log_chunk.CHUNK

perl SCRIPTSDIR/limit_NU.pl -o OUTDIR/RUM_NU_temp3.CHUNK -n LIMITNUCUTOFF 2>> ERRORFILE.CHUNK || exit 1
perl SCRIPTSDIR/sort_RUM_by_id.pl OUTDIR/RUM_Unique_temp2.CHUNK -o OUTDIR/RUM_Unique.CHUNK 2>> ERRORFILE.CHUNK || exit 1
echo "finished sorting Unique" `date` `date +%s` >> OUTDIR/rum.log_chunk.CHUNK

ls -l OUTDIR/RUM_Unique_temp.CHUNK >> OUTDIR/rum.log_chunk.CHUNK
ls -l OUTDIR/RUM_Unique_temp2.CHUNK >> OUTDIR/rum.log_chunk.CHUNK
ls -l OUTDIR/RUM_NU_temp.CHUNK >> OUTDIR/rum.log_chunk.CHUNK
ls -l OUTDIR/RUM_NU_temp2.CHUNK >> OUTDIR/rum.log_chunk.CHUNK
echo '' >> OUTDIR/RUM_NU_temp3.CHUNK
ls -l OUTDIR/RUM_NU_temp3.CHUNK >> OUTDIR/rum.log_chunk.CHUNK
ls -l OUTDIR/RUM_NU_idsorted.CHUNK >> OUTDIR/rum.log_chunk.CHUNK
yes|unlink OUTDIR/RUM_Unique_temp.CHUNK
yes|unlink OUTDIR/RUM_NU_temp.CHUNK
yes|unlink OUTDIR/RUM_Unique_temp2.CHUNK
yes|unlink OUTDIR/RUM_NU_temp2.CHUNK
yes|unlink OUTDIR/RUM_NU_temp3.CHUNK
yes|unlink OUTDIR/RUM_NU_idsorted.CHUNK
perl SCRIPTSDIR/rum2sam.pl OUTDIR/RUM_Unique.CHUNK OUTDIR/RUM_NU.CHUNK READSFILE.CHUNK QUALSFILE.CHUNK OUTDIR/RUM.sam.CHUNK NAMEMAPPING.CHUNK 2>> ERRORFILE.CHUNK || exit 1
echo "finished converting to SAM" `date` `date +%s` >> OUTDIR/rum.log_chunk.CHUNK
perl SCRIPTSDIR/get_nu_stats.pl OUTDIR/RUM.sam.CHUNK > OUTDIR/nu_stats.CHUNK 2>> ERRORFILE.CHUNK || exit 1
echo "finished counting the nu mappers" `date` `date +%s` >> OUTDIR/rum.log_chunk.CHUNK
perl SCRIPTSDIR/sort_RUM_by_location.pl OUTDIR/RUM_Unique.CHUNK OUTDIR/RUM_Unique.sorted.CHUNK RAM >> OUTDIR/chr_counts_u.CHUNK 2>> ERRORFILE.CHUNK || exit 1
echo "finished sorting RUM_Unique" `date` `date +%s` >> OUTDIR/rum.log_chunk.CHUNK
ls -l OUTDIR/RUM_Unique.sorted.CHUNK >> OUTDIR/rum.log_chunk.CHUNK
perl SCRIPTSDIR/sort_RUM_by_location.pl OUTDIR/RUM_NU.CHUNK OUTDIR/RUM_NU.sorted.CHUNK RAM >> OUTDIR/chr_counts_nu.CHUNK 2>> ERRORFILE.CHUNK || exit 1
echo "finished sorting RUM_NU" `date` `date +%s` >> OUTDIR/rum.log_chunk.CHUNK
ls -l OUTDIR/RUM_NU.sorted.CHUNK >> OUTDIR/rum.log_chunk.CHUNK
perl SCRIPTSDIR/rum2quantifications.pl GENEANNOTFILE OUTDIR/RUM_Unique.sorted.CHUNK OUTDIR/RUM_NU.sorted.CHUNK OUTDIR/quant.S1s.CHUNK -countsonly STRAND1s 2>> ERRORFILE.CHUNK || exit 1
perl SCRIPTSDIR/rum2quantifications.pl GENEANNOTFILE OUTDIR/RUM_Unique.sorted.CHUNK OUTDIR/RUM_NU.sorted.CHUNK OUTDIR/quant.S2s.CHUNK -countsonly STRAND2s 2>> ERRORFILE.CHUNK || exit 1
perl SCRIPTSDIR/rum2quantifications.pl GENEANNOTFILE OUTDIR/RUM_Unique.sorted.CHUNK OUTDIR/RUM_NU.sorted.CHUNK OUTDIR/quant.S1a.CHUNK -countsonly STRAND1a 2>> ERRORFILE.CHUNK || exit 1
perl SCRIPTSDIR/rum2quantifications.pl GENEANNOTFILE OUTDIR/RUM_Unique.sorted.CHUNK OUTDIR/RUM_NU.sorted.CHUNK OUTDIR/quant.S2a.CHUNK -countsonly STRAND2a 2>> ERRORFILE.CHUNK || exit 1

echo "finished quantification" `date` `date +%s` >> OUTDIR/rum.log_chunk.CHUNK

ls -l OUTDIR/RUM.sam.CHUNK >> OUTDIR/rum.log_chunk.CHUNK
ls -l OUTDIR/RUM_Unique.CHUNK >> OUTDIR/rum.log_chunk.CHUNK
ls -l OUTDIR/RUM_NU.CHUNK >> OUTDIR/rum.log_chunk.CHUNK
ls -l OUTDIR/RUM.sam.CHUNK >> OUTDIR/rum.log_chunk.CHUNK
ls -l OUTDIR/sam_header.CHUNK >> OUTDIR/rum.log_chunk.CHUNK
ls -l OUTDIR/quant.S1s.CHUNK >> OUTDIR/rum.log_chunk.CHUNK
ls -l OUTDIR/quant.S2s.CHUNK >> OUTDIR/rum.log_chunk.CHUNK
ls -l OUTDIR/quant.S1a.CHUNK >> OUTDIR/rum.log_chunk.CHUNK
ls -l OUTDIR/quant.S2a.CHUNK >> OUTDIR/rum.log_chunk.CHUNK
ls -l OUTDIR/reads.fa.CHUNK >> OUTDIR/rum.log_chunk.CHUNK
ls -l OUTDIR/nu_stats.CHUNK >> OUTDIR/rum.log_chunk.CHUNK
echo '' >> OUTDIR/quals.fa.CHUNK
ls -l OUTDIR/quals.fa.CHUNK >> OUTDIR/rum.log_chunk.CHUNK

echo "pipeline complete" `date` `date +%s` >> OUTDIR/rum.log_chunk.CHUNK
