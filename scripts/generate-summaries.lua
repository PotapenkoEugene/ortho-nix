-- generate-summaries.lua — Headless wrapper: generate _summary.md for all projects.
--
-- Usage (run from ~/Orthidian so getcwd() is the vault root):
--   cd ~/Orthidian
--   nvim --headless --noplugin \
--     -c 'luafile ~/.config/home-manager/scripts/generate-summaries.lua' \
--     -c 'qa!'
--
-- Sets vim.g.obsidian_generate_summaries_only before loading the main script,
-- which causes obsidian_daily_notes.lua to skip the interactive open/generate path
-- and only call generate_summaries().

vim.g.obsidian_generate_summaries_only = true
dofile(vim.fn.expand("~/.config/home-manager/scripts/obsidian_daily_notes.lua"))
