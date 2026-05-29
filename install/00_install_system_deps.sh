#!/usr/bin/env bash
set -euo pipefail

sudo apt update
sudo apt upgrade -y
sudo apt install -y \
  build-essential \
  cmake \
  git \
  wget \
  curl \
  tar \
  unzip \
  pkg-config \
  ninja-build \
  python3 \
  python3-pip \
  libfftw3-dev \
  libopenmpi-dev \
  openmpi-bin \
  htop \
  tree \
  dos2unix

echo "System dependencies installed."
echo "Check GPU with: nvidia-smi"
