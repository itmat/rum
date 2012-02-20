Chromosome Comparison Recommendations
=====================================

cmpChrs is defined in several different places, and there are small differences between some of the definitions. I would like to create a master version of cmpChrs. Here is a list of changes I would recommend making in order to create a single definition of cmpChrs. 

Function Prototype
------------------

While using a function prototype for Perl subroutines is generally not recommended, I think it would be good in this case to define `cmpChrs` as

```perl
sub cmpChrs ($$) {
    ...
}
```

The `($$)` prototype forces Perl to pass the arguments in using `@_`, rather than just setting the `$a` and `$b` package global variables. This allows you to define a comparator function in one package and use it in another package.

Comparing 'm' chromosomes to roman numerals
-------------------------------------------

It looks like all of the scripts have some code that handles 'm' chromosomes differently from other roman numerals:

```perl
if($b2_c =~ /m$/ && $a2_c =~ /vi+/) {
    return 1;
}
if($a2_c =~ /m$/ && $b2_c =~ /vi+/) {
    return -1;
}
```

In addition to the above, `RUM_runner` and `covmerge` also have this:

```perl
if($b2_c =~ /chr([ivx]+)/ && ($a2_c =~ /chrm/)) {
    return -1;
}
if($a2_c =~ /chr([ivx]+)/ && ($b2_c =~ /chrm/)) {
    return 1;
}
```

I think this extra check is redundant and can be safely removed.

Sort Order
----------

`cmpChrs.merge_chr_counts.pl` sorts in the opposite order of all the other scripts.

```perl
($a2_c, $b2_c) = @_;
my $a2_c = lc($a2_c);
my $b2_c = lc($b2_c);
```

Rather than make a whole other function for sorting in the opposite direction, we could just use a little wrapper function:

```perl
sub cmpChrsReverse ($$) {
    return cmpChrs($_[1], $_[0]);
}
```

### 'finished1234'

`merge_chr_counts.pl` looks for a sentinel value "finished1234", which is always less than any other value.

```perl
if($a2_c eq 'finished1234') {
    return -1;
}
if($b2_c eq 'finished1234') {
    return 1;
}
```

I haven't looked into it enough to see what puts that value there or what it's used for, but it seems like it would be safe to just include that in the master cmpChrs for now.

Position-based sorting
----------------------

featurequant2geneprofiles.pl sorts primarily on the chromosome name and then on the range as a secondary key:

```perl
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
```

We could instead make a function that wraps cmpChrs and enhances it with this functionality, e.g.:


```perl
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
}
```
