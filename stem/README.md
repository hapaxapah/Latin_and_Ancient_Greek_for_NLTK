The file "latin_snowball.py" is a lemmatizer for Latin modeled closely to the "snowball.py" stemmer for English. See data directory for helpful manipulations of the Perseus morphological data.

Remaining is to (a) pull out the replacement list to a new independent file somewhere in corpus; (b) link to the Latin ("/stop/latin" stoplist (also belonging in the coprus), which is finished; and (c) link to both, probably from snowball.py with a new class named "class LatinStemmer(_StandardStemmer):".
