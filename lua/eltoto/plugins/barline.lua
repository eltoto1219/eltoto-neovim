return {
    {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function ()
        local tabline = require("eltoto.ui.tabline")
        local processes = require("eltoto.processes")
        tabline.setup_highlights()
        tabline.register_autocmds()

        local function get_hl(name)
            local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
            return ok and hl or {}
        end

        local function to_hex(color)
            if type(color) ~= "number" then
                return nil
            end

            return string.format("#%06x", color)
        end

        local function tmux_indicator_color()
            local diff_add = get_hl("DiffAdd")
            local statusline = get_hl("StatusLine")

            return {
                fg = to_hex(diff_add.fg),
                bg = to_hex(statusline.bg),
            }
        end

        require('lualine').setup {
          options = {
            icons_enabled = true,
            theme = 'auto',
            component_separators = { left = '', right = ''},
            section_separators = { left = '', right = ''},
            disabled_filetypes = {
              statusline = {},
              winbar = {},
            },
            ignore_focus = {},
            always_divide_middle = true,
            globalstatus = true,
            refresh = {
              statusline = 1000,
              tabline = 1000,
              winbar = 1000,
            }
          },
          sections = {
            lualine_a = {'mode', 'FugitiveHead'},
            lualine_b = {'branch', 'diff'},
            lualine_c = {'filename',
                        {
                            require("noice").api.statusline.mode.get,
                            cond = require("noice").api.statusline.mode.has,
                            color = { fg = "#ff9e64" },
                        }
                    },
            lualine_x = {'encoding', 'fileformat', 'filetype',
                        {
                            function()
                                return "TMUX"
                            end,
                            cond = function()
                                return processes.current_process_name() ~= nil
                            end,
                            color = tmux_indicator_color,
                        },
                        {
                            'diagnostics',
                            icons_enabled = true,
                            sources = { 'nvim_lsp'},
                            -- Displays diagnostics for the defined severity types
                            sections = { 'error', 'warn', 'info', 'hint' },

                            diagnostics_color = {
                                -- Same values as the general color option can be used here.
                                error = 'DiagnosticError', -- Changes diagnostics' error color.
                                warn  = 'DiagnosticWarn',  -- Changes diagnostics' warn color.
                                info  = 'DiagnosticInfo',  -- Changes diagnostics' info color.
                                hint  = 'DiagnosticHint',  -- Changes diagnostics' hint color.
                            },
                            -- symbols = {error = 'E', warn = 'W', info = 'I', hint = 'H'},
                            colored = true,           -- Displays diagnostics status in color if set to true.
                            update_in_insert = false, -- Update diagnostics in insert mode.
                            always_visible = true,   -- Show diagnostics even if there are none.
                        }
            },
            lualine_y = {'progress'},
            lualine_z = {'location'}
          },
          inactive_sections = {
            lualine_a = {},
            lualine_b = {},
            lualine_c = {'filename'},
            lualine_x = {'location'},
            lualine_y = {},
            lualine_z = {}
          },
          tabline = {
                    lualine_a = { tabline.component },
                    lualine_b = {'branch'},
                    -- lualine_c = {'filename'},
                    lualine_x = {},
                    lualine_y = {},
                    lualine_z = {'tabs'}
                },
          winbar = {},
          inactive_winbar = {},
          extensions = {'quickfix', 'fugitive', 'mason', 'lazy'}
        }
    end

    }
}
