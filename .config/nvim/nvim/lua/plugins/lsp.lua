return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      clangd = {
        -- Cesta k tvému wrapperu
        mason = false,
        cmd = { "/home/daniel/git/personal-setup/scripts/ros-lsp.sh", "clangd", "--background-index" },
      },
    },
  },
}
