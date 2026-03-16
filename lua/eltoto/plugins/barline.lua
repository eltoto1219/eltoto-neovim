return {
    {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function ()
        local tabline = require("eltoto.ui.tabline")
        local processes = require("eltoto.processes")
        local colors = require("eltoto.ui.colors")
        tabline.setup_highlights()
        tabline.register_autocmds()

        local function mode_palette()
            local normal = colors.get_hl("Normal")
            local statusline = colors.get_hl("StatusLine")
            local tabline_hl = colors.get_hl("TabLine")
            local accent_sources = {
                normal = colors.get_hl("Function").fg or colors.get_hl("Identifier").fg or normal.fg,
                insert = colors.get_hl("DiffAdd").fg or colors.get_hl("String").fg or normal.fg,
                visual = colors.get_hl("Statement").fg or colors.get_hl("Special").fg or normal.fg,
                replace = colors.get_hl("DiagnosticWarn").fg or colors.get_hl("Constant").fg or normal.fg,
                command = colors.get_hl("Type").fg or colors.get_hl("PreProc").fg or normal.fg,
            }
            local base_bg = statusline.bg or tabline_hl.bg or normal.bg
            local base_fg = statusline.fg or normal.fg
            local muted_bg = colors.lighten(base_bg, 0.08, base_fg)
            local section_bg = colors.lighten(base_bg, 0.14, base_fg)
            local fill_bg = colors.lighten(base_bg, 0.2, base_fg)

            local function section(accent, amount, bold)
                return {
                    fg = colors.to_hex(base_fg),
                    bg = colors.to_hex(colors.lighten(base_bg, amount, accent or base_fg)),
                    bold = bold == true,
                }
            end

            local function neutral(bg)
                return {
                    fg = colors.to_hex(base_fg),
                    bg = colors.to_hex(bg),
                }
            end

            return {
                normal = {
                    a = section(accent_sources.normal, 0.34, true),
                    b = section(accent_sources.normal, 0.2, false),
                    c = neutral(section_bg),
                },
                insert = {
                    a = section(accent_sources.insert, 0.34, true),
                    b = section(accent_sources.insert, 0.2, false),
                    c = neutral(section_bg),
                },
                visual = {
                    a = section(accent_sources.visual, 0.34, true),
                    b = section(accent_sources.visual, 0.2, false),
                    c = neutral(section_bg),
                },
                replace = {
                    a = section(accent_sources.replace, 0.34, true),
                    b = section(accent_sources.replace, 0.2, false),
                    c = neutral(section_bg),
                },
                command = {
                    a = section(accent_sources.command, 0.34, true),
                    b = section(accent_sources.command, 0.2, false),
                    c = neutral(section_bg),
                },
                inactive = {
                    a = neutral(muted_bg),
                    b = neutral(muted_bg),
                    c = neutral(section_bg),
                },
                tabline = {
                    a = {
                        fg = colors.to_hex(base_fg),
                        bg = colors.to_hex(fill_bg),
                        bold = true,
                    },
                    b = neutral(section_bg),
                    c = neutral(section_bg),
                    x = neutral(section_bg),
                    y = neutral(section_bg),
                    z = neutral(fill_bg),
                },
            }
        end

        local function tmux_indicator_color()
            local diff_add = colors.get_hl("DiffAdd")
            local statusline = colors.get_hl("StatusLine")

            return {
                fg = colors.to_hex(diff_add.fg),
                bg = colors.to_hex(colors.lighten(statusline.bg or colors.get_hl("Normal").bg, 0.14, diff_add.fg)),
            }
        end

        local function lualine_config()
            local palette = mode_palette()

            return {
              options = {
                icons_enabled = true,
                theme = palette,
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
                                color = {
                                    fg = colors.to_hex(colors.get_hl("Special").fg or colors.get_hl("Statement").fg or colors.get_hl("StatusLine").fg or colors.get_hl("Normal").fg),
                                },
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
                                sections = { 'error', 'warn', 'info', 'hint' },

                                diagnostics_color = {
                                    error = 'DiagnosticError',
                                    warn  = 'DiagnosticWarn',
                                    info  = 'DiagnosticInfo',
                                    hint  = 'DiagnosticHint',
                                },
                                colored = true,
                                update_in_insert = false,
                                always_visible = true,
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
                        lualine_x = {},
                        lualine_y = {},
                        lualine_z = {{
                            'tabs',
                            tabs_color = {
                                active = {
                                    fg = colors.to_hex(colors.get_hl("Normal").fg),
                                    bg = colors.to_hex(colors.lighten((colors.get_hl("TabLineSel").bg or colors.get_hl("StatusLine").bg or colors.get_hl("Normal").bg), 0.18, colors.get_hl("TabLineSel").fg or colors.get_hl("Normal").fg)),
                                    bold = true,
                                },
                                inactive = {
                                    fg = colors.to_hex(colors.get_hl("TabLine").fg or colors.get_hl("Normal").fg),
                                    bg = colors.to_hex(colors.lighten((colors.get_hl("TabLine").bg or colors.get_hl("StatusLine").bg or colors.get_hl("Normal").bg), 0.08, colors.get_hl("TabLine").fg or colors.get_hl("Normal").fg)),
                                },
                            },
                        }}
                    },
              winbar = {},
              inactive_winbar = {},
              extensions = {'quickfix', 'fugitive', 'mason', 'lazy'}
            }
        end

        local function apply_lualine()
            require('lualine').setup(lualine_config())
        end

        apply_lualine()

        vim.api.nvim_create_autocmd("ColorScheme", {
            group = vim.api.nvim_create_augroup("EltotoLualineColors", { clear = true }),
            callback = function()
                apply_lualine()
            end,
        })
    end

    }
}
