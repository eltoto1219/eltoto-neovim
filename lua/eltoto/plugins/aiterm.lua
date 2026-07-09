return {
	{
		dir = vim.fs.normalize("~/projects/plugins/aiterm.nvim"),
		lazy = false,
		priority = 900,
		opts = {
			ai = {
				autostart = true,
				kinds = {
					claude = { args = { "--dangerously-skip-permissions" } },
					codex = {
						args = {
							"--no-alt-screen",
							"--search",
							"--dangerously-bypass-approvals-and-sandbox",
						},
					},
				},
			},
			-- note: sessions created under an older prefix (eltoto-process-*)
			-- are invisible to the picker until renamed or killed in shpool
			processes = { enabled = true, session_prefix = "proc-" },
			treehouse = {
				enabled = true,
			},
			mappings = {
				buffers = {
					previous = "<leader>,",
					next = "<leader>;",
					alternate = "<leader>y",
					quit = "qq",
				},
				terminal = {
					toggle = "<leader>t",
					new = "<leader>T",
					previous = "<leader>,",
					next = "<leader>;",
				},
				ai = {
					toggle = "<leader>m",
					pick = "<leader>nn",
					kill = "<leader>nk",
					kill_all = "<leader>nK",
					new = "<leader>M",
				},
				processes = {
					pick = "<leader>pp",
					new = "<leader>pn",
					attach_last = "<leader>pa",
					attach_all = "<leader>pA",
					kill = "<leader>pk",
					kill_all = "<leader>pK",
				},
				treehouse = {
					acquire = "<leader>fa",
					lease = "<leader>fl",
					status = "<leader>fs",
					pick = "<leader>fw",
					return_ws = "<leader>fr",
				},
				run = {
					current_file = "<leader>e",
				},
			},
			tabline = { enabled = true },
		},
	},
}
