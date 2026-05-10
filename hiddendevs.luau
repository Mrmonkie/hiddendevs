local module = {}
--Services/references
local image = script.Parent
local player = game.Players.LocalPlayer
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")

local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local burstEvent = ReplicatedStorage:WaitForChild("BurstEvent")

local movementFolder = ReplicatedStorage:WaitForChild("Animations"):WaitForChild("Movement")
local visualFolder = ReplicatedStorage:WaitForChild("Visuals")
local VFX = visualFolder:WaitForChild("VFX")
local BurstVfx = VFX:WaitForChild("Burst")

local normalAnim = humanoid:LoadAnimation(movementFolder:WaitForChild("NormalSpeed"))
local fastAnim = humanoid:LoadAnimation(movementFolder:WaitForChild("FastSpeed"))
local burstAnim = humanoid:LoadAnimation(movementFolder:WaitForChild("BurstSpeed"))

local camera = workspace.CurrentCamera

local root = character:WaitForChild("HumanoidRootPart")
--animation priorities
normalAnim.Priority = Enum.AnimationPriority.Movement
fastAnim.Priority = Enum.AnimationPriority.Movement
burstAnim.Priority = Enum.AnimationPriority.Movement

local bursts = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("BurstSound"):Clone()

local running = false
local movingTime = 0
local didBurst = false
local currentTween

local MAX_STAMINA = 100
local currentStamina = MAX_STAMINA
local staminaDrainRate = 5  -- drain rate when you running
local staminaRegenRate = 10 -- regen rate when your stamina ends

local playerGui = player:WaitForChild("PlayerGui")
local staminaGui = playerGui:WaitForChild("Stamina")
local staminaContainer = staminaGui:WaitForChild("ImageLabel")
local staminaBar = staminaContainer:WaitForChild("ImageLabel")

local originalSize = staminaBar.Size
local originalPosition = staminaBar.Position

local function updateStaminaBar()
	local ratio = math.clamp(currentStamina / MAX_STAMINA, 0, 1)

	staminaBar.Position = UDim2.new(
		originalPosition.X.Scale,
		originalPosition.X.Offset,
		originalPosition.Y.Scale + originalSize.Y.Scale * (1 - ratio),
		originalPosition.Y.Offset + originalSize.Y.Offset * (1 - ratio)
	)
end

if staminaBar then
	originalSize = staminaBar.Size
	updateStaminaBar()
end

--a function that stops all animations when you stop or another animation starts
local function stopAll()
	normalAnim:Stop()
	fastAnim:Stop()
	burstAnim:Stop()
end
--fov handler
local function tweenFOV(value, time)
	if currentTween then
		currentTween:Cancel()
	end
	currentTween = TweenService:Create(camera, TweenInfo.new(time, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {FieldOfView = value})
	currentTween:Play()
end

local function burstsound(hrp)
	bursts.Parent = hrp
	bursts:Play()

	bursts.Ended:Once(function()
		bursts:Destroy()
	end)
end

--clones the BurstVfx thats in replicated storage and places it infront of the player
--blue ui that appears when you burst connected to a local script by a bindable event
local function burstUI()
	image.ImageTransparency = 1
	image.Visible = true

	local tween = TweenService:Create(
		image,
		TweenInfo.new(
			0.5,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		),
		{
			ImageTransparency = 0
		}
	)

	tween:Play()
end

local function BurstVFX()
	local burst = BurstVfx:Clone()
	burst.Parent = workspace
	BurstVfx.Transparency = 0	
	local part

	if burst:IsA("Model") then
		if not burst.PrimaryPart then
			burst.PrimaryPart = burst:FindFirstChildWhichIsA("BasePart")
		end
		part = burst.PrimaryPart
	elseif burst:IsA("BasePart") then
		part = burst
	end

	if not part then return end

	part.Anchored = true
	part.Transparency = 1

	local connection
	connection = RunService.RenderStepped:Connect(function()
		if not running or not part or not part.Parent then
			connection:Disconnect()
			burst:Destroy()
			return
		end

		local targetCFrame = root.CFrame * CFrame.new(0, 0, -5)

		if burst:IsA("Model") then
			burst:SetPrimaryPartCFrame(targetCFrame)
		else
			part.CFrame = targetCFrame
		end
	end)
end
--shift key that gives you the ability to sprint
UIS.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		if currentStamina > 0 then
			running = true
			movingTime = 0
		end
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		running = false
		movingTime = 0
		didBurst = false
		stopAll()
		humanoid.WalkSpeed = 16
		tweenFOV(70, 0.5)
	end
end)
--glow effect that happends when you reach burst mode
local function glow()
	local glow = Instance.new("Highlight")
	glow.Name = "Glow"
	glow.Parent = character
	glow.FillTransparency = 0.5
	glow.FillColor = Color3.fromRGB(237, 230, 219)
	glow.OutlineTransparency = 0.5

	local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(glow, tweenInfo, {
		FillTransparency = 1,
		OutlineTransparency = 1
	})

	tween:Play()

	tween.Completed:Connect(function()
		glow:Destroy()
	end)
end

--Blueglow effect that happends when you reach the peak of burst mode
local function glowBlueHighlight()
	local glowBlue = Instance.new("Highlight")
	glowBlue.Name = "BlueGlow"
	glowBlue.Parent = character
	glowBlue.FillTransparency = 0.5
	glowBlue.FillColor = Color3.fromRGB(55, 151, 240)
	glowBlue.OutlineTransparency = 0.5

	local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(glowBlue, tweenInfo, {
		FillTransparency = 1,
		OutlineTransparency = 1
	})

	tween:Play()

	tween.Completed:Connect(function()
		glowBlue:Destroy()
	end)
end
--the main function that handles the sprinting and the speed of the humanoid
RunService.RenderStepped:Connect(function(dt)
	if running and humanoid.MoveDirection.Magnitude > 0 and currentStamina > 0 then
		movingTime += dt

		currentStamina = math.max(0, currentStamina - staminaDrainRate * dt)
		updateStaminaBar()

		if movingTime >= 9 then
			if not burstAnim.IsPlaying then
				stopAll()
				
				burstsound(root)
				
				burstAnim:Play()
				
				humanoid.WalkSpeed = 60
				tweenFOV(100, 1)
				
			--	if movingTime >= 9 then
					glow() -- why do we need double check here
			--	end
				if movingTime >= 10 then
					task.wait(4)
					humanoid.WalkSpeed = 90
				end

				if not didBurst then
					didBurst = true
					BurstVFX()
					burstEvent:Fire()
				end
			end
		elseif movingTime >= 4 then
			if not fastAnim.IsPlaying then
				stopAll()
				fastAnim:Play()
				humanoid.WalkSpeed = 45
				tweenFOV(80, 1)
			end
		else
			if not normalAnim.IsPlaying then
				stopAll()
				normalAnim:Play()
				humanoid.WalkSpeed = 30
				tweenFOV(70, 0.5)
			end
		end

		if currentStamina <= 0 then
			running = false
			movingTime = 0
			didBurst = false
			stopAll()
			humanoid.WalkSpeed = 16
			tweenFOV(70, 0.5)
		end
	else
		if not running and currentStamina < MAX_STAMINA then
			currentStamina = math.min(MAX_STAMINA, currentStamina + staminaRegenRate * dt)
			updateStaminaBar()
		end

		movingTime = 0
		didBurst = false
		stopAll()
		humanoid.WalkSpeed = 16
		tweenFOV(70, 0.5)
	end
end)

return module
