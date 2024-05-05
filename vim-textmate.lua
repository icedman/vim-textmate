local cpath = package.cpath

package.cpath = cpath .. ";" .. vim.fn.expand("~/.vim/lua/vim-textmate/?.so") 
local ok, module = pcall(require, "textmate")

if not ok then
  local target_path = vim.fn.expand("~/.vim/plugged/vim-textmate/")
  print("Compiling textmate module...")
  os.execute("make -C " .. target_path)
  module = require("textmate")
end

package.cpath = cpath

local script_version = "0.1"

module.highlight_set_extensions_dir(vim.fn.expand("~/.editor/extensions/"))
module.highlight_set_extensions_dir(vim.fn.expand("~/.vscode/extensions/"))
module.highlight_set_extensions_dir(vim.fn.expand("~/.vim/lua/vim-textmate/extensions/"))

local debug_scopes = false
local enable_highlighting = true
local enable_textmate_color_fidelity = true
local props = {}
local _buffers = {}

local function setup(parameters) end

local function buffers(id)
  if not _buffers[id] then
    _buffers[id] = {
      number = id,
      last_count = 0,
      langid = nil,
    }
  end
  return _buffers[id]
end

local scope_hl_map = {
  { "type", "StorageClass" },
  { "storage.type", "Identifier" },
  { "constant", "Constant" },
  { "constant.numeric", "Number" },
  { "constant.character", "Character" },
  { "primitive", "Boolean" },
  { "variable", "StorageClass" },
  { "keyword", "Define" },
  { "declaration", "Conditional" },
  { "control", "Conditional" },
  { "operator", "Operator" },
  { "directive", "PreProc" },
  { "require", "Include" },
  { "import", "Include" },
  { "function", "Function" },
  { "struct", "Structure" },
  { "class", "Structure" },
  { "modifier", "Boolean" },
  { "namespace", "StorageClass" },
  { "scope", "StorageClass" },
  { "name.type", "StorageClass" },
  -- { "name.type", "Variable" },
  { "tag", "Tag" },
  { "name.tag", "StorageClass" },
  { "attribute", "StorageClass" },
  -- { "attribute", "Variable" },
  { "property", "StorageClass" },
  -- { "property", "Variable" },
  { "heading", "markdownH1" },
  { "string", "String" },
  { "string.other", "Label" },
  { "comment", "Comment" },
}

function txmt_highlight_line(n, l)
  local b = buffers(vim.buffer().number)

  vim.command("call prop_clear(" .. n .. "," .. n .. ", { 'bufnr': " .. b.number .. "})")
  if not enable_highlighting then
    return
  end

  local langid = b.langid
  if not langid then
    langid = module.highlight_load_language(vim.fn.expand("%"))
    b.langid = langid
  end

  if langid == -1 then
    return
  end

  local r = vim.window().line
  local c = vim.window().column

  module.highlight_set_language(langid)
  local t = module.highlight_line(l, n, langid, b.number)

  for i, style in ipairs(t) do
    local start = math.floor(style[1])
    local length = math.floor(style[2])
    local scope = style[3]

    if debug_scopes and r == n and (c - 1) >= start and (c - 1) < start + length then
      print(scope)
    end

    local hl = nil

    -- render with colors
    if enable_textmate_color_fidelity then
      local rr = style[4] -- rgb color
      local gg = style[5]
      local bb = style[6]
      local aa = style[7] -- nearest color index
      local bold = style[8]
      local italic = style[9]
      local underline = style[10]
      local attribs = ""
      local term = {}
      local terms =  ""
      if rr > 0 then

        if bold == 1 then
          table.insert(term, "bold")
          attribs = attribs .. "b"
        end
        if italic == 1 then
          table.insert(term, "italic")
          attribs = attribs .. "i"
        end
        -- if underline == 1 then
        --   table.insert(term, "underline")
        --   attribs = attribs .. "u"
        -- end

        if #term > 0 then
          terms = " cterm=" .. table.concat(term, ",")
        end

        local clr = string.format("%02x%02x%02x", rr, gg, bb)
        if clr and clr:len() < 8 then
          hl = clr .. attribs
          if not props[hl] then
            vim.command("highlight " .. hl .. terms .. " ctermfg=" .. math.floor(aa) .. " guifg=#" .. clr)
          end
        end
      end
    end

    -- render with color schemes
    if not enable_textmate_color_fidelity then
      for j, map in ipairs(scope_hl_map) do
        if string.find(scope, map[1]) then
          hl = map[2]
        end
      end
    end

    if hl then
      if not props[hl] then
        vim.command("call prop_type_add('" .. hl .. "', { 'highlight': '" .. hl .. "', 'priority': 0 })")
        props[hl] = true
      end
      vim.command(
        "call prop_add(" .. n .. "," .. (start + 1) .. ", { 'length': " .. length .. ", 'type': '" .. hl .. "'})"
      )
    end
  end
end

function txmt_highlight_current_line()
  txmt_highlight_line(vim.window().line, vim.buffer()[vim.window().line])
end

function txmt_highlight_current_buffer(no_limit, make_dirty)
  local b = buffers(vim.buffer().number)

  if make_dirty then
    module.highlight_make_doc_dirty(b.number)
  end

  local r = vim.window().line
  local c = vim.window().column

  local lc = #vim.buffer()
  local sr = vim.window().height -- screen rows

  b.last_count = lc

  local ls = r - sr
  local le = r + sr

  if ls < 1 then
    ls = 1
  end
  if le > lc then
    le = lc
  end

  local dirty_count = 0
  for i = ls, le - 1, 1 do
    if module.highlight_is_line_dirty(i, b.number) ~= 0 then
      local line = vim.buffer()[i]
      txmt_highlight_line(i, line)
      dirty_count = dirty_count + 1
      if no_limit ~= true and dirty_count > (sr * 1.4) then
        break
      end
    end
  end

  if debug_scopes then
    txmt_highlight_current_line()
  end
end

function txmt_on_text_changed()
  local b = buffers(vim.buffer().number)
  local lc = b.last_count
  local count = #vim.buffer()
  local changed_lines = 1

  local nr = vim.window().line - 1

  local diff = count - lc
  if diff > 0 then
    changed_lines = diff
    for nr = 0, diff, 1 do
      module.highlight_add_block(nr, b.number)
    end
  end
  if diff < 0 then
    changed_lines = -diff
    for nr = 0, -diff, 1 do
      module.highlight_remove_block(nr, b.number)
    end
  end

  for cl = 0, changed_lines, 1 do
    module.highlight_make_line_dirty(nr + cl, b.number)
  end

  txmt_highlight_current_buffer(true)
end

function txmt_on_delete_buffer()
  local n = vim.buffer().number
  if _buffers[n] then
    _buffers[n] = nil
    module.highlight_remove_doc(n)
  end
end

function txmt_info()
  local b = buffers(vim.buffer().number)
  if script_version == module.highlight_module_version then
    print("version: " .. script_version)
  else
    print("warning script & module versions do not match")
    print("script version: " .. script_version)
    print("module version: " .. module.highlight_module_version)
  end
  print("file: " .. vim.fn.expand("%"))
  if b.langid and b.langid ~= -1 then
    local info = module.highlight_language_info(b.langid)
    print("language: " .. info[1] .. "\ngrammar: " .. info[2])
  end
end

function txmt_info_languages()
  local s = {}
  local languages = module.highlight_languages()
  for i, lang in ipairs(languages) do
    table.insert(s, lang[1])
  end
  print("languages available:\n")
  print(table.concat(s, ", "))
end

function txmt_info_themes()
  local s = {}
  local themes = module.highlight_themes()
  for i, thm in ipairs(themes) do
    table.insert(s, thm[1])
  end
  print("themes available:\n")
  print(table.concat(s, ", "))
end

function txmt_set_theme(thm)
  if string.len(thm) > 1 and string.sub(thm, 1, 1) == '"' then
    thm = string.sub(thm, 2, string.len(thm) - 1)
  end
  module.highlight_load_theme(thm)

  enable_textmate_color_fidelity = true

  --vim.command("syn off")
  txmt_highlight_current_buffer(true, true)
end

function txmt_debug_scopes()
  if debug_scopes then
    debug_scopes = false
  else
    debug_scopes = true
  end
end

function txmt_enable_color_fidelity()
  if enable_textmate_color_fidelity then
    enable_textmate_color_fidelity = false
  else
    enable_textmate_color_fidelity = true
  end
end

function txmt_enable(args)
  enable_highlighting = args
  if not enable_highlighting then
    txmt_on_delete_buffer()
  end
  txmt_highlight_current_buffer(true, true)
end

vim.command("syn on")
vim.command("au CursorMoved,CursorMovedI * :lua txmt_highlight_current_buffer()")
vim.command("au CursorHold,CursorHoldI * :lua txmt_highlight_current_buffer()")
vim.command("au TextChanged,TextChangedI * :lua txmt_on_text_changed()")
vim.command("au BufEnter * :lua txmt_highlight_current_buffer(true, true)")
vim.command("au BufDelete * :lua txmt_on_delete_buffer()")

vim.command("command TxmtInfo 0 % :lua txmt_info()")
vim.command("command TxmtInfoLanguages 0 % :lua txmt_info_languages()")
vim.command("command TxmtInfoThemes 0 % :lua txmt_info_themes()")
vim.command("command TxmtSetTheme 1 % :lua txmt_set_theme(<q-args>)")
vim.command("command TxmtDebugScopes 0 % :lua txmt_debug_scopes()")
vim.command("command TxmtEnable 0 % :lua txmt_enable(true)")
vim.command("command TxmtDisable 0 % :lua txmt_enable(false)")

return {
  setup = setup,
}
