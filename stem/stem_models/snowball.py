# taken from the NLTK Snowball stemmer ("/nltk/nltk/stem/snowball.py")
class EnglishStemmer(_StandardStemmer):

    """
    The English Snowball stemmer.

    :cvar __special_words: A dictionary containing words
                           which have to be stemmed specially.
    :type __special_words: dict

    :note: A detailed description of the English
           stemming algorithm can be found under
           http://snowball.tartarus.org/algorithms/english/stemmer.html
    """

    __special_words = {"skis" : "ski",
                       "skies" : "sky",
                       "dying" : "die",
                       "lying" : "lie",
                       "tying" : "tie",
                       "idly" : "idl",
                       "gently" : "gentl",
                       "ugly" : "ugli",
                       "early" : "earli",
                       "only" : "onli",
                       "singly" : "singl",
                       "sky" : "sky",
                       "news" : "news",
                       "howe" : "howe",
                       "atlas" : "atlas",
                       "cosmos" : "cosmos",
                       "bias" : "bias",
                       "andes" : "andes",
                       "inning" : "inning",
                       "innings" : "inning",
                       "outing" : "outing",
                       "outings" : "outing",
                       "canning" : "canning",
                       "cannings" : "canning",
                       "herring" : "herring",
                       "herrings" : "herring",
                       "earring" : "earring",
                       "earrings" : "earring",
                       "proceed" : "proceed",
                       "proceeds" : "proceed",
                       "proceeded" : "proceed",
                       "proceeding" : "proceed",
                       "exceed" : "exceed",
                       "exceeds" : "exceed",
                       "exceeded" : "exceed",
                       "exceeding" : "exceed",
                       "succeed" : "succeed",
                       "succeeds" : "succeed",
                       "succeeded" : "succeed",
                       "succeeding" : "succeed"}

    def stem(self, word):

        """
        Stem an English word and return the stemmed form.

        :param word: The word that is stemmed.
        :type word: str or unicode
        :return: The stemmed form.
        :rtype: unicode

        """
        word = word.lower()

        if word in self.stopwords or len(word) <= 2:
            return word

        elif word in self.__special_words:
            return self.__special_words[word]
