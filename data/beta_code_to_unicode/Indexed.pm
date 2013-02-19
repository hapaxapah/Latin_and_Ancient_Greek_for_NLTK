##############################################
#--------------------------------------------#
#-------TLG Indexed (Word List) Search-------#
#--------------------------------------------#
##############################################

package Diogenes::Indexed;
use Diogenes::Base qw(%work %author %last_work %work_start_block);
@Diogenes::Indexed::ISA = ('Diogenes::Search');

my ($tlgwlinx, $tlgwlist, $tlgwcinx, $tlgwcnts, $tlgawlst) =
    ('tlgwlinx.inx', 'tlgwlist.inx', 'tlgwcinx.inx', 
     'tlgwcnts.inx', 'tlgawlst.inx');

# The constructor is inherited.

sub read_index 
{
    my $self = shift;
    my $pattern = shift;
    # Evidently some like to mount their CD-Roms in uppercase
    if ($self->{uppercase_files})
    {
        $tlgwlinx = uc $tlgwlinx;
        $tlgwlist = uc $tlgwlist;
        $tlgwcinx = uc $tlgwcinx;
        $tlgwcnts = uc $tlgwcnts;
        $tlgawlst = uc $tlgawlst;
    }

    $pattern = $self->{input_encoding} eq 'Unicode' ? $self->unicode_pattern($pattern) :
        $self->simple_latin_to_beta ($pattern);

    my ($ref, @wlist) = $self->parse_word_list($pattern);
    
    if ($self->{filtered} or $self->{blacklist_file})
    {
        # If we are selecting texts, find out what words are in our texts.
        $self->parse_wcnts(@wlist);
        my @new_wlist;
        # Keep Greek alphabetical order.
        map {$self->{found_word}{$_} and push @new_wlist, $_} @wlist;
        $ref = $self->{word_total};
        @wlist = @new_wlist;
    }
    
    return $ref, @wlist;
}

# Override base class method
sub do_search 
{
    my $self = shift;
    
    $self->{pattern_list} = [];

    $self->{reject_pattern} = ($self->{input_encoding} eq 'Unicode') ?
        $self->unicode_pattern($self->{reject_pattern}) :
        $self->make_greek_pattern_from_translit($self->{reject_pattern});

    print STDERR "Using reject pattern: $self->{reject_pattern}\n" if $self->{debug}
                                                         and $self->{reject_pattern};
    my @wlist = @_;
    $self->parse_wcnts(@wlist);
    $self->make_big_regexp;
    
    $self->begin_boilerplate;
    $self->do_word_search;
    $self->print_wlist_report;
    $self->end_boilerplate;
}

###############################################################################
#-----------------------------------------------------------------------------#
#---------------- Only private subs and methods below ------------------------#
#-----------------------------------------------------------------------------#
###############################################################################

###############################################################################
#                                                                             #
# Subroutine to calculate which blocks of the file tlgwlist.inx to            #
# search in, based upon the first two letters of the pattern (not counting    #
# diacritics, except for "'").  Eg. for the two letters AB, the first block   #
# to look in is the one indexed for AB, and the last is the one indexed AG.   #
# This leads to a certain amount of unneccessary searching, but it allows     #
# us to apply our regexp to a limited section of the large word list file.    #       
#                                                                             #
###############################################################################
sub parse_wlinx 
{
    my $self = shift;
        
    my ($pb_offset, $block);
    my ($pa_block, $pb_block) = (0, 0);
        
    # the order of the Greek alphabet in terms of its Roman representation in
    # BETA code ("'" is 1, who knows why?).
    my @gk = (2, 3, 16, 5, 6, 23, 4, 9, 11, 0, 12, 13, 14, 15, 17, 18, 10, 19, 20,
              21, 22, 7, 26, 24, 25, 8);                      
                        
    # A hash of the  Greek alphabet, each letter pointing to the next.
    my %incr = ('\'', 'A', 'A', 'B', 'B', 'G', 'G', 'D', 'D', 'E', 'E', 'Z', 'Z', 'H',
                'H', 'Q', 'Q', 'I', 'I', 'K', 'K', 'L', 'L', 'M', 'M',
                'N', 'N', 'C', 'C', 'O', 'O', 'P', 'P', 'R', 'R', 'S', 'S', 'T', 'T', 'U',
                'U', 'F', 'F', 'X', 'X', 'Y', 'Y', 'W', 'W', '\'');
        
    # get pattern, which should not include diacritics in its first two
    # letters, and make sure it is uppercase
    my $pattern = shift;
    # This input  must be at least 2 letters long 
    # (the index is indexed by the first 2 letters).
    $pattern =~ tr/a-z/A-Z/;
    die "Input pattern is not long enough (must be at least 2 letters).\n" 
        if $pattern =~ tr/A-Z'/A-Z'/ < 2;
    $pattern =~ tr/A-Z'//cd;
    print STDERR "pattern: $pattern\n" if $self->{debug};
    
    # @pa holds the first two letters of $pattern
    my @pa = (substr ($pattern, 0, 1), substr ($pattern, 1, 1));
        
    # generate starting offset
    my $pa_offset = ((($pa[0] eq '\'') ? 1 : $gk[(ord($pa[0]) - 65)]) - 1) * 27;
    $pa_offset += (ord($pa[1]) eq '\'') ? 1 : ($gk[(ord($pa[1]) - 65)]) + 1;

    # open the index to the word index and get the whole thing
    open WLINX, $self->{cdrom_dir}."$tlgwlinx" or 
        $self->barf("Could not open $self->{cdrom_dir}$tlgwlinx");
    binmode WLINX;
    local $/;
    undef $/;
    my $buf = <WLINX>;
    close WLINX or $self->barf("Couldn't close $tlgwlinx");

    # add up the cumulative data in the index to get block numbers for the
    # starting block.
    for (my $i = 0; $i < $pa_offset; $i++) 
    {
        $pa_block += ord (substr($buf, $i, 1));
    }
        
    # @pb gets the two letters in Greek alphabetical sequence after @pa 
    my @pb = @pa;

    # For some reason, degenerate cases in which one has impossible combinations 
    # of letters do not properly index to their imaginary place in the list.
    # Thus QH has many words, but QQ begins in the same block (681) as QH and
    # not where it should, which is in the block where QI starts -- where QQ
    # *would* be if there were any words that began with theta-theta.
    # So we have to keep incrementing letters until we find one that points to
    # a different block than the first set of letters.  This is wasteful and I
    # would regard it as a bug in the TLG index.
    while ($pb_block <= $pa_block) 
    {
        # `increment' the two letter string
        if ($pb[0] eq 'W' and $pb[1] eq 'W') 
        {   # end -- WW is the last two-letter group in the Greek alphabet
            last;
        }
        elsif ($pb[1] eq 'W') 
        {                               
            $pb[0] = $incr{$pb[0]};                 # eg. BW -> GA
            $pb[1] = 'A';                                           
        } 
        else 
        { 
            $pb[1] = $incr{$pb[1]};                 # the usual case: BB -> BG
        }
        
        # generate finishing offset
        $pb_offset = ((($pb[0] eq '\'') ? 1 : $gk[(ord($pb[0]) - 65)]) - 1) * 27;
        $pb_offset += (ord($pb[1]) eq '\'') ? 1 : ($gk[(ord($pb[1]) - 65)]) + 1;
        
        # add up the cumulative data in the index to get block numbers
        for (my $i = 0; $i < $pb_offset; $i++) 
        {
            $pb_block += ord (substr($buf, $i, 1));
        }
    }
    
    # return the starting and ending blocks between which to search
    print STDERR "@pa : @pb ;  $pa_block : $pb_block       \n" if $self->{debug};
    return ($pa_block, $pb_block);
}

#######################################################
#                                                     #
# Method to search the greek word-list for a pattern. #
#                                                     #
#######################################################
sub parse_word_list 
{       
    my $self = shift;
    my $pattern = shift;
    
    my ($buf, $block, $data, $word, $word_hits, $last_pos, $word_num);
    my ($before, $tally, $i);
    my (%words, @word_list);
    
    # get the parts of the file to search
    print STDERR "1>$pattern \n" if $self->{debug};
    
    # modify pattern to match diacritics before and after each letter
    $pattern =~ tr/a-z/A-Z/;
    my $original_pattern = $pattern;
    $pattern =~ s#([A-Z][\\\\\)\(]*)#$1\[\'\\\\\/\+\(\)\|\!\=\]\*#g;
    #$pattern =~ s#^#\['!]\*#g;
        
    print STDERR "2>$pattern \n" if $self->{debug};

    my $start_pat = 0;
    # h looks ahead for a rough breathing 
    $start_pat++ if $pattern =~ s#\x072#(?=\\\(|[AEHIOWU/\\\\)=+?!|']+\\\()#gi;
    # non-rough breathing (possibly not at word beginning) 
    $pattern =~ s#\x071#(?!\\\(|[AEHIOWU/\\\\)=+?!|']+\\\()#gi;                
    $start_pat++ if $pattern =~ s#^\s+#(?<!['!A-Z)(/\\\\+=])#;
    $pattern =~ s#^#\['!A-Z)(/\\\\+=]\*#g unless $start_pat;
    $pattern =~ s#\s+$#(?!['!A-Z)(/\\\\+=])#;
        
    print STDERR "3>$pattern ($start_pat)\n" if $self->{debug};
        
    my ($start_block, $end_block);
    open WLIST, $self->{cdrom_dir}."$tlgwlist"
        or die("Couldn't open $self->{cdrom_dir}$tlgwlist: $!");
    binmode WLIST;
    if ($self->{use_tlgwlinx})
    {   # Use the index to the word list, only looking at the bit of the word-list 
        # containing the first two letters of our word.
        ($start_block, $end_block) = $self->parse_wlinx($original_pattern);
        seek WLIST, ($start_block * 8192), 0 or $self->barf("Couldn't seek in $tlgwlist");
    }
    else
    {   # Just read in the whole thing
        $start_block = 0;
        $end_block = (-s WLIST) / 8192 + 1;
    }
    print STDERR "WL: $pattern \n" if $self->{debug};
    $tally = 0;
    for ($block = $start_block; $block <= $end_block; $block++) 
    {
        # read each block
        # Must not check for errors here, because often end-block is way
        # beyond the end of the file. -- Not sure why.
        read WLIST, $buf, 8192;
        $last_pos = 0;
        $word_num = 0;
                
        # look for the pattern, capturing it and the non-ascii count data
        # preceding it
        while ($buf =~ m#([\x80-\xff]+)($pattern[\x20-\x60\x7c]*)#g) 
        {
            $data = $1;
            $word = $2; 
            $tally++;
                        
#            print "block: ".(sprintf "%lx", $block)."\n";
#            print "pos: " . (sprintf "%lx", pos $buf) . "\n";
            # parse the non-ascii data
            for ($i = 0, $word_hits = 0; $i < length ($data); $i++) 
            {
#                print "data: ".(ord (substr($data, $i, 1))-128)."\n";
#                print "old: ".($word_hits << 7)."\n";
                $word_hits = ($word_hits << 7) + (ord (substr($data, $i, 1)) - 128);
#                print "hits: $word_hits\n";
            }
            print STDERR "$word: $word_hits\n\n" if $self->{debug};
                        
            # count the number of words between this and the previous hit (or
            # start of block to determine the word number within this block
            
            $before = substr ($buf, $last_pos, ((pos $buf) - $last_pos));
            $word_num++ while ($before =~ m#[\x80-\xff]+#go);
                        
            # store the important data: the word found, the count data, the
            # block in was found in and the number within that block
            push @word_list, $word;
            $words{$word} = $word_hits;
            push @{ $self->{word_list}{$word} }, ($word_hits, $block, $word_num);
            $last_pos = pos $buf;
        }
    }
    close WLIST or $self->barf("Couldn't close $tlgwlist");
        
    return \%words, @word_list;
}       

sub get_word_info 
{
    my ($self, $word) = @_;
    return @{ $self->{word_list}{$word} };
}

##########################################################################
#                                                                        #
# Method to calculate the authors and works in which a word found in the #
# word list is to be located.                                            #
#                                                                        #
##########################################################################
sub parse_wcnts 
{
    my $self = shift;
    my ($word, $first_byte, $serial_num, $next_byte, $word_count, $aw_data);
    my ($offset, $first_char, $second_char, $third_char, $junk, $entry_length);
    my ($total_count, $block_num, $word_num, $author_num, $work_num, $length);
    my ($entry, $buf ,$i);
    $self->{list_total} = 0;

    # get the words to use 
    my @words;
    if (@_ == 1 or not ref $_[0])
    {
        # A simple list of words
        map { warn ("Bad input in word list: $_") if ref $_ } @_[1 .. -1];
        $self->{check_word_stats} = 1;
        push @words, ref $_[0] ? @{ $_[0] } : @_;
        $self->{word_set}[0] = [@words];
        $self->{single_list} = 1;
    }
    else
    {
        # A list of lists of words
        $self->{single_list} = 0;
        my $j = 0;
        foreach my $x (@_)
        {
            next unless $x;
            warn ("Bad input in word list: $x") if ref $x and ref $x ne 'ARRAY';
            $self->{check_word_stats} = 0;
            # A simple word becomes a one-element list
            $x = [$x] unless ref $x;
            $self->{word_set}[$j++] = $x;
            push @words, @{ $x };
        }
        print STDERR "<p>Words: @{$self->{word_set}[0]}<p>\n" if $self->{debug};
        print STDERR "<p>Words: @{$self->{word_set}[1]}<p>\n" if $self->{debug};
        
    }
    $self->{check_word_stats} = 0 if $self->{reject_pattern};
    
    $self->{min_matches_int} = $self->{min_matches};
    $self->{min_matches_int} = 1 if $self->{min_matches} eq 'any';
    $self->{min_matches_int} =  scalar @{ $self->{word_set} } if 
        $self->{min_matches} eq 'all';

    print STDERR "MM: $self->{min_matches}\n" if $self->{debug};
    print STDERR "MMI: $self->{min_matches_int}\n" if $self->{debug};
    
    print STDERR Data::Dumper->Dump([$self->{word_set}]), "\n" if $self->{debug};  
    # open the index files
    open WCINX, $self->{cdrom_dir}."$tlgwcinx" or $self->barf("Couldn't open $tlgwcinx");
    binmode WCINX;
    open WCNTS, $self->{cdrom_dir}."$tlgwcnts" or $self->barf("Couldn't open $tlgwcnts");
    binmode WCNTS;
    open AWLST, $self->{cdrom_dir}."$tlgawlst" or $self->barf("Couldn't open $tlgawlst");
    binmode AWLST;
    
    # We may want to blacklist some authors
    my $blacklist = '';
    if ($self->{blacklist_file})
    {
        open BL, "<$self->{blacklist_file}" or 
            die "Couldn't open blacklist file: $self->{blacklist_file}: $!\n";
        {
            local $/;
            undef $/;
            $blacklist = <BL>;
        }
    }
    
    my ($current_block, $current_word_num) = (-1, -1);
    # iterate through the list
    foreach $word (@words) 
    {
        # get the info for this word
        ($total_count, $block_num, $word_num) = @{ $self->{word_list}{$word} };
        
        # Skip if we already have the info stored.
        next if $self->{found_word}{$word};
        return if $Diogenes_Daemon::flag and not print ("\0");
        
        # An important optimization is to check to see if this is the next word in the
        # current block, in which case, we just read the next record.  If you feed back
        # the words to this routine in the same order in which they were output, this will
        # generally be the case.  If not, we have to reseek to the start of the block and 
        # reparse the file up to the word number.
        
        print STDERR ">> $block_num: $word_num ($word)\n" if $self->{debug};
        print STDERR "|| $current_block: $current_word_num\n\n" if $self->{debug};
        unless ($block_num == $current_block and $word_num == $current_word_num + 1)
        {
            # get the offset data (based on the block number in the word list)
            seek WCINX, ($block_num * 4), 0 or $self->barf("Couldn't seek in $tlgwcinx");
            read WCINX, $offset, 4 or $self->barf("Couldn't read from $tlgwcinx");
            
            # the offset data (32 bits) is big-endian 
            $offset = unpack "N", $offset;
            
            # seek in the big nasty file with all the data to the offset for our
            # block
            seek WCNTS, $offset, 0 or $self->barf("Couldn't seek in $tlgwcnts");
            $current_block = $block_num;
            
            # we now must read every entry in this section of the file (the only one
            # which is not itself broken into 8k blocks, unfortunately) beacuse the
            # entries are of variable length and apparently are not indexed, until we 
            # come to our word
            
        
            for ($i = 1; $i < $word_num; $i++) 
            {
#                 print STDERR "] $offset: $i ($word)\n" if $self->{debug};
                # ignore `word form byte' (whatever that is)
                read WCNTS, $junk, 1 or $self->barf("Couldn't read from $tlgwcnts");
                
                # the next byte(s) give the length of this entry (which we want to
                # skip)
                read WCNTS, $length, 1 or $self->barf("Couldn't read from $tlgwcnts");
                $entry_length = ord ($length); 
                if ($entry_length & hex("80")) 
                {
                    read WCNTS, $next_byte, 1 or 
                        $self->barf("Couldn't read from $tlgwcnts");
                    $entry_length = (($entry_length & hex("7f")) << 8 ) + 
                        ord ($next_byte);
                }
                                
                # now we seek past the rest of this entry
                seek WCNTS, $entry_length, 1 or 
                    $self->barf("Couldn't seek through $tlgwcnts");
            }
        }
        $current_word_num = $word_num;
        $self->{word_total}{$word} = 0;
        
        # We should now be at the entry we are interested in
                
        # ignore `word form byte'
        read WCNTS, $junk, 1 or $self->barf("Couldn't read from $tlgwcnts"); 
        # the next byte(s) give the length of our entry 
        read WCNTS, $length, 1 or $self->barf("Couldn't read from $tlgwcnts");
        $entry_length = ord ($length);
        if ($entry_length & hex("80")) 
        {
            read WCNTS, $next_byte, 1 or $self->barf("Couldn't read from $tlgwcnts");
            $entry_length = (($entry_length & hex("7f")) << 8 ) + 
                ord ($next_byte);
        }
        # read the rest of the entry into $buf and close the file
        read WCNTS, $buf, $entry_length or $self->barf("Couldn't read from $tlgwcnts");
                
        # go back to the start of the index of authors and works
        seek AWLST, 0, 0 or $self->barf("Couldn't seek to the start of $tlgawlst");
        
        my $entry = 0;          # An index for the entries in the author/work file.
        my $running_count = 0;  # We add the number of hits reported for each work
        # and compare this total against the total
        # reported in the word list. 
        my $i = -1;                             # This is an index into $buf
      ENTRY:  
        while ($i < $entry_length - 1) 
        {
            # first we get a serial code number which is a pointer to a (cumulative)
            # offset within another file (tlgawlst.inx) that encodes the author/work
            # combinations 
                        
            $first_byte = substr ($buf, ++$i, 1);
            $serial_num = ord ($first_byte);
            if ($serial_num & hex("80")) 
            {
                $next_byte = substr ($buf, ++$i, 1);
                $serial_num = (($serial_num & hex("7c")) << 6 ) + ord ($next_byte);
            }
            else 
            {
                $serial_num = $serial_num >> 2;
            }
            
            # now we get the number of times our word is found in the
            # author/work combination under present consideration
                        
            $word_count = ord ($first_byte) & hex("03");
            if ($word_count == 0) 
            {
                $word_count = substr ($buf, ++$i, 1);
                $word_count = ord ($word_count);
                if  ($word_count & hex("80")) 
                {
                    $next_byte = substr ($buf, ++$i, 1);
                    $word_count = (($word_count - hex("80")) << 8 ) + 
                        ord ($next_byte);
                }
                elsif ($word_count == 0) 
                {
                    $word_count = substr ($buf, ++$i, 1);
                    $next_byte = substr ($buf, ++$i, 1);
                    $word_count = ((ord ($word_count)) << 8) + ord ($next_byte);
                }
            }
            
                
            # the serial numbers begin from 1, not 0.  If the serial num is 1,
            # then it indicates the next work of this author -- we want that
            # to go to 0, so that we don't seek forward and skip anything at all, 
            # and the next read will just get the next 3 bytes in tlgawlst.inx.
            $serial_num = $serial_num - 1;
            print STDERR "Serial Num: $serial_num; " if $self->{debug};
            
            # each record in tlgawlst.inx, the file containing a sequential list
            # of the codes for each author/work combination in the TLG is three 
            # bytes long
            $offset = (3 * $serial_num);
            
            # the offset is cumulative; we go forward in the file relative to the
            # last author/work combination in which our word was found
            seek AWLST, $offset, 1 or $self->barf("Couldn't seek in $tlgawlst");
            read AWLST, $aw_data, 3 or $self->barf("Couldn't read from $tlgawlst");
                        
            # decode the three bytes to yield the author number, work number and
            # the number of times our word is found within that work.
            # The first byte gives the more significant bits ( > 6) of the author number;
            # the second byte contains the lower six bits of the author
            # number, and its two low bits are the more significant bits 
            # of the work number, whose low byte is the third byte.
            $first_char = ord (substr ($aw_data, 0, 1));
            $second_char = ord (substr ($aw_data, 1, 1));
            $third_char = ord (substr ($aw_data, 2, 1));
            $author_num = ($first_char << 6) + ($second_char >> 2);
            $work_num = (($second_char & hex("03")) << 8) + $third_char;
            
            $author_num = sprintf '%04d', $author_num;
            $work_num = sprintf '%03d', $work_num;
            
            print STDERR "Auth: $author_num; Work: $work_num; Word: $word; Word count: $word_count\n" if $self->{debug};
                
            # keep a running total, to make sure that we find all of the instances
            # that we should.
            $running_count += $word_count;
            $entry++;
            
            # Skip if we are selecting texts and this one was not chosen.
            next ENTRY if $self->{filtered} and 
                not ($self->{req_authors}{$author_num} 
                     or $self->{req_auth_wk}{$author_num}{$work_num} );
            if ($blacklist)
            {
                if ($blacklist =~ m/$self->{tlg_file_prefix}$author_num/i)
                {
                    print STDERR "Skipping blacklisted author: $author_num\n" if 
                        $self->{debug};
                    next ENTRY;
                }
            }
                        
            $self->{word_counts}{$author_num}{$work_num}{$word} = $word_count;
            $self->{word_total}{$word} += $word_count;
            $self->{found_word}{$word} = 1;
            # using this for testing ...
            $self->{temp_var}{$word}{$author_num} = 1;
        }
        if ($running_count != $total_count) 
        {
            # if the totals don't jibe, halt
            if ($word eq 'KAI/')
            {
                warn("\nWord-list totals don't agree for $word: this is a known error.\n");
            }
            else
            {
                warn( 
#                       $self->barf( 
"\n\n#########################################################################\n".
"ERROR: For the word $word ". 
"The total count in the word list is $total_count, ".
"but I only see $running_count in $tlgwcnts.\n\n".
"Please send a copy of ".
"this error message to the author of the program.\n".
"Diogenes version ($Diogenes::Base::Version).".
"\n#########################################################################\n\n");
            }
        }
    } # end of the iteration for each word
    continue
    {
        # Add the total of words selected form list
        $self->{list_total}     += $self->{word_total}{$word};
    }

    close AWLST or $self->barf("Couldn't close $tlgawlst");
    close WCNTS or $self->barf("Couldn't close $tlgwcnts");
    close WCINX or $self->barf("Couldn't close $tlgwcinx");
        
#     print STDERR Data::Dumper->Dump([$self->{word_counts}], ['word_counts']) if $self->{debug};
    # return the number of works in which the word was found (went one too
    # far)
    return --$entry;
}

sub make_big_regexp
{
    my $self = shift;
    # Construct the mammoth regexps to test for all patterns in each set, in
    # descending order of length.   
    
    foreach my $set (@{ $self->{word_set} })
    {
        my $pattern = '';
        foreach my $word (sort {length $b <=> length $a } @{ $set })
        {       
            # Skip if word was not found in the selected texts
            next unless $self->{found_word}{$word};
            my ($lw, $w) = $self->make_tlg_regexp ($word);
            $self->{tlg_regexps}{$word} = $lw;
            $pattern .= '(?:' . $w . ')|';
        }
        if ($pattern) {
            chop $pattern;
            $pattern = $Diogenes::Indexed::lookback . $pattern;
            print STDERR "Big pattern: $pattern \n" if $self->{debug};
            push @{ $self->{pattern_list} }, $pattern;
        }
    }
}

# $lookback is used globally in order to exclude bits with preceding word
# elements any hyphenation, and to catch leading accents and asterisks (prefix
# must not be used globally, for it causes a major efficiency hit).  Revised to
# skip such things as PERI- @1 BALLO/MENOS (0007, 041).  Watch out for
# PROS3BA/LLEIN.

# This is a sadly ad hoc procedure, which will not help us with
# eliminating SUM- (lots of binary data) BAI/NEI (0086, 014) across
# blocks.  When Perl has variable-length, zero-width lookbehind, we
# will be able to fix this.  Had to remove (?<![!\]]), as it
# improperly rejects some words.

my $usedch = '\\x27-\\x29\\x2f\\x3d\\x41-\\x5a\\x7c';


# This is the RIGHT line:
#$Diogenes::Indexed::lookback = '(?<!S\d)(?<!\-\ [@"]\d\ [\\x80-\\xff])(?<!\-[\\x80-\\xff][@"]\d)(?<!\-[\\x80-\\xff][@"])(?<!\-[\\x80-\\xff][\\x80-\\xff])(?<!\-[\\x80-\\xff])(?<!['.$usedch.']\\*)(?<!['.$usedch.'])';
# This is the workaround for the TLG disk e hyphenation bug:
$Diogenes::Indexed::lookback = '(?<!S\d)(?<!\-\ [@"]\d\ [\\x80-\\xff])(?<!\-[\\x80-\\xff][\\x80-\\xff])(?<!\-[\\x80-\\xff])(?<!['.$usedch.']\\*)(?<!['.$usedch.'])';
###############################################################
#                                                             #
# Method to generate a regular expression that corresponds to #
# the TLG word list's definition of a `word' from the word as #
# it appears in the word-list.                                #
#                                                             #
###############################################################


sub make_tlg_regexp 
{
    my ($self, $word, $not_begin, $not_end) = @_;
    # $not_begin and $not_end inhibit search for word-boundaries, front and end.
        
    my ($front, $sep, $back);
    my $diacrits = '\/\\\\\=\+\?\!\)\(\|\'';
        
    # Copy args if passed, otherwise assume full word with boundaries
    my $begin = $not_begin ? 1 : 0;
    my $end   = $not_end   ? 1 : 0;
                                
    my $vow = 'AEHIOWU';
    my $cons = 'BCDFGKLMNPQRSTVXYZ';

    # These are the bytes which do not appear in the word list. I (added "/"),
    # because of the bug shown by BRUXW/O(/)MENOS in 5014.  This, however,
    # produces many false positives where the word is meant to have no accent.
    # Added also "(" and ")", because there are sometimes breathings mid-word.
    # Added apostrophe as well.  Removed / and addressed the problem below. 
    # Removed space and \ 
    my $unused =
'\\x02-\\x19\\x22-\\x27\\x28-\\x2e\\x30-\\x3c\\x3e-\\x40\\x5b\\x5d-\\x7b\\x7d-\\xff';
    # these are the characters used in the word list
    my $used = '\\x21\\x27-\\x29\\x2f\\x3d\\x41-\\x5a\\x7c';
    my $unused_plus_space =
'\\x02-\\x20\\x22-\\x27\\x28-\\x2e\\x30-\\x3c\\x3e-\\x40\\x5b\\x5d-\\x7b\\x7d-\\xff';

    $word = quotemeta $word;
    $word =~ s/(?:\\\s)+/ /g;               # other spaces (not at start or end)
    print STDERR "Quotemeta: $word \n\n" if $self->{debug};

    # Unfortunately, early works in the corpus like Euripides have things like 
    # *)AMAZO/- ^250{[STR.} .^63NWN for *)AMAZO/NWN.
    # We make allowance first for hyphenation, with line breaks and block breaks
    # in between.  We then allow for anything else intervening between any two
    # letters: formatting codes, etc. 
    # This part of the regexp is the primary cause of the program's slowness.
    # Must allow for BA?- ...SKOPAI/, with ? before the hyphenation.
    # Also Latin strings: eg. A)NAI/- ^288{&Str. 2.$} .^63DEIAN
        
    # We allow for anything to intervene after a -, until there us a $used letter.
    # this didn't work for the Euripides example above
    #my $mid_word = "[?+]?(?:\-(?:[\\x00-\\xff](?![$used])|(?:\&[^\$]+))*[\\x00-\\xff])?[$unused]*";
    #Instead, we allow any non-binary data between a hyphen and some binary
    #Why did I abandon this solution earlier?
    my $mid_word = "[?+]?(?:\-(?:[\\x01-\\x7f]*[\\x00\\x80-\\xff]+))?[$unused]*";
                        
    # permit non-(alphabetic & diacritical) bytes to intervene
    $word =~ s#([$used])(?!$)#$1$mid_word#g;
    # spaces between words
    $word =~ s# (?!$)# [$unused_plus_space]*#g;
    print STDERR "Mid-word: $word\n\n" if $self->{debug};
    
    # ! (papyrus dot) at beginning or end is often ] or [ in the
    # texts, in which case we know that that is where the `word'
    # ends. v.9: added dot "." for tlg e
    my $front_dot = '[\!\]\.]+';
    $begin++ if $word =~ s#^(?:\\\!)#$front_dot#;
    #$begin++ if $word =~ s#^(?:\\\!)#\[\\!\\\]\\.\]\+#;
    # This is the RIGHT line:
    #$end++ if $word =~ s#(?:\\\!)$#\[\\!\\\[\\.\]#;
    # This is a workaround for TLG E hyphenation bug:
    # allow a word ending in ! to end at a hyphenation and a quote on the new line
    $end++ if $word =~ s#(?:\\\!)$#(?:\[\\!\\\[\\.\]|-(?=[\\d\\x80-\\xff\\x00]*\")|-(?=[_ .!\\]\\d\\x80-\\xff\\x00]*\\\]))#;
    print STDERR "!: $word\n\n" if $self->{debug};
                                
    # allow for capitalized words with diacritics moved in front
    $word =~
#               s#^([AEHIOWUR])\Q$mid_word\E(\\(?:\)|\())\Q$mid_word\E([\\\/=+|]*)#\(\?\:$1$2$3\|\\\*$2$3$1\)$mid_word#;
#               s#(^(?:\Q$front_dot\E)?(?:\Q$mid_word\E)?)([AEHIOWUR])\Q$mid_word\E(\\(?:\)|\())\Q$mid_word\E([\\\/=+|]*)#\(\?\:$1$2$3$4\|$1\\\*$3$4$2\)$mid_word#;
        s#(\b(?:\Q$front_dot\E)?(?:\Q$mid_word\E)?)([AEHIOWUR])\Q$mid_word\E(\\(?:\)|\())\Q$mid_word\E([\\\/=+|]*)#\(\?\:$1$2$3$4\|$1\\\*$3$4$2\)$mid_word#;
                                
    ##################################################################
    #                                                                #
    #  let oxytone accent become barytone:                           #
    # $word =~ s#\\\/$#\[\\/\\\\\]# or                               #
    #                $word =~ s#\\\/([^AEHIOWU]+)$#\[\\/\\\\\]$1#;   #
    #  The above would be more grammatical, but the TLG converts all #
    #  grave accents in the text to acute in the index, even when    #
    #  they are not on the final syllable, as in pseuo-word          #
    #  artifacts like KATALHKTIKO/NON, from KATALHK-TIKO\N[1O/N]1    #
    #  in 5014, 007.                                                 #
    #                                                                #
    ##################################################################
    $word =~ s#\\\/#\[\\/\\\\\]#g;
                        
    # allow for r)r( mid-word.
    $word =~ s#\*R#\*R\[\\(\\)]\?#g;
    print STDERR "rr: $word\n\n" if $self->{debug};
                                
                                
    #############################################################################
    #                                                                           #
    #  allow for accents thrown back from following enclitic                    #
    # if ($word_key =~ m#\/[\|$cons]*[$vow]+[$cons]*[$vow]+[$cons]*$            #
    #                        or $word_key =~ m#\=[\|$cons]*[$vow]+[$cons]*$#) { #
    #        # proparoxytone or properispomenon                                 #
    #        $word =~ s#(.*[$vow])#$1\\/?                                       #
    # }                                                                         #
    #  The above is the grammatically correct answer, but it fails              #
    #  in some cases, since apparently the TLG word list simply                 #
    #  strips the second accent from a `word', even from something              #
    #  like BRUXW/<6O/>6MENOS, where the second accent is really a              #
    #  variant, thus giving BRUXW/OMENOS in the word list.                      #
    #  So instead we allow any accent after any vowel after the                 #
    #  first accent (/=) in the word list entry.                                #
    #                                                                           #
    #############################################################################
                                
    $word =~ m#(.*)()#;
    $word =~ m#([^=/]*\\[=/])(.*)#;
    ($front, $back) = ($1, $2);
    print STDERR "Front: $front\nBack: $back\n\n" if $self->{debug};
    $back =~ s#([$vow])#$1\[\\=\\/\\\\\]?#g;
    $word = $front.$back;
    
# End of the regexp -- it is nearly the same as $used, except with the hyphen
# and with * added. We use a lookahead assertion, so that we don't step on the
# next search (in the case of *BRO/MIE *BRO/MIE, ktl.) We cannot end on a "*".
# We also allow ( because of words like A)GKONI/WAI( and KATANEU=AI( and we
# allow ) because of words like A)GLAI+ZE'QW), and diallow lower-case Latin so
# that the first letter of Anon. is not counted as an Alpha. If the pattern
# ends in a !, then we allow that.                        

# Added ] [ + and \ to the second group; had to delete + and ] and [
# We must allow AAA! before any word.

## For Disk E, we have to match A)POLOGHSAMEN!N, so allow anything to follow a final dot in the pattern
##      $end ?
##              $word =~
##              s/$/(?![\\x27\\x2a\\x2d\\x2f\\x3d\\x41-\\x5a\\x61-\\x7a\\x7c])/
##      :       $word =~
##              s/$/(?![\\x21\\x27\\x2a\\x2d\\x2f\\x3d\\x41-\\x5a\\x5c\\x61-\\x7a\\x7c])/;

    unless ($end)
    {
        $word =~
            s/$/(?![\\x21\\x27\\x2a\\x2d\\x2f\\x3d\\x41-\\x5a\\x5c\\x61-\\x7a\\x7c])/;
    }       
    my $full_word = $begin ? $word : $Diogenes::Indexed::lookback.$word;
    
    $word =~ s#^#\\*?#; # To catch leading capitalization
    
    # The first, longer regexp includes the lookback stuff that comes before
    # the word; the shorter one is for inclusion in a larger, compound regexp
    return ($full_word, $word);
}

########################################################################
# Method to do the actual search, using the data that has been gleaned #
# from the TLG word list by other methods.                             #
########################################################################

sub do_word_search 
{
    my $self = shift;
    my ($author, $word, $work, $word_key, $author_num, $start_block, $end_block);
    my ($filename, $offset, $bare_word);
    
    local $/;
    undef $/;
    my $buf;
    $self->{buf} = \$buf;
        
    # Loop through each author in which one or more of our words were found
    # (according to the word list)
    foreach $author (sort numerically keys %{ $self->{word_counts} }) 
    {
        $filename = $self->{file_prefix} . $author;
        
        # open the .txt file 
        open INP, "$self->{cdrom_dir}$filename$self->{txt_suffix}" 
            or $self->barf("Couln't open $filename$self->{txt_suffix}!");
        binmode INP;
        
        # loop through each work in which a match was found
      WORK:   foreach $work (sort keys %{ $self->{word_counts}{$author} }) 
      {
          my %counts = ();
          unless ($self->{single_list})
          {
              # Loop over the contents of each set, adding up hits in this work
              foreach my $set_num (0 .. $#{ $self->{word_set} })
              {
                  local $^W = 0; # no warnings for patterns not in this work
                  $counts{$set_num} += $self->{word_counts}{$author}{$work}{$_} 
                  for @{ $self->{word_set}[$set_num] };
              }
              print STDERR ((join ', ', values %counts), " | ") if $self->{debug};
              my $sets = grep { $_ > 0 } (values %counts);
              #print ">$sets\n";
              
              # Skip this work if a match is impossible here
              next WORK unless $sets >= $self->{min_matches_int};
          }
          # /Now/ parse .idt file
          $self->parse_idt($author);
          
          # get only those blocks of the file containing the work in question
          $start_block = $work_start_block{$self->{type}}{$author}{$work};
          $offset = $start_block << 13;
          seek INP, $offset, 0;
          if ($work == $last_work{$self->{type}}{$author})
          {
              $buf = <INP>;
              print STDERR "\nReading from $offset to the end of $filename.txt!\n" if $self->{debug};
              $self->barf ("Couln't read the rest of $filename!") unless
                  defined $buf;
          }
          else
          {
              # Subtle stringification wierdness here to make the 
              # automagic increment work right 
              my $next = "$work"; 
              ++$next;
              ++$next until 
                  exists ($work_start_block{$self->{type}}{$author}{$next});
              $end_block = $work_start_block{$self->{type}}{$author}{$next};
              print STDERR "\nReading from $offset to ", $end_block << 13, 
                  " of $filename.txt!\n" if $self->{debug};
              read INP, $buf, (($end_block - $start_block + 1) << 13) or
                  $self->barf ("Couln't read from $filename");
          }
                                                
          my @order;
          if ($self->{single_list})
          {
              @order = (0);
              $counts{0}++;
          }
          else
          {
              # Optimal searching order for sets within this work
              @order = sort { $counts{$a} <=> $counts{$b} } keys %counts;
              
              # Cut off needless sets at top end of list
              $#order = @{ $self->{word_set} } - $self->{min_matches_int};
          }
          foreach my $set_num (@order)
          {
              # Skip this set if there are no hits in it for this work
              next unless $counts{$set_num};
              
              foreach my $word_key (@{ $self->{word_set}[$set_num] })
              {
                  next unless $self->{word_counts}{$author}{$work}{$word_key};
                  print STDERR 
                      "\nSearching in $author{$self->{type}}{$author}, ", 
                      "$work{$self->{type}}{$author}{$work} for $word_key \n" if
                      $self->{debug};
                  $self->{word_key} = $word_key;
                  print STDERR "\nWord list entry: $word_key\n" if $self->{debug};
                  
                  # use in the form of a suitable regexp
                  $word = $self->{tlg_regexps}{$word_key};
                  print STDERR "Using pattern: $word in author $author\n\n" if 
                      $self->{debug};
                  # clear the last search
                  undef $self->{seen}{$author};
                  
                  return if $Diogenes_Daemon::flag and not print ("\0");
                                        
                  # this does the search, storing the locations in %seen
                  while ($buf =~ m#$word#g)
                  {
                      push @{ $self->{seen}{$author} }, (pos $buf);
                  }
                  
                  print STDERR "Seen: " . @{ $self->{seen}{$author} }. "\n" if 
                      $self->{seen}{$author} and $self->{debug};
                  # print the hits, after finding location and context
                  $self->{current_work} = $work;
                  $self->extract_hits($author);
                  if ($self->{check_word_stats} 
                      and $self->{word_counts}{$author}{$work}{$word_key} >
                      ($self->{hits_hash}{$author}{$work}{$word_key} || 0) )
                  {
                      # We have a false negative.  
                      if ($author eq '2892' and $work eq '110')
                      {   # Maximus Confessor
                          warn 
                              "Word list counts are off for author $author, work $work. ".
                              "This is a known error.\n\n";
                      }
                      else
                      {
                          warn (
"\n\n+-----------------------------------------------------------+\n".
        "ERROR: The TLG word list indicates that there ".
        "should be $self->{word_counts}{$author}{$work}{$word_key} instance(s)\n".
        "of the word $word_key for author number $author, work number $work, but \n".
        "Diogenes found " . ( $self->{hits_hash}{$author}{$work}{$word_key} || 0 ) .
        " of them.\n\n".
        "Please send a copy of ".
        "this error message to $Diogenes::Base::my_address.\n".
        "Diogenes version ($Diogenes::Base::Version).".
        "\n+-----------------------------------------------------------+\n\n");
                      }
                  }
                  elsif ($self->{check_word_stats} 
                         and $self->{word_counts}{$author}{$work}{$word_key} <
                         $self->{hits_hash}{$author}{$work}{$word_key}) 
                  {
                      # We have one or more false positives.  
                      if ($word eq 'KAI/')
                      {
                          warn(
                              "\nWord-list totals don't agree for $word: ".
                              "this is a known error.\n");
                      }
                      else
                      {
                          my $inst = ($self->{hits_hash}{$author}{$work}{$word_key} -
                                      $self->{word_counts}{$author}{$work}{$word_key});
                          warn (
                              "WARNING: Diogenes found $inst extra instance".
                              ($inst == 1 ? '' : 's').
                              " of $word_key in author $author, work $work. \n");
                      }
                  }
              }
          }
      }
        close INP or $self->barf("Couln't close $filename!");
    }       
}


# Uninteresting debugging subroutine
sub print_word_search 
{
    my $self = shift;
    my $total = 0;
        
    my ($author, $word, $work);
        
    # This stuff is mostly for debugging
    foreach $author (sort numerically keys %{ $self->{word_counts} }) 
    {
        print STDERR "------------------------------ \n\n" if $self->{debug};
        print STDERR "author: $author \n" if $self->{debug};
        foreach $work (sort numerically keys %{ $self->{word_counts}{$author} }) 
        {
            foreach $word (sort keys %{ $self->{word_counts}{$author}{$work} }) 
            {
                print STDERR "word: $word \n" if $self->{debug};
                $total += $self->{word_counts}{$author}{$work}{$word};
                print STDERR "work: $work --> word count: $self->{word_counts}{$author}{$work}{$word} \n\n" if $self->{debug};
            }
        }
    }
    print "\n##########\n";
    print "Total instances reported by word list: $total\n";
    print "Total hits: $self->{hits}\n";
    print "##########\n\n";
}

#####################################################################
#                                                                   #
# Method to print the overall results of a word-list search.        #
# It's expected that Diogenes may find more matches than            #
# anticipated, since it values comprehensiveness over selectivity.  #
#                                                                   #
#####################################################################
sub print_wlist_report 
{
    my $self = shift;

    my $output = "\&\nIncidence of all words as reported by word list: ";
    $output .= $self->{list_total} || 0;
    $output .= "\nPassages containing those words reported by Diogenes: ";
    $output .= $self->{hits} || 0;
    $output .= "\n\n";
    $output .= "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n\n" 
        unless $self->{output_format} eq 'html';
    $self->print_output(\$output);
        
}

sub numerically { $a <=> $b; }

1;
