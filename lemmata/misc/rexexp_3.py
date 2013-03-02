import nltk

from replacers import RegexpReplacer
from replacers import RegexpReplacer2

replacer = RegexpReplacer()
replacer2 = RegexpReplacer2()

print replacer.replace("rrr")
print replacer.replace(" rrr ")
print replacer.replace("rrraffix")
print replacer.replace("prefixrrr")

print '*' * 20

print replacer2.replace("rrr")
print replacer2.replace(" rrr ")
print replacer2.replace("rrraffix")
print replacer2.replace("prefixrrr")

