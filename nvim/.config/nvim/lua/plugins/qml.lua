-- QML for the Quickshell config. LazyVim has no QML extra, so set it up here.
-- qmlls ships with qt6-declarative (pulled in by quickshell) but isn't on PATH,
-- and Mason doesn't provide it.
return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "qmljs" } },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        qmlls = {
          mason = false,
          cmd = { "/usr/lib/qt6/bin/qmlls" },
        },
      },
    },
  },
}
