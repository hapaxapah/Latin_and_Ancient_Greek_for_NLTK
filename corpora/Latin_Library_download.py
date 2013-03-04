import os

#print "Making 'Latin_Library_corpus' directory if it doesn't exist ... "
#directory = "Latin_Library_corpus"
#if not os.path.exists(directory):
#    os.makedirs(directory)

print "Downloading files ..."

# -nd for all in one file
os.system("wget -r -l0 -t1 -N -np -A.html,shtml -erobots=off http://www.thelatinlibrary.com/indices.html")

print "Find current path ..."
current_path = os.getcwd()

print "Entering 'www.thelatinlibrary.com' directory ..."
directory = "www.thelatinlibrary.com"
enter_dir = os.chdir(directory)

print "Removing the '/101/' directory"
os.system("rm -r 101/")
