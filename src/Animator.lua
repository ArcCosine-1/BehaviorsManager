local Animator = {};

local Players = game:GetService("Players");
local RunService = game:GetService("RunService");

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait();

local RbxAssetId = "rbxassetid://%d";

function Animator.Reload()
	if (LocalPlayer.Character == nil) then
		error("Cannot reload animations at this time.", 2);
	end;
	
	for AnimationId: number in pairs(Animator) do
		if (type(AnimationId) == "string") then
			continue;
		end;
		
		Animator[AnimationId] = nil;
		Animator.LoadAnimation(AnimationId);
	end;
end;

function Animator.LoadAnimation(AnimationId: number, PlayerAnimator: Animator?): AnimationTrack
	while (LocalPlayer.Character == nil) do
		RunService.Heartbeat:Wait();
	end;
	
	if (Animator[AnimationId] ~= nil) then
		return (Animator[AnimationId]);
	end;
	
	if (PlayerAnimator == nil) then
		local Humanoid = LocalPlayer.Character:WaitForChild("Humanoid");
		PlayerAnimator = Humanoid.Animator;
	end;
	
	local Animation = Instance.new("Animation");
	Animation.AnimationId = RbxAssetId:format(AnimationId);
	
	local AnimationTrack = PlayerAnimator:LoadAnimation(Animation);
	Animator[AnimationId] = AnimationTrack;
	
	return (AnimationTrack);
end;

LocalPlayer.CharacterAdded:Connect(Animator.Reload);

return (Animator);
