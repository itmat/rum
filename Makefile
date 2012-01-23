DELETE_ON_ERROR=true
NAME=

all : $(NAME)_genome_one-line-seqs.fa

$(NAME)_genome.fa : $(NAME)_genome.txt
	perl bin/modify_fasta_header_for_genome_seq_database.pl $< >$@

$(NAME)_genome_one-line-seqs_temp.fa : $(NAME)_genome.fa
	perl bin/modify_fa_to_have_seq_on_one_line.pl $< >$@

$(NAME)_genome_one-line-seqs.fa : $(NAME)_genome_one-line-seqs_temp.fa
	perl bin/sort_genome_fa_by_chr.pl $< >$@

clean : 
	rm -f $(NAME)_genome.fa $(NAME)_genome_one-line-seqs_temp.fa