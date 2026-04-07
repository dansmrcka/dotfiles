return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      clangd = {
        -- Cesta k tvému wrapperu
        mason = false,
        cmd = { vim.env.HOME .. "/.1scripts/ros-lsp.sh", "clangd", "--background-index" },
      },
    },
  },
}
