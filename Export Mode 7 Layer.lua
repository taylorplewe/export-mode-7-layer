-- HELPER FUNCTIONS

function validateAndShowErrorDialog(validations, errorDialogHeaderText)
	local errorLines = {}
	for errorText, invalidCheck in pairs(validations) do
		if invalidCheck() then
			table.insert(errorLines, '- ' .. errorText)
		end
	end
	if #errorLines > 0 then
		table.insert(errorLines, 1, errorDialogHeaderText)
		app.alert{ title='ERROR - Export Mode 7 Layer Binary', text=errorLines }
		return false
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
function validateForDialog()
	local validations = {
		['There must be at least one tilemap layer.'] = function() return #tilemapLayerNames < 1 end,
		['Sprite must be of color mode "Indexed".'] = function() return app.sprite.colorMode ~= ColorMode.INDEXED end,
		['Duplicate tilemap layer names exist.'] = function() return areDuplicateTilemapLayers end,
	}
	return validateAndShowErrorDialog(validations, 'The script cannot continue due to the following reasons:')
end
function validateForExport()
	local validations = {
		['No output file selected.'] = function() return #exportDlg.data.outFile == 0 end,
		['Tilemap layer has no content.'] = function() return #tilemapLayersByName[exportDlg.data.nameLayer].cels == 0 end,
		['Tilemap layer\'s content must be 128 tiles (1,024px) wide.'] = function() return #tilemapLayersByName[exportDlg.data.nameLayer].cels == 0 or tilemapLayersByName[exportDlg.data.nameLayer].cels[1].bounds.width ~= 128*8 end,
	}
	return validateAndShowErrorDialog(validations, 'The following issues are prohibiting exporting:')
end
function showExportWarningsAndProceed()
	nameLayer = tilemapLayersByName[exportDlg.data.nameLayer]

	-- tilemap layer content is not 128 tiles tall
	if nameLayer.cels[1].bounds.height < 128*8 then
		if not showWarningDialogAndProceed({ 'NAME (tilemap) layer content is less than 128 tiles (1,024px) tall.', 'Empty space will be filled with 0\'s.' })
			then return false end
	elseif nameLayer.cels[1].bounds.height > 128*8 then
		if not showWarningDialogAndProceed({ 'NAME (tilemap) layer content is more than 128 tiles (1,024px) tall.', 'Part of the tilemap will be cut off in the binary.' })
			then return false end
	end

	-- tileset contains less than 128x128 tiles
	if not nameLayer.tileset:tile(16384) then
		if not showWarningDialogAndProceed({ 'Tileset contains less than 128x128 (16,384) tiles.', 'Empty space will be filled with 0\'s.' })
			then return false end
	elseif nameLayer.tileset:tile(16385) then
		if not showWarningDialogAndProceed({ 'Tileset contains more than 128x128 (16,384) tiles.', 'Only the first 16,384 tiles will appear in the binary.' })
			then return false end
	end

	return true
end


-- MAIN SCRIPT

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

if not validateForDialog() then return end

-- open export dialog
exportDlg = Dialog('Export Mode 7 Layer Binary')
	:combobox{
		id='nameLayer',
		label='NAME (tilemap) layer:',
		options=tilemapLayerNames,
	}
	:label{ text='* Only tilemap layers appear in this list.' }
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
	:button{ text='Cancel', }
	:show{ wait=false } -- TODO might be able to not wait=false

function export()
	if not validateForExport() then return end
	if not showExportWarningsAndProceed() then return end

	-- try to open output file
	local outFileName = exportDlg.data.outFile
	local outFile = io.open(exportDlg.data.outFile, "wb")
	if not outFile then
		app.alert{ title='File open error', text={ 'Could not open file:', '', outFileName, '' } }
		return
	end

	-- write to output file
	local nameLayer = tilemapLayersByName[exportDlg.data.nameLayer]
	local outFileWordInd = 0
	-- CHR portion
		local chrTileInd = 1
		local tile = nameLayer.tileset:tile(chrTileInd)
		while outFileWordInd < 16384 do
			if tile ~= nil then
				-- will always be 8x8 px at this point
				for px in tile.image:pixels() do
					outFile:write(string.char(0x00)) -- placeholder for NAME byte
					outFile:write(string.char(px()))
					outFileWordInd = outFileWordInd + 1
				end
				chrTileInd = chrTileInd + 1
				tile = nameLayer.tileset:tile(chrTileInd)
			else
				while outFileWordInd < 16384 do
					outFile:write(string.char(0x00, 0x00))
					outFileWordInd = outFileWordInd + 1
				end
			end
		end
	-- NAME portion
		outFileWordInd = 0
		outFile:seek('set') -- go back to beginning of file
		for nameTileInd in nameLayer.cels[1].image:pixels() do
			outFile:write(string.char(nameTileInd()))
			outFile:seek('cur', 1) -- skip over CHR byte
			outFileWordInd = outFileWordInd + 1
			if outFileWordInd >= 16384 then break end
		end
	outFile:close()

	-- show success alert & close export dialog
	app.alert{ title='Export Success', text={ 'Mode 7 binary written to:', '', outFileName, '' } }
	exportDlg:close()
end