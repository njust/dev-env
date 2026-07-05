FROM ubuntu:24.04 

ARG TARGETARCH
ARG TARGETOS
RUN echo "Building for ${TARGETOS}/${TARGETARCH}" 

RUN apt-get update && apt-get upgrade -y
RUN apt install -y curl wget build-essential git xclip mold ripgrep fd-find git
RUN apt install -y sudo 
RUN echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ubuntu

# Nodejs needed for pi
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
RUN sudo apt install -y nodejs

USER ubuntu
WORKDIR /tmp

# Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --default-toolchain=1.95.0 -y
ENV PATH="/home/ubuntu/.cargo/bin:$PATH"

RUN rustup component add rust-analyzer
RUN cargo install cargo-binstall

# Helix with steel plugin system
RUN git clone https://github.com/njust/helix.git
WORKDIR /tmp/helix
RUN git checkout steel-event-system
RUN cargo xtask steel

ENV STEEL_JIT=false
RUN mkdir -p /home/ubuntu/.local/share/steel
RUN forge pkg install --git https://github.com/njust/streal.hx.git
RUN forge pkg install --git https://github.com/thomasschafer/scooter.hx.git

ENV HELIX_RUNTIME=/usr/lib/helix/runtime
RUN sudo mkdir -p /usr/lib/helix
RUN sudo mv /tmp/helix/runtime/ /usr/lib/helix/

WORKDIR /tmp

# Nushell
RUN case "$TARGETARCH" in \
  amd64) wget -q https://github.com/nushell/nushell/releases/download/0.113.1/nu-0.113.1-x86_64-unknown-linux-musl.tar.gz -O nu-musl.tar.gz \
         && tar xzf nu-musl.tar.gz \
         && sudo cp nu-0.113.1-x86_64-unknown-linux-musl/nu /usr/local/bin/nu ;; \
  arm64) wget -q https://github.com/nushell/nushell/releases/download/0.113.1/nu-0.113.1-aarch64-unknown-linux-musl.tar.gz -O nu-musl.tar.gz \
         && tar xzf nu-musl.tar.gz \
         && sudo cp nu-0.113.1-aarch64-unknown-linux-musl/nu /usr/local/bin/nu ;; \
esac

# Zellij
RUN cargo binstall -y zellij

# Pi agent
RUN sudo npm install -g @earendil-works/pi-coding-agent
RUN pi install npm:pi-web-access

# Layzgit
RUN case "$TARGETARCH" in \
  amd64) wget https://github.com/jesseduffield/lazygit/releases/download/v0.62.2/lazygit_0.62.2_linux_x86_64.tar.gz \
         && tar xzvf lazygit_0.62.2_linux_x86_64.tar.gz ;; \
  arm64) wget https://github.com/jesseduffield/lazygit/releases/download/v0.62.2/lazygit_0.62.2_linux_arm64.tar.gz \
         && tar xzvf lazygit_0.62.2_linux_arm64.tar.gz ;; \
esac
RUN sudo mv /tmp/lazygit /usr/bin/

# Language servers for helix
RUN sudo apt-get install -y dotnet-sdk-10.0
RUN dotnet tool install --global roslyn-language-server --prerelease
ENV PATH="/home/ubuntu/.dotnet/tools:$PATH"

RUN sudo npm install -g @angular/language-service@next typescript @angular/language-server

# Kubectl
RUN sudo apt-get install -y apt-transport-https ca-certificates curl gnupg
RUN curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
RUN sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
RUN echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
RUN sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list
RUN sudo apt-get update
RUN sudo apt-get install -y kubectl

# K9s
RUN case "$TARGETARCH" in \
  amd64) wget https://github.com/derailed/k9s/releases/download/v0.51.0/k9s_linux_amd64.deb \
         && sudo dpkg -i k9s_linux_amd64.deb ;; \
  arm64) wget https://github.com/derailed/k9s/releases/download/v0.51.0/k9s_linux_arm64.deb \
         && sudo dpkg -i k9s_linux_arm64.deb ;; \
esac

# Uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/home/ubuntu/.local/bin:$PATH"

# Sandlock
RUN mkdir sandlock
RUN case "$TARGETARCH" in \
  amd64) wget https://github.com/multikernel/sandlock/releases/download/v0.8.4/sandlock-x86_64-unknown-linux-gnu.tar.gz \
         && tar xzvf sandlock-x86_64-unknown-linux-gnu.tar.gz -C sandlock ;; \
  arm64) wget https://github.com/multikernel/sandlock/releases/download/v0.8.4/sandlock-aarch64-unknown-linux-gnu.tar.gz \
         && tar xzvf sandlock-aarch64-unknown-linux-gnu.tar.gz -C sandlock ;; \
esac
RUN sudo mv sandlock/sandlock /usr/local/bin

# Azure cli
RUN curl -fsSL 'https://azurecliprod.blob.core.windows.net/$root/deb_install.sh' | sudo bash

# Config
ENV PI_CODING_AGENT_DIR="/home/ubuntu/.config/pi"
COPY tools/ /usr/bin/

# Clean tmp dir
RUN sudo rm * -r

WORKDIR /home/ubuntu
CMD ["/home/ubuntu/.cargo/bin/zellij"]
