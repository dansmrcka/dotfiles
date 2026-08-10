return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      clangd = {
        -- Wrapper spustí clangd v prostředí, které odpovídá projektu (docker image
        -- u edf_core, apptainer SIF u starších repozitářů). Flagy si nastavuje sám —
        -- liší se podle backendu (path-mappings, query-driver), takže tady zůstává
        -- jen "spusť clangd".
        mason = false,
        cmd = {
          vim.env.HOME .. "/.scripts/ros-lsp.sh",
          "clangd",
        },
      },
      -- Python balíčky (ros2_detection_visualizer) běží na hostovém pyrightu, ten ale
      -- rclpy nevidí. Ukazuje se na kopii ROS site-packages, kterou vytáhne
      -- ~/.scripts/f4f-sysroot-sync.sh. Neexistující cesta pyrightu nevadí.
      pyright = {
        settings = {
          python = {
            analysis = {
              extraPaths = {
                vim.env.HOME .. "/.cache/f4f-sysroot/opt/ros/jazzy/lib/python3.12/site-packages",
              },
            },
          },
        },
      },
    },
  },
}
