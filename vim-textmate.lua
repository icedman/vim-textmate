local cpath = package.cpath
package.cpath = cpath .. ";" .. vim.fn.expand("~/.vim/lua/vim-textmate/?.so")
local module = require("textmate")
package.cpath = cpath

module.highlight_set_extensions_dir(vim.fn.expand("~/.editor/extensions/"))

local debug_scopes = false
local props = {}
local _buffers = {}

local function setup(parameters) end

local function buffers(id)
	if not _buffers[id] then
		_buffers[id] = {
			number = id,
			last_count = 0,
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

	local t = module.highlight_line(l, n, langid, b.number)

	vim.command("call prop_clear(" .. n .. ")")

	for i, style in ipairs(t) do
		local start = math.floor(style[1])
		local length = math.floor(style[2])
		-- local rr = style[3]
		-- local gg = style[4]
		-- local bb = style[5]
		local scope = style[6]

		if debug_scopes and r == n and (c - 1) >= start and (c - 1) < start + length then
			print(scope)
		end

		-- local clr = string.format("%02x%02x%02x", rr, gg, bb)
		-- if clr and clr:len() < 8 then
		-- end

		local hl = nil
		for j, map in ipairs(scope_hl_map) do
			if string.find(scope, map[1]) then
				hl = map[2]
			end
		end
		if hl then
			if not props[hl] then
				vim.command("call prop_type_add('" .. hl .. "', { 'highlight': '" .. hl .. "', 'priority': 999 })")
				props[hl] = true
			end
			vim.command(
				"call prop_add("
					.. n
					.. ","
					.. (start + 1)
					.. ", { 'length': "
					.. length
					.. ", 'type': '"
					.. hl
					.. "'})"
			)
		end
	end
end

function txmt_highlight_current_line()
	txmt_highlight_line(vim.window().line, vim.buffer()[vim.window().line])
end

function txmt_highlight_current_buffer()
	local b = buffers(vim.buffer().number)

	local r = vim.window().line
	local c = vim.window().column

	local lc = #vim.buffer()
	local sr = vim.window().height -- screen rows

	b.last_count = lc

	local ls = r - sr
	local le = r + sr

	if ls < 0 then
		ls = 0
	end
	if le > lc then
		le = lc
	end

	for i = ls, le - 1, 1 do
		if module.highlight_is_line_dirty(i + 1, b.number) ~= 0 then
			local line = vim.buffer()[i + 1]
			txmt_highlight_line(i + 1, line)
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

	txmt_highlight_current_buffer()
end

function txmt_on_delete_buffer()
	local n = vim.buffer().number
	if _buffers[n] then
		_buffers[n] = nil
		module.highlight_remove_doc(n)
	end
end

vim.command("syn on")
vim.command("au CursorMoved,CursorMovedI * :lua txmt_highlight_current_buffer()")
vim.command("au TextChanged,TextChangedI * :lua txmt_on_text_changed()")
vim.command("au BufEnter * :lua txmt_highlight_current_buffer()")
vim.command("au BufDelete * :lua txmt_on_delete_buffer()")

function txmt_info()
	local b = buffers(vim.buffer().number)
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

function txmt_debug_scopes()
	if debug_scopes then
		debug_scopes = false
	else
		debug_scopes = true
	end
end

vim.command("command TxmtInfo 0 % :lua txmt_info()")
vim.command("command TxmtInfoLanguages 0 % :lua txmt_info_languages()")
vim.command("command TxmtDebugScopes 0 % :lua txmt_debug_scopes()")

-- vim.command"au BufEnter * :luado txmt_highlight_line(linenr, line)"
-- vim.command"luado txmt_highlight_line(linenr, line)"

return {
	setup = setup,
}
