import sys

in_file_prefixes = ['t/data/shared/RUM_Unique',
                    't/data/shared/RUM_NU']

def parse_input(filename):
    with open(filename) as f:
        for line in f:
            (readid, chr_, spans, rest) = line.split("\t", 3)
                
            for span in spans.split(", "):
                (start, end) = [int(x) for x in span.split("-")]
                yield (chr_, start, end)

def rum_to_bed(data, out_filename):

    with open(out_filename, 'w') as out:
        out.write("track\tname=rum\tvisibility=3\tdescription=\"RUM Stuff\"\titemRGB=\"On\"")
        for (chr_, start, end) in data:
            out.write("{0}\t{1}\t{2}\n".format(chr_, start - 1, end))

def rum_to_separate_tab(data, out_filename):

    with open(out_filename, 'w') as out:
        out.write("chr\tstart\tend\n")
        for (chr_, start, end) in data:
            out.write("{0}\t{1}\t{2}\n".format(chr_, start - 1, end))

def rum_to_combined_tab(data, out_filename):

    with open(out_filename, 'w') as out:
        out.write("loc\n")
        for (chr_, start, end) in data:
            out.write("{0}:{1}-{2}\n".format(chr_, start - 1, end))


for prefix in in_file_prefixes:
    print "Working on " + prefix
    data = list(parse_input(prefix + '.sorted.1'))
    rum_to_bed(data, prefix + '.bed')
    rum_to_separate_tab(data,  prefix + '.separate.tab')
    rum_to_combined_tab(data, prefix + '.combined.tab')

