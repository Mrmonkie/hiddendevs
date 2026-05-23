local module = {}

--// UI reference for the blue burst image effect
local image = script.Parent

--// Player references
local player = game.Players.LocalPlayer
local character = script.Parent

--// Gets the humanoid so we can control movement and animations
local humanoid = character:WaitForChild("Humanoid")

--// Services
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

--// RemoteEvent used for the burst effect
local burstEvent = ReplicatedStorage:WaitForChild("BurstEvent")

--// Animation folders
local movementFolder = ReplicatedStorage:WaitForChild("Animations"):WaitForChild("Movement")

--// Visual folders
local visualFolder = ReplicatedStorage:WaitForChild("Visuals")
local VFX = visualFolder:WaitForChild("VFX")
local BurstVfx = VFX:WaitForChild("Burst")

--// Loads all sprint animations
local normalAnim = humanoid:LoadAnimation(movementFolder:WaitForChild("NormalSpeed"))
local fastAnim = humanoid:LoadAnimation(movementFolder:WaitForChild("FastSpeed"))
local burstAnim = humanoid:LoadAnimation(movementFolder:WaitForChild("BurstSpeed"))

--// Camera reference used for FOV effects
local camera = workspace.CurrentCamera

--// HumanoidRootPart used for movement/VFX positioning
local root = character:WaitForChild("HumanoidRootPart")

--// Sets animation priorities so they override default movement animations
normalAnim.Priority = Enum.AnimationPriority.Movement
fastAnim.Priority = Enum.AnimationPriority.Movement
burstAnim.Priority = Enum.AnimationPriority.Movement

--// Clones burst sound from ReplicatedStorage
local bursts = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("BurstSound"):Clone()

--// Sprint variables
local running = false
local movingTime = 0
local didBurst = false
local currentTween

--// Stamina system values
local MAX_STAMINA = 100
local currentStamina = MAX_STAMINA

--// How fast stamina drains while sprinting
local staminaDrainRate = 5

--// How fast stamina regenerates when not sprinting
local staminaRegenRate = 10

--// GUI references for the stamina bar
local playerGui = player:WaitForChild("PlayerGui")
local staminaGui = playerGui:WaitForChild("Stamina")
local staminaContainer = staminaGui:WaitForChild("ImageLabel")
local staminaBar = staminaContainer:WaitForChild("ImageLabel")

--// Stores original size/position of the stamina bar
local originalSize = staminaBar.Size
local originalPosition = staminaBar.Position

--// Updates the stamina UI based on current stamina
local function updateStaminaBar()
	local ratio = math.clamp(currentStamina / MAX_STAMINA, 0, 1)

	staminaBar.Position = UDim2.new(
		originalPosition.X.Scale,
		originalPosition.X.Offset,
		originalPosition.Y.Scale + originalSize.Y.Scale * (1 - ratio),
		originalPosition.Y.Offset + originalSize.Y.Offset * (1 - ratio)
	)
end

--// Makes sure the stamina bar updates when the script starts
if staminaBar then
	originalSize = staminaBar.Size
	updateStaminaBar()
end

--// Stops all sprint animations
--// Prevents animations overlapping each other
local function stopAll()
	normalAnim:Stop()
	fastAnim:Stop()
	burstAnim:Stop()
end

--// Tweens the camera FOV smoothly
--// Used to make sprinting feel faster
local function tweenFOV(value, time)
	if currentTween then
		currentTween:Cancel()
	end

	currentTween = TweenService:Create(
		camera,
		TweenInfo.new(time, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
		{
			FieldOfView = value
		}
	)

	currentTween:Play()
end

--// Plays the burst sound on the player
local function burstsound(hrp)
	bursts.Parent = hrp
	bursts:Play()

	--// Deletes the sound after it finishes
	bursts.Ended:Once(function()
		bursts:Destroy()
	end)
end

--// Blue UI flash effect when burst activates
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

--// Creates the burst VFX in front of the player
local function BurstVFX()
	local burst = BurstVfx:Clone()

	burst.Parent = workspace

	BurstVfx.Transparency = 0	

	local part

	--// Checks if the VFX is a model or part
	if burst:IsA("Model") then
		if not burst.PrimaryPart then
			burst.PrimaryPart = burst:FindFirstChildWhichIsA("BasePart")
		end

		part = burst.PrimaryPart

	elseif burst:IsA("BasePart") then
		part = burst
	end

	--// Stops if no valid part exists
	if not part then
		return
	end

	part.Anchored = true
	part.Transparency = 1

	local connection

	--// Keeps the VFX positioned in front of the player
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

--// Detects when LeftShift is pressed
--// Starts sprinting if stamina is available
UIS.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.LeftShift then
		if currentStamina > 0 then
			running = true
			movingTime = 0
		end
	end
end)

--// Detects when LeftShift is released
--// Resets sprint values
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

--// White glow effect when entering burst stage
local function glow()
	local glow = Instance.new("Highlight")

	glow.Name = "Glow"
	glow.Parent = character

	glow.FillTransparency = 0.5
	glow.FillColor = Color3.fromRGB(237, 230, 219)

	glow.OutlineTransparency = 0.5

	local tweenInfo = TweenInfo.new(
		2,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)

	local tween = TweenService:Create(
		glow,
		tweenInfo,
		{
			FillTransparency = 1,
			OutlineTransparency = 1
		}
	)

	tween:Play()

	--// Removes highlight after fade
	tween.Completed:Connect(function()
		glow:Destroy()
	end)
end

--// Blue glow effect used at peak burst mode
local function glowBlueHighlight()
	local glowBlue = Instance.new("Highlight")

	glowBlue.Name = "BlueGlow"
	glowBlue.Parent = character

	glowBlue.FillTransparency = 0.5
	glowBlue.FillColor = Color3.fromRGB(55, 151, 240)

	glowBlue.OutlineTransparency = 0.5

	local tweenInfo = TweenInfo.new(
		2,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)

	local tween = TweenService:Create(
		glowBlue,
		tweenInfo,
		{
			FillTransparency = 1,
			OutlineTransparency = 1
		}
	)

	tween:Play()

	--// Removes highlight after fade
	tween.Completed:Connect(function()
		glowBlue:Destroy()
	end)
end

--// Main sprint loop
--// Runs every frame
RunService.RenderStepped:Connect(function(dt)

	--// Checks if the player is sprinting and moving
	if running and humanoid.MoveDirection.Magnitude > 0 and currentStamina > 0 then

		--// Tracks how long the player has been moving
		movingTime += dt

		--// Drains stamina while sprinting
		currentStamina = math.max(
			0,
			currentStamina - staminaDrainRate * dt
		)

		updateStaminaBar()

		--// Burst stage
		if movingTime >= 9 then

			if not burstAnim.IsPlaying then

				stopAll()

				burstsound(root)

				burstAnim:Play()

				humanoid.WalkSpeed = 60

				tweenFOV(100, 1)

				glow()

				--// Extra speed after 10 seconds
				if movingTime >= 10 then
					task.wait(4)
					humanoid.WalkSpeed = 90
				end

				--// Makes sure burst only activates once
				if not didBurst then
					didBurst = true

					BurstVFX()

					burstEvent:Fire()
				end
			end

		--// Fast sprint stage
		elseif movingTime >= 4 then

			if not fastAnim.IsPlaying then

				stopAll()

				fastAnim:Play()

				humanoid.WalkSpeed = 45

				tweenFOV(80, 1)
			end

		--// Normal sprint stage
		else

			if not normalAnim.IsPlaying then

				stopAll()

				normalAnim:Play()

				humanoid.WalkSpeed = 30

				tweenFOV(70, 0.5)
			end
		end

		--// Stops sprinting if stamina hits 0
		if currentStamina <= 0 then

			running = false
			movingTime = 0
			didBurst = false

			stopAll()

			humanoid.WalkSpeed = 16

			tweenFOV(70, 0.5)
		end

	else

		--// Regenerates stamina when not sprinting
		if not running and currentStamina < MAX_STAMINA then

			currentStamina = math.min(
				MAX_STAMINA,
				currentStamina + staminaRegenRate * dt
			)

			updateStaminaBar()
		end

		--// Resets sprint state
		movingTime = 0
		didBurst = false

		stopAll()

		humanoid.WalkSpeed = 16

		tweenFOV(70, 0.5)
	end
end)

return module
