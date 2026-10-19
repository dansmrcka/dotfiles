plugins=(git tmuxinator)

export DOTFILES=~/.dotfiles
export EDITOR=nvim
export VISUAL=nvim
export READER="zathura"
export TERM=rxvt-unicode-256color
export TERMINAL="kitty"
export BROWSER="brave"
export VIDEO="cvlc"
export IMAGE="imv"
export COLORTERM="truecolor"
export OPENER="xdg-open"
export PAGER="less"
export GPG_TTY=$(tty)

export OPENSSL_CONF=/dev/null

source ~/.config/nnn/config.zsh
source ~/.aliases
source ~/git/personal-setup/shell/commons
export PATH=$PATH:~/.scripts
export FZF_DEFAULT_COMMAND="fd --type f --hidden --no-ignore --exclude '.git/'"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# path to the git root
export GIT_PATH=~/git

# run Tmux automatically in every normal terminal
# vypnout pro jednorázový shell: RUN_TMUX=false kitty
: ${RUN_TMUX:=true}

fpath+=(~/.local/share/zsh/site-functions)
if [ -e $HOME/.oh-my-zsh ]; then
  export ZSH=$HOME/.oh-my-zsh
  ZSH_THEME="lukerandall"
  plugins=(git zsh-syntax-highlighting alias-tips sudo zsh-completions fzf)
  source $ZSH/oh-my-zsh.sh
fi

# Vi mode in ZSH
bindkey -v

# I dont like shared history between terminals, does not play well with tmux
unsetopt share_history

# use the vi navigation keys in menu completion
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect 'j' vi-down-line-or-history

# dGPU (NVIDIA T550) jen na vyzadani: `prime-run blender`.
# Driv tu byl bezpodminecny export, ktery na dGPU poslal uplne vsechno spustene
# z terminalu vcetne prohlizece. Kompozitor pritom bezi na Intelu
# (WLR_DRM_DEVICES v ~/.config/environment.d/10-wlroots.conf), takze se vysledek
# musel PRIME kopirovat zpet - pomalejsi start a zbytecne probuzena karta.
prime-run() {
  __NV_PRIME_RENDER_OFFLOAD=1 \
  __GLX_VENDOR_LIBRARY_NAME=nvidia \
  __VK_LAYER_NV_optimus=NVIDIA_only \
  "$@"
}

r1() {
  export ROS_DISTRO="noetic"  
}

r2() {
  export ROS_DISTRO="jazzy"
}

r2

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

export APPTAINER_TMPDIR=$HOME/.apptainer_tmp
export APPTAINER_CACHE=$HOME/.apptainer_cache

# # Automatické spuštění tmuxu — každý terminál dostane vlastní session
# if [[ -z "$TMUX" && -z "$INTEGRATED_TERMINAL" && -z "$VSCODE_INJECTION" && $- == *i* ]] \
#    && [[ "$RUN_TMUX" == true ]] && command -v tmux >/dev/null; then
#   tmux new-session
# fi
