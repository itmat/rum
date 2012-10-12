from numpy import *
import argparse
import re
import collections

readid_re = re.compile('seq.(\d+)([ab]?)')

class AlignmentPart:
    def __init__(self, starts, ends, sequence):
        self.starts   = starts
        self.ends     = ends
        self.sequence = sequence

    def __str__(self):
        return str(self.__dict__)

    def __repr__(self):
        return 'AlignmentPart' + repr(self.__dict__)

class Alignment:

    def __init__(self, line=None, read_num=None, chromosome=None, strand=None, 
                 forward=None, reverse=None, joined=None):

        if (line is not None):
            (readid, chromosome, loc_str, strand, sequence) = line.split('\t', 4)
            m = readid_re.match(readid)
            if m is None:
                raise Exception("%s doesn't look like a read id" % readid)

            starts = []
            ends   = []
            for loc in loc_str.split(', '):
                (fwd, rev) = loc.split('-')
                starts.append(fwd)
                ends.append(rev)

            self.read_num   = int(m.group(1))
            self.chromosome = chromosome
            self.strand     = strand

            ab           = m.group(2)

            part = AlignmentPart(starts, ends, sequence)

            self.forward = None
            self.reverse = None
            self.joined  = None

            if   ab is 'a': self.forward = part
            elif ab is 'b': self.reverse = part
            else:           self.joined  = part

        else:
            self.read_num   = read_num
            self.chromosome = chromosome
            self.strand     = strand
            self.forward    = forward
            self.reverse    = reverse
            self.joined     = joined

    def is_mate(self, other):
        return (self.order == other.order and 
                ((self.is_forward and other.is_reverse) or
                 (self.is_reverse and other.is_forward)))

    def __str__(self):
        return str(self.__dict__)

    def __repr__(self):
        return repr(self.__dict__)

def read_coverage(cov_file):
    header = cov_file.next()
    footprint = 0
    for line in cov_file:
        (chromosome, start, end, cov) = line.split("\t")
        start = int(start)
        end   = int(end)
        footprint += end - start
    return footprint

def aln_iter(lines):
    alns = (Alignment(line=line) for line in lines)

    last = alns.next()

    for aln in alns:
        result = None
        if (last is None):
            last = aln
        elif (last.forward is not None and
              aln.reverse  is not None and
              last.read_num   == aln.read_num   and
              last.chromosome == aln.chromosome and
              last.strand     == aln.strand):
            yield Alignment(
                read_num   = last.read_num,
                chromosome = last.chromosome,
                strand     = last.strand,
                forward    = last.forward,
                reverse    = aln.reverse)
            last = None
        else:
            yield last
            last = aln

    if last is not None:
        yield last

def unique_stats(rum_unique, n):

    fwd_only = zeros(n + 1, dtype=bool)
    rev_only = zeros(n + 1, dtype=bool)
    joined   = zeros(n + 1, dtype=bool)
    unjoined = zeros(n + 1, dtype=bool)

    for aln in aln_iter(rum_unique):
        i = aln.read_num
        
        if aln.joined is not None:
            joined[i] = True
        else:
            fwd = aln.forward is not None
            rev = aln.reverse is not None
            if fwd and rev:
                unjoined[i] = True
            elif fwd:
                fwd_only[i] = True
            elif rev:
                rev_only[i] = True

    stats = {
        'fwd_only' : sum(fwd_only),
        'rev_only' : sum(rev_only),
        'joined'   : sum(joined),
        'unjoined' : sum(unjoined),

        }


    stats['consistent'] = stats['joined'] + stats['unjoined']
    stats['fwd'] = stats['fwd_only'] + stats['consistent']
    stats['rev'] = stats['rev_only'] + stats['consistent']

    stats['any'] = stats['fwd_only'] + stats['rev_only'] + stats['consistent']

    return add_percents(stats, n)

def nu_stats(rum_nu, n):

    fwd  = zeros(n + 1, dtype=bool)
    rev  = zeros(n + 1, dtype=bool)
    both = zeros(n + 1, dtype=bool)

    for aln in aln_iter(rum_nu):
        i = aln.read_num

        if aln.forward is not None:
            fwd[i] = True
        if aln.reverse is not None:
            rev[i] = True

        if (aln.joined is not None or
            (aln.forward is not None and
             aln.reverse is not None)):
            both[i] = True

    stats = {
        'fwd' : sum(fwd & ~(rev | both)),
        'rev' : sum(rev & ~(fwd | both)),
        'consistent' : sum(both)
        }

    stats['any'] = sum(fwd | rev | both)

    return add_percents(stats, n)

def add_percents(stats, n):
    result = {}

    for k in stats:
        result[k] = stats[k]
        result['pct_' + k] = float(stats[k]) * 100.0 / float(n)

    return result

def get_cov_stats(cov_unique, cov_nu, genome_size):
    cov_u = read_coverage(cov_unique)
    cov_nu = read_coverage(cov_nu)
    
    stats = add_percents({
        'cov_u' : cov_u,
        'cov_nu' : cov_nu
        }, genome_size)

    stats['genome_size'] = genome_size
    return stats

def main():

    parser = argparse.ArgumentParser()
    parser.add_argument('--rum-unique',  required=True, type=file)
    parser.add_argument('--rum-nu',      required=True, type=file)
    parser.add_argument('--cov-unique',  required=True, type=file)
    parser.add_argument('--cov-nu',      required=True, type=file)
    parser.add_argument('--max-seq',     required=True, type=int)
    parser.add_argument('--genome-size', required=True, type=int)

    args = parser.parse_args()

    ustats = unique_stats(args.rum_unique, args.max_seq)

    print """
UNIQUE MAPPERS

Both forward and reverse mapped consistently: %(consistent)d (%(pct_consistent).2f%%)
  - do overlap: %(joined)d (%(pct_joined).2f)
  - don't overlap: %(unjoined)d (%(pct_unjoined).2f)
Number of forward mapped only: %(fwd_only)d
Number of reverse mapped only: %(rev_only)d
Number of forward total: %(fwd)d (%(pct_fwd).2f)
Number of reverse total: %(rev)d (%(pct_rev).2f)
At least one of forward or reverse mapped: %(any)d (%(any).2f)
""" % ustats

    nustats = nu_stats(args.rum_nu, args.max_seq)

    print """
NON-UNIQUE MAPPERS
------------------
Total number forward only ambiguous: %(fwd)d (%(pct_fwd).2f%%)
Total number reverse only ambiguous: %(rev)d (%(pct_rev).2f%%)
Total number consistent ambiguous: %(consistent)d (%(pct_consistent).2f%%)
""" % nustats

    combined = {
        'fwd' : ustats['fwd'] + nustats['fwd'] + nustats['consistent'],
        'rev' : ustats['rev'] + nustats['rev'] + nustats['consistent'],
        'consistent' : ustats['consistent'] + nustats['consistent'],
        'any' : ( ustats['any'] +
                  nustats['fwd'] + nustats['rev'] + nustats['consistent'])

        }

    combined = add_percents(combined, args.max_seq)

    print """
TOTAL
-----
Total number forward: %(fwd)d (%(pct_fwd).2f%%)
Total number reverse: %(rev)d (%(pct_rev).2f%%)
Total number consistent: %(consistent)d (%(pct_consistent).2f%%)
At least one of forward or reverse mapped: %(any)d (%(pct_any).2f%%)
""" % combined


    cov = get_cov_stats(args.cov_unique, args.cov_nu, args.genome_size)

    print """
Genome size: {genome_size:,d}
Number of bases covered by unique mappers: {cov_u:,d} ({pct_cov_u:.2f}%)
Number of bases covered by non-unique mappers: {cov_nu:,d} ({pct_cov_nu:.2f}%)
""".format(**cov)




main()
