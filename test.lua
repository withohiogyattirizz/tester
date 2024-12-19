local HTTPService = game:GetService("HttpService")

local Prerequisite = loadstring(game:HttpGet("https://raw.githubusercontent.com/withohiogyattirizz/skibidialgortym/refs/heads/main/main.lua",true))()

local IgnorableObjects = {"WindTrail", "NewDirt", "WaterImpact", "Footprint", "Part"}
local UnnededClasses = {"SpecialMesh", "CylinderMesh", "UnionOperation"}
local ClassesToConvertToFolders = {"ModuleScript", "Script", "LocalScript", "StarterGui", "PlayerGui", "Backpack", "MaterialService", "Lighting"}

local DontSave = {
	['Parent'] = {},
	['BrickColor'] = {},
	['Orientation'] = {"ParticleEmitter"},
	['Position'] = {"GuiBase"},
	["WorldCFrame"] = {},
	["WorldPosition"] = {},
	['WorldPivot'] = {},
	["Grip"] = {},
	["Origin"] = {},
	["PrimaryPart"] = {},
	["UniqueId"] = {},
	["PivotOffset"] = {};
	["Pivot Offset"] = {};
	["FontFace"] = {};
	["NextSelectionUp"] = {};
	["NextSelectionDown"] = {};
	["NextSelectionLeft"] = {};
	["NextSelectionRight"] = {};
	["RootLocalizationTable"] = {};
	["AbsolutePosition"] = {};
	["AbsoluteRotation"] = {};
	["AbsoluteSize"] = {};
}

local DontSaveIf = {
	Rotation = {'CFrame'},
}

local ValueTypeRenames = {
	int = 'number'
}

local function ShouldntSave(properties, property, objectClass, OBJECT)
	local disallow = false

	if DontSave[property] then
		disallow = not table.find(DontSave[property], objectClass)

		if table.find(DontSave[property], "GuiBase") then
			disallow = not OBJECT:IsA("GuiBase")
		end
	end

	if not DontSaveIf[property] or disallow then 
		return disallow
	end

	for i, prop in pairs(DontSaveIf[property])do
		if properties[prop] then
			return true
		end
	end
end

local Converter = {
	AssignGUIDs = {},
	Meshes = {},
	ModelsCache = {}
}
local PropertiesAPI = {
	Dump = {};
	Defaults = {};
	Properties = {};
}

PropertiesAPI.Dump = HTTPService:JSONDecode(game:HttpGet('https://raw.githubusercontent.com/CloneTrooper1019/Roblox-Client-Tracker/roblox/API-Dump.json', true))

local RootClass = '<<<ROOT>>>'

local DefaultOverwrites = {
	Anchored = true,
	TopSurface = Enum.SurfaceType.Smooth,
	BottomSurface = Enum.SurfaceType.Smooth
}

local AlwaysSave = {
	'MeshId'
}

local function IsDeprecated(Property)
	if not Property.Tags then return end

	return table.find(Property.Tags, 'Deprecated') ~= nil
end

local function IsWriteable(Property)
	return table.find(AlwaysSave, Property.Name) or Property.Security and (Property.Security == 'None' or Property.Security.Write == 'None') and (not Property.Tags or not table.find(Property.Tags, 'ReadOnly'))
end

function PropertiesAPI:GetDefaults(ClassName : string)
	assert(ClassName, 'No class name was given')

	if self.Defaults[ClassName] then return self.Defaults[ClassName] end

	local success, instance = pcall(function()
		return Instance.new(ClassName)
	end)

	if not success then error(instance) return {} end

	local defaults = {}
	local properties = self:GetProperties(ClassName)

	for i, property in pairs(properties)do
		pcall(function()
			defaults[property.Name] = (DefaultOverwrites[property.Name] ~= nil and DefaultOverwrites[property.Name]) or instance[property.Name]
		end)
	end

	table.sort(properties, function(a, b) return a.Name < b.Name end)

	self.Defaults[ClassName] = defaults

	instance:Destroy()

	return defaults
end

function PropertiesAPI:GetProperties(ClassName : string)
	assert(ClassName, 'No class name was given')

	if self.Properties[ClassName] then return self.Properties[ClassName] end

	local properties = {}

	for i, data in pairs(self.Dump.Classes)do
		if data.Name and data.Name == ClassName then
			for i, property in pairs(data.Members)do
				if not property.Name or not property.ValueType or not property.MemberType or property.MemberType ~= 'Property' or IsDeprecated(property) or not IsWriteable(property) then continue end

				table.insert(properties, property)
			end

			if data.Superclass and data.Superclass ~= RootClass then
				for i, property in pairs(self:GetProperties(data.Superclass) or {})do
					table.insert(properties, property)
				end
			end

			break
		end
	end

	table.sort(properties, function(a, b) return a.Name < b.Name end)

	self.Properties[ClassName] = properties

	return properties
end

function Converter:ToValue(Parent, Value)
	local Type = typeof(Value)
	local Data = nil

	if (Type == 'Instance') and (Value:IsDescendantOf(Parent) or Value == Parent) then
		Data = Value:GetAttribute('GUID')
		--Data.Value = Converter:ConvertToTable(Value)
	elseif Type == 'CFrame' then
		Data = {Value:GetComponents()}
	elseif Type == 'Vector2' then
		Data = {Value.X, Value.Y}
	elseif Type == "Vector3" then
		Data = {Value.X, Value.Y, Value.Z}
	elseif Type == 'UDim2' then
		Data = {Value.X.Scale, Value.X.Offset, Value.Y.Scale, Value.Y.Offset}
	elseif Type == 'UDim' then
		Data = {Value.Scale, Value.Offset}
	elseif Type == 'ColorSequence' or Type == 'NumberSequence' then
		Data = {}

		for i, keypoint in pairs(Value.Keypoints)do
			local value = self:ToValue(Parent, keypoint.Value)
			table.insert(Data, {keypoint.Time, value, (Type == "NumberSequence" and keypoint["Envelope"]) or nil})
		end
	elseif Type == 'Color3' or Type == 'BrickColor' then
		Data = {Value.r, Value.g, Value.b}
	elseif Type == 'Faces' then
		Data = {Value.Top, Value.Bottom, Value.Left, Value.Right, Value.Back, Value.Front}
	elseif Type == 'NumberRange' then
		Data = {Value.Min, Value.Max}
	elseif Type == 'EnumItem' then
		Data = Value.Value
	elseif Type == "Rect" then
		Data = {Value.Min.X, Value.Min.Y, Value.Max.X, Value.Max.Y}
	elseif Type == "string" then
		Data = Value
	else
		Data = Value
	end

	return Data
end

function Converter:ConvertToTable(Object, Parent, IncludeDescendants)
	assert(Object, 'No object was passed through')

	if not Parent then Parent = Object end
	if not IncludeDescendants then IncludeDescendants = false end

	Object.Archivable = true

	for _, Object__ in Object:GetDescendants() do
		Object__.Archivable = true
	end

	local DesiredClass = Object.ClassName

	if table.find(ClassesToConvertToFolders, Object.ClassName) then
		DesiredClass = "Folder"
	end

	local properties = PropertiesAPI:GetProperties(DesiredClass)
	local defaults = PropertiesAPI:GetDefaults(DesiredClass)
	local data = {
		ClassName = DesiredClass,
		ID = Object:GetAttribute('GUID')
	}

	if ((Object:IsA('Model') or Object:IsA('Folder')) and #Object:GetChildren() <= 0) then
		return
	end

	if Object:IsA("Model") then
		data["CFrame"] = {
			Value = Converter:ToValue(Object, Object:GetPivot());
			Class = "CFrame";
		}
	end

	for i, property in pairs(properties)do
		property = property.Name
		if (defaults[property] ~= nil and Object[property] == defaults[property]) or ShouldntSave(data, property, DesiredClass, Object) then continue end
		if property == "Scale" then continue end
		if typeof(data[property]) == "Instance" or (DesiredClass == "Model" and property == "CFrame") then continue end

		xpcall(function()
			data[property] = { 
				Value = Converter:ToValue(Parent, Object[property]);
				Class = typeof(Object[property]);
			}
		end, function(err)
			warn(`FAILED TO SAVE: {err}`)
		end)
	end

	if IncludeDescendants then
		data.Children = {}

		for i, child in pairs(Object:GetChildren())do
			local tab = Converter:ConvertToTable(child, Parent, IncludeDescendants)
			table.insert(data.Children, tab)
		end

		if #data.Children <= 0 then
			data.Children = nil
		end
	end

	return data
end

function Converter:ConvertToSaveable(Object : Instance, IncludeDescendants:boolean)
	local data = Converter:ConvertToTable(Object, nil, IncludeDescendants)

	return Prerequisite:Run(HTTPService:JSONEncode(data))
end

return Converter, PropertiesAPI
