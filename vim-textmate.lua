function script_path()
	local str = debug.getinfo(2, "S").source:sub(2)
	return str:match("(.*/)")
end

local module = require("textmate")

module.highlight_set_extensions_dir(vim.fn.expand("~/.editor/extensions/"))
module.highlight_load_theme("Monokai")

local props = {}
local buffers = {}

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
	local b = vim.buffer().number

	local langid = buffers[b]
	if not langid then
		langid = module.highlight_load_language(vim.fn.expand("%"))
		buffers[b] = langid
	end

	-- local r = vim.window().line;
	-- local c = vim.window().column;

	local t = module.highlight_line(l, n, langid, b)

	vim.command("call prop_clear(" .. n .. ")")

	for i, style in ipairs(t) do
		local start = math.floor(style[1])
		local length = math.floor(style[2])
		-- local rr = style[3]
		-- local gg = style[4]
		-- local bb = style[5]
		local scope = style[6]

		-- if r == n and (c - 1) >= start and (c - 1) < start + length then
		--     print(scope)
		-- end

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
				vim.command("call prop_type_add('" .. hl .. "', { 'highlight': '" .. hl .. "' })")
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
	local b = vim.buffer().number

	local r = vim.window().line
	local c = vim.window().column

	local lc = #vim.buffer()
	local sr = 50 -- screen rows

	local ls = r - sr
	local le = r + sr

	if ls < 0 then
		ls = 0
	end
	if le > lc then
		le = lc
	end

	for i = ls, le - 1, 1 do
		if module.highlight_is_line_dirty(i + 1, b) ~= 0 then
			local line = vim.buffer()[i + 1]
			txmt_highlight_line(i + 1, line)
		end
	end
end

vim.command("syn on")
vim.command("au CursorMoved,CursorMovedI * :lua txmt_highlight_current_buffer()")
vim.command("au TextChanged,TextChangedI * :lua txmt_highlight_current_buffer()")
vim.command("au BufEnter * :lua txmt_highlight_current_buffer()")

-- vim.command"au BufEnter * :luado txmt_highlight_line(linenr, line)"
-- vim.command"luado txmt_highlight_line(linenr, line)"
