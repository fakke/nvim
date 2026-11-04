set -g __nvim_runner_python $argv[1]
set -g __nvim_runner_script $argv[2]

function __nvim_runner_prompt --on-event fish_prompt
    set -l result $status
    bind \cx\cr __nvim_runner_dispatch
    bind --mode insert \cx\cr __nvim_runner_dispatch
    command tmux set-option -p -t $TMUX_PANE @nvim_runner_last_status $result
    command tmux set-option -p -t $TMUX_PANE @nvim_runner_state ready
    return $result
end

function nvim-run
    if not set -q __nvim_runner_request
        echo 'No command requested by Neovim' >&2
        return 1
    end
    $__nvim_runner_python $__nvim_runner_script --execute $__nvim_runner_request
    set -l result $status
    set -e __nvim_runner_request
    return $result
end

function __nvim_runner_preexec --on-event fish_preexec
    command tmux set-option -p -t $TMUX_PANE @nvim_runner_state busy
end

function __nvim_runner_dispatch
    set -l request (command tmux show-options -pqv -t $TMUX_PANE @nvim_runner_request)
    if test -z "$request"
        return
    end
    command tmux set-option -pu -t $TMUX_PANE @nvim_runner_request
    set -l input (commandline)
    if test -n "$input"
        command tmux set-option -p -t $TMUX_PANE @nvim_runner_state ready
        command tmux set-option -p -t $TMUX_PANE @nvim_runner_reply input
        return
    end
    set -g __nvim_runner_request $request
    commandline -r -- nvim-run
    command tmux set-option -p -t $TMUX_PANE @nvim_runner_reply accepted
    commandline -f execute
end
