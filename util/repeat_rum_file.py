from rum_mapping_stats import aln_iter
import argparse
import sys

parser = argparse.ArgumentParser()

parser.add_argument('--times', type=int)
parser.add_argument('--max-seq', type=int)
parser.add_argument('rum_file', type=file)

args = parser.parse_args()

alns = list(aln_iter(args.rum_file))

for t in range(args.times):
    for aln in alns:
        old_read_num = aln.read_num
        aln.read_num = old_read_num + t * args.max_seq
        aln.write(sys.stdout)
        aln.read_num = old_read_num
        
