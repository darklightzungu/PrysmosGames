wait(0.1)

local SeatValue = script:WaitForChild("Seat")
local seat = SeatValue.Value

if not seat or not seat:IsA("VehicleSeat") then
	script:Destroy()
	return
end

local car = seat.Parent
if not car then
	script:Destroy()
	return
end

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")

local bikeBody = car.PrimaryPart
if not bikeBody then
	for _, part in pairs(car:GetDescendants()) do
		if part:IsA("Part") and part.Name ~= "Seat" then
			bikeBody = part
			break
		end
	end
end

if not bikeBody then
	script:Destroy()
	return
end

local bodyVelocity = bikeBody:FindFirstChild("BodyVelocity")
if not bodyVelocity then
	bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.Velocity = Vector3.new(0, 0, 0)
	bodyVelocity.MaxForce = Vector3.new(math.huge, 0, math.huge)
	bodyVelocity.P = 10000
	bodyVelocity.D = 500
	bodyVelocity.Parent = bikeBody
end

local MAX_SPEED = 100
local ACCELERATION = 50
local DECELERATION = 60
local TURN_SPEED = 180
local TURN_LERP = 0.08
local CAMERA_INFLUENCE = 0.05
local DRIFT_FACTOR = 0.96

local currentSpeed = 0
local currentDirection = bikeBody.CFrame.LookVector
local lastUpdate = tick()

local function getInput()
	local throttle = 0
	local steering = 0
	
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		throttle = 1
	elseif UserInputService:IsKeyDown(Enum.KeyCode.S) then
		throttle = -1
	end
	
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		steering = 1
	elseif UserInputService:IsKeyDown(Enum.KeyCode.D) then
		steering = -1
	end
	
	return throttle, steering
end

local function updatePhysics(deltaTime)
	local throttle, steering = getInput()
	
	if throttle ~= 0 then
		currentSpeed = currentSpeed + (throttle * ACCELERATION * deltaTime)
	else
		if math.abs(currentSpeed) > 0 then
			local sign = if currentSpeed > 0 then 1 else -1
			currentSpeed = currentSpeed - (sign * DECELERATION * deltaTime)
			if math.abs(currentSpeed) < 1 then
				currentSpeed = 0
			end
		end
	end
	
	currentSpeed = math.clamp(currentSpeed, -MAX_SPEED, MAX_SPEED)
	
	if steering ~= 0 then
		local turnAngle = steering * TURN_SPEED * deltaTime
		local rotated = bikeBody.CFrame * CFrame.Angles(0, math.rad(turnAngle), 0)
		currentDirection = rotated.LookVector
	end
	
	local cameraDelta = camera.CFrame.LookVector - bikeBody.CFrame.LookVector
	if cameraDelta.Magnitude > 0.1 then
		currentDirection = currentDirection:Lerp(camera.CFrame.LookVector, CAMERA_INFLUENCE)
		currentDirection = currentDirection.Unit
	end
	
	currentDirection = currentDirection * DRIFT_FACTOR + bikeBody.CFrame.LookVector * (1 - DRIFT_FACTOR)
	currentDirection = currentDirection.Unit
	
	local targetCFrame = CFrame.lookAt(bikeBody.Position, bikeBody.Position + currentDirection)
	bikeBody.CFrame = bikeBody.CFrame:Lerp(targetCFrame, TURN_LERP)
	
	bodyVelocity.Velocity = currentDirection * currentSpeed
end

local RunService = game:GetService("RunService")
local renderConnection

renderConnection = RunService.RenderStepped:Connect(function()
	if not seat.Occupant or seat.Occupant ~= humanoid then
		if bodyVelocity then
			bodyVelocity:Destroy()
		end
		if renderConnection then
			renderConnection:Disconnect()
		end
		script:Destroy()
		return
	end
	
	local currentTime = tick()
	local deltaTime = math.min(currentTime - lastUpdate, 0.016)
	lastUpdate = currentTime
	
	updatePhysics(deltaTime)
end)

humanoid.Died:Connect(function()
	if seat.Occupant then
		seat:Sit(nil)
	end
	if renderConnection then
		renderConnection:Disconnect()
	end
	if bodyVelocity then
		bodyVelocity:Destroy()
	end
	script:Destroy()
end)

player.CharacterAdded:Connect(function()
	script:Destroy()
end)

script.AncestryChanged:Connect(function(child, parent)
	if parent == nil then
		if bodyVelocity then
			bodyVelocity:Destroy()
		end
		if renderConnection then
			renderConnection:Disconnect()
		end
	end
end)
