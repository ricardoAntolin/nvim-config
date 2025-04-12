local utils = require("utils")

<<<<<<< HEAD
=======
-- set quickfix list from diagnostics in a certain buffer, not the whole workspace
local set_qflist = function(buf_num, severity)
  local diagnostics = nil
  diagnostics = diagnostic.get(buf_num, { severity = severity })

  local qf_items = diagnostic.toqflist(diagnostics)
  vim.fn.setqflist({}, " ", { title = "Diagnostics", items = qf_items })

  -- open quickfix by default
  vim.cmd([[copen]])
end

local custom_attach = function(client, bufnr)
  -- Mappings.
  local map = function(mode, l, r, opts)
    opts = opts or {}
    opts.silent = true
    opts.buffer = bufnr
    keymap.set(mode, l, r, opts)
  end

  map("n", "gd", vim.lsp.buf.definition, { desc = "go to definition" })
  map("n", "gi", vim.lsp.buf.implementation, { desc = "go to implementation" })
    map("n", "K", function()
      vim.lsp.buf.hover { border = "single", max_height = 25, max_width = 120 }
    end)
  map("n", "<C-k>", vim.lsp.buf.signature_help)
  map("n", "<space>rn", vim.lsp.buf.rename, { desc = "varialbe rename" })
  map("n", "gr", vim.lsp.buf.references, { desc = "show references" })
  map("n", "<space>qb", function()
    set_qflist(bufnr)
  end, { desc = "put buffer diagnostics to qf" })
  map("n", "<space>ca", vim.lsp.buf.code_action, { desc = "LSP code action" })
  map("n", "<space>wa", vim.lsp.buf.add_workspace_folder, { desc = "add workspace folder" })
  map("n", "<space>wr", vim.lsp.buf.remove_workspace_folder, { desc = "remove workspace folder" })
  map("n", "<space>wl", function()
    vim.print(vim.lsp.buf.list_workspace_folders())
  end, { desc = "list workspace folder" })

  -- Set some key bindings conditional on server capabilities
  if client.server_capabilities.documentFormattingProvider and client.name ~= "lua_ls" then
    map({ "n", "x" }, "<space>f", vim.lsp.buf.format, { desc = "format code" })
  end

  -- Uncomment code below to enable inlay hint from language server, some LSP server supports inlay hint,
  -- but disable this feature by default, so you may need to enable inlay hint in the LSP server config.
  -- vim.lsp.inlay_hint.enable(true, {buffer=bufnr})

  api.nvim_create_autocmd("CursorHold", {
    buffer = bufnr,
    callback = function()
      local float_opts = {
        focusable = false,
        close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
        border = "rounded",
        source = "always", -- show source in diagnostic popup window
        prefix = " ",
      }

      if not vim.b.diagnostics_pos then
        vim.b.diagnostics_pos = { nil, nil }
      end

      local cursor_pos = api.nvim_win_get_cursor(0)
      if
        (cursor_pos[1] ~= vim.b.diagnostics_pos[1] or cursor_pos[2] ~= vim.b.diagnostics_pos[2])
        and #diagnostic.get() > 0
      then
        diagnostic.open_float(nil, float_opts)
      end

      vim.b.diagnostics_pos = cursor_pos
    end,
  })

  -- The blow command will highlight the current variable and its usages in the buffer.
  if client.server_capabilities.documentHighlightProvider then
    vim.cmd([[
      hi! link LspReferenceRead Visual
      hi! link LspReferenceText Visual
      hi! link LspReferenceWrite Visual
    ]])

    local gid = api.nvim_create_augroup("lsp_document_highlight", { clear = true })
    api.nvim_create_autocmd("CursorHold", {
      group = gid,
      buffer = bufnr,
      callback = function()
        lsp.buf.document_highlight()
      end,
    })

    api.nvim_create_autocmd("CursorMoved", {
      group = gid,
      buffer = bufnr,
      callback = function()
        lsp.buf.clear_references()
      end,
    })
  end

  if vim.g.logging_level == "debug" then
    local msg = string.format("Language server %s started!", client.name)
    vim.notify(msg, vim.log.levels.DEBUG, { title = "Nvim-config" })
  end
end

local capabilities = vim.lsp.protocol.make_client_capabilities()

-- required by nvim-ufo
capabilities.textDocument.foldingRange = {
  dynamicRegistration = false,
  lineFoldingOnly = true,
}

-- For what diagnostic is enabled in which type checking mode, check doc:
-- https://github.com/microsoft/pyright/blob/main/docs/configuration.md#diagnostic-settings-defaults
-- Currently, the pyright also has some issues displaying hover documentation:
-- https://www.reddit.com/r/neovim/comments/1gdv1rc/what_is_causeing_the_lsp_hover_docs_to_looks_like/

if utils.executable("pyright") then
  local new_capability = {
    -- this will remove some of the diagnostics that duplicates those from ruff, idea taken and adapted from
    -- here: https://github.com/astral-sh/ruff-lsp/issues/384#issuecomment-1989619482
    textDocument = {
      publishDiagnostics = {
        tagSupport = {
          valueSet = { 2 },
        },
      },
      hover = {
        contentFormat = { "plaintext" },
        dynamicRegistration = true,
      },
    },
  }
  local merged_capability = vim.tbl_deep_extend("force", capabilities, new_capability)

  lspconfig.pyright.setup {
    cmd = { "delance-langserver", "--stdio" },
    on_attach = custom_attach,
    capabilities = merged_capability,
    settings = {
      pyright = {
        -- disable import sorting and use Ruff for this
        disableOrganizeImports = true,
        disableTaggedHints = false,
      },
      python = {
        analysis = {
          autoSearchPaths = true,
          diagnosticMode = "workspace",
          typeCheckingMode = "standard",
          useLibraryCodeForTypes = true,
          -- we can this setting below to redefine some diagnostics
          diagnosticSeverityOverrides = {
            deprecateTypingAliases = false,
          },
          -- inlay hint settings are provided by pylance?
          inlayHints = {
            callArgumentNames = "partial",
            functionReturnTypes = true,
            pytestParameters = true,
            variableTypes = true,
          },
        },
      },
    },
  }
else
  vim.notify("pyright not found!", vim.log.levels.WARN, { title = "Nvim-config" })
end

if utils.executable("ruff") then
  require("lspconfig").ruff.setup {
    on_attach = custom_attach,
    capabilities = capabilities,
    init_options = {
      -- the settings can be found here: https://docs.astral.sh/ruff/editors/settings/
      settings = {
        organizeImports = true,
      },
    },
  }
end

if utils.executable("ltex-ls") then
  lspconfig.ltex.setup {
    cmd = { "ltex-ls" },
    filetypes = { "text", "plaintex", "tex", "markdown" },
    settings = {
      ltex = {
        language = "en",
      },
    },
    flags = { debounce_text_changes = 300 },
  }
end

    -- Uncomment code below to enable inlay hint from language server, some LSP server supports inlay hint,
    -- but disable this feature by default, so you may need to enable inlay hint in the LSP server config.
    -- vim.lsp.inlay_hint.enable(true, {buffer=bufnr})

    -- The blow command will highlight the current variable and its usages in the buffer.
    if client.server_capabilities.documentHighlightProvider then
      local gid = vim.api.nvim_create_augroup("lsp_document_highlight", { clear = true })
      vim.api.nvim_create_autocmd("CursorHold", {
        group = gid,
        buffer = bufnr,
        callback = function()
          vim.lsp.buf.document_highlight()
        end,
      })

      vim.api.nvim_create_autocmd("CursorMoved", {
        group = gid,
        buffer = bufnr,
        callback = function()
          vim.lsp.buf.clear_references()
        end,
      })
    end
  end,
  nested = true,
  desc = "Configure buffer keymap and behavior based on LSP",
})

-- Enable lsp servers when they are available

local capabilities = require("lsp_utils").get_default_capabilities()

vim.lsp.config("*", {
  capabilities = capabilities,
  flags = {
    debounce_text_changes = 500,
  },
})

-- A mapping from lsp server name to the executable name
local enabled_lsp_servers = {
  pyright = "delance-langserver",
  ruff = "ruff",
  lua_ls = "lua-language-server",
  -- ltex = "ltex-ls",
  -- clangd = "clangd",
  vimls = "vim-language-server",
  bashls = "bash-language-server",
  yamlls = "yaml-language-server",
}


for server_name, lsp_executable in pairs(enabled_lsp_servers) do
  if utils.executable(lsp_executable) then
    vim.lsp.enable(server_name)
  else
    local msg = string.format(
      "Executable '%s' for server '%s' not found! Server will not be enabled",
      lsp_executable,
      server_name
    )
    vim.notify(msg, vim.log.levels.WARN, { title = "Nvim-config" })
  end
end

lspconfig.sourcekit.setup {
  capabilities = {
    workspace = {
      didChangeWatchedFiles = {
        dynamicRegistration = true,
      },
    },
  },
}

lspconfig.elixirls.setup {
  cmd = { "~/.lsp/elixir/language_server.sh" },
  on_attach = custom_attach,
}

lspconfig.dartls.setup{
  on_attach = custom_attach,
}

lspconfig.gopls.setup{}

lspconfig.ruby_lsp.setup{}
