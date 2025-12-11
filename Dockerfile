# cuda-dev/Dockerfile
ARG CUDA_VERSION=13.0.0-devel-ubuntu24.04
FROM nvidia/cuda:${CUDA_VERSION}
    # 12.8.0-devel-ubuntu24.04

ARG USER=dev
ARG UID=1000
ARG GID=1000

ENV DEBIAN_FRONTEND=noninteractive

# Core dev tooling
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        ninja-build \
        net-tools \
        file \
        vim \
        emacs \
        less \
        grep \
        sed \
        git \
        pipx \
        curl \
        wget \
        ca-certificates \
        zsh \
        tmux \
        less \
        nano \
        openssh-client \
        openssh-server \
        pkg-config \
        python3 \
        python3-pip \
        python3-venv \
        ripgrep \
        fd-find \
        htop \
        locales \
        sudo \
        tree \
        rsync \
        && rm -rf /var/lib/apt/lists/*

RUN pipx install gpustat

# Locale
RUN locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV PATH="/usr/local/cuda/bin:${PATH}"

# Create a non-root user that matches your host UID/GID
RUN groupadd -g ${GID} -o ${USER} && \
    useradd -m -u ${UID} -g ${GID} -s /usr/bin/zsh ${USER} && \
    echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER}

USER ${USER}
WORKDIR /workspace
ENV HOME=/home/${USER}

# --- Zsh + Oh My Zsh + Powerlevel10k theme ---

# Install Oh My Zsh (unattended)
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install Powerlevel10k
RUN git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
    ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k && \
    sed -i 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' $HOME/.zshrc

# Set zsh as default shell in the image
SHELL ["/usr/bin/zsh", "-lc"]

# Optional: install some Python packages you always want available
# RUN pip install --no-cache-dir numpy ipython

