set -x PATH $PATH /sbin/ $HOME/Developer/anaconda3/bin $HOME/Developer/bin
set -x LENSDIR ~/Developer/Lens
set -x HOSTTYPE x86_64
set -x PATH $PATH $LENSDIR/Bin/$HOSTTYPE
set -x DYLD_LIBRARY_PATH $LENSDIR/Bin/$HOSTTYPE $DYLD_LIBRARY_PATH


function gs
	git status
end

function a
	ag -i
end

function hack
	atom .
end

function gl
	git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit
end

