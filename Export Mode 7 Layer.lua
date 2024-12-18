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
				text = 'There must be at least one tilemap layer.',
				check = function() return #tilemapLayerNames < 1 end,
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
		id='nameLayer',
		label='NAME (tilemap) layer:',
		options=tilemapLayerNames,
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
				text = 'No output file selected.',
				check = function() return #exportDlg.data.outFile == 0 end,
			},
		},
		{
			{
				text = 'Tilemap layer has no content.',
				check = function() return #tilemapLayersByName[exportDlg.data.nameLayer].cels == 0 end,
			},
			{
				text = 'Tilemap layer\'s content must be 128 tiles (1,024px) wide.',
				check = function() return tilemapLayersByName[exportDlg.data.nameLayer].cels[1].bounds.width ~= 128*8 end,
			},
		},
	}
	return getErrorLinesFromValidationTable(validations)
end

function export()
	local errorLines = getExportDialogErrorLines()
	if #errorLines > 0 then
		table.insert(errorLines, 1, 'The following issues are prohibiting exporting:')
		app.alert{ title = 'Can\'t Export', text=errorLines}
	else
		if not showWarningsAndProceed() then
			return
		end

		-- try to open output file
		local nameLayer = tilemapLayersByName[exportDlg.data.nameLayer]
		local outFileName = exportDlg.data.outFile
		local outFile = io.open(exportDlg.data.outFile, "wb")
		if not outFile then
			app.alert{title='File open error', text={'Could not open file:', '', outFileName, ''}}
			return
		end

		-- write to output file
		-- CHR portion
		local tileInd = 1
		local tile = nameLayer.tileset:tile(tileInd)
		local i = 0
		while i < 16384 do
			if tile ~= nil then
				-- will always be 8x8 px at this point
				for px in tile.image:pixels() do
					outFile:write(string.char(0x00))
					outFile:write(string.char(px()))
					i = i + 1
				end
				tileInd = tileInd + 1 -- TODO try ++
				tile = nameLayer.tileset:tile(tileInd)
			else
				while i < 16384 do
					outFile:write(string.char(0x00))
					outFile:write(string.char(0x00))
					i = i + 1
				end
			end
		end
		-- NAME portion
		i = 0
		outFile:seek('set') -- go back to beginning of file
		for px in nameLayer.cels[1].image:pixels() do
			outFile:write(string.char(px()))
			outFile:seek('cur', 1) -- skip over CHR byte
			i = i + 1
			if i >= 16384 then break end
		end
		outFile:close()

		-- show success alert & close export dialog
		app.alert{title='Export Success', text={'Mode 7 binary written to:', '', outFileName, ''}}
		exportDlg:close()
	end
end

function showWarningsAndProceed()
	nameLayer = tilemapLayersByName[exportDlg.data.nameLayer]

	-- tilemap layer content is not 128 tiles tall
	if nameLayer.cels[1].bounds.height < 128*8 then
		if not showWarningDialogAndProceed({'NAME (tilemap) layer content is less than 128 tiles (1,024px) tall.', 'Empty space will be filled with 0\'s.'})
			then return false end
	elseif nameLayer.cels[1].bounds.height > 128*8 then
		if not showWarningDialogAndProceed({'NAME (tilemap) layer content is more than 128 tiles (1,024px) tall.', 'Part of the tilemap will be cut off in the binary.'})
			then return false end
	end

	-- tileset contains less than 128x128 tiles
	if not nameLayer.tileset:tile(16384) then
		if not showWarningDialogAndProceed({'Tileset contains less than 128x128 (16,384) tiles.', 'Empty space will be filled with 0\'s.'})
			then return false end
	elseif nameLayer.tileset:tile(16385) then
		if not showWarningDialogAndProceed({'Tileset contains more than 128x128 (16,384) tiles.', 'Only the first 16,384 tiles will appear in the binary.'})
			then return false end
	end

	return true
end

function showWarningDialogAndProceed(warningLines)
	local dlg = Dialog('Warning')
	for _, line in ipairs(warningLines) do
		dlg:label{
			label=line,
			hexpand=true,
		}
	end
	dlg:button{
		id='proceed',
		text='Proceed',
		focus=true,
	}
	dlg:button{
		id='cancel',
		text='Cancel',
	}
	dlg:show()
	if dlg.data.proceed then return true else return false end
end