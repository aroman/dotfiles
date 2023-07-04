#! /bin/sh

# Homebrew doesn't remember which formulas are installed by user and
# which are installed as dependancies, and it doesn't uninstall dependancies
# when you uninstall a formula.
# 
# This script will how you find orphaned formulas that were insatlled as dependecies 
# but no londer needed because you've unsintalled the parent packages.
#
# 	Usage:
# 		./brew-show-orphans.sh pkg-list.txt
#
# pkg-list.txt is a list of package names you want to keep. One package per line.
# The file can have comments. Comments begin with '#' and can be the entire line or after a package name.
#
# 	E.g.
#       ## a list of packages I want to keep
#
#		node
#		rbenv
#		tmx
#		mysql	# this is a comment
#
#       # empty lines are ok too
#
#		# another comment
#		ruby
#		python
#
# If you want to uninstall all orphaned packages, simply use xargs:
#
# 	./brew-show-orphans.sh pkg-list.txt | xargs brew uninstall
#
#

LEAVES_TMPFILE="$TMPDIR/brew-leaves.list"
PINS_TMPFILE="$TMPDIR/brew-pins.list"
brew leaves > "$LEAVES_TMPFILE"

# # first strip frontmatter from pinfile
# gsed '1 { /^---/ { :a N; /\n---/! ba; d} }
# 		# then strip comments
# 		s/[[:space:]]*#.*$//
# 		# then strip leading spaces, trailing spaces and empty lines
# 		s/[[:space:]]//g  ;  /^$/d' "$1" | \
# 	# finally, sort it and save to temp file
# 	sort > "$PINS_TMPFILE"
	

# first strip comments
sed 's/#.*$//
	# then strip leading spaces, trailing spaces and empty lines
	s/[[:space:]]//g
	/^$/d' "$1" | \
	# finally, sort it and save to temp file
	sort > "$PINS_TMPFILE"


	
diff "$LEAVES_TMPFILE" "$PINS_TMPFILE" | \
	# delete lines doesn't begin with '<' then remove leading '< '
	sed '/^</! d  ;  s/^< //'
