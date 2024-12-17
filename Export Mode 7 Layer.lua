-- gather all tilemap layer names
tilemapLayersByName = {}
tilemapLayerNames = {}
areDuplicateTilemapLayers = false
for _, layer in ipairs(app.sprite.layers) do
	if layer.isTilemap then
		if tilemapLayersByName[layer.name] then areDuplicateTilemapLayers = true end
		tilemapLayersByName[layer.name] = layer
		table.insert(tilemapLayerNames, layer.name)
	end
end

function getErrorLinesFromValidationTable(validations)
	local errorLines = {}
	for _, validationGroup in ipairs(validations) do
		for _, validation in ipairs(validationGroup) do
			if validation.check() then
				table.insert(errorLines, "- " .. validation.text)
				break
			end
		end
	end
	return errorLines
end

-- ensure the current project meets certain critera before opening export dialog
if (function()
	local validations = {
		{
			{
				text = 'There must be at least two tilemap layers.',
				check = function() return #tilemapLayerNames < 2 end,
			},
		},
		{
			{
				text = 'Sprite must be of color mode "Indexed".',
				check = function() return app.sprite.colorMode ~= ColorMode.INDEXED end,
			},
		},
		{
			{
				text = 'Duplicate tilemap layer names exist.',
				check = function() return areDuplicateTilemapLayers end,
			}
		}
	}

	local errorDialogLines = getErrorLinesFromValidationTable(validations)
	if #errorDialogLines > 0 then
		table.insert(errorDialogLines, 1, 'The script cannot continue due to the following reasons:')
		app.alert{ title = 'Error - Export Mode 7 Layer Binary', text = errorDialogLines }
		return true
	end
	return false
end)() then return end

-- write the image's palette-indexed pixels to the file's binary
-- print('isfile', app.fs.isFile(app.fs.normalizePath('C:/Users/tplew/AppData/Roaming/aseprite/scripts/hello.bin')))
-- local file = io.open(app.fs.normalizePath('C:/Users/tplew/AppData/Roaming/aseprite/scripts/hello.bin'), 'wb')

-- for px in app.image:pixels() do
-- 	file:write(string.char(px()))
-- end
-- file:close()

-- open export dialog
exportDlg = Dialog('Export Mode 7 Layer Binary')
	:combobox{
		id='chrLayer',
		label='CHR (graphics) layer:',
		option=tilemapLayerNames[0],
		options=tilemapLayerNames,
		onchange=updateDialog
	}
	:label{
		text='* Only tilemap layers appear in this list.'
	}
	:combobox{
		id='nameLayer',
		label='NAME (tilemap) layer:',
		option=tilemapLayerNames[1],
		options=tilemapLayerNames,
		onchange=updateDialog
	}
	:label{
		text='* Only tilemap layers appear in this list.'
	}
	:file{
		id='outFile',
		label='Out file (.bin):',
		save=true,
		title='Out file (.bin)',
		filetypes={'bin'},
	}
	:button{
		id='exportBtn',
		text='Export',
		onclick=export
	}
	:button{
		text='Cancel',
	}
	:show{wait=false}

function getExportDialogErrorLines()
	local validations = {
		{
			{
				text = 'Both layers must share the same tileset.',
				check = function() return tilemapLayersByName[exportDlg.data.chrLayer].tileset ~= tilemapLayersByName[exportDlg.data.nameLayer].tileset end,
			},
			{
				text = 'CHR (graphics) layer and NAME (tilemap) layer must be different.',
				check = function() return exportDlg.data.chrLayer == exportDlg.data.nameLayer end,
			},
		},
		{
			{
				text = 'CHR (graphics) layer does not contain any graphical (pixel) data.',
				check = function() return #tilemapLayersByName[exportDlg.data.chrLayer].cels == 0 end,
			}
		},
		{
			{
				text = 'No output file selected.',
				check = function() return #exportDlg.data.outFile == 0 end,
			},
		},
	}
	return getErrorLinesFromValidationTable(validations)
end

function export()
	local errorLines = getExportDialogErrorLines()
	if #errorLines > 0 then
		local errorDlg = Dialog('Can\'t Export')
			:label{label='The following issues are prohibiting exporting:'}
		for _, errorLine in ipairs(errorLines) do
			errorDlg:label{label=errorLine}
		end
		errorDlg
			:button{text='Close'}
			:show()
	else
		exportDlg:close()

		chrLayer = tilemapLayersByName[exportDlg.data.chrLayer]
		nameLayer = tilemapLayersByName[exportDlg.data.nameLayer]

		-- write to output file
		local outFile = io.open(exportDlg.data.outFile, "wb")
		for tileInd in chrLayer.cels[1].image:pixels() do
			local tileImage = chrLayer.tileset:tile(tileInd()).image
			for px in tileImage:pixels() do
				pixel = px()
				outFile:write(string.char(pixel))
			end


			-- print(px())
			-- outFile:write(string.char(px()))
		end
		outFile:close()
	end
end