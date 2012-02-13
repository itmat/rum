Differences Between cmpChrs
===========================

Rum runner and covmerge have this:

    if($b2_c =~ /chr([ivx]+)/ && ($a2_c =~ /chrm/)) {
      return -1;
    }
    if($a2_c =~ /chr([ivx]+)/ && ($b2_c =~ /chrm/)) {
      return 1;
    }
    if($b2_c =~ /m$/ && $a2_c =~ /vi+/) {
      return 1;
    }
    if($a2_c =~ /m$/ && $b2_c =~ /vi+/) {
      return -1;
    }

get_inferred_internal_exons.pl, merge_sorted_rum_files.pl, and rum2quantifications have this:

    if($b2_c =~ /m$/ && $a2_c =~ /vi+/) {
      return 1;
    }
    if($a2_c =~ /m$/ && $b2_c =~ /vi+/) {
      return -1;
    }


featurequant2geneprofiles.pl  has this:

    $A2_c =~ /^(.*):(\d+)-(\d+)$/;
    $a2_c = $1;
    $startcoord_a = $2;
    $endcoord_a = $3;

    $B2_c =~ /^(.*):(\d+)-(\d+)$/;
    $b2_c = $1;
    $startcoord_b = $2;
    $endcoord_b = $3;

    if($a2_c eq $b2_c) {
        if($startcoord_a < $startcoord_b) {
            return 1;
        }
        if($startcoord_b < $startcoord_a) {
            return -1;
        }
        if($startcoord_a == $startcoord_b) {
            if($endcoord_a < $endcoord_b) {
                return 1;
            }
            if($endcoord_b < $endcoord_a) {
                return -1;
            }
            if($endcoord_a == $endcoord_b) {
                return 1;
            }
        }
    }


... snip ...


    if($b2_c =~ /m$/ && $a2_c =~ /vi+/) {
        return 1;
    }
    if($a2_c =~ /m$/ && $b2_c =~ /vi+/) {
        return -1;
    }
    
cmpChrs.merge_chr_counts.pl has this:

It sorts in the opposite order from all the other scripts:

     ($a2_c, $b2_c) = @_;
     my $a2_c = lc($a2_c);
     my $b2_c = lc($b2_c);
     
(all the other ones reverse $a and $b). 

It looks for a sentinel value 'finished1234', which is allways less than any other value.

    if($a2_c eq 'finished1234') {
        return -1;
    }
    if($b2_c eq 'finished1234') {
        return 1;
    }

... snip ...

    if($b2_c =~ /m$/ && $a2_c =~ /vi+/) {
        return 1;
    }
    if($a2_c =~ /m$/ && $b2_c =~ /vi+/) {
        return -1;
    }



By feature
==========


Comparing 'm' chromosomes to roman numerals
-------------------------------------------

It looks like all of the scripts have some code that handles 'm' chromosomes differently from other roman numerals:

    if($b2_c =~ /m$/ && $a2_c =~ /vi+/) {
      return 1;
    }
    if($a2_c =~ /m$/ && $b2_c =~ /vi+/) {
      return -1;
    }

In addition to the above, RUM_runner and covmerge also have this:

    if($b2_c =~ /chr([ivx]+)/ && ($a2_c =~ /chrm/)) {
      return -1;
    }
    if($a2_c =~ /chr([ivx]+)/ && ($b2_c =~ /chrm/)) {
      return 1;
    }

I think this extra check is redundant and can be safely removed.

Sort Order
----------
cmpChrs.merge_chr_counts.pl sorts in the opposite order of all the other scripts.

     ($a2_c, $b2_c) = @_;
     my $a2_c = lc($a2_c);
     my $b2_c = lc($b2_c);
     
Rather than make a whole other function for sorting in the opposite direction, we could just use a little wrapper function:

    sub cmpChrsReverse {
        my ($a, $b) = @_;
        return cmpChrs($b, $a);
    }

'finished1234'

It looks for a sentinel value 'finished1234', which is always less than any other value.

    if($a2_c eq 'finished1234') {
        return -1;
    }
    if($b2_c eq 'finished1234') {
        return 1;
    }

I haven't looked into it enough to see what puts that value there or what it's used for, but it seems like it would be safe to just include that in the master cmpChrs for now.

Position-based sorting
----------------------

featurequant2geneprofiles.pl sorts primarily on the chromosome name and then on the range as a secondary key:

    $A2_c =~ /^(.*):(\d+)-(\d+)$/;
    $a2_c = $1;
    $startcoord_a = $2;
    $endcoord_a = $3;

    $B2_c =~ /^(.*):(\d+)-(\d+)$/;
    $b2_c = $1;
    $startcoord_b = $2;
    $endcoord_b = $3;

    if($a2_c eq $b2_c) {
        if($startcoord_a < $startcoord_b) {
            return 1;
        }
        if($startcoord_b < $startcoord_a) {
            return -1;
        }
        if($startcoord_a == $startcoord_b) {
            if($endcoord_a < $endcoord_b) {
                return 1;
            }
            if($endcoord_b < $endcoord_a) {
                return -1;
            }
            if($endcoord_a == $endcoord_b) {
                return 1;
            }
        }
    }

We could instead make a function that wraps cmpChrs and enhances it with this functionality, e.g.:

    sub cmpChrsCoords {
    
        $A2_c = lc($b);
        $B2_c = lc($a);

        $A2_c =~ /^(.*):(\d+)-(\d+)$/;
        $a2_c = $1;
        $startcoord_a = $2;
        $endcoord_a = $3;

        $B2_c =~ /^(.*):(\d+)-(\d+)$/;
        $b2_c = $1;
        $startcoord_b = $2;
        $endcoord_b = $3;

        if ($a2_c ne $b2_c) {
            return cmpChrs($a, $b);
        }

        if($startcoord_a < $startcoord_b) {
            return 1;
        }
        if($startcoord_b < $startcoord_a) {
            return -1;
        }
        if($startcoord_a == $startcoord_b) {
            if($endcoord_a < $endcoord_b) {
                return 1;
            }
            if($endcoord_b < $endcoord_a) {
                return -1;
            }
            if($endcoord_a == $endcoord_b) {
                return 1;
            }
        }

     

