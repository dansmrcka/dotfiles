return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      clangd = {
        -- Cesta k tvému wrapperu
        mason = false,
        cmd = {
          vim.env.HOME .. "/.scripts/ros-lsp.sh",
          "clangd",
          "--background-index",
          "--query-driver=" .. vim.env.HOME .. "/.scripts/ros-lsp.sh",
        },
      },
    },
  },
}
