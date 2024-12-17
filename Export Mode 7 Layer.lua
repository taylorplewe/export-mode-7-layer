-- ensure the current project meets certain critera before continuing
if (function()
local validations = {
	{
		{
			text = 'There must be at least two layers.',
			check = function() return #app.sprite.layers < 2 end,
		},
		{
			text = 'Both layers must be tilemaps and share the same tileset.',
			check = function() return
				not app.sprite.layers[1].isTilemap or
				not app.sprite.layers[2].isTilemap or
				app.sprite.layers[1].tileset ~= app.sprite.layers[2].tileset
			end,
		},
		{
			text = 'Tilemap grid size must be 8x8.',
			check = function() return
				app.sprite.layers[1].tileset.grid.tileSize.width ~= 8 or
				app.sprite.layers[1].tileset.grid.tileSize.height ~= 8 or
				app.sprite.layers[2].tileset.grid.tileSize.width ~= 8 or
				app.sprite.layers[2].tileset.grid.tileSize.height ~= 8
			end,
		},
	},
	{
		{
			text = 'Sprite must be of color mode "Indexed".',
			check = function() return app.sprite.colorMode ~= ColorMode.INDEXED end,
		},
	},
}

local errorDialogLines = {}
for _, validationGroup in ipairs(validations) do
	for _, validation in ipairs(validationGroup) do
		if validation.check() then
			table.insert(errorDialogLines, "- " .. validation.text)
			break
		end
	end
end

	if #errorDialogLines > 0 then
		table.insert(errorDialogLines, 1, 'The script could not run due to the following reasons:')
		app.alert{ title = 'Error', text = errorDialogLines }
		return true
	end
	return false
end)() then return end

-- write the image's palette-indexed pixels to the file's binary
-- print('isfile', app.fs.isFile(app.fs.normalizePath('C:/Users/tplew/AppData/Roaming/aseprite/scripts/hello.bin')))
local file = io.open(app.fs.normalizePath('C:/Users/tplew/AppData/Roaming/aseprite/scripts/hello.bin'), 'wb')

-- for px in app.image:pixels() do
-- 	file:write(string.char(px()))
-- end
-- file:close()