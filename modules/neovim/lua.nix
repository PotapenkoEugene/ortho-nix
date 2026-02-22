{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.nixvim.extraConfigLua = ''
    vim.opt.conceallevel = 1

    -- vim-highlighter: green as default color
    vim.api.nvim_set_hl(0, "HiColor1", { bg = "#2e7d32", fg = "#ffffff" })
    vim.api.nvim_set_hl(0, "HiColor2", { bg = "#c62828", fg = "#ffffff" })

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
  '';
}
