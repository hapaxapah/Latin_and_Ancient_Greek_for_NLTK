#see p. 33 of buddha book

import re

#eee     --> any match anywhere
#(\w)eee --> only if match at word end
#iii(\s) --> only if space follows match
#^...$   --> only exact match of entire word
replacement_patterns = [
    (r'aaa', 'bbb'),
    (r'(\w+)eee', 'fff'),
    (r'iii(\s)', 'jjj'),
    (r'(\s)mmm', 'nnn'),
    (r'\brrr\b', 'sss'),
#     (r'won\'t', 'will not'),
#    (r'can\'t', 'cannot'),
#    (r'i\'m', 'i am'),
#    (r'ain\'t', 'is not'),
#    (r'(\w+)\'ll', '\g<1> will'),
#    (r'(\w+)n\'t', '\g<1> not'),
#    (r'(\w+)\'ve', '\g<1> have'),
#    (r'(\w+)\'s', '\g<1> is'),
#    (r'(\w+)\'re', '\g<1> are'),
#    (r'(\w+)\'d', '\g<1> would')
]

class RegexpReplacer(object):
    def __init__(self, patterns=replacement_patterns):
        self.patterns = [(re.compile(regex), repl) for (regex, repl) in patterns]
    def replace(self, text):
        s = text
        for (pattern, repl) in self.patterns:
            (s, count) = re.subn(pattern, repl, s)
        return s


class RegexpReplacer2(object):
    def __init__(self, patterns=replacement_patterns):
        self.patterns = [(re.compile(regex), repl) for (regex, repl) in patterns]
    def replace(self, item):
        s = item
        for (pattern, repl) in self.patterns:
            (s, count) = re.subn(pattern, repl, s)
        return s
