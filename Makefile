DELETE_ON_ERROR=true
NAME=

gene_info_files := $(shell cat gene_info_files)

all : $(NAME)_genome_one-line-seqs.fa

genome : $(NAME)_genome_one-line-seqs.fa

gene_info : gene_info_merged_sorted_fixed.txt

cleanup=$(NAME)_genome.fa $(NAME)_genome_one-line-seqs_temp.fa $(NAME)_genome_one-line-seqs.fa gene_info_merged_unsorted.txt gene_info_merged_unsorted_fixed.txt gene_info_merged_sorted_fixed.txt 

$(NAME)_genome.fa : $(NAME)_genome.txt
	perl bin/modify_fasta_header_for_genome_seq_database.pl $< >$@

$(NAME)_genome_one-line-seqs_temp.fa : $(NAME)_genome.fa
	perl bin/modify_fa_to_have_seq_on_one_line.pl $< >$@

$(NAME)_genome_one-line-seqs.fa : $(NAME)_genome_one-line-seqs_temp.fa
	perl bin/sort_genome_fa_by_chr.pl $< >$@

gene_info_merged_unsorted.txt : gene_info_files $(gene_info_files)
	perl bin/make_master_file_of_genes.pl $< >$@

gene_info_merged_unsorted_fixed.txt : gene_info_merged_unsorted.txt
	perl fix_geneinfofile_for_neg_introns.pl $< >$@

gene_info_merged_sorted_fixed.txt : gene_info_merged_unsorted_fixed.txt
	perl sort_geneinfofile.pl $< >$@

clean : 
	rm -f $(cleanup)