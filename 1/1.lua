--=== TKOT KEY CHECK ===--

local REQUIRED_KEY = "TKOT"  -- your exact key (capital letters, no spaces)

-- ask user for input
local input = game:GetService("StarterGui"):PromptInputAsync{
    Title = "TKOT Key Required",
    Text = "Enter Key:",
    PlaceholderText = "TKOT",
    Password = true
}

if not input or input ~= REQUIRED_KEY then
    -- Wrong key OR no key entered
    print("Invalid TKOT key. Script terminated.")

    -- SELF-DELETE (clears the script from memory)
    for i = 1, 200 do
        pcall(function()
            script:Destroy()
        end)
    end

    return  -- stop execution immediately
end

print("TKOT Key Accepted. Loading...")

-- SERVICES
local Players = game:GetService("Players")
local UIS     = game:GetService("UserInputService")
local RS      = game:GetService("RunService")
local TS      = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local plr     = Players.LocalPlayer
local cam     = workspace.CurrentCamera

-- ===== STATE =====
local freecamEnabled, noclipEnabled, flyEnabled, invisEnabled, tpEnabled = false, false, false, false, false
local godEnabled, regenEnabled = false, false
local moveSpeed = 2
local keysDown = {}
local camRot = Vector2.new()
local bodyVelocity, bodyGyro
local tpMarker, lastTP
local guiVisible = true
local healthConn, regenConn, noclipConn

-- SPECTATE STATE
local spectating = false
local spectateTarget = nil

-- FLY SLIDER STATE
local sliderMenuOpen = false
local sliderFrame
local flySpeed = 2

-- ===== CONFIG =====
local PURPLE_DARK_1 = Color3.fromRGB(30, 0, 45)
local PURPLE_DARK_2 = Color3.fromRGB(45, 0, 70)
local PURPLE_DARK_3 = Color3.fromRGB(68, 0, 98)
local PURPLE_DARK_4 = Color3.fromRGB(90, 0, 130)
local TELEPORT_MAX_DIST, DROP_HEIGHT, DROP_STEPS = 1200, 3000, 10

-- ===== GUI ROOT =====
local screenGui = Instance.new("ScreenGui")
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.Parent = CoreGui

-- Fade overlay
local fadeFrame = Instance.new("Frame", screenGui)
fadeFrame.Size = UDim2.new(1,0,1,0)
fadeFrame.BackgroundColor3 = Color3.new(0,0,0)
fadeFrame.BackgroundTransparency = 1
fadeFrame.ZIndex = 10

local function fadeInOut(cb)
	TS:Create(fadeFrame, TweenInfo.new(0.25), {BackgroundTransparency = 0}):Play()
	task.wait(0.25)
	if cb then cb() end
	TS:Create(fadeFrame, TweenInfo.new(0.25), {BackgroundTransparency = 1}):Play()
end

-- Main Frame
local frame = Instance.new("Frame", screenGui)
frame.Size = UDim2.new(0, 460, 0, 300)
frame.Position = UDim2.new(0.3, 0, 0.2, 0)
frame.BackgroundColor3 = PURPLE_DARK_1
frame.Active, frame.Draggable = true, true

-- Banner
local banner = Instance.new("TextLabel", frame)
banner.Size = UDim2.new(1, 0, 0, 35)
banner.Position = UDim2.new(0, 0, 0, 0)
banner.BackgroundColor3 = PURPLE_DARK_2
banner.Text = "Made by Tubes — TK1"
banner.TextColor3 = Color3.fromRGB(255,255,255)
banner.Font = Enum.Font.SourceSansBold
banner.TextSize = 24

-- Tabs bar
local tabFrame = Instance.new("Frame", frame)
tabFrame.Size = UDim2.new(1, 0, 0, 30)
tabFrame.Position = UDim2.new(0, 0, 0, 35)
tabFrame.BackgroundColor3 = PURPLE_DARK_2

local contentFrame = Instance.new("Frame", frame)
contentFrame.Size = UDim2.new(1, 0, 1, -65)
contentFrame.Position = UDim2.new(0, 0, 0, 65)
contentFrame.BackgroundColor3 = PURPLE_DARK_1

local function makeTab(name, x)
	local b = Instance.new("TextButton", tabFrame)
	b.Size = UDim2.new(0, 100, 1, 0)
	b.Position = UDim2.new(0, x, 0, 0)
	b.Text = name
	b.BackgroundColor3 = PURPLE_DARK_3
	b.TextColor3 = Color3.fromRGB(255,255,255)
	b.Font = Enum.Font.SourceSansBold
	b.TextSize = 20
	return b
end

-- NEW TAB LAYOUT (Movement, Other, Teleport, Spectate)
local movementTab = makeTab("Movement", 5)
local otherTab    = makeTab("Other",    110)
local teleportTab = makeTab("Teleport", 215)
local spectateTab = makeTab("Spectate", 320) -- NEW

-- PAGE SYSTEM
local pages = {}
local function makePage(name)
	local p = Instance.new("Frame", contentFrame)
	p.Size = UDim2.new(1,0,1,0)
	p.BackgroundTransparency = 1
	p.Visible = false
	pages[name] = p
	return p
end

local function switchPage(name)
	for n, p in pairs(pages) do
		p.Visible = (n == name)
	end
end

-- Existing pages
local movePage = makePage("Movement")
local otherPage = makePage("Other")
local tpPage = makePage("Teleport")

-- NEW SPECTATE PAGE
local spectatePage = makePage("Spectate")

movementTab.MouseButton1Click:Connect(function() switchPage("Movement") end)
otherTab.MouseButton1Click:Connect(function() switchPage("Other") end)
teleportTab.MouseButton1Click:Connect(function() switchPage("Teleport") end)
spectateTab.MouseButton1Click:Connect(function() switchPage("Spectate") end)

switchPage("Movement")  -- default
-- ===== BUTTON FACTORY =====
local function makeButton(parent, name, y)
	local b = Instance.new("TextButton", parent)
	b.Size = UDim2.new(0, 200, 0, 40)
	b.Position = UDim2.new(0.5, -100, 0, y)
	b.Text = name
	b.BackgroundColor3 = PURPLE_DARK_4
	b.TextColor3 = Color3.fromRGB(255,255,255)
	b.Font = Enum.Font.SourceSansBold
	b.TextSize = 22
	return b
end

-- ===== MOVEMENT PAGE BUTTONS =====
local freecamBtn  = makeButton(movePage, "Freecam",       10)
local noclipBtn   = makeButton(movePage, "Noclip",        60)
local flyBtn      = makeButton(movePage, "Fly",          110)
local teleportBtn = makeButton(movePage, "Teleport Tool",160)

-- ============================================
-- ==  FLY SPEED SLIDER (FLOATING MINI PANEL) ==
-- ============================================

-- Create the slider UI (hidden until right-click)
sliderFrame = Instance.new("Frame", screenGui)
sliderFrame.Size = UDim2.new(0, 180, 0, 90)
sliderFrame.Position = UDim2.new(0, 0, 0, 0)
sliderFrame.BackgroundColor3 = PURPLE_DARK_3
sliderFrame.Visible = false
sliderFrame.Active = true
sliderFrame.Draggable = true

local sliderTitle = Instance.new("TextLabel", sliderFrame)
sliderTitle.Size = UDim2.new(1, 0, 0, 28)
sliderTitle.BackgroundColor3 = PURPLE_DARK_4
sliderTitle.Text = "Fly Speed"
sliderTitle.Font = Enum.Font.SourceSansBold
sliderTitle.TextSize = 18
sliderTitle.TextColor3 = Color3.fromRGB(255,255,255)

local sliderBar = Instance.new("Frame", sliderFrame)
sliderBar.Size = UDim2.new(1, -20, 0, 6)
sliderBar.Position = UDim2.new(0, 10, 0, 45)
sliderBar.BackgroundColor3 = Color3.fromRGB(80, 0, 120)

local sliderFill = Instance.new("Frame", sliderBar)
sliderFill.Size = UDim2.new(0.2, 0, 1, 0)
sliderFill.BackgroundColor3 = Color3.fromRGB(150, 0, 255)

local sliderLabel = Instance.new("TextLabel", sliderFrame)
sliderLabel.Size = UDim2.new(1, 0, 0, 20)
sliderLabel.Position = UDim2.new(0, 0, 0, 63)
sliderLabel.BackgroundTransparency = 1
sliderLabel.Font = Enum.Font.SourceSansBold
sliderLabel.TextSize = 16
sliderLabel.TextColor3 = Color3.fromRGB(255,255,255)
sliderLabel.Text = "Speed: 2"

-- Slider logic
local draggingSlider = false

local function setFlySpeed(val)
	flySpeed = math.clamp(val, 1, 10)
	moveSpeed = flySpeed
	sliderFill.Size = UDim2.new(flySpeed / 10, 0, 1, 0)
	sliderLabel.Text = "Speed: " .. tostring(flySpeed)
end

sliderBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		draggingSlider = true
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		draggingSlider = false
	end
end)

RS.RenderStepped:Connect(function()
	if draggingSlider then
		local mouse = UIS:GetMouseLocation().X
		local pos = sliderBar.AbsolutePosition.X
		local size = sliderBar.AbsoluteSize.X
		local pct = math.clamp((mouse - pos) / size, 0, 1)
		setFlySpeed(pct * 10)
	end
end)

-- Close slider when clicking elsewhere
UIS.InputBegan:Connect(function(input, gpe)
	if sliderMenuOpen and input.UserInputType == Enum.UserInputType.MouseButton1 then
		local m = UIS:GetMouseLocation()
		local abs = sliderFrame.AbsolutePosition
		local size = sliderFrame.AbsoluteSize

		local inside =
			m.X >= abs.X and m.X <= abs.X + size.X and
			m.Y >= abs.Y and m.Y <= abs.Y + size.Y

		if not inside then
			sliderFrame.Visible = false
			sliderMenuOpen = false
		end
	end
end)

-- =========================
-- RIGHT-CLICK TO OPEN PANEL
-- =========================
flyBtn.MouseButton2Click:Connect(function()
	if sliderMenuOpen then
		sliderFrame.Visible = false
		sliderMenuOpen = false
		return
	end

	-- open at mouse location
	local m = UIS:GetMouseLocation()
	sliderFrame.Position = UDim2.fromOffset(m.X - 80, m.Y - 20)
	sliderFrame.Visible = true
	sliderMenuOpen = true
end)
-- ===== UTIL =====
local function character()
	return plr.Character or plr.CharacterAdded:Wait()
end

-- ===== FREECAM =====
freecamBtn.MouseButton1Click:Connect(function()
	freecamEnabled = not freecamEnabled
	local char = character()

	if freecamEnabled then
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = (char:FindFirstChild("Head") and char.Head.CFrame) or cam.CFrame

		if char:FindFirstChild("HumanoidRootPart") then
			char.HumanoidRootPart.Anchored = true
		end

		UIS.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		UIS.MouseIconEnabled = false
		freecamBtn.Text = "Freecam ON"

	else
		cam.CameraType = Enum.CameraType.Custom
		cam.CameraSubject = char:FindFirstChildWhichIsA("Humanoid")

		if char:FindFirstChild("HumanoidRootPart") then
			char.HumanoidRootPart.Anchored = false
		end

		UIS.MouseBehavior = Enum.MouseBehavior.Default
		UIS.MouseIconEnabled = true
		freecamBtn.Text = "Freecam"
	end
end)

UIS.InputChanged:Connect(function(input)
	if freecamEnabled and input.UserInputType == Enum.UserInputType.MouseMovement then
		camRot = camRot + Vector2.new(-input.Delta.y, -input.Delta.x) * 0.2
	end
end)

-- ===== NOCLIP (FIXED & STABLE) =====

-- force collision state
local function setCollision(char, state)
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = state
		end
	end
end

-- connection holder
local noclipConn = nil

-- noclip ON
local function startNoclip()
	-- clean old connections to avoid double-running
	if noclipConn then
		noclipConn:Disconnect()
		noclipConn = nil
	end

	noclipConn = RS.Stepped:Connect(function()
		local c = plr.Character
		if c then
			setCollision(c, false)
		end
	end)
end

-- noclip OFF
local function stopNoclip()
	if noclipConn then
		noclipConn:Disconnect()
		noclipConn = nil
	end

	local c = plr.Character
	if c then
		setCollision(c, true)
	end
end

-- button toggle
noclipBtn.MouseButton1Click:Connect(function()
	noclipEnabled = not noclipEnabled
	noclipBtn.Text = noclipEnabled and "Noclip ON" or "Noclip"

	if noclipEnabled then
		startNoclip()
	else
		stopNoclip()
	end
end)

-- persist after respawn
plr.CharacterAdded:Connect(function(char)
	if noclipEnabled then
		-- wait for character to fully load
		char:WaitForChild("HumanoidRootPart")
		task.wait(0.1)
		startNoclip()
	end
end)


-- ===== FLY =====
flyBtn.MouseButton1Click:Connect(function()
	flyEnabled = not flyEnabled
	local c = character()
	local hum = c:FindFirstChildOfClass("Humanoid")

	if flyEnabled and c:FindFirstChild("HumanoidRootPart") then
		local hrp = c.HumanoidRootPart

		if hum then hum.PlatformStand = true end

		-- Movement forces
		bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.MaxForce = Vector3.new(1e5,1e5,1e5)
		bodyVelocity.Velocity = Vector3.zero
		bodyVelocity.Parent = hrp

		bodyGyro = Instance.new("BodyGyro")
		bodyGyro.MaxTorque = Vector3.new(1e5,1e5,1e5)
		bodyGyro.CFrame = cam.CFrame
		bodyGyro.Parent = hrp

		flyBtn.Text = "Fly ON"

	else
		if bodyVelocity then bodyVelocity:Destroy() end
		if bodyGyro then bodyGyro:Destroy() end
		if hum then hum.PlatformStand = false end
		flyBtn.Text = "Fly"
	end
end)

-- ===== MOVEMENT LOOP (updated for slider flySpeed) =====
RS.RenderStepped:Connect(function(dt)

	-- ==== FREECAM MOVEMENT ====
	if freecamEnabled then
		local cf = cam.CFrame
		local mv = Vector3.zero

		if keysDown[Enum.KeyCode.W] then mv += cf.LookVector end
		if keysDown[Enum.KeyCode.S] then mv -= cf.LookVector end
		if keysDown[Enum.KeyCode.A] then mv -= cf.RightVector end
		if keysDown[Enum.KeyCode.D] then mv += cf.RightVector end
		if keysDown[Enum.KeyCode.E] then mv += cf.UpVector end
		if keysDown[Enum.KeyCode.Q] then mv -= cf.UpVector end

		local speed = flySpeed  -- UPDATED
		if keysDown[Enum.KeyCode.LeftShift] then speed = flySpeed * 6 end
		if keysDown[Enum.KeyCode.LeftControl] then speed = flySpeed * 0.3 end

		if mv.Magnitude > 0 then
			cf = cf + mv.Unit * speed * dt * 60
		end

		local rotX = CFrame.Angles(0, math.rad(camRot.Y), 0)
		local rotY = CFrame.Angles(math.rad(camRot.X), 0, 0)
		cam.CFrame = rotX * rotY + cf.Position
	end

	-- ==== FLY MOVEMENT ====
	if flyEnabled and bodyVelocity and bodyGyro and plr.Character then
		local mv = Vector3.zero

		if keysDown[Enum.KeyCode.W] then mv += cam.CFrame.LookVector end
		if keysDown[Enum.KeyCode.S] then mv -= cam.CFrame.LookVector end
		if keysDown[Enum.KeyCode.A] then mv -= cam.CFrame.RightVector end
		if keysDown[Enum.KeyCode.D] then mv += cam.CFrame.RightVector end
		if keysDown[Enum.KeyCode.Space] then mv += Vector3.yAxis end
		if keysDown[Enum.KeyCode.LeftControl] then mv -= Vector3.yAxis end

		local speed = flySpeed * 30  -- UPDATED
		if keysDown[Enum.KeyCode.LeftShift] then speed *= 60 end

		bodyVelocity.Velocity = (mv.Magnitude > 0) and mv.Unit * speed or Vector3.zero
		bodyGyro.CFrame = cam.CFrame
	end
end)
-- ===== SPECTATE PAGE UI =====

local spectateList = Instance.new("ScrollingFrame", spectatePage)
spectateList.Size = UDim2.new(0, 350, 0, 220)
spectateList.Position = UDim2.new(0.5, -175, 0, 20)
spectateList.CanvasSize = UDim2.new(0, 0, 0, 0)
spectateList.ScrollBarThickness = 6
spectateList.BackgroundColor3 = PURPLE_DARK_2
spectateList.BorderSizePixel = 0

-- Create a single list entry
local function makeSpectateEntry(pl, y)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, -6, 0, 50)
	container.Position = UDim2.new(0, 3, 0, y)
	container.Parent = spectateList
	container.BackgroundColor3 = PURPLE_DARK_3

	-- thumbnail
	local thumb = Instance.new("ImageLabel", container)
	thumb.Size = UDim2.new(0, 50, 0, 50)
	thumb.BackgroundTransparency = 1
	local ok, img = pcall(function()
		return Players:GetUserThumbnailAsync(pl.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
	end)
	if ok then thumb.Image = img end

	-- player name
	local nameLbl = Instance.new("TextLabel", container)
	nameLbl.Size = UDim2.new(1, -60, 1, 0)
	nameLbl.Position = UDim2.new(0, 60, 0, 0)
	nameLbl.BackgroundTransparency = 1
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.TextColor3 = Color3.fromRGB(255,255,255)
	nameLbl.Font = Enum.Font.SourceSansBold
	nameLbl.TextSize = 20
	nameLbl.Text = pl.DisplayName

	-- click overlay
	local btn = Instance.new("TextButton", container)
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text = ""

	btn.MouseButton1Click:Connect(function()
		-- start spectating
		if pl ~= plr then
			spectating = true
			spectateTarget = pl
		end
	end)

	return container
end

-- refresh spectate list
local function refreshSpectate()
	spectateList:ClearAllChildren()
	local y = 0
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= plr then
			makeSpectateEntry(p, y)
			y += 55
		end
	end
	spectateList.CanvasSize = UDim2.new(0, 0, 0, y)
end

Players.PlayerAdded:Connect(refreshSpectate)
Players.PlayerRemoving:Connect(refreshSpectate)
refreshSpectate()

-- ===== STOP SPECTATE ON BACKSPACE (FIXED) =====
UIS.InputBegan:Connect(function(input, gpe)
	-- Prevent GUI from blocking Backspace
	if gpe then return end

	if input.KeyCode == Enum.KeyCode.Backspace then
		if spectating then
			spectating = false
			spectateTarget = nil
			cam.CameraType = Enum.CameraType.Custom
		end
	end
end)


-- ===== CAMERA FOLLOW ENGINE =====
RS.RenderStepped:Connect(function()
	if spectating and spectateTarget and spectateTarget.Character then
		local hrp = spectateTarget.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			-- follow behind player smoothly
			local camPos = hrp.Position + Vector3.new(0, 3, -8)
			local lookPos = hrp.Position

			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = CFrame.new(camPos, lookPos)
		else
			-- lost limb = stop spectating
			spectating = false
			spectateTarget = nil
		end
	end
end)
-- ===== OTHER PAGE BUTTONS =====
local invisBtn  = makeButton(otherPage, "Invisibility",   10)
local godBtn    = makeButton(otherPage, "God Mode",       60)
local regenBtn  = makeButton(otherPage, "Regen Mode",    110)

-- ===== INVISIBILITY (local-only) =====
local function setInvisibleLocal(state)
	local c = plr.Character
	if not c then return end

	for _, d in ipairs(c:GetDescendants()) do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = state and 1 or 0
			d.CanCollide = not state
		elseif d:IsA("Decal") or d:IsA("Texture") then
			d.Transparency = state and 1 or 0
		elseif d:IsA("Accessory") then
			local h = d:FindFirstChild("Handle")
			if h and h:IsA("BasePart") then
				h.LocalTransparencyModifier = state and 1 or 0
				h.CanCollide = not state
			end
		end
	end
end

invisBtn.MouseButton1Click:Connect(function()
	invisEnabled = not invisEnabled
	setInvisibleLocal(invisEnabled)
	invisBtn.Text = invisEnabled and "Invis ON" or "Invis"
end)

-- ===== GOD MODE =====
local function enableGod(hum)
	if healthConn then healthConn:Disconnect() end

	healthConn = hum.HealthChanged:Connect(function()
		if godEnabled then hum.Health = hum.MaxHealth end
	end)

	hum.TakeDamage = function() end
	hum.Health = hum.MaxHealth
end

local function disableGod()
	if healthConn then healthConn:Disconnect() end
	healthConn = nil
end

godBtn.MouseButton1Click:Connect(function()
	godEnabled = not godEnabled
	godBtn.Text = godEnabled and "God Mode ON" or "God Mode"

	local c = plr.Character
	if c then
		local hum = c:FindFirstChildOfClass("Humanoid")
		if hum then
			if godEnabled then enableGod(hum) else disableGod() end
		end
	end
end)

-- ===== REGEN MODE =====
local function enableRegen(hum)
	if regenConn then regenConn:Disconnect() end

	regenConn = hum.HealthChanged:Connect(function(v)
		if regenEnabled and v < hum.MaxHealth then
			task.delay(0.1, function()
				if regenEnabled and hum then
					hum.Health = hum.MaxHealth
				end
			end)
		end
	end)
end

local function disableRegen()
	if regenConn then regenConn:Disconnect() end
	regenConn = nil
end

regenBtn.MouseButton1Click:Connect(function()
	regenEnabled = not regenEnabled
	regenBtn.Text = regenEnabled and "Regen Mode ON" or "Regen Mode"

	local c = plr.Character
	if c then
		local hum = c:FindFirstChildOfClass("Humanoid")
		if hum then
			if regenEnabled then enableRegen(hum) else disableRegen() end
		end
	end
end)

-- ===== TELEPORT TOOL =====
local function buildRayParams()
	local params = RaycastParams.new()
	local ignoreList = { plr.Character }
	if tpMarker then table.insert(ignoreList, tpMarker) end
	params.FilterDescendantsInstances = ignoreList
	params.FilterType = Enum.RaycastFilterType.Blacklist
	return params
end

local function resolveGroundFromView()
	local origin = cam.CFrame.Position
	local dir = cam.CFrame.LookVector * TELEPORT_MAX_DIST
	local params = buildRayParams()

	-- forward ray
	local forward = workspace:Raycast(origin, dir, params)
	if forward then return forward.Position end

	local far = origin + dir
	local high = far + Vector3.new(0, DROP_HEIGHT, 0)

	local drop1 = workspace:Raycast(high, Vector3.new(0, -DROP_HEIGHT*2, 0), params)
	if drop1 then return drop1.Position end

	for i = 1, DROP_STEPS do
		local t = i / DROP_STEPS
		local step = origin + dir * t
		local probeStart = step + Vector3.new(0, DROP_HEIGHT, 0)
		local stepDrop = workspace:Raycast(probeStart, Vector3.new(0, -DROP_HEIGHT*2, 0), params)
		if stepDrop then return stepDrop.Position end
	end

	local camHigh = origin + Vector3.new(0, DROP_HEIGHT, 0)
	local camDrop = workspace:Raycast(camHigh, Vector3.new(0, -DROP_HEIGHT*2, 0), params)
	if camDrop then return camDrop.Position end

	return lastTP
end

teleportBtn.MouseButton1Click:Connect(function()
	tpEnabled = not tpEnabled
	teleportBtn.Text = tpEnabled and "Teleport ON" or "Teleport Tool"

	if tpEnabled then
		if not tpMarker then
			tpMarker = Instance.new("Part")
			tpMarker.Size = Vector3.new(2, 0.5, 2)
			tpMarker.Anchored = true
			tpMarker.Color = Color3.fromRGB(200, 0, 255)
			tpMarker.Material = Enum.Material.Neon
			tpMarker.CanCollide = false
			tpMarker.Transparency = 0.3
			tpMarker.Parent = workspace
		end
	else
		if tpMarker then tpMarker:Destroy() tpMarker = nil end
		lastTP = nil
	end
end)

-- right-click teleport while in freecam
UIS.InputBegan:Connect(function(input, processed)
	if tpEnabled and freecamEnabled and input.UserInputType == Enum.UserInputType.MouseButton2 then
		local pos = resolveGroundFromView()
		if pos then
			local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				fadeInOut(function()
					hrp.CFrame = CFrame.new(pos + Vector3.new(0,3,0))
				end)
			end
		end
	end
end)

-- TP marker updates
RS.RenderStepped:Connect(function()
	if tpEnabled and freecamEnabled and tpMarker then
		local p = resolveGroundFromView()
		if p then
			tpMarker.CFrame = CFrame.new(p + Vector3.new(0,0.25,0))
			lastTP = p
		end
	end
end)

-- ===== RESPAWN PERSISTENCE =====
plr.CharacterAdded:Connect(function(c)
	c:WaitForChild("HumanoidRootPart", 5)
	local hum = c:WaitForChild("Humanoid", 5)

	if invisEnabled then task.wait(0.1) setInvisibleLocal(true) end

	if noclipEnabled then startNoclip() end

	if flyEnabled and c:FindFirstChild("HumanoidRootPart") then
		local hrp = c.HumanoidRootPart
		if hum then hum.PlatformStand = true end

		bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.MaxForce = Vector3.new(1e5,1e5,1e5)
		bodyVelocity.Velocity = Vector3.zero
		bodyVelocity.Parent = hrp

		bodyGyro = Instance.new("BodyGyro")
		bodyGyro.MaxTorque = Vector3.new(1e5,1e5,1e5)
		bodyGyro.CFrame = cam.CFrame
		bodyGyro.Parent = hrp
	end

	if godEnabled and hum then enableGod(hum) end
	if regenEnabled and hum then enableRegen(hum) end
end)
-- ===== TELEPORT TAB: PLAYER LIST =====

local tpFrame = Instance.new("ScrollingFrame", tpPage)
tpFrame.Size = UDim2.new(0, 350, 0, 220)
tpFrame.Position = UDim2.new(0.5, -175, 0, 20)
tpFrame.CanvasSize = UDim2.new(0,0,0,0)
tpFrame.ScrollBarThickness = 6
tpFrame.BackgroundColor3 = PURPLE_DARK_2
tpFrame.BorderSizePixel = 0

local function makePlayerEntry(pl, y)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, -6, 0, 50)
	container.Position = UDim2.new(0, 3, 0, y)
	container.BackgroundColor3 = PURPLE_DARK_3
	container.Parent = tpFrame

	local thumb = Instance.new("ImageLabel", container)
	thumb.Size = UDim2.new(0, 50, 0, 50)
	thumb.BackgroundTransparency = 1

	local ok, img = pcall(function()
		return Players:GetUserThumbnailAsync(pl.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
	end)
	if ok then thumb.Image = img end

	local nameLbl = Instance.new("TextLabel", container)
	nameLbl.Size = UDim2.new(1, -60, 1, 0)
	nameLbl.Position = UDim2.new(0, 60, 0, 0)
	nameLbl.BackgroundTransparency = 1
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.TextColor3 = Color3.fromRGB(255,255,255)
	nameLbl.Font = Enum.Font.SourceSansBold
	nameLbl.TextSize = 20
	nameLbl.Text = pl.DisplayName

	local btn = Instance.new("TextButton", container)
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text = ""

	btn.MouseButton1Click:Connect(function()
		local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		local tHRP = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
		if hrp and tHRP then
			hrp.CFrame = tHRP.CFrame + Vector3.new(0, 3, 0)
		end
	end)

	return container
end

local function refreshTP()
	tpFrame:ClearAllChildren()
	local y = 0

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= plr then
			makePlayerEntry(p, y)
			y += 55
		end
	end

	tpFrame.CanvasSize = UDim2.new(0, 0, 0, y)
end

Players.PlayerAdded:Connect(refreshTP)
Players.PlayerRemoving:Connect(refreshTP)
refreshTP()

-- ===== INPUT / HOTKEYS =====

UIS.InputBegan:Connect(function(input, processed)
	if not processed then
		keysDown[input.KeyCode] = true

		-- Show/hide main GUI with RightControl
		if input.KeyCode == Enum.KeyCode.RightControl then
			guiVisible = not guiVisible
			frame.Visible = guiVisible
		end
	end
end)

UIS.InputEnded:Connect(function(input)
	keysDown[input.KeyCode] = nil
end)

-- ===== EVERYTHING READY =====
print("TK1 FULL GUI Loaded Successfully by Tubes.")
