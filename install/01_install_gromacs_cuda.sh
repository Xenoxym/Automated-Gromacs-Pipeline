#!/usr/bin/env bash
set -euo pipefail

GMX_VERSION="2026.2"
INSTALL_PREFIX="$HOME/apps/gromacs-${GMX_VERSION}-cuda"
SRC_DIR="$HOME/src"

if ! command -v nvidia-smi >/dev/null 2>&1; then
  echo "ERROR: nvidia-smi not found. Install/update Windows NVIDIA Driver with WSL support first."
  exit 1
fi

if ! command -v nvcc >/dev/null 2>&1; then
  echo "nvcc not found. Installing CUDA Toolkit from NVIDIA WSL repo..."
  cd /tmp
  wget -nc https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-keyring_1.1-1_all.deb
  sudo dpkg -i cuda-keyring_1.1-1_all.deb
  sudo apt update
  sudo apt install -y cuda-toolkit
fi

mkdir -p "$SRC_DIR" "$HOME/apps"
cd "$SRC_DIR"

wget -nc "https://ftp.gromacs.org/gromacs/gromacs-${GMX_VERSION}.tar.gz"
[ -d "gromacs-${GMX_VERSION}" ] || tar xfz "gromacs-${GMX_VERSION}.tar.gz"

cd "gromacs-${GMX_VERSION}"
rm -rf build
mkdir build
cd build

cmake .. \
  -G Ninja \
  -DGMX_GPU=CUDA \
  -DGMX_BUILD_OWN_FFTW=ON \
  -DREGRESSIONTEST_DOWNLOAD=ON \
  -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
  -DCMAKE_CUDA_ARCHITECTURES=89

ninja -j"$(nproc)"
ctest --output-on-failure
ninja install

if ! grep -q "gromacs-${GMX_VERSION}-cuda/bin/GMXRC" "$HOME/.bashrc"; then
  echo "source $INSTALL_PREFIX/bin/GMXRC" >> "$HOME/.bashrc"
fi

source "$INSTALL_PREFIX/bin/GMXRC"
gmx --version

echo "GROMACS CUDA installed. Restart shell or run: source ~/.bashrc"
