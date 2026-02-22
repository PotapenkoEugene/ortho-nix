{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.nixvim.keymaps = [
    # Main
    {
      mode = ["n" "v"];
      key = "<leader><leader>";
      action = "<C-^>";
      options = {
        desc = "Toggle to previous buffer";
        silent = true;
      };
    }

    {
      mode = ["v"];
      key = "<leader>y";
      action = "\"+y";
      options = {
        desc = "Copy to clipboard";
        silent = true;
      };
    }

    # Rebind Tab to Esc in Normal, Insert, and Visual modes
    {
      mode = ["i"]; # Added 'v' for Visual mode
      key = "jk";
      action = "<Esc>";
    }
    # telescope
    {
      action = "<cmd>Telescope find_files<CR>";
      key = "<leader>ff";
    }
    {
      action = "<cmd>Telescope live_grep<CR>";
      key = "<leader>fg";
    }
    {
      action = "<cmd>Telescope buffers<CR>";
      key = "<leader>fb";
    }
    {
      action = "<cmd>Telescope help_tags<CR>";
      key = "<leader>fh";
    }

    #-- Copy :messages to system clipboard
    {
      mode = ["n" "v"];
      key = "<leader>lc";
      action = "<cmd>redir @+<CR><cmd>silent messages<CR><cmd>redir END<CR>";
      options = {
        desc = "Copy Neovim messages to clipboard";
        silent = true;
      };
    }
    # codecompanion
    {
      mode = ["n" "v"];
      key = "<leader>aa";
      action = "<cmd>CodeCompanionActions<CR>";
      options = {
        desc = "CodeCompanion actions";
        silent = true;
      };
    }

    {
      mode = ["n" "v"];
      key = "<leader>ac";
      action = "<cmd>CodeCompanionChat<CR>";
      options = {
        desc = "CodeCompanion chat";
        silent = true;
      };
    }

    # Molten
    {
      mode = ["n" "v" "i"];
      key = "<leader>ml";
      action = "<cmd>MoltenEvaluateLine<CR>";
      options = {
        desc = "Execute current line";
        silent = true;
      };
    }

    {
      mode = ["n" "v"];
      key = "<leader>mc";
      action = "<cmd>lua local cur=vim.fn.line('.') local s=vim.fn.search('^```', 'bn') local e=vim.fn.search('^```', 'n') vim.api.nvim_buf_set_mark(0, '<', s+1, 0, {}) vim.api.nvim_buf_set_mark(0, '>', e-1, 1000, {}) vim.cmd('MoltenEvaluateVisual')<CR>";
      options = {
        desc = "Execute current chunk";
        silent = true;
      };
    }

    {
      mode = ["n" "v" "i"];
      key = "<leader>ma";
      action = "<cmd>MoltenReevaluateAll<CR>";
      options = {
        desc = "Execute all";
        silent = true;
      };
    }

    {
      mode = ["n" "v" "i"];
      key = "<leader>mn";
      action = "<cmd>MoltenNext<CR>";
      options = {
        desc = "Go next chunk";
        silent = true;
      };
    }

    {
      mode = ["n" "v" "i"];
      key = "<leader>mp";
      action = "<cmd>MoltenPrev<CR>";
      options = {
        desc = "Go previous chunk";
        silent = true;
      };
    }

    {
      mode = ["n" "v"];
      key = "<leader>mh";
      action = "<cmd>MoltenHideOutput<CR>";
      options = {
        desc = "Hide output window";
        silent = true;
      };
    }

    {
      mode = ["n" "v"];
      key = "<leader>ms";
      action = "<cmd>MoltenShowOutput<CR>";
      options = {
        desc = "Show output window";
        silent = true;
      };
    }

    # Translation (vim-translator) — popup shows translation without leaving context
    {
      mode = ["n"];
      key = "<leader>tw";
      action.__raw = ''
        function()
          local word = vim.fn.expand('<cword>')
          local file = io.open(os.getenv("HOME") .. "/Orthidian/personal/english.md", "a")
          if file then
            file:write("- " .. word .. "\n")
            file:close()
          end
          vim.cmd('TranslateW')
        end
      '';
      options = {
        desc = "Translate word (popup + save)";
        silent = true;
      };
    }
    {
      mode = ["n"];
      key = "<leader>ts";
      action = "vis:TranslateW<CR>";
      options = {
        desc = "Translate sentence (popup)";
        silent = true;
      };
    }

    # Links
    {
      mode = ["n"];
      key = "<leader>gl";
      action.__raw = ''
        function()
          local word = vim.fn.expand('<cWORD>')
          local url = word:match("https?://[%w%./_%-~:@!%$&*+,;=%%?#]+")
            or word:match("doi:[%w%./_%-]+")
          if url then vim.ui.open((url:gsub('^doi:', 'https://doi.org/'))) end
        end
      '';
      options = {
        desc = "Open link under cursor";
        silent = true;
      };
    }

    # Highlighter
    {
      mode = ["n"];
      key = "<leader>hg";
      action.__raw = ''
        function()
          vim.fn.feedkeys("vis1f\r", "")
        end
      '';
      options = {
        desc = "Highlight sentence green";
        silent = true;
      };
    }
    {
      mode = ["v"];
      key = "<leader>hg";
      action.__raw = ''
        function()
          vim.fn.feedkeys("1f\r", "")
        end
      '';
      options = {
        desc = "Highlight selection green";
        silent = true;
      };
    }
    {
      mode = ["n"];
      key = "<leader>hr";
      action.__raw = ''
        function()
          vim.fn.feedkeys("vis2f\r", "")
        end
      '';
      options = {
        desc = "Highlight sentence red";
        silent = true;
      };
    }
    {
      mode = ["v"];
      key = "<leader>hr";
      action.__raw = ''
        function()
          vim.fn.feedkeys("2f\r", "")
        end
      '';
      options = {
        desc = "Highlight selection red";
        silent = true;
      };
    }

    {
      mode = ["n" "v"];
      key = "<leader>h<BS>";
      action.__raw = ''
        function()
          local bs = vim.api.nvim_replace_termcodes("f<BS>", true, false, true)
          vim.api.nvim_feedkeys(bs, "m", false)
        end
      '';
      options = {
        desc = "Remove highlight under cursor";
        silent = true;
      };
    }

    # Obsidian
    {
      mode = ["n"];
      key = "<leader>on";
      action = "<cmd>ObsidianNew<CR>";
      options = {
        desc = "Create new Obsidian note";
        silent = true;
      };
    }

    {
      mode = ["n"];
      key = "<leader>od";
      action.__raw = ''
        function()
          -- TEMP path
          ${builtins.readFile ../../scripts/obsidian_daily_notes.lua}
        end
      '';
      options = {
        desc = "Open Obsidian daily notes";
        silent = true;
      };
    }
  ];
}
