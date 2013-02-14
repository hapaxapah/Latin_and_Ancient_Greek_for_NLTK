#!/usr/bin/perl -w
use strict;

open my $in, "</home/pj/Unicode/UnicodeData.txt" or die $!;
open my $out, ">unicode-equivs.pl" or die $!;
print $out "# This is an auto-generated file.  Do not edit.\n\n";
print $out "%Diogenes::UnicodeInput::unicode_equivs = (\n";

my @case;
while (<$in>) {
    my @f = split ";";
    next unless $f[1] =~ m/^GREEK|COPTIC/;
    next unless $f[1] =~ m/LETTER/;
    next if $f[1] =~ m/VRACHY|MACRON/;
    next if $f[5] =~ m/<sub>|<super>/;

    if ($f[1] =~ m/CAPITAL/) {
        if ($f[13] =~ m/([0-9A-F]+)/) {
            push @case, q("\x{).$f[0].q(}" => "\x{).$1.q(}", )."\n";
        }
    }

    next if $f[5] eq '';
    if ($f[5] =~ m/^([0-9A-F]+)$/) {
        print $out q("\x{).$f[0].q(}" => "\x{).$1.q(}", )."\n";
        next;
    }
    elsif ($f[5] =~ m/^([0-9A-F]+) ([0-9A-F]+)$/) {
        print $out q("\x{).$f[0].q(}" => ["\x{).$1.q(}", "\x{).$2.q(}"], )."\n";
    }
    else {
        die "What is ->$f[5]<- ($f[0])?";
    }
}

print $out ");

";

print $out "%Diogenes::UnicodeInput::upper_to_lower = (\n";
print $out $_ for @case;
print $out ");

1;
";

close $in or die $!;
close $out or die $!;

