# .zshrc - Common settings for usability

# --- History Configuration ---
# Keep plenty of history, don't write duplicates, and share across tabs
export HISTSIZE=10000
export SAVEHIST=10000
export HISTFILE=~/.zsh_history
setopt appendhistory      # Append to history, don't overwrite
setopt sharehistory       # Share history between all sessions
setopt histignorealldups  # Ignore duplicate commands in history
setopt histverify         # When using ! expansions, show the command before executing

# --- Basic Auto-completion ---
autoload -Uz compinit
compinit
# Menu-driven completion
zstyle ':completion:*' menu select
# Case-insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'

# --- Colors ---
autoload -Uz colors && colors
export CLICOLOR=1
export LSCOLORS="Gxfxcxdxbxegedabagacad" # Mac standard coloring for ls

# --- Basic Prompt ---
# A clean, simple prompt: user@host current_directory % 
PROMPT="%F{green}%n%f@%F{blue}%m%f %F{cyan}%1~%f %# "

# --- Aliases ---
# Navigation
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."

# Listing files
alias ls="ls -G"         # Colorize output
alias ll="ls -l"         # Detailed list
alias la="ls -la"        # Detailed list including hidden files

# Utilities
alias grep="grep --color=auto"
alias df="df -h"         # Human-readable sizes
alias du="du -h"         # Human-readable sizes

# Use 'bat' instead of 'cat' if installed
if command -v bat &> /dev/null; then
    alias cat="bat"
fi

# --- FZF Integration ---
# Enable fzf key bindings and fuzzy completion based on architecture
if [[ -f "/opt/homebrew/opt/fzf/shell/completion.zsh" ]]; then
    # Apple Silicon
    source "/opt/homebrew/opt/fzf/shell/completion.zsh"
    source "/opt/homebrew/opt/fzf/shell/key-bindings.zsh"
elif [[ -f "/usr/local/opt/fzf/shell/completion.zsh" ]]; then
    # Intel Macs
    source "/usr/local/opt/fzf/shell/completion.zsh"
    source "/usr/local/opt/fzf/shell/key-bindings.zsh"
fi
