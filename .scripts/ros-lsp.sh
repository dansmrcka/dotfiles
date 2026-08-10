#!/bin/bash
# Runs a language server / tool inside the ROS environment that matches the project,
# while the editor stays on the host.
#
# Two backends:
#
#   docker     — repositories that carry their own development image and bind-mount the
#                workspace into it (edf_core: the host's <repo>/docker/development/ros2_ws
#                is the container's /home/f4f/ros2_ws). Selected by walking up from $PWD.
#   apptainer  — the older mrs_apptainer-ros{1,2} SIF images, selected by $ROS_DISTRO.
#                Those bind /home:/home, so host and container paths are identical and
#                nothing has to be translated.
#
# clang-format always runs natively on the host: it needs no ROS headers, only the
# .clang-format the repository ships.
#
# Set EDF_LSP_DEBUG=1 to log which backend was picked to /tmp/ros-lsp.log.

F4F_IMAGE="${F4F_IMAGE:-fly4future/mrs-system:dev}"
F4F_SYSROOT="${F4F_SYSROOT:-$HOME/.cache/f4f-sysroot}"
MASON_DIR="$HOME/.local/share/nvim/mason"

log() {
  if [ -n "${EDF_LSP_DEBUG:-}" ]; then
    echo "[ros-lsp $(date +%T)] $*" >>/tmp/ros-lsp.log
  fi
  return 0
}

# clang-format never needs a container — it reads no headers, only a style config. That
# is also how the apptainer backend has always done it.
#
# Nothing to arrange here: clang-format walks up from the file, so a package's own
# .clang-format wins, and anything without one reaches ~/.clang-format, since every
# checkout lives under $HOME. That walk is the only mechanism clang-format has — there is
# no user-level or XDG config, and --fallback-style takes a preset name, not a path.
if [ "$1" = "clang-format" ]; then
  exec clang-format "${@:2}"
fi

# --- docker backend -----------------------------------------------------------------

# Walks up from $1 looking for a checkout that bind-mounts a workspace into a dev
# container. colcon_defaults.yaml is the marker: it is tracked by the meta repo, unlike
# ros2_ws/src, which only exists after `vcs import`.
find_docker_ws() {
  local dir
  dir=$(cd "${1:-$PWD}" 2>/dev/null && pwd) || return 1
  while [ -n "$dir" ] && [ "$dir" != "/" ]; do
    if [ -f "$dir/docker/development/ros2_ws/colcon_defaults.yaml" ]; then
      echo "$dir/docker/development/ros2_ws"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

HOST_WS=$(find_docker_ws "${EDF_WS:-$PWD}") || HOST_WS=""

if [ -n "$HOST_WS" ] && [ "$1" = "clangd" ] && docker image inspect "$F4F_IMAGE" >/dev/null 2>&1; then
  CTR_WS=/home/f4f/ros2_ws
  log "docker backend: $HOST_WS -> $CTR_WS (pwd=$PWD)"

  # A throwaway container rather than `docker exec` into the running one: the LSP has to
  # work whether or not the simulation is up, and it must not be torn down by ./kill.sh.
  #
  # --path-mappings translates <client_path>=<server_path>, client being the editor on
  # the host and server being clangd in the container. First match wins; the three
  # prefixes below do not overlap. The sysroot entries are what make go-to-definition
  # into ROS and system headers land on a file the editor can actually open — populate
  # them with f4f-sysroot-sync.sh.
  #
  # clangd comes from mason over a read-only mount, so the image needs no rebuild. It is
  # an upstream LLVM release build and runs fine on the image's Ubuntu 24.04.
  #
  # --query-driver points at the container's GCC, the compiler compile_commands.json was
  # generated with, so clangd picks up the matching libstdc++ include paths.
  exec docker run --rm -i \
    --user "$(id -u):$(id -g)" \
    -e HOME=/home/f4f \
    -v "$HOST_WS:$CTR_WS" \
    -v "$MASON_DIR:$MASON_DIR:ro" \
    -w "$CTR_WS" \
    "$F4F_IMAGE" \
    "$MASON_DIR/bin/clangd" \
    --compile-commands-dir="$CTR_WS/build" \
    --path-mappings="$HOST_WS=$CTR_WS,$F4F_SYSROOT/opt/ros=/opt/ros,$F4F_SYSROOT/usr/include=/usr/include" \
    --query-driver=/usr/bin/c++ \
    --background-index \
    --clang-tidy \
    --header-insertion=iwyu \
    --completion-style=detailed \
    "${@:2}"
fi

# --- apptainer backend --------------------------------------------------------------

case "${ROS_DISTRO:-}" in
"noetic")
  SIF="$HOME/git/f4f/mrs_apptainer-ros1/images/mrs_uav_system.sif"
  SOURCE_CMD="source /opt/ros/noetic/setup.bash"
  ;;
"jazzy")
  SIF="$HOME/git/f4f/mrs_apptainer-ros2/images/mrs_uav_system_modified.sif"
  SOURCE_CMD="source /opt/ros/jazzy/setup.bash"
  ;;
*)
  log "no backend matched (ROS_DISTRO='${ROS_DISTRO:-}', pwd=$PWD); running natively: $*"
  exec "$@"
  ;;
esac

if [ ! -f "$SIF" ]; then
  log "SIF '$SIF' missing; running natively: $*"
  exec "$@"
fi

log "apptainer backend: $SIF"

if [ "$1" = "clangd" ]; then
  exec apptainer exec -e --bind /home:/home "$SIF" /bin/bash -c "$SOURCE_CMD && exec $MASON_DIR/bin/clangd \"\$@\"" -- "${@:2}"
fi

exec apptainer exec -e --bind /home:/home "$SIF" /bin/bash -c "$SOURCE_CMD && exec \"\$@\"" -- "$@"
