#!/bin/bash

set -euo pipefail

# move to this scripts' folder
cd "$(dirname "$0")"

sudo apt update

sudo apt-get install -y make build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
    libsqlite3-dev wget curl llvm libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
    libffi-dev liblzma-dev zsh git direnv libnotify-bin thefuck bzip2 git git-lfs cmake

# install pyenv
curl https://pyenv.run | bash

# install rustup and rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# install cargo-binstall
curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash

# install atuin
cargo binstall atuin -y

# ensure the submodules are updated
git submodule update --init --recursive

# install pexp
cargo install --path "pexp"

# setup gitconfig
git config --global include.path "$(pwd)/base.gitconfig"

# setup the zshrc
echo "source $(pwd)/shared.zshrc"

# set zsh as the shell
chsh "$(which zsh)"

# start zsh for the first time
zsh