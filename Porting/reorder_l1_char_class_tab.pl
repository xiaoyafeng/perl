# This program is used to help port Perl to a platform that uses a non-ASCII
# character set, by generating a l1_char_class_tab.h file suitable for the new
# platform by reordering the official l1_char_class_tab.h that comes with the
# distribution.  It requires a miniperl to have been compiled.
#
# To use, 
# 1.    copy the official l1_char_class_tab.h to a safe place, in case
#       something goes awry.
# 2.    Run this command (example using Linux shell syntax):
#           ./miniperl Porting/reorder_l1_char_class_tab.pl
# 3.    Assuming you got no messages, examine the output file
#           l1_char_class_tab.h.new.
#       Look for the entry with 'A" in it.  Suppose in your platform's native
#       character set the ordinal of 'A' is 193.  Then the entry for 'A"
#       should be at line 194 of the file (not 193, because of the 0th entry).
#       Similarly, look for '0' and 'a'.  If these aren't all correct,
#       something is horribly wrong, and you should seek help by sending email
#       to perl5-porters@perl.org.
# 4.    Replace l1_char_class_tab.h with l1_char_class_tab.h.new.
# 5.    Do a 'make'.
#
# Note that this will only work on the fresh l1_char_class_tab.h that comes
# with the distribution.  If something goes wrong, you must copy your saved
# version back before retrying.

# Note that this very deliberately doesn't use regular expressions

open my $input, "<", "l1_char_class_tab.h" or die "Couldn't open l1_char_class_tab.h for reading: $!";
open my $output, ">", "l1_char_class_tab.h.new" or die "Couldn't open l1_char_class_tab.h.new for writing: $!";

my @entries;
my $count = 0;

while (<$input>) {
    next unless index($_, "<<_CC_") >= 0;

    #print "$count : ", utf8::unicode_to_native($count), "\n";
    $entries[utf8::unicode_to_native($count)] = $_;
    $count++;
}

die "Should have found 256 entries; instead got $count" unless $count == 256;

close $input or die "Couldn't close input: $!";

print $output @entries or die "Couldn't print entries: $!";
close $output or die "Couldn't close output: $!";
