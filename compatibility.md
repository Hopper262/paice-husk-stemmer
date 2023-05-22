# Compatibility of Lancaster stemmer implementations

While the Lancaster stemmer was presented on its official site as a single algorithm with multiple implementations, it is more accurately seen as a family of rules and quirks, both deliberate and accidental, with no single authoritative standard. The published implementations disagree on up to 8% of a test corpus of words, and the original paper does not fully capture the details of any individual implementation. The reasons for these discrepancies are collected here.

## Background

The “Lancaster stemmer” was first published in the 1990 paper [Another stemmer](https://doi.org/10.1145/101306.101310) by Chris D. Paice of Lancaster University, where it was dubbed the Paice/Husk stemmer. The paper included a text description of the algorithm, and a full computer-readable ruleset. Ultimately, four implementations in different languages were published on the [Lancaster University site (archived)](https://web.archive.org/web/20060819173645/http://www.comp.lancs.ac.uk/computing/research/stemming/Links/implementations.htm):

* Pascal (undated, but presumably a version of the Pascal code “routinely used at Lancaster University for several years” mentioned in the paper)
* C (developed December 1994)
* Perl (developed August 2000) - ported from the C version
* Java (developed September 2000) - ported from the Pascal version

Neither the site nor the individual downloads mention any deliberate changes to the algorithm or rules. However, there are notable differences in both of these, which affect stemming quality and compatibility.

## Ruleset differences

### Version 1

The rules file included in the Pascal and Java implementations is identical to the 1990 paper. This uses a fairly terse format, with suffixes stored in reverse order, and special characters for flags and continuation options. Comments are also included, to ease human reading of the file.

### Version 2

The C and Perl implementations use a different comma-separated format for encoding the rules. One rule which affects stemming was replaced:

* Version 1: ( protect -s ) `s0.` or `s,?,protect`
* Version 2: ( -s > - ) `s1.` or `s,?,stop`

## Algorithm differences

The four implementations mentioned above were tested with ruleset version 2 and a list of 274,937 words from [an-array-of-english-words](https://github.com/words/an-array-of-english-words). Each word contains only lowercase letters; differences in handling punctuation, digits, etc. were not tested. The Pascal and C implementations were also adjusted to accept word sizes longer than 24 characters, so the full list could be tested. Where applicable, programs were freshly compiled from source instead of using provided binaries.

The Pascal and Java outputs agreed exactly. The C output differed on 16,525 words. The Perl output differed from the C output on 7,247 words, and from the Pascal output on 22,165 words.

### Acceptability conditions

In the paper, a rule is not applied unless the resulting stem meets two conditions:

1. If the first character is a vowel, it must be at least two characters long.
2. If the first character is a consonant, it must be at least three characters long, and include a vowel or ‘y’.

The Pascal and Java implementations do not count a leading ‘y’ toward the rule 2 requirement. The stem “ycl” is not acceptable, but “ywy” is acceptable.

The C and Perl implementations use different conditions:

1. If the first character is a vowel or ‘y’, and the second character is not a vowel or ‘y’, it must be at least two characters long.
2. Otherwise, it must be at least four characters long.

The comments preceding the C function describe conditions which do not match any implementation:

1. If the first character is a vowel, it must be at least two characters long, and contain a consonant.
2. If the first character is a consonant, it must be at least three characters long, and include a vowel or ‘y’.

### Skipping of acceptability conditions

In the C implementation, if a rule under consideration does not have the continue flag set, the acceptability conditions are not checked and the resulting stem is always used. This may result in the final stem being an empty string.

### Premature exit of rule loop

In the C and Perl implementations, if a rule can be applied but the resulting-stem acceptability conditions are not met, rule processing is terminated instead of continuing to the next rule. When stemming the word “implement”, if a rule `ment,?,continue` were rejected, a subsequent rule `ent,?,continue` would never be considered.

### Starting word conditions

The Pascal and Java implementations refuse to stem words of 3 or fewer letters. They also refuse to stem words which do not contain a vowel.

The C and Perl implementations refuse to stem words which do not meet the acceptability conditions used to check potential stemming results. This means some 2-letter and 3-letter words are processed.

### Rule matching at first vowel

The Pascal and Java implementations will reject stemming rules which match too close to the beginning of the word. This is based on the position of the first vowel, or the first ‘y’ if not at the start of the word, whichever is closer.

If the rule ending (the portion to match) is two letters or more, it is rejected if the match overlaps with the first vowel. The rejection occurs even if the vowel is retained by the substitution rule.

If a 1-letter rule matches against the first vowel, it is allowed to apply as long as the result passes the acceptability conditions. (It is unclear whether this behavior was intentionally coded.) In this case, the code does not re-calculate the position of the first vowel, but none of the provided rules would result in a position change.

The C and Perl implementations do not include this check. For instance, when processing the word “ropy”, the rule ( -opy > -op ) would be rejected by the Pascal implementation but applied in the C implementation.

### Prefix removal

The Java implementation has an optional, off-by-default step to remove a small, hardcoded list of prefixes including “kilo” and “milli” from input words before stemming.

## Conclusion

While the original paper describes the Lancaster stemmer as “easy to implement”, and the algorithm oulined appears straightforward, the published implementations include many more details and subtle behaviors than an initial reading suggests. This leaves a definitive, interoperable specification out of reach. Choosing a set of behaviors for optimal stemming is a task left to future implementers.