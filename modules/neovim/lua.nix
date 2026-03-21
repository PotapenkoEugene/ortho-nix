{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.nixvim.extraConfigLua = ''
      vim.opt.conceallevel = 1

      -- vim-highlighter: colors and auto-save/load
      vim.api.nvim_set_hl(0, "HiColor1", { bg = "#2e7d32", fg = "#ffffff" })
      vim.api.nvim_set_hl(0, "HiColor2", { bg = "#c62828", fg = "#ffffff" })

      vim.g.HiSyncMode = 0

      local function hi_filepath()
        local path = vim.api.nvim_buf_get_name(0)
        if path == "" or vim.bo.buftype ~= "" then return nil end
        return path
      end

      local function hi_file_for(path)
        return path .. ".hl"
      end

      -- Check if .hl file has actual highlights (more than 2-line header)
      local function hi_file_has_data(hlpath)
        local f = io.open(hlpath, "r")
        if not f then return false end
        local count = 0
        for _ in f:lines() do
          count = count + 1
          if count > 2 then f:close(); return true end
        end
        f:close()
        return false
      end

      local hi_group = vim.api.nvim_create_augroup("HiAutoSave", { clear = true })
      vim.api.nvim_create_autocmd({ "BufLeave", "VimLeave" }, {
        group = hi_group,
        callback = function()
          local path = hi_filepath()
          if not path then return end
          local hlpath = hi_file_for(path)
          pcall(vim.cmd, "silent! Hi save " .. vim.fn.fnameescape(path))
          -- Delete .hl file if it only has the 2-line header (no highlights)
          if not hi_file_has_data(hlpath) then
            os.remove(hlpath)
            -- Also remove backup file if it exists
            os.remove(hlpath .. ".o")
          end
        end,
      })
      vim.api.nvim_create_autocmd("BufReadPost", {
        group = hi_group,
        callback = function()
          local path = hi_filepath()
          if not path then return end
          local hlpath = hi_file_for(path)
          -- Only load if .hl file exists and has data
          if hi_file_has_data(hlpath) then
            pcall(vim.cmd, "silent! Hi load " .. vim.fn.fnameescape(path))
          end
        end,
      })

      -- cursor beacon: flash on large jumps
      do
        local last_line = 0
        local ns = vim.api.nvim_create_namespace("beacon")
        vim.api.nvim_create_autocmd("CursorMoved", {
          callback = function()
            local cur = vim.fn.line(".")
            if math.abs(cur - last_line) > 5 then
              local buf = vim.api.nvim_get_current_buf()
              vim.api.nvim_buf_add_highlight(buf, ns, "Visual", cur - 1, 0, -1)
              vim.defer_fn(function()
                pcall(vim.api.nvim_buf_clear_namespace, buf, ns, 0, -1)
              end, 300)
            end
            last_line = cur
          end,
        })
      end

      -- vim-translator (lightweight floating popup)
      vim.g.translator_target_lang = "ru"
      vim.g.translator_default_engines = {"google"}
      vim.g.translator_window_type = "popup"
      vim.g.translator_window_max_width = 0.6
      vim.g.translator_window_max_height = 0.6

      local default_notebook = [[
      {
        "cells": [
          {
            "cell_type": "markdown",
            "metadata": {},
            "source": [""]
          }
        ],
        "metadata": {
          "kernelspec": {
            "display_name": "Python 3",
            "language": "python",
            "name": "python3"
          },
          "language_info": {
            "codemirror_mode": {
              "name": "ipython"
            },
            "file_extension": ".py",
            "mimetype": "text/x-python",
            "name": "python",
            "nbconvert_exporter": "python",
            "pygments_lexer": "ipython3"
          }
        },
        "nbformat": 4,
        "nbformat_minor": 5
      }
      ]]
      local function new_notebook(filename)
        local path = vim.fn.expand(filename) .. ".ipynb"
        local file = io.open(path, "w")
        if file then
          file:write(default_notebook)
          file:close()
          vim.cmd("edit " .. path)
        else
          vim.notify("Error: Could not create notebook file", vim.log.levels.ERROR)
        end
      end

      vim.api.nvim_create_user_command("NewNotebook", function(opts)
        new_notebook(opts.args)
      end, {
        nargs = 1,
        complete = "file",
      })

    require("tv").setup({})
  '';
}
