#!/usr/bin/env bash
# bootstrap_dev_env.sh — Ali’s full-stack / web3 / AI toolkit
set -euo pipefail

##
## 0. Helpers
##
log(){ printf "\n\033[1;35m▶ %s\033[0m\n" "$*"; }
need(){ command -v "$1" >/dev/null 2>&1; }

##
## 1. Xcode CLI + Homebrew
##
if ! xcode-select -p &>/dev/null; then
  log "Installing Xcode Command Line Tools…"
  xcode-select --install
  until xcode-select -p &>/dev/null; do sleep 20; done
fi

if ! need brew; then
  log "Installing Homebrew…"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  log "Updating Homebrew…"
  brew update && brew upgrade
fi

##
## 2. CLI must-haves
##
BREW_PKGS=(
  git git-lfs gh
  wget curl gnupg gnu-sed
  zsh zsh-completions starship
  bat eza fd ripgrep
  tmux fzf
  jq yq
  openssl@3 libpq
  asdf
)
brew install "${BREW_PKGS[@]}"
brew cleanup

log "Setting up aliases for eza…"
cat <<'EOF' >> ~/.zprofile

# Aliases for modern ls (eza)
if command -v eza &>/dev/null; then
  alias ls='eza --icons'
  alias ll='eza -lah --icons'
  alias la='eza -a --icons'
  alias lt='eza -T --icons'
fi
EOF

log "Exporting libpq flags for PostgreSQL builds…"
cat <<'EOF' >> ~/.zprofile

# libpq build support
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
export LDFLAGS="-L/opt/homebrew/opt/libpq/lib"
export CPPFLAGS="-I/opt/homebrew/opt/libpq/include"
EOF

##
## 3. asdf runtimes
##
source "$(brew --prefix asdf)/libexec/asdf.sh"

add_asdf_plugin(){ 
  local plugin_name="$1"
  local plugin_url="${2:-}"
  
  # Check if plugin is already installed
  if asdf plugin list | grep -q "^${plugin_name}$"; then
    log "Plugin $plugin_name already installed"
    return 0
  fi
  
  # Add plugin
  if [[ -n "$plugin_url" ]]; then
    asdf plugin add "$plugin_name" "$plugin_url" || log "⚠️ Failed to add plugin $plugin_name"
  else
    asdf plugin add "$plugin_name" || log "⚠️ Failed to add plugin $plugin_name"
  fi
}

install_asdf(){
  local lang="${1:-}"
  local ver="${2:-}"
  if [[ -z "$lang" || -z "$ver" ]]; then
    log "⚠️ install_asdf called with missing lang or version"
    return 1
  fi
  log "Installing $lang@$ver"
  add_asdf_plugin "$lang"
  asdf install "$lang" "$ver"
  asdf set "$lang" "$ver"
}

log "Installing runtimes with asdf…"

# Node.js
add_asdf_plugin nodejs
asdf install nodejs lts
asdf set nodejs lts

# The rest via generic function
install_asdf python  "3.12.3"
install_asdf java    "temurin-17.0.11+9"

##
## 4. Global packages
##
npm i -g pnpm

pip3 install --upgrade pip poetry langchain openai-cli

##
## 5. Databases & services
##
brew tap mongodb/brew
SERVICES=(
  postgresql@16 redis mongodb-community@7.0
  meilisearch minio
)
brew install "${SERVICES[@]}"
for svc in postgresql@16 redis mongodb-community@7.0 meilisearch; do
  brew services start "$svc"
done

##
## 6. GUI apps
##
CASKS=(
  visual-studio-code
  iterm2
  docker
  google-chrome
  notion
  insomnia
)

# Install GUI apps, checking if they already exist
for cask in "${CASKS[@]}"; do
  # Check if the app is already installed
  if brew list --cask | grep -q "^${cask}$"; then
    log "✓ $cask is already installed"
  else
    log "Installing $cask..."
    brew install --cask "$cask" || log "⚠️ Failed to install $cask (may already exist)"
  fi
done

##
## 7. Git + SSH
##
GIT_EMAIL="aly.lhaj@gmail.com"
if [ ! -f ~/.ssh/id_ed25519 ]; then
  log "Generating new SSH key…"
  ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f ~/.ssh/id_ed25519 -N ""
  eval "$(ssh-agent -s)"
  ssh-add ~/.ssh/id_ed25519
  log "Public key below — add it to GitHub/GitLab:"
  cat ~/.ssh/id_ed25519.pub
fi

git config --global user.name  "Ali Hajeh"
git config --global user.email "$GIT_EMAIL"
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global credential.helper osxkeychain

##
## 8. Dotfiles / Secrets
##
if [ ! -d ~/code/dotfiles ]; then
  log "Cloning dotfiles repo…"
  gh repo clone ali-hajeh/dotfiles ~/code/dotfiles || true
  ~/code/dotfiles/install.sh || true
fi

[ ! -f ~/.extra ] && touch ~/.extra

log "✅  All set! Open a new terminal or run: source ~/.zprofile"
