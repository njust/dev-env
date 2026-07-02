FROM ubuntu:24.04 

ARG TARGETARCH
ARG TARGETOS
RUN echo "Building for ${TARGETOS}/${TARGETARCH}" 

RUN apt-get update && apt-get upgrade -y
RUN apt install curl wget build-essential git xclip mold ripgrep fd-find -y
RUN apt install sudo -y
RUN echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ubuntu

RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
RUN sudo apt install -y nodejs

USER ubuntu

WORKDIR /tmp
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --default-toolchain=1.95.0 -y
ENV PATH="/home/ubuntu/.cargo/bin:$PATH"

RUN rustup component add rust-analyzer
RUN cargo install cargo-binstall

RUN git clone https://github.com/njust/helix.git
WORKDIR /tmp/helix
RUN git checkout steel-event-system
RUN cargo xtask steel

ENV STEEL_JIT=false
RUN mkdir -p /home/ubuntu/.local/share/steel
RUN forge pkg install --git https://github.com/njust/streal.hx.git
RUN forge pkg install --git https://github.com/thomasschafer/scooter.hx.git

RUN mkdir -p /home/ubuntu/.config/helix/
RUN mv /tmp/helix/runtime/ /home/ubuntu/.config/helix/

WORKDIR /tmp
RUN case "$TARGETARCH" in \
  amd64) wget -q https://github.com/nushell/nushell/releases/download/0.113.1/nu-0.113.1-x86_64-unknown-linux-musl.tar.gz -O nu-musl.tar.gz \
         && tar xzf nu-musl.tar.gz \
         && sudo cp nu-0.113.1-x86_64-unknown-linux-musl/nu /usr/local/bin/nu ;; \
  arm64) wget -q https://github.com/nushell/nushell/releases/download/0.113.1/nu-0.113.1-aarch64-unknown-linux-musl.tar.gz -O nu-musl.tar.gz \
         && tar xzf nu-musl.tar.gz \
         && sudo cp nu-0.113.1-aarch64-unknown-linux-musl/nu /usr/local/bin/nu ;; \
esac

RUN cargo binstall -y zellij

RUN sudo npm install -g @earendil-works/pi-coding-agent
RUN pi install npm:pi-web-access

COPY --chown=ubuntu:ubuntu /config/pi /home/ubuntu/.pi/
COPY --chown=ubuntu:ubuntu config/zellij /home/ubuntu/.config/zellij/
COPY --chown=ubuntu:ubuntu config/nushell /home/ubuntu/.config/nushell/
COPY --chown=ubuntu:ubuntu config/helix /home/ubuntu/.config/helix/
COPY tools/ /usr/bin/

CMD ["/home/ubuntu/.cargo/bin/zellij"]
