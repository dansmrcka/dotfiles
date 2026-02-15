#!/bin/bash

# Výběr SIFu a setupu podle proměnné prostředí
case "$ROS_DISTRO" in
"noetic")
  SIF="$HOME/git/f4f/mrs_apptainer-ros1/images/mrs_uav_system.sif"
  SOURCE_CMD="source /opt/ros/noetic/setup.bash"
  ;;
"jazzy")
  SIF="$HOME/git/f4f/mrs_apptainer-ros2/images/mrs_uav_system.sif"
  SOURCE_CMD="source /opt/ros/jazzy/setup.bash"
  ;;
*)
  # Pokud není ROS_DISTRO nastaveno, nebo je "local", spustíme přímo na Fedoře
  exec "$@"
  ;;
esac

# Kontrola, zda SIF existuje, jinak fallback na local
if [ ! -f "$SIF" ]; then
  exec "$@"
fi

# Důležité: 'exec' nahradí shell procesem apptaineru, 'exec $*' nahradí vnitřní shell procesem clangd/clang-format
exec apptainer exec -e --bind /home:/home "$SIF" /bin/bash -c "$SOURCE_CMD && exec $*"
