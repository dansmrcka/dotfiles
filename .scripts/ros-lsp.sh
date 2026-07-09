#!/bin/bash

case "$ROS_DISTRO" in
"noetic")
  SIF="$HOME/git/f4f/mrs_apptainer-ros1/images/mrs_uav_system.sif"
  SOURCE_CMD="source /opt/ros/noetic/setup.bash"
  ;;
"jazzy")
  SIF="$HOME/git/f4f/mrs_apptainer-ros2/images/mrs_uav_system_modified.sif"
  SOURCE_CMD="source /opt/ros/jazzy/setup.bash"
  ;;
*)
  exec "$@"
  ;;
esac

if [ ! -f "$SIF" ]; then
  exec "$@"
fi

# clangd a clang-format běží lokálně
if [ "$1" = "clangd" ]; then
  exec apptainer exec -e --bind /home:/home "$SIF" /bin/bash -c "$SOURCE_CMD && exec /home/daniel/.local/share/nvim/mason/bin/clangd \"\$@\"" -- "${@:2}"
fi

if [ "$1" = "clang-format" ]; then
  exec clang-format "${@:2}"
fi

exec apptainer exec -e --bind /home:/home "$SIF" /bin/bash -c "$SOURCE_CMD && exec \"\$@\"" -- "$@"
