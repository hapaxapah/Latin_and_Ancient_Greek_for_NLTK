The two stopword lists are taken from the Perseus Hopper source, found in "/sgml/reading/build/stoplists".[1]

This is working correctly. To use:

    (1) Place file "latin" in "~/nltk_data/corpora/stopwords"
    
    (2) Include the stopwords as usual, with "from nltk.corpus import stopwords"
    
    (3) To view stopwords, and to test if installation is successful, call:
    >>> stopwords.words('latin')
    
    (4) For a minimum working example, enter the following commands:
    >>> import nltk, re
    >>> from nltk.corpus import stopwords
    >>> latin_sentence = 'Etsi tibi omnia suppetunt ea quae consequi ingenio aut usu homines aut diligentia possunt, tamen amore nostro non sum alienum arbitratus ad te perscribere ea quae mihi veniebant in mentem dies ac noctes de petitione tua cogitanti, non ut aliquid ex his novi addisceres, sed ut ea quae in re dispersa atque infinita viderentur esse ratione et distributione sub uno aspectu ponerentur.'
    >>> lower = latin_sentence.lower()
    >>> words = re.findall(r'\w+', lower,flags = re.UNICODE | re.LOCALE)
    >>> important_words=[]
    >>> for word in words:
    ...     if word not in stopwords.words('latin'):
    ...         important_words.append(word)
    >>> print print important_words

[1] http://sourceforge.net/projects/perseus-hopper/

Mozilla Public License 1.1 (MPL 1.1)
http://www.mozilla.org/MPL/1.1/
