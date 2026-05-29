#!/usr/bin/env bash
set -euo pipefail

GMX_VERSION="2026.2"
INSTALL_PREFIX="$HOME/apps/gromacs-${GMX_VERSION}-cuda"
SRC_DIR="$HOME/src"
CMAKE_MIN_MAJOR=3
CMAKE_MIN_MINOR=28

cmake_version_ok() {
  command -v cmake >/dev/null 2>&1 || return 1
  local ver major minor
  ver="$(cmake --version | head -1 | awk '{print $3}')"
  major="${ver%%.*}"
  minor="${ver#*.}"; minor="${minor%%.*}"
  [ "$major" -gt "$CMAKE_MIN_MAJOR" ] || { [ "$major" -eq "$CMAKE_MIN_MAJOR" ] && [ "$minor" -ge "$CMAKE_MIN_MINOR" ]; }
}

ensure_cmake() {
  if cmake_version_ok; then
    echo "CMake OK: $(cmake --version | head -1)"
    return 0
  fi
  echo "CMake >= ${CMAKE_MIN_MAJOR}.${CMAKE_MIN_MINOR} required for GROMACS ${GMX_VERSION} (Ubuntu 22.04 apt ships 3.22)."
  echo "Installing newer CMake from Kitware APT..."
  sudo apt-get update
  sudo apt-get install -y ca-certificates gpg wget
  wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null \
    | gpg --dearmor \
    | sudo tee /usr/share/keyrings/kitware-archive-keyring.gpg >/dev/null
  # shellcheck source=/dev/null
  . /etc/os-release
  echo "deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ ${VERSION_CODENAME} main" \
    | sudo tee /etc/apt/sources.list.d/kitware.list >/dev/null
  sudo apt-get update
  sudo apt-get install -y cmake
  if cmake_version_ok; then
    echo "CMake OK: $(cmake --version | head -1)"
    return 0
  fi
  echo "Kitware install did not yield CMake ${CMAKE_MIN_MAJOR}.${CMAKE_MIN_MINOR}+; trying pip..."
  python3 -m pip install --user --upgrade "cmake>=${CMAKE_MIN_MAJOR}.${CMAKE_MIN_MINOR}"
  export PATH="$HOME/.local/bin:$PATH"
  if cmake_version_ok; then
    echo "CMake OK: $(cmake --version | head -1)"
    return 0
  fi
  echo "ERROR: Could not install CMake >= ${CMAKE_MIN_MAJOR}.${CMAKE_MIN_MINOR}."
  exit 1
}

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

ensure_cmake

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
  -DGMX_BUILD_OWN_FFTW=OFF \
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
