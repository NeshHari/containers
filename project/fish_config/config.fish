set fish_greeting

set -gx EDITOR "nvim"
set -gx VISUAL "nvim"
set -q GHCUP_INSTALL_BASE_PREFIX[1]; or set GHCUP_INSTALL_BASE_PREFIX $HOME ; set -gx PATH $HOME/.cabal/bin /home/nesh/.ghcup/bin /home/nesh/.local/bin $HOME/node_modules/tree-sitter-cli /home/nesh/.local/share/bob/nvim-bin $PATH
# set -Ux LS_COLORS $(vivid generate catppuccin-mocha)
# set -Ux DOCKER_HOST unix:///run/docker.sock

# alias ce="chezmoi edit"

alias l='eza --color=always --color-scale=all --color-scale-mode=gradient --icons=always --group-directories-first'
alias ll='eza --color=always --color-scale=all --color-scale-mode=gradient --icons=always --group-directories-first -l --git -h'
alias la='eza --color=always --color-scale=all --color-scale-mode=gradient --icons=always --group-directories-first -a'
alias lla='eza --color=always --color-scale=all --color-scale-mode=gradient --icons=always --group-directories-first -a -l --git -h'
alias lt='eza --color=always --color-scale=all --color-scale-mode=gradient --icons=always --group-directories-first -T'

alias grep='rg'
alias find='fd'
alias cat='bat'
alias du='dust'
alias mkdir='mkdir -p'
# alias cp='xcp'
alias lg='lazygit'

# alias pacin='sudo pacman -S (pacman -Slq | fzf --multi)'
# alias parin='paru -S (paru -Slq | fzf --multi)' 
# alias pacrm='sudo pacman -Rsu (pacman -Qq | fzf --multi)'
# alias parrm='paru -Rnsu (paru -Qq | fzf --multi)'
# alias pacinnc='sudo pacman -S (pacman -Slq | fzf --multi) --noconfirm'
# alias parinnc='paru -S (paru -Slq | fzf --multi) --noconfirm'
# alias pacrmnc='sudo pacman -Rsu (pacman -Qq | fzf --multi) --noconfirm'

alias histr='history | fzf | read -l cmd; eval $cmd'
alias hist='history | fzf | read -l cmd; commandline -t $cmd'

alias logout='pkill -KILL -u $USER'

alias vi='nvim'

# alias ghce='gh copilot explain'
# alias ghcs='gh copilot suggest'

if status --is-interactive
    fish_vi_key_bindings
    if type -q zoxide
        zoxide init fish | source
    end
    if type -q starship
        starship init fish | source
        enable_transience
    end
    if type -q atuin
        atuin init fish --disable-up-arrow | source
    end
end

# function vim
#     neovide $argv
#     disown (jobs -p)
#     kill (ps -o pid= -o ppid= -p %self | awk '{print $2}')
# end
#
# function fontsearch
#     fc-list | rg -i $argv | cut -d ':' -f 2- | fzf
# end
#
# thefuck --alias | source
#
