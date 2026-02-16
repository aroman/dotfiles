function fkill
    ps -eo pid,comm,args | fzf --exact --wrap --header="Select process(es) to kill" --multi | awk '{print $1}' | xargs -r kill $argv
end
