-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Some .yaml/.yml files (e.g. tmuxinator configs like robot.yaml/simulator.yaml
-- in edf_core) are actually ERB templates without a .erb extension: the ERB
-- control tags (<% if %>/<% end %>) interleave with the YAML structure itself,
-- so the file isn't valid YAML on its own. That breaks treesitter (it needs a
-- parseable document) and, once a parser is installed, the eruby treesitter
-- grammar injects "html" as the host language, not yaml, so it's wrong anyway.
-- The old regex-based :syntax engine tolerates this fine (syntax/eruby.vim +
-- syntax/yaml.vim via b:eruby_subtype), but nvim doesn't enable it by default
-- while treesitter is active, so force both explicitly.
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = { "*.yaml", "*.yml" },
  group = vim.api.nvim_create_augroup("detect_erb_yaml", { clear = true }),
  callback = function(args)
    local lines = vim.api.nvim_buf_get_lines(args.buf, 0, -1, false)
    for _, line in ipairs(lines) do
      if line:find("<%%") then
        vim.b[args.buf].eruby_subtype = "yaml"
        vim.bo[args.buf].filetype = "eruby"
        -- Treesitter attaches for the new filetype via its own FileType
        -- autocmd, deferred with vim.schedule; defer our override the same
        -- way so it runs after that attach, not before it.
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(args.buf) then
            pcall(vim.treesitter.stop, args.buf)
            vim.bo[args.buf].syntax = "eruby"
          end
        end)
        break
      end
    end
  end,
})
