-- [[ Module Definition ]] --

local BehaviorsManager = {};
BehaviorsManager.Heartbeat = {Callbacks = {}}
BehaviorsManager.Environments = {};

-- [[ Type Definitions ]] --

type Function = (...any?) -> (...any?);
type Array<ValueType> = {[number]: ValueType};
type Dictionary<KeyType, ValueType> = {[KeyType]: ValueType};
type UserData = typeof(newproxy());

export type BehaviorsManager = typeof(BehaviorsManager);
export type Behavior = {
	Name: string,
	Animations: Dictionary<string, number>?,
	Imports: Dictionary<string, any>,
	Initialize: Function,
	Step: Function?,
	Key: UserData?,
};

type Signal = {
	SignalType: string,
	Check: (...any?) -> (boolean),
	Trigger: (Behavior.Imports, BehaviorsManager, ...any?) -> (),
	Behavior: Behavior
};

-- [[ Roblox Services ]] --

local Players = game:GetService("Players");
local ReplicatedStorage = game:GetService("ReplicatedStorage");
local RunService = game:GetService("RunService");

-- [[ Modules ]] --

local Animator = require(script.Animator);
local KeyBind = require(script.KeyBind);

-- [[ Variables ]] --

local IsServer: boolean = RunService:IsServer();
local Heartbeat: RBXScriptSignal = RunService.Heartbeat;

local LocalPlayer = IsServer == false and (Players.LocalPlayer or Players.PlayerAdded:Wait()) or nil;

-- [[ Functions ]] --

local function ConsoleFormat(Log: Function, Pattern: string, ...: any)
	local Arg2: string | number = Log == error and 2 or "";
	Log(Pattern:format(...), Arg2);
end;

-- [[ Public Metatables ]] --

local BehaviorsManagerPublicMeta: Dictionary<string, Function> = {
	__index = function(self: BehaviorsManager, Key: string)
		local ServiceName: string = tostring(self);
		ConsoleFormat(error, "%s is not a valid member of %s %q", Key, ServiceName, ServiceName);
	end,
	__newindex = function(self: BehaviorsManager, Key: string, Value: any)
		local ServiceName: string = tostring(self);
		ConsoleFormat(error, "%s is not a valid member of %s %q", Key, ServiceName, ServiceName);
	end,
	__tostring = function(): string
		return ("BehaviorsManager");
	end,
};

local BehaviorPublicMeta: Dictionary<string, Function> = {
	__newindex = function(self: Behavior, Key: string, Value: any)
		self[Key] = Value;
	end,
	__tostring = function(self: Behavior): string
		return (self.Name);
	end,
};

-- [[ Constructor Functions ]] --

function BehaviorsManager.InitializeBehavior(_behaviorsManager: BehaviorsManager, Behavior: Behavior, WaitForKey: boolean?)
	local BehaviorName: string = Behavior.Name;
	
	rawset(_behaviorsManager, BehaviorName, Behavior);
	setmetatable(_behaviorsManager[BehaviorName].Imports, BehaviorPublicMeta);
	Behavior = _behaviorsManager[BehaviorName];
	
	if (WaitForKey == true) then
		coroutine.wrap(function()
			repeat
				Heartbeat:Wait();
			until Behavior.Key ~= nil;
			Behavior.Initialize(Behavior.Imports, Behavior.Name, _behaviorsManager);
		end)();
	else
		coroutine.wrap(Behavior.Initialize)(Behavior.Imports, Behavior.Name, _behaviorsManager);
	end;
	
	getmetatable(Behavior.Imports).__index = function(self, Key: string): any
		if (Key:match("Animation$") ~= nil and Behavior.Animations ~= nil) then
			local AnimationName: string = Key:sub(1, Key:len() - 9);
			local AnimationId: number? = Behavior.Animations[AnimationName];

			if (AnimationId ~= nil) then
				return Animator.LoadAnimation(AnimationId);
			end;
		end;

		return (rawget(self, Key));
	end;
	
	if (rawget(Behavior, "Animations") ~= nil) then
		for _, AnimationId in pairs(Behavior.Animations) do
			Animator.LoadAnimation(AnimationId);
		end;
	end;
	
	--TODO:Signals
	--if (Behavior.Step ~= nil) then
	--	_behaviorsManager:ConnectEventToBehavior(BehaviorName, "Step", Heartbeat)
	--end;

	return (_behaviorsManager[BehaviorName]);
end;

function BehaviorsManager.CreateNewBehavior(
	_behaviorsManager: BehaviorsManager, BehaviorName: string, Animations: Dictionary<string, number>?,
	Imports: Dictionary<string, any>, Initialize: Function, Step: Function?
)
	--	>> Create behavior
	local Behavior: Behavior = {
		Name = BehaviorName,
		Animations = Animations,
		Imports = Imports,
		Initialize = Initialize,
		Step = Step,
	};
	
	--	>> Log behavior in behaviors manager and initialize
	local InitializedBehavior: Behavior = _behaviorsManager:InitializeBehavior(Behavior);
	return (InitializedBehavior);
end;

function BehaviorsManager.CreateNewEnvironment(_behaviorsManager: BehaviorsManager, Environment: Dictionary<string, any>): UserData
	local UniqueKey: UserData = newproxy();
	local CopyEnvironment: Dictionary<string, any> = {};
	
	for Key: string, Value: any in pairs(Environment) do
		if (Key == "Initialize") then
			continue;
		end;
		CopyEnvironment[Key] = Value;
	end;
	
	_behaviorsManager.Environments[UniqueKey] = CopyEnvironment;
	
	if (Environment.Initialize ~= nil) then
		Environment.Initialize(_behaviorsManager.Environments[UniqueKey]);
	end;
	
	return (UniqueKey);
end;

function BehaviorsManager.CompileEnvironment(_behaviorsManager: BehaviorsManager, Environment: ModuleScript)
	debug.profilebegin("envcompile");
	
	local Modules: Array<ModuleScript> = Environment:GetChildren();
	local Environment: Dictionary<string, any> = require(Environment);
	local Key: UserData = _behaviorsManager:CreateNewEnvironment(Environment);
	
	for _, Module: ModuleScript in ipairs(Modules) do
		xpcall(function()
			local Behavior: Behavior = _behaviorsManager:InitializeBehavior(require(Module), true);
			_behaviorsManager:AddBehaviorToEnvironment(Behavior.Name, Key);
		end, function(ErrorMessage: string)
			ConsoleFormat(warn, "Unable to add behavior, %q, to environment, %q, for reason: %s", 
				Module.Name, tostring(Key), ErrorMessage);
		end);
	end;
	
	debug.profileend("envcompile");
end;

-- [[ Public Methods ]] --

function BehaviorsManager.AddBehaviorToEnvironment(_behaviorsManager: BehaviorsManager, BehaviorName: string, Key: UserData)
	local Behavior: Behavior = _behaviorsManager:GetBehavior(BehaviorName);
	
	if (_behaviorsManager.Environments[Key] == nil) then
		ConsoleFormat(error, "Environemnt with key, %q, does not exist.", tostring(Key));
	end;
	
	rawset(Behavior, "Key", Key);
end;

function BehaviorsManager.BindKeyToBehavior(
	_behaviorsManager: BehaviorsManager, BehaviorName: string, 
	InputKey: Enum.KeyCode, InputStates: Dictionary<Enum.UserInputState, Function>
)
	local Behavior: Behavior = _behaviorsManager[BehaviorName];
	local FormattedKey: string = string.format("%sKeyBind", BehaviorName);
	
	rawset(Behavior.Imports, FormattedKey, KeyBind.new(FormattedKey, InputKey, InputStates));
	Behavior.Imports[FormattedKey]:BindAction();
end;

function BehaviorsManager.BehaviorHasEnvironment(_behaviorsManager: BehaviorsManager, BehaviorName: string): boolean
	local Behavior: Behavior = _behaviorsManager:GetBehavior(BehaviorName);
	return Behavior.Key ~= nil;
end;

function BehaviorsManager.GetBehavior(_behaviorsManager: BehaviorsManager, BehaviorName: string): Behavior
	local Behavior: Behavior = rawget(_behaviorsManager, BehaviorName);

	if (Behavior == nil) then
		ConsoleFormat(error, "Behavior, %q, does not exist.", BehaviorName);
	end;
	
	return Behavior;
end;

function BehaviorsManager.GetEnvironment(_behaviorsManager: BehaviorsManager, BehaviorName: string): Dictionary<string, any>
	local Behavior: Behavior = _behaviorsManager:GetBehavior(BehaviorName);
	local Key: UserData = nil;
	
	if (_behaviorsManager:BehaviorHasEnvironment(BehaviorName) == false) then
		ConsoleFormat(error, "Behavior, %q, does not have an environment.", BehaviorName);
	else
		Key = Behavior.Key;
	end;
	
	return _behaviorsManager.Environments[Key];
end;

function BehaviorsManager.OutSource(_behaviorsManager: BehaviorsManager, BehaviorName: string, YieldTime: number?): Dictionary<string, any>
	if (rawget(_behaviorsManager, BehaviorName) == nil) then
		if (YieldTime == 0) then
			return;
		end;
		
		local YieldTime: number = YieldTime or 5;
		local ElapsedTime: number = 0;
		local Imports: Dictionary<string, any> = nil;
		
		repeat
			Imports = _behaviorsManager:OutSource(BehaviorName, 0);
			ElapsedTime = ElapsedTime + Heartbeat:Wait();
		until (Imports ~= nil or ElapsedTime >= YieldTime);
		
		return (Imports);
	end;
	
	return (_behaviorsManager[BehaviorName].Imports);
end;

function BehaviorsManager.OutSourceMultiple(_behaviorsManager: BehaviorsManager, Behaviors: Array<string>): Dictionary<string, Behavior>
	local LoadedBehaviors: Dictionary<string, Behavior> = {};
	
	for _, BehaviorName: string in pairs(Behaviors) do
		local LoadedBehavior: Behavior = _behaviorsManager:OutSource(BehaviorName);
		LoadedBehaviors[BehaviorName] = LoadedBehavior;
	end;
	
	return (LoadedBehaviors);
end;

return (setmetatable(BehaviorsManager, BehaviorsManagerPublicMeta));
