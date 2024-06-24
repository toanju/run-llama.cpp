#!/usr/bin/env bash

set -euo pipefail

CDI_CONFIG="$HOME/.cdi/nvidia.yaml"
PODMAN_CONFIG="$HOME/.config/containers/containers.conf.d/99-engine-cdi-spec-dir.conf"
NVIDIA_REPO="/etc/yum.repos.d/nvidia-container-toolkit.repo"

# install nvidia ctk repo
if [ ! -f $NVIDIA_REPO ]; then
  curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo \
    | sudo tee "$NVIDIA_REPO"
  sudo dnf install nvidia-container-toolkit
fi

# check if cdi config exists
if [ ! -f "$CDI_CONFIG" ]; then
  nvidia-ctk cdi generate --output="$CDI_CONFIG"
fi

if [ ! -f "$PODMAN_CONFIG" ]; then
  mkdir -p "$(dirname "$PODMAN_CONFIG")"

  cat <<EOF >"$PODMAN_CONFIG"
[engine]
# Directories to scan for CDI Spec files.
#
cdi_spec_dirs = [
  "~/.cdi/",
]
EOF
fi

# install poetry
# pip install -U --user poetry
poetry install

# full image with all binaries 26.4 GB
#podman pull ghcr.io/ggerganov/llama.cpp:full-cuda

# server only image 2.41 GB
podman pull ghcr.io/ggerganov/llama.cpp:server-cuda

# download model
mkdir -p models
poetry run huggingface-cli download TheBloke/Llama-2-7b-Chat-GGUF llama-2-7b-chat.Q4_K_M.gguf --local-dir ./models/

# run llama.cpp server
podman run --rm --gpus all --security-opt=label=disable -p 8080:8080 -v ./models:/models:Z ghcr.io/ggerganov/llama.cpp:server-cuda -m /models/llama-2-7b-chat.Q4_K_M.gguf --port 8080 --host 0.0.0.0 -n 512 --n-gpu-layers 1 --keep -1 --chat-template llama2

#podman run --rm --gpus all  --security-opt=label=disable -v ./models:/models:Z ghcr.io/ggerganov/llama.cpp:full-cuda --run -m /models/llama-2-7b-chat.Q4_K_M.gguf -n 512 --n-gpu-layers 1 -p "Building a website can be done in 5 simple steps:"
