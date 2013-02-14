package Diogenes::UnicodeInput;
use vars '%unicode_equivs', '%upper_to_lower';
# use encoding 'utf8';
# use utf8;
no bytes;

# do "unicode-equivs.pl" or die ($! or $@);
do "Diogenes/unicode-equivs.pl" or die ($! or $@);

sub new {
    my $self = {};
    bless $self;
    return $self;
}

sub IsMyGreekCopt {
    return <<END;
0001\t007F
0300\t036F
0370\t03FF
1F00\t1FFF
2C80\t2CFF
END
}    

sub unicode_pattern {
    my $self = shift;
    my $pat = shift;

    if ($pat =~ m/^\p{InBasicLatin}+$/) {
        # All ascii
        if (ref $self eq 'Diogenes::Search') {
            return $self->latin_pattern($pat);
        }
        else {
            return $pat;
        }
    }

    if (ref $self eq 'Diogenes::Indexed') {
        $pat = $self->unicode_greek_to_beta($pat);
        # No diacrits, for searching the word-list
        $pat =~ s/[^A-Z]//;
        return $pat;
    }
    elsif (ref $self eq 'Diogenes::Search') {
        $pat =~ s#\(#\x073#g;                           # protect parens
        $pat =~ s#\)#\x074#g;
        $pat = $self->unicode_greek_to_beta($pat);

        if ($pat =~ m/[\\\/=|]/) {
            # Accent(s) present, so significant 
            $pat = $self->make_strict_greek_pattern($pat);
        }
        else {
            $pat =~ s/\b([AEIOUHW]*)\)/\x071$1/g;               # mark where smooth breathing goes
            $pat =~ s/\b([AEIOUHW]*)\(/\x072$1/g;               # mark where rough breathing goes
            $pat = $self->make_loose_greek_pattern($pat);
        }
        return $pat;
    }
    else {
        # For Perseus, etc.
        $pat = $self->unicode_greek_to_beta($pat);
        $pat =~ tr /A-Z/a-z/;
        return $pat;
    }
    warn "Flow error!\n"
}

# Also works for Coptic
sub unicode_greek_to_beta {
    my $self = shift;
    my $pat = shift;

    unless ($pat =~ m/^\p{Diogenes::UnicodeInput::IsMyGreekCopt}*$/) {
        $pat =~ m/(^\P{Diogenes::UnicodeInput::IsMyGreekCopt})/;
        warn "WARNING: Character(s) of input $pat not understood! ($1)";
        return;
    }

    my $out = '';
    while ($pat =~ m/(\s*)(\p{L})(\p{Mn}*)(\s*)/g) {
        my $front_space = $1 || '';
        my $initial_char = $2;
        my $initial_diacrits = $3 || '';
        my $end_space = $4 || '';
        my ($char, $diacrits) = $self->decompose($initial_char, $initial_diacrits); 
        $char = $upper_to_lower{$char} if exists $upper_to_lower{$char};
        if (exists $unicode_to_beta{$char}) {
            $out .= $unicode_to_beta{$char};
        }
        else {
            warn "I don't know what to do with character $char";
            return;
        }
        my $temp = '';
        my @diacrits = split //, $diacrits;
        for my $d (@diacrits) {
            if (exists $unicode_to_beta{$d}) {
                $temp .= $unicode_to_beta{$d};
            }
            else {
                warn "I don't know what to do with diacritical mark $d";
                return;
            }
        }
        # Put the diacrits in the correct order
        for my $d qw{ ) ( / \ = | + } {
            my $r = quotemeta $d;
            $out .= $d if $temp =~ m/$r/; 
        }
        $out = $front_space.$out.$end_space;
    }
    return $out;
}

sub decompose {
    my ($self, $compound, $extra_diacrits) = @_;
    my $ret = $unicode_equivs{$compound};
    if (ref $ret) {
        return $self->decompose($ret->[0], ($ret->[1].$extra_diacrits));
    }
    elsif ($ret) {
        return $self->decompose($ret, $extra_diacrits);
    }
    else {
        return $compound, $extra_diacrits;
    }
}

%Diogenes::UnicodeInput::unicode_to_beta = (
    "\x{03B1}" => "A",
    "\x{03B2}" => "B",
    "\x{03B3}" => "G",
    "\x{03B4}" => "D",
    "\x{03B5}" => "E",
    "\x{03B6}" => "Z",
    "\x{03B7}" => "H",
    "\x{03B8}" => "Q",
    "\x{03B9}" => "I",
    "\x{03BA}" => "K",
    "\x{03BB}" => "L",
    "\x{03BC}" => "M",
    "\x{03BD}" => "N",
    "\x{03BE}" => "C",
    "\x{03BF}" => "O",
    "\x{03C0}" => "P",
    "\x{03C1}" => "R",
    "\x{03C2}" => "S",
    "\x{03C3}" => "S",
    "\x{03C4}" => "T",
    "\x{03C5}" => "U",
    "\x{03C6}" => "F",
    "\x{03C7}" => "X",
    "\x{03C8}" => "Y",
    "\x{03C9}" => "W",
    
    "\x{0300}" => "\\",
    "\x{0301}" => "/",
    "\x{0308}" => "+",
    "\x{0313}" => ")",
    "\x{0314}" => "(",
    "\x{0342}" => "=",
    "\x{0345}" => "|",

    "\x{03DC}" => "V", # digamma
    "\x{03DD}" => "V",
    
    # coptic (old block)
    "\x{03E3}" => "s",
    "\x{03E5}" => "f",
    "\x{03E9}" => "h",
    "\x{03EF}" => "t",
    "\x{03EB}" => "j",
    "\x{03ED}" => "g",

    # coptic (new unicode block)

    "\x{2C81}" => "A",
    "\x{2C83}" => "B",
    "\x{2C85}" => "G",
    "\x{2C87}" => "D",
    "\x{2C89}" => "E",
    "\x{2C8D}" => "Z",
    "\x{2CB7}" => "H",
    "\x{2C91}" => "Q",
    "\x{2C93}" => "I",
    "\x{2C95}" => "K",
    "\x{2C97}" => "L",
    "\x{2C99}" => "M",
    "\x{2C9B}" => "N",
    "\x{2C9D}" => "C",
    "\x{2C9F}" => "O",
    "\x{2CA1}" => "P",
    "\x{2CA3}" => "R",
    "\x{2CA5}" => "S",
    "\x{2CA7}" => "T",
    "\x{2CA9}" => "U",
    "\x{2CAB}" => "F",
    "\x{2CAD}" => "X",
    "\x{2CAF}" => "Y",
    "\x{2CB1}" => "W",

    # For the demotic letters, we use the old Greek and Coptic block
    
    );

1;
