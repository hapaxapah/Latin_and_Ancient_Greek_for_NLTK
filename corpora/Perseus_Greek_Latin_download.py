import urllib
import tarfile

url = "http://www.perseus.tufts.edu/hopper/opensource/downloads/texts/hopper-texts-GreekRoman.tar.gz"

print "Downloading Perseus texts (125MB) ..."

urllib.urlretrieve(url, "Perseus_corpus.tar.gz")

print "Decompressing files ..."
tar = tarfile.open("Perseus_corpus.tar.gz")
tar.extractall()
tar.close()

