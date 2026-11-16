# Source this file: sets up the devkitPro environment installed by setup-toolchain.sh
_here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DEVKITPRO="${DEVKITPRO_OVERRIDE:-$_here/build/toolchain/opt/devkitpro}"
export DEVKITARM="$DEVKITPRO/devkitARM"
export PATH="$_here/build/toolchain/bin:$DEVKITPRO/tools/bin:$DEVKITARM/bin:$PATH"
unset _here
