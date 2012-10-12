import numpy as np
import argparse
import re
import collections

readid_re = re.compile('seq.(\d+)([ab]?)')

class ChromosomeAlnCounter:
    """Accumulates counts of aligments by chromosome."""

    def __init__(self):
        """Create a new ChromosomeAlnCounter, with no arguments."""
        self.mapping = {}
        self.chromosomes = []

    def add_aln(self, chromosome):
        """Increment the count for the given chromosome."""
        if chromosome not in self.mapping:
            self.mapping[chromosome] = 0
            self.chromosomes.append(chromosome)
        self.mapping[chromosome] += 1

    def results(self):

        """Return the accumulated counts as a list of tuples.

        Each tuple is of the format (chromosome, count), and gives the
        count of alignments for a chromosome. There is one tuple for
        each chromosome, and they are returned in the order that the
        chromosomes were first seen.
        """

        return [ (c, self.mapping[c]) for c in self.chromosomes ]


class AlignmentPart:

    """Once part of an alignment. May represent a forward, reverse, or
    joined read."""

    def __init__(self, starts, ends, sequence):
        self.starts   = starts
        self.ends     = ends
        self.sequence = sequence

    def __str__(self):
        return str(self.__dict__)

    def __repr__(self):
        return 'AlignmentPart' + repr(self.__dict__)

class Alignment:

    """A RUM alignment.

    An Alignment contains enough information to identify a read and
    describe one mapping of the read to the genome. It contains the
    read number, the chromosome and strand it mapped to, and then one
    or two 'parts' (forward, reverse, and joined) which contain the
    coordinates and the actual sequence. The valid combinations of
    parts are:

      * forward: Alignment for the forward read only
      * reverse: Alignment for the reverse read only
      * joined: An overlapping alignment for the forward and reverse
                reads, which has been joined together.
      * forward and reverse: Non-overlapping alignment for both the
                forward and reverse read.

                """

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
                starts.append(int(fwd))
                ends.append(int(rev))

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

    def parts(self):
        parts = []
        if self.forward is not None: parts.append(forward)
        if self.reverse is not None: parts.append(reverse)
        if self.joined  is not None: parts.append(joined)
        return parts
    
    def __maybe_write_part(self, out, part, direction):
        if part is not None:
            locs = ""
            for i in range(len(part.starts)):
                if i > 0:
                    locs += ', '
                locs += '{:d}-{:d}'.format(part.starts[i], part.ends[i])
            if part is not None:
                out.write("seq.{:d}{:s}\t{:s}\t{:s}\t{:s}\t{:s}".format(
                        self.read_num, direction, self.chromosome, locs, self.strand, part.sequence))

    def write(self, out):
        self.__maybe_write_part(out, self.forward, 'a')
        self.__maybe_write_part(out, self.reverse, 'b')
        self.__maybe_write_part(out, self.joined, '')

    def __str__(self):
        return str(self.__dict__)

    def __repr__(self):
        return repr(self.__dict__)

def read_coverage(cov_file):
    """Determine the total number of bases covered.

    Reads in the given coverage file and computes the total number of
    bases covered, returning that value as an int.
    """
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

    print "Reading RUM_Unique"

    fwd_only = np.zeros(n + 1, dtype=bool)
    rev_only = np.zeros(n + 1, dtype=bool)
    joined   = np.zeros(n + 1, dtype=bool)
    unjoined = np.zeros(n + 1, dtype=bool)
    chr_counts = ChromosomeAlnCounter()

    counter = 0
    for aln in aln_iter(rum_unique):
        counter += 1
        if (counter % 100000) == 0:
            print "  {:d}".format(counter)
        chr_counts.add_aln(aln.chromosome)
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

    return (add_percents(stats, n), chr_counts.results())

def nu_stats(rum_nu, n):

    fwd  = np.zeros(n + 1, dtype=bool)
    rev  = np.zeros(n + 1, dtype=bool)
    both = np.zeros(n + 1, dtype=bool)

    chr_counts = ChromosomeAlnCounter()
    counter = 0
    for aln in aln_iter(rum_nu):
        counter += 1
        if (counter % 100000) == 0:
            print "  {:d}".format(counter)
        chr_counts.add_aln(aln.chromosome)
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

    return (add_percents(stats, n), chr_counts.results())

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

    (ustats, u_chr_counts) = unique_stats(args.rum_unique, args.max_seq)

    print """
UNIQUE MAPPERS
--------------

Both forward and reverse mapped consistently: %(consistent)d (%(pct_consistent).2f%%)
  - do overlap: %(joined)d (%(pct_joined).2f)
  - don't overlap: %(unjoined)d (%(pct_unjoined).2f)
Number of forward mapped only: %(fwd_only)d
Number of reverse mapped only: %(rev_only)d
Number of forward total: %(fwd)d (%(pct_fwd).2f)
Number of reverse total: %(rev)d (%(pct_rev).2f)
At least one of forward or reverse mapped: %(any)d (%(any).2f)
""" % ustats

    (nustats, nu_chr_counts) = nu_stats(args.rum_nu, args.max_seq)

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

    print """
RUM_Unique reads per chromosome
-------------------------------"""
    for (c, x) in u_chr_counts:
        print '{:10s} {:10d}'.format(c, x)

    print """
RUM_NU reads per chromosome
---------------------------"""
    for (c, x) in nu_chr_counts:
        print '{:10s} {:10d}'.format(c, x)

if __name__ == '__main__':
    main()
