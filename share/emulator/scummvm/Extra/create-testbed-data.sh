#!/bin/sh

# Create the directory structure
# Avoided bash shortcuts / file-separators in interest of portability

if [ -e testbed ]; then
	echo "Game-data already present as testbed/"
	echo "To regenerate, remove and rerun"
	exit 0
fi

mkdir testbed

cd testbed || exit 1

# For game detection
echo "ScummVM rocks!" > TESTBED

mkdir test1
mkdir Test2
mkdir TEST3
mkdir tEST4
mkdir test5


cd test1 || exit 1
echo "It works!" > file.txt
cd .. || exit 1

cd Test2 || exit 1
echo "It works!" > File.txt
cd .. || exit 1

cd TEST3 || exit 1
echo "It works!" > FILE.txt
cd .. || exit 1

cd tEST4 || exit 1
echo "It works!" > fILe.txt
cd .. || exit 1

cd test5 || exit 1
echo "It works!" > file.
cd .. || exit 1

# back to the top
cd .. || exit 1

# move the audiocd data to newly created directory
cp -r testbed-audiocd-files testbed/audiocd-files
mv testbed/audiocd-files/music.mid testbed/
echo "Game data created"
