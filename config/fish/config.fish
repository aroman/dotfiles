function gs
	git status
end

function a
	ag -i
end

function hack
	code .
end

function gl
	git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit
end
