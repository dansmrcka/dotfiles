return {
  {
    "m4xshen/hardtime.nvim",
    lazy = false,
    dependencies = { "MunifTanjim/nui.nvim" },
    opts = {
      disable_mouse = true,
      max_time = 1000,
      max_count = 2,
    },
  },
  "stevearc/conform.nvim",
  opts = {
    formatters = {
      ros_clang_format = {
        command = "/home/daniel/git/personal-setup/scripts/ros-lsp.sh",
        -- 'clang-format' je první argument pro náš wrapper, zbytek jsou parametry pro clang-format
        args = { "clang-format", "-assume-filename", "$FILENAME" },
      },
    },
    formatters_by_ft = {
      cpp = { "ros_clang_format" },
      c = { "ros_clang_format" },
    },
  },
}
