{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.nixvim.plugins = {
    lualine.enable = true;
    luasnip.enable = true;
    web-devicons.enable = true; # add because of warning
    telescope.enable = true;

    treesitter = {
      enable = true;
      folding = false;
      settings = {
        indent.enable = true;
        highlight.enable = true;
      };
      #   grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
      # python
      # markdown
      # markdown_inline
      # bash
      # nix
      # r
      #    ];
    };

    oil.enable = true; # view\rename\create files\dirs

    # LSP nixvim: https://nix-community.github.io/nixvim/lsp/index.html
    lsp = {
      enable = true;
      servers = {
        bashls.enable = true;
        nil_ls = {
          enable = true;
          settings = {
            nil = {
              formatting = {
                command = ["nixpkgs-fmt"];
              };
            };
          };
        };
      };
    };

    # Completion
    cmp-nvim-lsp.enable = false;
    cmp = {
      enable = true;
      autoEnableSources = true;
      autoLoad = true;

      settings = {
        sources = [
          #{ name = "nvim_lsp"; }
          {name = "buffer";}
          {name = "path";}
          {name = "luasnip";}
          {name = "codecompanion";}
        ];
        mapping = {
          "<CR>" = "cmp.mapping.confirm({ select = true })";
          "<Down>" = "cmp.mapping(cmp.mapping.select_next_item(), {'i', 's'})";
          "<Up>" = "cmp.mapping(cmp.mapping.select_prev_item(), {'i', 's'})";
        };
      };
    };

    # Jupyter-like
    image = {
      enable = true;
      settings = {
        backend = "kitty";
        processor = "magick_rock";
      };
    };
    quarto = {
      enable = true;
      settings = {
        codeRunner = {
          default_method = "molten";
        };
      };
    };
    jupytext = {
      enable = true;
      settings = {
        style = "markdown";
        output_extension = "md";
        force_ft = "markdown";
      };
    };
    otter = {
      enable = true;
    };
    molten = {
      enable = true;
      settings = {
        # Core options for molten (Keep it as it is)
        image_provider = "image.nvim";
        auto_open_output = true;
        wrap_output = true;
        virt_text_output = false;
        virt_lines_off_by_1 = true;

        ft = ["python" "norg" "markdown" "quarto"]; # not sure it's needed
      };
    };

    # AI
    #copilot
    copilot-vim = {
      enable = true;
      package = pkgs.vimPlugins.copilot-vim;
    };
    #codecompanion
    codecompanion = {
      enable = true;

      settings = {
        tools = {
          enable = true;
          files.enable = true;
          workspace.enable = true;
          codebase.enable = true;
        };
        opts = {
          log_level = "TRACE";
          send_code = true;
          use_default_actions = true;
          use_default_prompts = true;
          display = {
            action_palette = {
              provider = "telescope";
            };
            completion = {
              provider = "nvim-cmp";
            };
            command_palette = {
              provider = "telescope";
            };
            chat = {
              window = {
                width = 0.4;
                border = "rounded";
              };
            };
          };
          actions = {
            auto_import = true;
            auto_format = true;
          };
        };
        adapters = {
          openai = {
            __raw = ''
              function()
                return require("codecompanion.adapters").extend("openai", {
                  env = {
                    api_key = os.getenv("OPENAI_API_KEY"),
                  }
                })
              end
            '';
          };
          acp = {
            claude_code = {
              __raw = ''
                function()
                  return require("codecompanion.adapters").extend("claude_code", {
                    env = {
                      CLAUDE_CODE_OAUTH_TOKEN = os.getenv("CLAUDE_CODE_OAUTH_TOKEN"),
                    },
                  })
                end
              '';
            };
          };
        };
        strategies = {
          agent = {
            adapter = "claude_code";
          };
          chat = {
            adapter = "openai";
          };
          inline = {
            adapter = "openai";
          };
        };
        display = {
          chat = {
            window = {
              position = "right";
              width = 0.35;
            };
          };
        };
      };
    }; # codecompanion

    obsidian = {
      enable = true;
      autoLoad = true;
      settings = {
        legacy_commands = false;
        workspaces = [
          {
            name = "Personal";
            path = "/home/ortho/Orthidian/";
          }
        ];
        daily_notes = {
          folder = "daily";
          date_format = "%Y-%m-%d";
          template = "daily.md";
        };
        templates = {
          folder = "Templates";
          date_format = "%Y-%m-%d";
          time_format = "%H:%M";
        };
      };
    };
  }; # plugins

  programs.nixvim.extraPlugins = [
    (pkgs.vimUtils.buildVimPlugin {
      name = "pantran-nvim";
      src = pkgs.fetchFromGitHub {
        owner = "potamides";
        repo = "pantran.nvim";
        rev = "main";
        sha256 = "sha256-b4odpXwh+BmFsK5v3HmSWG43FA+ygOAPU+qFNy6vWDU=";
      };
    })
  ];
}
