#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Echo the environment variables need to to build/configure standard
# GNU make/automake/configure projects.  e.g. CC, CXX, CFLAGS, etc.
# The values for these variables are calculated based on the following
# environment variables:
#
# $NACL_ARCH - i386, x86_64, arm or pnacl.  Default: x86_64
# $TOOLAHIN - bionic, newlib, glibc or pnacl.  Default: newlib
#
# To import these variables into your environment do:
# $ . nacl-env.sh
#
# Alternatively you can see just the essential environment
# variables by passing --print.  This can by used within
# a script using:
# eval `./nacl-env.sh --print`
#
# Finally you can run a command within the NaCl environment
# by passing the command line. e.g:
# ./nacl-env.sh make


if [ -z "${NACL_SDK_ROOT:-}" ]; then
  echo "-------------------------------------------------------------------"
  echo "NACL_SDK_ROOT is unset."
  echo "This environment variable needs to be pointed at some version of"
  echo "the Native Client SDK (the directory containing toolchain/)."
  echo "NOTE: set this to an absolute path."
  echo "-------------------------------------------------------------------"
  exit -1
fi

# Pick platform directory for compiler.
OS_NAME=$(uname -s)
if [ $OS_NAME = "Darwin" ]; then
  readonly OS_SUBDIR="mac"
elif [ $OS_NAME = "Linux" ]; then
  readonly OS_SUBDIR="linux"
else
  readonly OS_SUBDIR="win"
  if [ $(uname -o) = "Cygwin" ]; then
    OS_NAME="Cygwin"
  fi
fi

if [ $OS_NAME = "Cygwin" ]; then
  NACL_SDK_ROOT=`cygpath $NACL_SDK_ROOT`
  if [ -z "${CYGWIN:-}" ]; then
    export CYGWIN=nodosfilewarning
  fi
fi

if [ "$TOOLCHAIN" = "bionic" ]; then
  DEFAULT_ARCH=arm
elif [ "$TOOLCHAIN" = "pnacl" ]; then
  DEFAULT_ARCH=pnacl
else
  DEFAULT_ARCH=x86_64
fi

# Default value for NACL_ARCH
NACL_ARCH=${NACL_ARCH:-${DEFAULT_ARCH}}

# Default Value for TOOLCHAIN, taking into account legacy
# NACL_GLIBC varible.
if [ "${NACL_GLIBC:-}" = "1" ]; then
  echo "WARNING: \$NACL_GLIBC is deprecated (use \$TOOLCHAIN=glibc instead)"
  TOOLCHAIN=${TOOLCHAIN:-glibc}
else
  TOOLCHAIN=${TOOLCHAIN:-newlib}
fi

# Check NACL_ARCH
if [ ${NACL_ARCH} != "i686" -a ${NACL_ARCH} != "x86_64" -a \
     ${NACL_ARCH} != "arm" -a ${NACL_ARCH} != "pnacl" -a \
     ${NACL_ARCH} != "emscripten" ]; then
  echo "Unknown value for NACL_ARCH: '${NACL_ARCH}'" 1>&2
  exit -1
fi

# Check TOOLCHAIN
if [ ${TOOLCHAIN} != "newlib" -a ${TOOLCHAIN} != "pnacl" -a \
     ${TOOLCHAIN} != "glibc" -a ${TOOLCHAIN} != "bionic" ]; then
  echo "Unknown value for TOOLCHAIN: '${TOOLCHAIN}'" 1>&2
  exit -1
fi

if [ "${NACL_ARCH}" = "emscripten" -a -z "${PEPPERJS_SRC_ROOT:-}" ]; then
  echo "-------------------------------------------------------------------"
  echo "PEPPERJS_SRC_ROOT is unset."
  echo "This environment variable needs to be pointed at some version of"
  echo "the pepper.js repository."
  echo "NOTE: set this to an absolute path."
  echo "-------------------------------------------------------------------"
  exit -1
fi

if [ "${TOOLCHAIN}" = "pnacl" ]; then
  if [ "${NACL_ARCH}" != "pnacl" ]; then
    echo "PNaCl does not support the selected architecture: $NACL_ARCH" 1>&2
    exit -1
  fi
fi

if [ "${TOOLCHAIN}" = "glibc" ]; then
  if [ "${NACL_ARCH}" = "pnacl" ]; then
    echo "PNaCl is not supported by the glibc toolchain" 1>&2
    exit -1
  fi
  if [ "${NACL_ARCH}" = "arm" ]; then
    echo "ARM is not supported by the glibc toolcahin" 1>&2
    exit -1
  fi
  NACL_LIBC=glibc
elif [ "${TOOLCHAIN}" = "bionic" ]; then
  if [ "${NACL_ARCH}" != "arm" ]; then
    echo "Bionic toolchain only supports ARM" 1>&2
    exit -1
  fi
  NACL_LIBC=bionic
else
  NACL_LIBC=newlib
fi

# In some places i686 is also known as x86_32 so we use
# second variable to store this alternate architecture
# name
if [ "${NACL_ARCH}" = "i686" ]; then
  export NACL_ARCH_ALT=x86_32
else
  export NACL_ARCH_ALT=${NACL_ARCH}
fi

if [ ${NACL_ARCH} = "i686" ]; then
  readonly NACL_SEL_LDR=${NACL_SDK_ROOT}/tools/sel_ldr_x86_32
  readonly NACL_IRT=${NACL_SDK_ROOT}/tools/irt_core_x86_32.nexe
elif [ ${NACL_ARCH} = "x86_64" ]; then
  readonly NACL_SEL_LDR=${NACL_SDK_ROOT}/tools/sel_ldr_x86_64
  readonly NACL_IRT=${NACL_SDK_ROOT}/tools/irt_core_x86_64.nexe
elif [ ${NACL_ARCH} = "pnacl" ]; then
  readonly NACL_SEL_LDR_X8632=${NACL_SDK_ROOT}/tools/sel_ldr_x86_32
  readonly NACL_IRT_X8632=${NACL_SDK_ROOT}/tools/irt_core_x86_32.nexe
  readonly NACL_SEL_LDR_X8664=${NACL_SDK_ROOT}/tools/sel_ldr_x86_64
  readonly NACL_IRT_X8664=${NACL_SDK_ROOT}/tools/irt_core_x86_64.nexe
fi

# NACL_CROSS_PREFIX is the prefix of the executables in the
# toolchain's "bin" directory. For example: i686-nacl-<toolname>.
if [ ${NACL_ARCH} = "pnacl" ]; then
  NACL_CROSS_PREFIX=pnacl
elif [ ${NACL_ARCH} = "emscripten" ]; then
  NACL_CROSS_PREFIX=em
else
  NACL_CROSS_PREFIX=${NACL_ARCH}-nacl
fi

export NACL_LIBC
export NACL_ARCH
export NACL_CROSS_PREFIX

InitializeNaClGccToolchain() {
  if [ $NACL_ARCH = "arm" ]; then
    local TOOLCHAIN_ARCH="arm"
  else
    local TOOLCHAIN_ARCH="x86"
  fi

  local TOOLCHAIN_DIR=${OS_SUBDIR}_${TOOLCHAIN_ARCH}_${NACL_LIBC}

  readonly NACL_TOOLCHAIN_ROOT=${NACL_TOOLCHAIN_ROOT:-${NACL_SDK_ROOT}/toolchain/${TOOLCHAIN_DIR}}
  readonly NACL_BIN_PATH=${NACL_TOOLCHAIN_ROOT}/bin

  if [ ! -d "${NACL_TOOLCHAIN_ROOT}" ]; then
    echo "Toolchain not found: ${NACL_TOOLCHAIN_ROOT}"
    exit -1
  fi

  # export nacl tools for direct use in patches.
  export NACLCC=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-gcc
  export NACLCXX=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-g++
  export NACLAR=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-ar
  export NACLRANLIB=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-ranlib
  export NACLLD=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-ld
  export NACLSTRINGS=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-strings
  export NACLSTRIP=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-strip
  export NACLREADELF=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-readelf
  export NACL_EXEEXT=".nexe"

  if [ ${NACL_ARCH} = "arm" ]; then
    local NACL_LIBDIR=arm-nacl/lib
  elif [ ${NACL_ARCH} = "x86_64" ]; then
    local NACL_LIBDIR=x86_64-nacl/lib64
  else
    local NACL_LIBDIR=x86_64-nacl/lib32
  fi

  readonly NACL_SDK_LIB=${NACL_TOOLCHAIN_ROOT}/${NACL_LIBDIR}

  # There are a few .la files that ship with the SDK that
  # contain hardcoded paths that point to the build location
  # on the machine where the SDK itself was built.
  # TODO(sbc): remove this hack once these files are removed from the
  # SDK or fixed.
  LA_FILES=$(echo ${NACL_SDK_LIB}/*.la)
  if [ "${LA_FILES}" != "${NACL_SDK_LIB}/*.la" ]; then
    for LA_FILE in ${LA_FILES}; do
      mv ${LA_FILE} ${LA_FILE}.old
    done
  fi

  if [ "${NACL_DEBUG:-}" = "1" ]; then
    NACL_SDK_LIBDIR="${NACL_SDK_ROOT}/lib/${NACL_LIBC}_${NACL_ARCH_ALT}/Debug"
  else
    NACL_SDK_LIBDIR="${NACL_SDK_ROOT}/lib/${NACL_LIBC}_${NACL_ARCH_ALT}/Release"
  fi
}

InitializeEmscriptenToolchain() {
  local TC_ROOT=${NACL_SDK_ROOT}/toolchain
  local EM_ROOT=${PEPPERJS_SRC_ROOT}/emscripten

  # The PNaCl toolchain moved in pepper_31.  Check for
  # the existence of the old folder first and use that
  # if found.
  if [ -d "${TC_ROOT}/${OS_SUBDIR}_x86_pnacl" ]; then
    TC_ROOT=${TC_ROOT}/${OS_SUBDIR}_x86_pnacl/newlib
  elif [ -d "${TC_ROOT}/${OS_SUBDIR}_pnacl/newlib" ]; then
    TC_ROOT=${TC_ROOT}/${OS_SUBDIR}_pnacl/newlib
  else
    TC_ROOT=${TC_ROOT}/${OS_SUBDIR}_pnacl
  fi

  readonly NACL_TOOLCHAIN_ROOT=${EM_ROOT}
  readonly NACL_BIN_PATH=${EM_ROOT}

  # export emscripten tools for direct use in patches.
  export NACLCC=${EM_ROOT}/emcc
  export NACLCXX=${EM_ROOT}/em++
  export NACLAR=${EM_ROOT}/emar
  export NACLRANLIB=${EM_ROOT}/emranlib
  export NACLLD=${EM_ROOT}/em++
  export NACLSTRINGS=/bin/true
  export NACLSTRIP=/bin/true
  export NACL_EXEEXT=".js"
  export LLVM=${TC_ROOT}/bin

  if [ "${NACL_DEBUG:-}" = "1" ]; then
    NACL_SDK_LIBDIR="${PEPPERJS_SRC_ROOT}/lib/emscripten/Debug"
  else
    NACL_SDK_LIBDIR="${PEPPERJS_SRC_ROOT}/lib/emscripten/Release"
  fi
}

InitializePNaClToolchain() {
  local TC_ROOT=${NACL_SDK_ROOT}/toolchain
  # The PNaCl toolchain moved in pepper_31.  Check for
  # the existence of the old folder first and use that
  # if found.
  if [ -d "${TC_ROOT}/${OS_SUBDIR}_x86_pnacl" ]; then
    TC_ROOT=${TC_ROOT}/${OS_SUBDIR}_x86_pnacl/newlib
  elif [ -d "${TC_ROOT}/${OS_SUBDIR}_pnacl/newlib" ]; then
    TC_ROOT=${TC_ROOT}/${OS_SUBDIR}_pnacl/newlib
  else
    TC_ROOT=${TC_ROOT}/${OS_SUBDIR}_pnacl
  fi

  readonly NACL_TOOLCHAIN_ROOT=${NACL_TOOLCHAIN_ROOT:-${TC_ROOT}}
  readonly NACL_BIN_PATH=${NACL_TOOLCHAIN_ROOT}/bin

  # export nacl tools for direct use in patches.
  export NACLCC=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-clang
  export NACLCXX=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-clang++
  export NACLAR=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-ar
  export NACLRANLIB=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-ranlib
  export NACLREADELF=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-readelf
  export NACLLD=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-ld
  export NACLSTRINGS=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-strings
  export NACLSTRIP=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-strip
  # pnacl's translator
  export TRANSLATOR=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-translate
  export PNACLFINALIZE=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-finalize
  # pnacl's pexe optimizer
  export PNACL_OPT=${NACL_BIN_PATH}/${NACL_CROSS_PREFIX}-opt
  # TODO(robertm): figure our why we do not have a pnacl-string
  #export NACLSTRINGS=${NACL_BIN_PATH}/pnacl-strings
  # until then use the host's strings tool
  # (used only by the cairo package)
  export NACLSTRINGS="$(which strings)"
  export NACL_EXEEXT=".pexe"

  if [ "${NACL_DEBUG:-}" = "1" ]; then
    NACL_SDK_LIBDIR="${NACL_SDK_ROOT}/lib/${NACL_ARCH_ALT}/Debug"
  else
    NACL_SDK_LIBDIR="${NACL_SDK_ROOT}/lib/${NACL_ARCH_ALT}/Release"
  fi
}

NaClEnvExport() {
  export EXEEXT=${NACL_EXEEXT}
  export CC=${NACLCC}
  export CXX=${NACLCXX}
  export AR=${NACLAR}
  export RANLIB=${NACLRANLIB}
  export STRIP=${NACLSTRIP}
  export PKG_CONFIG_PATH=${NACL_PREFIX}/lib/pkgconfig
  export PKG_CONFIG_LIBDIR=${NACL_PREFIX}/lib/pkgconfig
  export PATH=${NACL_PREFIX}/bin:${PATH}:${NACL_BIN_PATH}
  export CPPFLAGS=${NACL_CPPFLAGS}
  export LDFLAGS=${NACL_LDFLAGS}
}

if [ "${NACL_ARCH}" = "pnacl" ]; then
  InitializePNaClToolchain
elif [ "${NACL_ARCH}" = "emscripten" ]; then
  InitializeEmscriptenToolchain
else
  InitializeNaClGccToolchain
fi

# As of version 33 the PNaCl C++ standard library is LLVM's libc++,
# others use GCC's libstdc++.
NACL_SDK_VERSION=$(${NACL_SDK_ROOT}/tools/getos.py --sdk-version)
if [ "${NACL_ARCH}" = "pnacl" -a ${NACL_SDK_VERSION} -gt 32 ]; then
  export NACL_CPP_LIB="c++"
else
  export NACL_CPP_LIB="stdc++"
fi

NACL_LDFLAGS="-L${NACL_SDK_LIBDIR}"
NACL_CPPFLAGS="-I${NACL_SDK_ROOT}/include"

if [ "${TOOLCHAIN}" = "glibc" ]; then
  NACL_LDFLAGS+=" -Wl,-rpath-link=${NACL_SDK_LIBDIR}"
fi

if [ "${NACL_ARCH}" = "pnacl" ]; then
  readonly NACL_PREFIX=${NACL_TOOLCHAIN_ROOT}/usr/local
elif [ "${NACL_ARCH}" = "emscripten" ]; then
  readonly NACL_PREFIX=${NACL_TOOLCHAIN_ROOT}/usr
else
  readonly NACL_PREFIX=${NACL_TOOLCHAIN_ROOT}/${NACL_CROSS_PREFIX}/usr
fi

if [ -z "${NACL_ENV_IMPORT:-}" ]; then
  if [ $# -gt 0 ]; then
    if [ "$1" = '--print' ]; then
      echo "export EXEEXT=${NACL_EXEEXT}"
      echo "export CC=${NACLCC}"
      echo "export CXX=${NACLCXX}"
      echo "export AR=${NACLAR}"
      echo "export RANLIB=${NACLRANLIB}"
      echo "export STRIP=${NACLSTRIP}"
      echo "export PKG_CONFIG_PATH=${NACL_PREFIX}/lib/pkgconfig"
      echo "export PKG_CONFIG_LIBDIR=${NACL_PREFIX}/lib/pkgconfig"
      echo "export PATH=${NACL_PREFIX}/bin:\${PATH}:${NACL_BIN_PATH}"
      echo "export CPPFLAGS=\"${NACL_CPPFLAGS}\""
      echo "export LDFLAGS=\"${NACL_LDFLAGS}\""
    else
      NaClEnvExport
      exec $@
    fi
  fi
fi
