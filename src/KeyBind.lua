-- [[ Module Definition ]] --

local KeyBind = {};
KeyBind.__index = KeyBind;
KeyBind.__tostring = function(self)
	return (self.BindName);
end;

-- [[ Roblox Services ]] --

local ContextActionService = game:GetService("ContextActionService");

-- [[ Type Definitions ]] --

type Array<ValueType> = {[number]: ValueType};
type Dictionary<KeyType, ValueType> = {[KeyType]: ValueType};
type Function = (...any?) -> (...any?);

type UserInputStates = Dictionary<Enum.UserInputState, Function>;

-- [[ Functions ]] --

local function errorf(Pattern: string, ...: any)
	error(Pattern:format(...), 2);
end;

local function ActionHandler(Name: string, InputState: Enum.UserInputState, InputObject: InputObject)
	local KeyCode: Enum.KeyCode = InputObject.KeyCode;
	
	if (KeyCode == Enum.KeyCode.Unknown) then
		return;
	end;
	
	if (KeyBind[KeyCode] == nil) then
		errorf("KeyCode, %q, has not been registered as a valid keybind.", KeyCode.Name);
	end;
	
	local KeyBinds = KeyBind[KeyCode];
	
	for _, InputStates: UserInputStates in pairs(KeyBinds) do
		local Callback: Function = InputStates[InputState];
		
		if (Callback ~= nil) then
			coroutine.wrap(Callback)(InputState);
		end;
	end;
end;

-- [[ Public ]] --

function KeyBind.new(BindName: string, KeyCode: Enum.KeyCode, InputStates: UserInputStates)
	local self = {};
	
	self.BindName = BindName;
	self.KeyCode = KeyCode;
	self.InputStates = InputStates;
	
	return (setmetatable(self, KeyBind));
end;

function KeyBind:BindAction()
	local KeyCode: Enum.KeyCode = self.KeyCode;
	
	if (KeyBind[KeyCode] == nil) then
		KeyBind[KeyCode] = {};
		ContextActionService:BindAction(KeyCode.Name, ActionHandler, false, KeyCode);
	end;
	
	local BindName: string = self.BindName;
	
	if (KeyBind[KeyCode][BindName] ~= nil) then
		errorf("KeyBind, %q, has already been bound.", BindName);
	end;
	
	KeyBind[KeyCode][BindName] = self.InputStates;
end;

function KeyBind:UnbindAction(DoDestroy: boolean?)
	local KeyCode: Enum.KeyCode, BindName: string = self.KeyCode, self.BindName;
	
	if (KeyBind[KeyCode] == nil or KeyBind[KeyCode][BindName] == nil) then
		errorf("KeyBind, %q, has not yet been bound.", BindName);
	end;
	
	KeyBind[KeyCode][BindName] = nil;
	
	if (DoDestroy == true) then
		for Key: string in pairs(self) do
			self[Key] = nil;
		end;
		
		self = nil;
	end;
end;

return (KeyBind);
