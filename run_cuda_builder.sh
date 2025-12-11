#!/bin/bash
set -e

# This script builds and runs a Docker container with CUDA 13.0 support
# for Hopper (sm_90) and Blackwell (sm_100).

# 1. Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker daemon is not running."
    echo "Please start Docker Desktop and try again."
    open -a Docker 2>/dev/null || true
    exit 1
fi

IMAGE_NAME="cuda-blackwell-builder"

# 2. Detect Host User details
HOST_USER=$(whoami)
HOST_UID=$(id -u)
HOST_GID=$(id -g)

# Setup SSH Agent forwarding arguments based on OS
SSH_ARGS=""
if [[ "$(uname)" == "Darwin" ]]; then
    # Docker Desktop on macOS
    SSH_ARGS="-v /run/host-services/ssh-auth.sock:/ssh-agent -e SSH_AUTH_SOCK=/ssh-agent"
    # Ensure docker-credential-desktop is in PATH
    export PATH="$PATH:/Applications/Docker.app/Contents/Resources/bin"
elif [ -n "$SSH_AUTH_SOCK" ]; then
    # Linux
    SSH_ARGS="-v $SSH_AUTH_SOCK:/ssh-agent -e SSH_AUTH_SOCK=/ssh-agent"
fi

# 3. Check for Apple Silicon
ARCH=$(uname -m)
PLATFORM_FLAG="--platform linux/amd64"
if [[ "$ARCH" == "arm64" ]]; then
    echo "Detected Apple Silicon (arm64). Forcing linux/amd64..."
fi

# CUDA Version Selection
# Default to 13.0.0 if not specified
CUDA_VERSION=${1:-"13.0.0-devel-ubuntu24.04"}
# Sanitize the version string for use in image tag (replace ':' and '/' with '-')
VERSION_TAG=$(echo "$CUDA_VERSION" | sed 's/[:\/]/-/g')
IMAGE_NAME="cuda-blackwell-builder:${VERSION_TAG}"

# Calculate SSH Port: 22 + Major + Minor (e.g., 13.0 -> 22130, 12.8 -> 22128)
# Extract major and minor version (assuming format X.Y.Z...)
MAJOR=$(echo "$CUDA_VERSION" | cut -d. -f1)
MINOR=$(echo "$CUDA_VERSION" | cut -d. -f2)
SSH_PORT="22${MAJOR}${MINOR}"

# Hostname: gpu-dev-<major><minor>
HOSTNAME="gpu-dev-${MAJOR}_${MINOR}"

echo "Using CUDA Image: nvidia/cuda:$CUDA_VERSION"
echo "Target Image Name: $IMAGE_NAME"
echo "SSH Port: $SSH_PORT"
echo "Hostname: $HOSTNAME"

# Check if image exists before building
if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    echo "Image '$IMAGE_NAME' not found. Building..."
    echo "  User: $HOST_USER (UID: $HOST_UID, GID: $HOST_GID)"

    # 4. Build the image with current user mapping
    docker build $PLATFORM_FLAG --ssh default \
    -t $IMAGE_NAME \
    --build-arg USER=$HOST_USER \
    --build-arg UID=$HOST_UID \
    --build-arg GID=$HOST_GID \
    --build-arg CUDA_VERSION=$CUDA_VERSION \
    .
else
    echo "Image '$IMAGE_NAME' already exists. Skipping build."
    echo "To force rebuild, run: docker rmi $IMAGE_NAME"
fi

echo ""
echo "Starting container..."
echo "Mounting $(pwd) to /workspace"

# 5. Run the container
echo "Checking for existing container..."
CONTAINER_NAME="cuda-builder-${VERSION_TAG}"

if [ "$(docker ps -q -f name=${CONTAINER_NAME})" ]; then
    echo "Container '${CONTAINER_NAME}' is already running."
elif [ "$(docker ps -aq -f name=${CONTAINER_NAME})" ]; then
    echo "Starting existing '${CONTAINER_NAME}' container..."
    docker start ${CONTAINER_NAME}
else
    echo "Creating and starting new '${CONTAINER_NAME}' container..."
    docker run -d \
        --platform linux/amd64 \
        --name ${CONTAINER_NAME} \
        --hostname ${HOSTNAME} \
        --restart unless-stopped \
        -p ${SSH_PORT}:22 \
        $SSH_ARGS \
    -v "$(pwd):/workspace" \
        -v "$HOME/.ssh:/tmp/host_ssh:ro" \
    -w /workspace \
    $IMAGE_NAME \
        bash -c "sudo service ssh start; \
                 mkdir -p \$HOME/.ssh; \
                 cat /tmp/host_ssh/*.pub > \$HOME/.ssh/authorized_keys 2>/dev/null || true; \
                 chmod 700 \$HOME/.ssh; \
                 chmod 600 \$HOME/.ssh/authorized_keys; \
                 # Link p10k config if present
                 if [ -f /workspace/dot-p10k.zsh ]; then
                     ln -sf /workspace/dot-p10k.zsh \$HOME/.p10k.zsh
                 # Ensure we don't start the wizard by pre-defining the variable
                 echo 'typeset -g POWERLEVEL9K_INSTANT_PROMPT=off' >> \$HOME/.zshrc
                 grep -q 'source.*p10k.zsh' \$HOME/.zshrc || echo '[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh' >> \$HOME/.zshrc
                 
                 # Ensure nvcc is in path
                 grep -q 'export PATH="/usr/local/cuda/bin:\$PATH"' \$HOME/.zshrc || echo 'export PATH="/usr/local/cuda/bin:\$PATH"' >> \$HOME/.zshrc
             fi; \
             tail -f /dev/null"
fi

echo "Container '${CONTAINER_NAME}' is running."
echo "SSH access: ssh -p $SSH_PORT $HOST_USER@localhost"
echo "Attach: docker exec -it ${CONTAINER_NAME} zsh"
