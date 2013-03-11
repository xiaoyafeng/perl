# This program is used to help port Perl to a platform that uses a non-ASCII
# character set, by generating a charclass_invlists.h file suitable for the new
# platform.  It uses as its basis, the charclass_invlists.h that came with the
# distribution.  It requires a miniperl to have been compiled.
#
# To use:
# 1.    copy your charclass_invlists.h to a safe place in case something goes
#       awry.
# 2.    Run this command (example using Linux shell syntax):
#           ./miniperl Porting/reorder_charclass_invlists.pl
# 3.    Assuming you got no messages, examine the output file
#           charclass_invlists.h.new.
#       Comments in regcomp.c describe how inversion lists look.  You can
#       compare the new one with the old; they should have the same structure,
#       and the entries for Latin1_invlist and Above_Latin1_invlist should be
#       identical.  On an EBCDIC system, the body for PosixCntrl_invlist[]
#       should look like
#            4,
#            ...
#            0      /* offset */
#            64,
#            255,
#            256,
#            0
#         };
#
# 4.    Replace charclass_invlists.h with charclass_invlists.h.new.
# 5.    Do a 'make'.
#
# Note that this will only work on the fresh charclass_invlists.h that comes
# with the distribution.  If something goes wrong, you must copy your saved
# version back before retrying.
#
# The contents of the generated file are used in regular expressions which
# have [bracketed character classes] containing things like \s, \D, \w, or
# [:posix:].  This program very deliberately avoids these constructs.
#
# This works for each inversion list by populating a list of this platform's
# Latin1-range code points with a 1 if they are in that list; 0 if not, based
# on the input file's data.  Then a new inversion list is generated, and
# written

open my $input, "<", "charclass_invlists.h" or die "Couldn't open charclass_invlists.h for reading: $!";
open my $output, ">", "charclass_invlists.h.new" or die "Couldn't open charclass_invlists.h.new for writing: $!";

my @entries;
my $count = 0;

sub next_line
{   # Removes leading and trailing blanks, and comments, including multi-line
    # comments.  Also removes trailing commas, to get just the essence of the
    # line

    local $_ = <$input>;
    chomp;

    s/ ^ \s* //x;
    s! / \* .*? \* / $ !!gx;
    while (m! / \* !x) {    # Absorb multi-line comments
        $_ .= <$input>;
        s! / \* .*? \* / $ !!gx;
    }

    s/ ,? \s* $//x;

    return $_;
}

while (<$input>) {

    # Just pass through any line not part of an inversion list body
    print $output $_;

    next unless /static UV/;

    # Here, we have the beginning of an inversion list.  The next lines
    # comprise it, starting with header ones

    my $count = next_line;
    my $header1 = <$input>;   # iteration
    my $header2 = <$input>;   # previous search result

    my $version = next_line;
    die "Unexpected version '$version'" if $version != 290655244;

    my $offset = next_line;
    die "Unexpected offset '$offset'" if $offset != 0 && $offset != 1;

    my @bitmap = (0) x 256; # Initialize bit map to nothing in it
    my $are_we_in_list = 0; # Assume \0 isn't in the list
    my $range_start;
    my @above_latin1;

    # But if \0 is in the list, fix things up
    if ($offset == 0) {
        $range_start = 0;
        $are_we_in_list = 1;
    }

    # Read the inversion list proper
    while ($count > 0) {
        my $boundary = next_line;

        # Set the bits for all the translated code points in the range
        if ($are_we_in_list) {
            for my $i ($range_start .. $boundary - 1) {
                $bitmap[utf8::unicode_to_native($i)] = 1;
            }
        }
        else {
            $range_start = $boundary;
        }

        $count--;

        # Only range 0-255 are translated.  A 0 can also end the list
        # final entry
        if ($boundary == 0 || $boundary > 255) {
            push @above_latin1, $boundary if $boundary != 0;
            last;
        }

        $are_we_in_list = $are_we_in_list ^ 1;  # complement
    }

    # The rest of the inversion list comprises the non-translated above-Latin1
    # code points
    while ($count > 0) {
        push @above_latin1, next_line;
        $count--;
    }

    # Whether or not \0 is in the list
    $offset = $bitmap[0] ? 0 : 1;

    # Now construct the new inversion list from the bitmap.  An entry happens
    # only when the run of bits changes from a string of zeros to/from ones.
    my @invlist;
    for my $i (1 .. 255) {
        push @invlist, $i if $bitmap[$i] != $bitmap[$i-1];
    }

    # If the old and new values at 255 are the same, there's no issues from
    # old to new, but if they differ, we have to look more carefully to see
    # what comes after
    if ($are_we_in_list != $bitmap[255]) {

        # If the new [255] element is in the inversion list, and the old
        # one wasn't, it means that the first above-Latin1 value in the old
        # list marked the end of a range not matched by the list.  We have to
        # insert a [256] element to turn off the range that includes [255].
        #
        # But if instead, the new [255th] element is not in the inversion
        # list, but the old one was, the code points from 256 ..
        # the_next_value_on_the_list are matched by the inversion list, and we
        # need to add a [256] to turn on that range.  But only if there is
        # such a range -- if the list is empty after that point there's
        # nothing to turn it on for.

        # First, we get rid of any elements that are for [256] or any trailing
        # 0.  These will be added at various points below if necessary.
        while (@above_latin1 && ($above_latin1[0] == 256
                                 || $above_latin1[0] == 0))
        {
            shift @above_latin1;
        }
        push @invlist, 256 if $bitmap[255] || @above_latin1;
    }

    push @invlist, @above_latin1;

    # Add in a trailing 0 if the list starts at 0.
    push @invlist, 0 if ! $offset && $invlist[-1] != 0;

    # Print out new inversion list
    print $output "\t", scalar @invlist, ",\t/* Number of elements */\n";
    print $output $header1;
    print $output $header2;
    print $output "\t", $version, ",\t/* Version and data structure type */\n";
    print $output "\t", $offset, ",\t/* offset */\n";
    for my $i (0 .. @invlist - 2) {
        print $output "\t$invlist[$i],\n";
    }
    print $output "\t$invlist[@invlist-1]\n";
} # Continue with next

close $input or die "Couldn't close input: $!";
close $output or die "Couldn't close output: $!";
