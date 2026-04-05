BattlefieldTerminalMenuComponent = {}

local function getBattlefieldScreenPlay()
	if (BattlefieldSpawner ~= nil and BattlefieldSpawner._instance ~= nil) then
		return BattlefieldSpawner._instance
	end

	if (LuaScreenPlay ~= nil and LuaScreenPlay.getScreenPlay ~= nil) then
		local screenplay = LuaScreenPlay.getScreenPlay("BattlefieldSpawner")
		if (screenplay ~= nil) then
			return screenplay
		end
	end

	return BattlefieldSpawner
end

function BattlefieldTerminalMenuComponent:fillObjectMenuResponse(pSceneObject, pMenuResponse, pPlayer)
	local response = LuaObjectMenuResponse(pMenuResponse)
	response:addRadialMenuItem(120, 3, "Capture Terminal")
end

function BattlefieldTerminalMenuComponent:handleObjectMenuSelect(pSceneObject, pPlayer, selectedID)
	print("[BattlefieldTerminalMenuComponent] handleObjectMenuSelect called, selectedID: " .. tostring(selectedID))
	
	if (pSceneObject == nil or pPlayer == nil or selectedID ~= 120) then
		print("[BattlefieldTerminalMenuComponent] Invalid params or wrong ID")
		return 0
	end

	print("[BattlefieldTerminalMenuComponent] Calling startTerminalCapture")
	local screenplay = getBattlefieldScreenPlay()
	return screenplay:startTerminalCapture(pSceneObject, pPlayer)
end

BattlefieldSpawner = ScreenPlay:new {
	numberOfActs = 1,

	screenplayName = "BattlefieldSpawner",

	planets = {"corellia", "naboo", "tatooine", "dathomir", "yavin4", "talus", "rori", "endor"},

	notifyOnSpawn = true,

	notifyMessagePrefix = "[Battlefield]",
	captureTerminalTemplate = "object/tangible/terminal/terminal_hq.iff",
	captureTerminalOffsets = {
		{10, 10},
		{-10, -10},
		{10, -10},
	},
	notifyOnTerminalCapture = true,

	entryExpelDistance = 20,

	overtPromptCooldownMs = 15000,

	rotationIntervalMs = 1 * 60 * 60 * 1000,
	battlefieldDurationMs = 1 * 60 * 60 * 1000,
	rotationEventName = "BattlefieldRotationTick",
	captureTerminalDelayMs = 15000,
	captureTerminalTickMs = 1000,
	captureMovementTolerance = 3.0,

	noBuildRadius = 768,

	battlefields = {
		--{objecTemplate, x, z, y, size}

		--Templates:
		--object/battlefield_marker/battlefield_marker_128m.iff
		--object/battlefield_marker/battlefield_marker_192m.iff
		--object/battlefield_marker/battlefield_marker_256m.iff
		--object/battlefield_marker/battlefield_marker_384m.iff
		--object/battlefield_marker/battlefield_marker_512mm.iff

		corellia = {
			{"object/battlefield_marker/battlefield_marker_128m.iff", 3784, 380, -4048, 128},
			{"object/battlefield_marker/battlefield_marker_128m.iff", -1856, 7, -1232, 128},
			{"object/battlefield_marker/battlefield_marker_128m.iff", 246, 50, 4552, 128},
			{"object/battlefield_marker/battlefield_marker_128m.iff", -3570, 30, -2615, 128},
		},

		naboo = {
			{"object/battlefield_marker/battlefield_marker_128m.iff", -5032, -207, 6632, 128},
			{"object/battlefield_marker/battlefield_marker_128m.iff", -4168, 45, -589, 128},
			{"object/battlefield_marker/battlefield_marker_256m.iff", -3776, 10, -5344, 256},
		},

		tatooine = {
			{"object/battlefield_marker/battlefield_marker_256m.iff", 4949, 34, 4643, 256},
			{"object/battlefield_marker/battlefield_marker_128m.iff", 2396, 0, 4238, 128},
			{"object/battlefield_marker/battlefield_marker_128m.iff", -1873, 20, -585, 128},
			{"object/battlefield_marker/battlefield_marker_128m.iff", -2739, 34, -1560, 128},
		},

		dathomir = {
			{"object/battlefield_marker/battlefield_marker_128m.iff", 4245, 79, -3725, 128},
		},

		yavin4 = {
			{"object/battlefield_marker/battlefield_marker_256m.iff", -4230, 103, 3755, 256},
			{"object/battlefield_marker/battlefield_marker_256m.iff", 3791, 868, -2416, 256},
		},

		talus = {
			{"object/battlefield_marker/battlefield_marker_128m.iff", -491, 0, 4578, 128},
			{"object/battlefield_marker/battlefield_marker_128m.iff", -5331, 43, 2799, 128},
			{"object/battlefield_marker/battlefield_marker_256m.iff", -3342, 26, -3141, 256},
		},

		rori = {
			{"object/battlefield_marker/battlefield_marker_256m.iff", -2306, 79, 6467, 256},
			{"object/battlefield_marker/battlefield_marker_128m.iff", 2955, 108, -1249, 128},
			{"object/battlefield_marker/battlefield_marker_128m.iff", -3424, 100, -6129, 128},
		},

		endor = {
			{"object/battlefield_marker/battlefield_marker_128m.iff", -3677, 17, -4393, 128},
		},

	},
}

registerScreenPlay("BattlefieldSpawner", true)

function BattlefieldSpawner:ensureRotationPlanets()
	if (self.rotationPlanets == nil or #self.rotationPlanets == 0) then
		self.rotationPlanets = self:getEnabledRotationPlanets()
		BattlefieldSpawner.rotationPlanets = self.rotationPlanets
	end
end

function BattlefieldSpawner:start()
	BattlefieldSpawner._instance = self
	self.captureStates = {}
	self.rotationPlanets = self:getEnabledRotationPlanets()
	BattlefieldSpawner.captureStates = self.captureStates
	BattlefieldSpawner.rotationPlanets = self.rotationPlanets

	if (#self.rotationPlanets <= 0) then
		print("[BattlefieldSpawner] No enabled rotation planets found")
		return
	end

	print("[BattlefieldSpawner] Starting with " .. #self.rotationPlanets .. " rotation planets")

	-- Restore persisted state from storage
	self:loadPersistedState()

	if (self.activePlanetName ~= nil and self.activePlanetName ~= "" and self.battlefields[self.activePlanetName] ~= nil) then
		local hasLiveObjects = false
		if (self.activeBattlefieldObjectIDs ~= nil) then
			for i = 1, #self.activeBattlefieldObjectIDs, 1 do
				if (getSceneObject(self.activeBattlefieldObjectIDs[i]) ~= nil) then
					hasLiveObjects = true
					break
				end
			end
		end

		if (not hasLiveObjects) then
			local restorePlanet = self.activePlanetName
			local restoreIndex = self.activeBattlefieldIndex

			self.activePlanetName = nil
			self.activeBattlefieldIndex = nil
			self.activeBattlefieldObjectIDs = {}
			self.activeAreaObjectIDs = {}
			self.activeTerminalObjectIDs = {}
			BattlefieldSpawner.activePlanetName = nil
			BattlefieldSpawner.activeBattlefieldIndex = nil
			BattlefieldSpawner.activeBattlefieldObjectIDs = self.activeBattlefieldObjectIDs
			BattlefieldSpawner.activeAreaObjectIDs = self.activeAreaObjectIDs
			BattlefieldSpawner.activeTerminalObjectIDs = self.activeTerminalObjectIDs

			print("[BattlefieldSpawner] Restoring persisted battlefield state on startup: " .. tostring(restorePlanet) .. " index " .. tostring(restoreIndex))
			self:activateBattlefieldPlanet(restorePlanet, restoreIndex)
		else
			print("[BattlefieldSpawner] Persisted battlefield already active in world: " .. tostring(self.activePlanetName))
		end

		if (hasServerEvent(self.rotationEventName)) then
			rescheduleServerEvent(self.rotationEventName, self.rotationIntervalMs)
		else
			createServerEvent(self.rotationIntervalMs, "BattlefieldSpawner", "doRotationTick", self.rotationEventName)
		end

		print("[BattlefieldSpawner] Started successfully")
		return
	end

	self:applyRotationState()
	self:scheduleNextRotationTick()

	print("[BattlefieldSpawner] Started successfully")
end

function BattlefieldSpawner:getEnabledRotationPlanets()
	local enabledPlanets = {}

	for i = 1, #self.planets, 1 do
		local planetName = self.planets[i]

		if (isZoneEnabled(planetName) and self.battlefields[planetName] ~= nil) then
			table.insert(enabledPlanets, planetName)
		end
	end

	return enabledPlanets
end

function BattlefieldSpawner:getRotationState()
	self:ensureRotationPlanets()
	if (self.rotationPlanets == nil or #self.rotationPlanets == 0) then
		return false, 1, 0
	end

	local now = getTimestampMilli()
	local rotationIndex = math.floor(now / self.rotationIntervalMs)
	local intervalOffset = now % self.rotationIntervalMs
	local isActive = intervalOffset < self.battlefieldDurationMs
	local planetIndex = (rotationIndex % #self.rotationPlanets) + 1

	return isActive, planetIndex, intervalOffset
end

function BattlefieldSpawner:getCurrentRotationSlot()
	return math.floor(getTimestampMilli() / self.rotationIntervalMs)
end

function BattlefieldSpawner:getStableRotationIndex(planetName, locationCount)
	if (locationCount <= 1) then
		return 1
	end

	local currentSlot = self:getCurrentRotationSlot()
	local savedSlot = tonumber(readData("battlefieldRotationSlot"))
	local savedPlanet = readData("battlefieldRotationPlanet")
	local savedIndex = tonumber(readData("battlefieldRotationIndex"))

	if (savedSlot ~= nil and savedPlanet ~= nil and savedIndex ~= nil and savedSlot == currentSlot and savedPlanet == planetName and savedIndex >= 1 and savedIndex <= locationCount) then
		return savedIndex
	end

	local selectedIndex = self:getRandomBattlefieldIndex(planetName, locationCount)
	writeData("battlefieldRotationSlot", currentSlot)
	writeData("battlefieldRotationPlanet", planetName)
	writeData("battlefieldRotationIndex", selectedIndex)

	return selectedIndex
end

function BattlefieldSpawner:applyRotationState()
	local isActive, planetIndex = self:getRotationState()

	print("[BattlefieldSpawner] applyRotationState - isActive: " .. tostring(isActive) .. ", planetIndex: " .. tostring(planetIndex))

	if not isActive then
		print("[BattlefieldSpawner] State is inactive, calling deactivate...")
		self:deactivateCurrentBattlefieldPlanet()
		return
	end

	local planetName = self.rotationPlanets[planetIndex]

	if (self.activePlanetName == planetName) then
		if (self.activeBattlefieldObjectIDs ~= nil) then
			for i = 1, #self.activeBattlefieldObjectIDs, 1 do
				if (getSceneObject(self.activeBattlefieldObjectIDs[i]) ~= nil) then
					print("[BattlefieldSpawner] Already active on " .. tostring(planetName))
					return
				end
			end
		end

		print("[BattlefieldSpawner] Active planet persisted but objects missing, respawning on " .. tostring(planetName))
		self:activateBattlefieldPlanet(planetName, self.activeBattlefieldIndex)
		return
	end

	print("[BattlefieldSpawner] Activating battlefield on " .. tostring(planetName))
	self:activateBattlefieldPlanet(planetName)
end

function BattlefieldSpawner:scheduleNextRotationTick()
	local _, _, intervalOffset = self:getRotationState()
	local timeToNextTick = 1000

	if (intervalOffset < self.battlefieldDurationMs) then
		timeToNextTick = self.battlefieldDurationMs - intervalOffset
	else
		timeToNextTick = self.rotationIntervalMs - intervalOffset
	end

	if (timeToNextTick < 1000) then
		timeToNextTick = 1000
	end

	local seconds = math.floor(timeToNextTick / 1000)
	print("[BattlefieldSpawner] Scheduling next rotation tick in " .. seconds .. " seconds")

	if (hasServerEvent(self.rotationEventName)) then
		rescheduleServerEvent(self.rotationEventName, timeToNextTick)
	else
		createServerEvent(timeToNextTick, "BattlefieldSpawner", "doRotationTick", self.rotationEventName)
	end
end

function BattlefieldSpawner:doRotationTick()
	print("[BattlefieldSpawner] doRotationTick fired")
	
	-- Get the screenplay instance to ensure we have the correct context
	local screenplay = getBattlefieldScreenPlay()

	local success, err = pcall(function()
		screenplay:applyRotationState()
	end)

	if not success then
		print("[BattlefieldSpawner] ERROR in applyRotationState: " .. tostring(err))
	end

	-- Always reschedule even if there was an error
	local success2, err2 = pcall(function()
		screenplay:scheduleNextRotationTick()
	end)

	if not success2 then
		print("[BattlefieldSpawner] ERROR in scheduleNextRotationTick: " .. tostring(err2))
		-- Fallback: schedule in 1 hour if we can't calculate properly
		if (hasServerEvent(screenplay.rotationEventName)) then
			rescheduleServerEvent(screenplay.rotationEventName, 60 * 60 * 1000)
		else
			createServerEvent(60 * 60 * 1000, "BattlefieldSpawner", "doRotationTick", screenplay.rotationEventName)
		end
	end
end

function BattlefieldSpawner:activateBattlefieldPlanet(planetName, forcedIndex)
	self:deactivateCurrentBattlefieldPlanet()

	local location = self.battlefields[planetName]

	if (location == nil or #location <= 0) then
		return
	end

	local randomIndex = forcedIndex
	if (randomIndex == nil or randomIndex < 1 or randomIndex > #location) then
		randomIndex = self:getStableRotationIndex(planetName, #location)
	end

	-- Set planet data before spawning so terminals can read it
	self.activePlanetName = planetName
	self.activeBattlefieldIndex = randomIndex
	self.activeBattlefieldObjectIDs = {}
	self.activeAreaObjectIDs = {}
	self.activeTerminalObjectIDs = {}
	BattlefieldSpawner.activePlanetName = self.activePlanetName
	BattlefieldSpawner.activeBattlefieldIndex = self.activeBattlefieldIndex
	BattlefieldSpawner.activeBattlefieldObjectIDs = self.activeBattlefieldObjectIDs
	BattlefieldSpawner.activeAreaObjectIDs = self.activeAreaObjectIDs
	BattlefieldSpawner.activeTerminalObjectIDs = self.activeTerminalObjectIDs
	writeData("battlefieldActivePlanet", planetName)
	writeData("battlefieldActiveIndex", randomIndex)

	self:spawnBattlefield(location, randomIndex, planetName)
	self:spawnActiveArea(location, randomIndex, planetName)
	self:spawnCaptureTerminal(location, randomIndex, planetName)

	-- Persist spawned object IDs to storage
	self:savePersistedState()
end

function BattlefieldSpawner:getRandomBattlefieldIndex(planetName, locationCount)
	if (locationCount <= 1) then
		return 1
	end

	local lastIndexDataKey = "battlefieldLastIndex:" .. planetName
	local lastIndex = tonumber(readData(lastIndexDataKey))
	local randomIndex = getRandomNumber(1, locationCount)

	if (lastIndex ~= nil and randomIndex == lastIndex) then
		randomIndex = (randomIndex % locationCount) + 1
	end

	writeData(lastIndexDataKey, randomIndex)

	return randomIndex
end

function BattlefieldSpawner:deactivateCurrentBattlefieldPlanet()
	local endedPlanetName = self.activePlanetName

	if (endedPlanetName ~= nil) then
		print("[BattlefieldSpawner] Deactivating battlefield on " .. tostring(endedPlanetName))
	else
		print("[BattlefieldSpawner] Deactivate called but no active planet")
	end

	local winningFaction = self:getCurrentBattlefieldWinningFaction()

	for i = 1, #self.activeAreaObjectIDs, 1 do
		local pObj = getSceneObject(self.activeAreaObjectIDs[i])

		if (pObj ~= nil) then
			SceneObject(pObj):destroyObjectFromWorld()
			deleteData("battlefieldTerminal:" .. tostring(self.activeTerminalObjectIDs[i]))
		end
	end

	for i = 1, #self.activeBattlefieldObjectIDs, 1 do
		local pObj = getSceneObject(self.activeBattlefieldObjectIDs[i])

		if (pObj ~= nil) then
			SceneObject(pObj):destroyObjectFromWorld()
		end
	end

	for i = 1, #self.activeTerminalObjectIDs, 1 do
		local pObj = getSceneObject(self.activeTerminalObjectIDs[i])

		if (pObj ~= nil) then
			SceneObject(pObj):destroyObjectFromWorld()
		end
	end

	if (endedPlanetName ~= nil) then
		self:announceBattlefieldResult(endedPlanetName, winningFaction)
	end

	self.activeAreaObjectIDs = {}
	self.activeBattlefieldObjectIDs = {}
	self.activeTerminalObjectIDs = {}
	self.activePlanetName = nil
	self.activeBattlefieldIndex = nil
	deleteData("battlefieldActivePlanet")
	deleteData("battlefieldActiveIndex")

	-- Clear persisted state
	self:savePersistedState()

	print("[BattlefieldSpawner] Deactivation complete")
end

function BattlefieldSpawner:getCurrentBattlefieldWinningFaction()
	local imperialCount = 0
	local rebelCount = 0

	for i = 1, #self.activeTerminalObjectIDs, 1 do
		local pTerminal = getSceneObject(self.activeTerminalObjectIDs[i])

		if (pTerminal ~= nil) then
			local faction = TangibleObject(pTerminal):getFaction()

			if (faction == FACTIONIMPERIAL) then
				imperialCount = imperialCount + 1
			elseif (faction == FACTIONREBEL) then
				rebelCount = rebelCount + 1
			end
		end
	end

	if (imperialCount > rebelCount) then
		return FACTIONIMPERIAL
	elseif (rebelCount > imperialCount) then
		return FACTIONREBEL
	end

	return FACTIONNEUTRAL
end

function BattlefieldSpawner:announceBattlefieldResult(planetName, winningFaction)
	local factionName = self:getFactionDisplayName(winningFaction)

	if (winningFaction == FACTIONNEUTRAL) then
		local message = self.notifyMessagePrefix .. " Battlefield ended on " .. self:getDisplayPlanetName(planetName) .. ". No faction held majority control of the terminals."
		broadcastToGalaxy(nil, message)
		print(message)
		return
	end

	local message = self.notifyMessagePrefix .. " Battlefield ended on " .. self:getDisplayPlanetName(planetName) .. ". " .. factionName .. " controls the terminal majority and wins this event."
	broadcastToGalaxy(nil, message)
	print(message)
end

function BattlefieldSpawner:spawnBattlefield(location, num, planetName)
	if num <= 0 or num > #location then
		return
	end

	local sceneObjectTable = location[num]

	local pObj = spawnSceneObject(planetName, sceneObjectTable[1], sceneObjectTable[2], sceneObjectTable[3], sceneObjectTable[4], 0, math.rad(0))

	if (pObj ~= nil) then
		SceneObject(pObj):setRadius(sceneObjectTable[5])
		table.insert(self.activeBattlefieldObjectIDs, SceneObject(pObj):getObjectID())
		self:announceBattlefieldSpawn(sceneObjectTable, planetName)
	end
end

function BattlefieldSpawner:spawnCaptureTerminal(location, num, planetName)
	if num <= 0 or num > #location then
		return
	end

	local sceneObjectTable = location[num]
	local offsets = self.captureTerminalOffsets

	if (offsets == nil or #offsets <= 0) then
		return
	end

	for i = 1, #offsets, 1 do
		local offsetData = offsets[i]
		local terminalX = sceneObjectTable[2] + offsetData[1]
		local terminalY = sceneObjectTable[4] + offsetData[2]
		local terminalZ = sceneObjectTable[3]
		local pHeightRef = nil
		if (self.activeBattlefieldObjectIDs ~= nil and #self.activeBattlefieldObjectIDs > 0) then
			pHeightRef = getSceneObject(self.activeBattlefieldObjectIDs[1])
		end
		if (pHeightRef ~= nil) then
			terminalZ = getTerrainHeight(pHeightRef, terminalX, terminalY) + 0.25
		end

		local pTerminal = spawnSceneObject(planetName, self.captureTerminalTemplate, terminalX, terminalZ, terminalY, 0, math.rad(0))

		if (pTerminal ~= nil) then
			local terminalID = SceneObject(pTerminal):getObjectID()
			print("[BattlefieldSpawner] Spawned terminal " .. i .. " with ID: " .. tostring(terminalID))
			if (terminalID > 0) then
				TangibleObject(pTerminal):setFaction(FACTIONNEUTRAL)
				SceneObject(pTerminal):setObjectMenuComponent("BattlefieldTerminalMenuComponent")
				writeScreenPlayData(pTerminal, "BattlefieldSpawner", "isBattlefieldTerminal", 1)
				writeScreenPlayData(pTerminal, "BattlefieldSpawner", "terminalPlanet", planetName)
				writeData("battlefieldTerminal:" .. tostring(terminalID), 1)
				table.insert(self.activeTerminalObjectIDs, terminalID)
				BattlefieldSpawner.activeTerminalObjectIDs = self.activeTerminalObjectIDs
			else
				print("[BattlefieldSpawner] WARNING: Terminal spawned with invalid ID 0")
			end
		else
			print("[BattlefieldSpawner] WARNING: Failed to spawn terminal " .. i)
		end
	end
	print("[BattlefieldSpawner] Spawned " .. #self.activeTerminalObjectIDs .. " terminals total")
end

function BattlefieldSpawner:announceBattlefieldSpawn(sceneObjectTable, planetName)
	if not self.notifyOnSpawn then
		return
	end

	local message = self.notifyMessagePrefix .. " Battlefield active on " .. self:getDisplayPlanetName(planetName) .. " at (" .. sceneObjectTable[2] .. ", " .. sceneObjectTable[4] .. ")."

	broadcastToGalaxy(nil, message)
	print(message)
end

function BattlefieldSpawner:getDisplayPlanetName(planetName)
	if planetName == "yavin4" then
		return "Yavin 4"
	end

	return string.upper(string.sub(planetName, 1, 1)) .. string.sub(planetName, 2)
end

function BattlefieldSpawner:getFactionDisplayName(faction)
	if (faction == FACTIONIMPERIAL) then
		return "Imperial"
	elseif (faction == FACTIONREBEL) then
		return "Rebel"
	end

	return "Neutral"
end

function BattlefieldSpawner:isActiveBattlefieldTerminal(pTerminal)
	if (pTerminal == nil) then
		print("[BattlefieldSpawner] isActiveBattlefieldTerminal: pTerminal is nil")
		return false
	end

	if (self.activeTerminalObjectIDs == nil or #self.activeTerminalObjectIDs == 0) then
		self:ensureTerminalStateLoaded()
	end

	local terminalID = SceneObject(pTerminal):getObjectID()
	local terminalFlag = readScreenPlayData(pTerminal, "BattlefieldSpawner", "isBattlefieldTerminal")
	if (terminalFlag == 1 or terminalFlag == "1") then
		if (self.activeTerminalObjectIDs == nil) then
			self.activeTerminalObjectIDs = {}
		end
		local found = false
		for i = 1, #self.activeTerminalObjectIDs, 1 do
			if (self.activeTerminalObjectIDs[i] == terminalID) then
				found = true
				break
			end
		end
		if not found then
			table.insert(self.activeTerminalObjectIDs, terminalID)
		end
		return true
	end

	local terminalKey = "battlefieldTerminal:" .. tostring(terminalID)
	if (readData(terminalKey) == 1) then
		if (self.activeTerminalObjectIDs == nil) then
			self.activeTerminalObjectIDs = {}
		end
		local found = false
		for i = 1, #self.activeTerminalObjectIDs, 1 do
			if (self.activeTerminalObjectIDs[i] == terminalID) then
				found = true
				break
			end
		end
		if not found then
			table.insert(self.activeTerminalObjectIDs, terminalID)
		end
		return true
	end

	if (self.activeTerminalObjectIDs == nil or #self.activeTerminalObjectIDs == 0) then
		print("[BattlefieldSpawner] isActiveBattlefieldTerminal: activeTerminalObjectIDs is nil or empty")
		return false
	end
	print("[BattlefieldSpawner] Checking terminal ID: " .. tostring(terminalID))
	print("[BattlefieldSpawner] Active terminal IDs count: " .. #self.activeTerminalObjectIDs)
	
	for i = 1, #self.activeTerminalObjectIDs, 1 do
		print("[BattlefieldSpawner] Active terminal [" .. i .. "]: " .. tostring(self.activeTerminalObjectIDs[i]))
		if (self.activeTerminalObjectIDs[i] == terminalID) then
			return true
		end
	end

	return false
end

function BattlefieldSpawner:ensureTerminalStateLoaded()
	if (self.activeTerminalObjectIDs ~= nil and #self.activeTerminalObjectIDs > 0) then
		return
	end

	self.activeTerminalObjectIDs = {}

	local terminalIDs = readData("battlefieldTerminalIDs")
	if (terminalIDs ~= nil and terminalIDs ~= "") then
		for idStr in string.gmatch(terminalIDs, "[^,]+") do
			local objID = tonumber(idStr)
			if (objID ~= nil and objID > 0) then
				table.insert(self.activeTerminalObjectIDs, objID)
			end
		end
	end

	if (self.activePlanetName == nil or self.activePlanetName == "") then
		local planetName = readData("battlefieldActivePlanet")
		if (planetName ~= nil and planetName ~= "" and type(planetName) == "string") then
			self.activePlanetName = planetName
		end
	end

	print("[BattlefieldSpawner] ensureTerminalStateLoaded loaded " .. tostring(#self.activeTerminalObjectIDs) .. " terminal IDs")
end

function BattlefieldSpawner:parseCaptureStateData(captureData)
	if (captureData == nil or captureData == "") then
		return nil
	end

	local parts = {}
	for value in string.gmatch(captureData, "[^,]+") do
		table.insert(parts, value)
	end

	if (#parts < 4) then
		return nil
	end

	return {
		terminalID = tonumber(parts[1]),
		startTs = tonumber(parts[2]),
		startX = tonumber(parts[3]),
		startY = tonumber(parts[4]),
	}
end

function BattlefieldSpawner:serializeCaptureState(state)
	if (state == nil) then
		return ""
	end

	return tostring(state.terminalID) .. "," .. tostring(state.startTs) .. "," .. tostring(state.startX) .. "," .. tostring(state.startY)
end

function BattlefieldSpawner:clearCaptureState(playerID, pPlayer)
	local playerKey = string.format("%.0f", tonumber(playerID) or 0)
	local dataKey = "battlefieldCapture:" .. playerKey

	if (self.captureStates == nil) then
		self.captureStates = {}
	end

	self.captureStates[playerKey] = nil
	BattlefieldSpawner.captureStates = self.captureStates
	deleteData(dataKey)

	if (pPlayer ~= nil and SceneObject(pPlayer):isPlayerCreature()) then
		writeScreenPlayData(pPlayer, "BattlefieldSpawner", "captureState", "")
	end
end

function BattlefieldSpawner:resolveCaptureTerminalForPlayer(pPlayer, state)
	local pTerminal = nil

	if (state ~= nil and state.terminalID ~= nil) then
		pTerminal = getSceneObject(state.terminalID)
		if (pTerminal ~= nil and not self:isActiveBattlefieldTerminal(pTerminal)) then
			pTerminal = nil
		end
	end

	if (pTerminal ~= nil) then
		return pTerminal
	end

	local targetID = CreatureObject(pPlayer):getTargetID()
	if (targetID ~= nil and targetID ~= 0) then
		local pTarget = getSceneObject(targetID)
		if (pTarget ~= nil and self:isActiveBattlefieldTerminal(pTarget) and CreatureObject(pPlayer):isInRangeWithObject(pTarget, 6)) then
			if (state ~= nil) then
				state.terminalID = SceneObject(pTarget):getObjectID()
			end
			return pTarget
		end
	end

	return nil
end

function BattlefieldSpawner:refreshTerminalForNearbyPlayers(pTerminal, range)
	if (pTerminal == nil) then
		return
	end

	local refreshRange = range or 128
	local players = SceneObject(pTerminal):getPlayersInRange(refreshRange)
	if (players == nil) then
		return
	end

	for i = 1, #players, 1 do
		local pObj = players[i]
		if (pObj ~= nil and SceneObject(pObj):isPlayerCreature()) then
			SceneObject(pTerminal):sendTo(pObj)
		end
	end
end

function BattlefieldSpawner:savePersistedState()
	local battlefieldIDs = ""
	if (self.activeBattlefieldObjectIDs ~= nil) then
		for i = 1, #self.activeBattlefieldObjectIDs, 1 do
			if (i > 1) then
				battlefieldIDs = battlefieldIDs .. ","
			end
			battlefieldIDs = battlefieldIDs .. tostring(self.activeBattlefieldObjectIDs[i])
		end
	end

	local areaIDs = ""
	if (self.activeAreaObjectIDs ~= nil) then
		for i = 1, #self.activeAreaObjectIDs, 1 do
			if (i > 1) then
				areaIDs = areaIDs .. ","
			end
			areaIDs = areaIDs .. tostring(self.activeAreaObjectIDs[i])
		end
	end

	local terminalIDs = ""
	if (self.activeTerminalObjectIDs ~= nil) then
		for i = 1, #self.activeTerminalObjectIDs, 1 do
			if (i > 1) then
				terminalIDs = terminalIDs .. ","
			end
			terminalIDs = terminalIDs .. tostring(self.activeTerminalObjectIDs[i])
		end
	end

	print("[BattlefieldSpawner] Saving terminal IDs: " .. terminalIDs)
	writeData("battlefieldObjectIDs", battlefieldIDs)
	writeData("battlefieldAreaIDs", areaIDs)
	writeData("battlefieldTerminalIDs", terminalIDs)

	if (self.activePlanetName ~= nil and self.activePlanetName ~= "") then
		writeData("battlefieldActivePlanet", self.activePlanetName)
	else
		deleteData("battlefieldActivePlanet")
	end
end

function BattlefieldSpawner:loadPersistedState()
	self.activeBattlefieldObjectIDs = {}
	self.activeAreaObjectIDs = {}
	self.activeTerminalObjectIDs = {}
	self.activePlanetName = nil
	self.activeBattlefieldIndex = nil

	local battlefieldIDs = readData("battlefieldObjectIDs")
	if (battlefieldIDs ~= nil and battlefieldIDs ~= "") then
		for idStr in string.gmatch(battlefieldIDs, "[^,]+") do
			local objID = tonumber(idStr)
			if (objID ~= nil) then
				table.insert(self.activeBattlefieldObjectIDs, objID)
			end
		end
		print("[BattlefieldSpawner] Loaded " .. #self.activeBattlefieldObjectIDs .. " battlefield object IDs")
	end

	local areaIDs = readData("battlefieldAreaIDs")
	if (areaIDs ~= nil and areaIDs ~= "") then
		for idStr in string.gmatch(areaIDs, "[^,]+") do
			local objID = tonumber(idStr)
			if (objID ~= nil) then
				table.insert(self.activeAreaObjectIDs, objID)
			end
		end
		print("[BattlefieldSpawner] Loaded " .. #self.activeAreaObjectIDs .. " area object IDs")
	end

	local terminalIDs = readData("battlefieldTerminalIDs")
	if (terminalIDs ~= nil and terminalIDs ~= "") then
		for idStr in string.gmatch(terminalIDs, "[^,]+") do
			local objID = tonumber(idStr)
			if (objID ~= nil and objID > 0) then
				table.insert(self.activeTerminalObjectIDs, objID)
				print("[BattlefieldSpawner] Loaded terminal ID: " .. tostring(objID))
			end
		end
		print("[BattlefieldSpawner] Loaded " .. #self.activeTerminalObjectIDs .. " terminal object IDs total")
	end

	local planetName = readData("battlefieldActivePlanet")
	if (planetName ~= nil and tostring(planetName) ~= "") then
		self.activePlanetName = tostring(planetName)
		print("[BattlefieldSpawner] Loaded active planet: " .. tostring(planetName))
	end

	local activeIndex = tonumber(readData("battlefieldActiveIndex"))
	if (activeIndex ~= nil and activeIndex > 0) then
		self.activeBattlefieldIndex = activeIndex
	end
end

function BattlefieldSpawner:startTerminalCapture(pTerminal, pPlayer)
	print("[BattlefieldSpawner] startTerminalCapture called")
	
	if (pTerminal == nil or pPlayer == nil or not SceneObject(pPlayer):isPlayerCreature()) then
		print("[BattlefieldSpawner] Failed: pTerminal or pPlayer invalid")
		return 0
	end

	if (not self:isActiveBattlefieldTerminal(pTerminal)) then
		print("[BattlefieldSpawner] Failed: Not an active battlefield terminal")
		return 0
	end

	if (CreatureObject(pPlayer):isInCombat() or CreatureObject(pPlayer):isIncapacitated() or CreatureObject(pPlayer):isDead()) then
		print("[BattlefieldSpawner] Failed: Player in combat/incap/dead")
		CreatureObject(pPlayer):sendSystemMessage(self.notifyMessagePrefix .. " You cannot capture while in combat or incapacitated.")
		return 0
	end

	if (not CreatureObject(pPlayer):isInRangeWithObject(pTerminal, 6)) then
		print("[BattlefieldSpawner] Failed: Player not in range")
		return 0
	end

	if (not CreatureObject(pPlayer):isOvert()) then
		print("[BattlefieldSpawner] Failed: Player not overt")
		CreatureObject(pPlayer):sendSystemMessage(self.notifyMessagePrefix .. " You must be Overt to capture the battlefield terminal.")
		return 0
	end

	local playerFaction = CreatureObject(pPlayer):getFaction()

	if (playerFaction ~= FACTIONIMPERIAL and playerFaction ~= FACTIONREBEL) then
		CreatureObject(pPlayer):sendSystemMessage(self.notifyMessagePrefix .. " You must be Imperial or Rebel to capture the battlefield terminal.")
		return 0
	end

	local terminalFaction = TangibleObject(pTerminal):getFaction()

	if (terminalFaction == playerFaction) then
		CreatureObject(pPlayer):sendSystemMessage(self.notifyMessagePrefix .. " Your faction already controls this terminal.")
		return 0
	end

	if (self.captureStates == nil) then
		self.captureStates = {}
	end
	BattlefieldSpawner.captureStates = self.captureStates

	local playerID = SceneObject(pPlayer):getObjectID()
	local playerKey = string.format("%.0f", tonumber(playerID) or 0)
	local captureDataKey = "battlefieldCapture:" .. playerKey
	local existingCaptureData = readData(captureDataKey)
	if (existingCaptureData == nil or existingCaptureData == "") then
		existingCaptureData = readScreenPlayData(pPlayer, "BattlefieldSpawner", "captureState")
	end
	if (existingCaptureData ~= nil and existingCaptureData ~= "") then
		local existingState = self:parseCaptureStateData(existingCaptureData)
		local existingStartTs = 0
		if (existingState ~= nil and existingState.startTs ~= nil) then
			existingStartTs = tonumber(existingState.startTs) or 0
		end

		local now = getTimestampMilli()
		local clearPersistedCapture = false

		if (existingStartTs <= 0) then
			clearPersistedCapture = true
		elseif ((now - existingStartTs) > (self.captureTerminalDelayMs * 2)) then
			clearPersistedCapture = true
		else
			clearPersistedCapture = false
		end

		if (clearPersistedCapture) then
			deleteData(captureDataKey)
			writeScreenPlayData(pPlayer, "BattlefieldSpawner", "captureState", "")
			existingCaptureData = nil
			if (self.captureStates ~= nil) then
				self.captureStates[playerKey] = nil
			end
		else
			CreatureObject(pPlayer):sendSystemMessage(self.notifyMessagePrefix .. " Capture already in progress. Remain still and out of combat.")
			return 0
		end
	end

	if ((existingCaptureData ~= nil and existingCaptureData ~= "") and self.captureStates[playerKey] == nil) then
		self.captureStates[playerKey] = self:parseCaptureStateData(existingCaptureData)
	end

	if (self.captureStates[playerKey] ~= nil) then
		CreatureObject(pPlayer):sendSystemMessage(self.notifyMessagePrefix .. " Capture already in progress. Remain still and out of combat.")
		return 0
	end

	self.captureStates[playerKey] = {
		terminalID = SceneObject(pTerminal):getObjectID(),
		startTs = getTimestampMilli(),
		startX = SceneObject(pPlayer):getWorldPositionX(),
		startY = SceneObject(pPlayer):getWorldPositionY(),
	}
	local serializedCapture = self:serializeCaptureState(self.captureStates[playerKey])
	writeData(captureDataKey, serializedCapture)
	writeScreenPlayData(pPlayer, "BattlefieldSpawner", "captureState", serializedCapture)
	print("[BattlefieldSpawner] capture state write key=" .. captureDataKey .. " value=" .. serializedCapture)

	local seconds = math.floor(self.captureTerminalDelayMs / 1000)
	CreatureObject(pPlayer):sendSystemMessage(self.notifyMessagePrefix .. " Capturing terminal... stay still and out of combat for " .. seconds .. " seconds.")
	print("[BattlefieldSpawner] Starting terminal capture for player " .. CreatureObject(pPlayer):getFirstName())
	createEvent(self.captureTerminalTickMs, "BattlefieldSpawner", "processTerminalCapture", pPlayer, "")

	return 0
end

function BattlefieldSpawner:processTerminalCapture(pPlayer)
	print("[BattlefieldSpawner] processTerminalCapture called")
	
	if (pPlayer == nil or not SceneObject(pPlayer):isPlayerCreature()) then
		print("[BattlefieldSpawner] pPlayer is nil or not a player creature")
		return 0
	end
	
	-- Get the screenplay instance
	local screenplay = getBattlefieldScreenPlay()

	if (screenplay.captureStates == nil) then
		if (BattlefieldSpawner.captureStates ~= nil) then
			screenplay.captureStates = BattlefieldSpawner.captureStates
		else
			screenplay.captureStates = {}
			BattlefieldSpawner.captureStates = screenplay.captureStates
		end
	end

	local playerID = SceneObject(pPlayer):getObjectID()
	local playerKey = string.format("%.0f", tonumber(playerID) or 0)
	local captureDataKey = "battlefieldCapture:" .. playerKey
	local state = screenplay.captureStates[playerKey]
	if (state == nil) then
		local captureData = readData(captureDataKey)
		state = screenplay:parseCaptureStateData(captureData)
		if (state ~= nil) then
			screenplay.captureStates[playerKey] = state
		end
	end

	if (state == nil) then
		local playerCaptureData = readScreenPlayData(pPlayer, "BattlefieldSpawner", "captureState")
		state = screenplay:parseCaptureStateData(playerCaptureData)
		if (state ~= nil) then
			screenplay.captureStates[playerKey] = state
			writeData(captureDataKey, screenplay:serializeCaptureState(state))
		end
	end

	if (state == nil) then
		print("[BattlefieldSpawner] processTerminalCapture: no capture state found for player " .. tostring(playerID))
		return 0
	end

	local pTerminal = screenplay:resolveCaptureTerminalForPlayer(pPlayer, state)

	if (pTerminal == nil) then
		print("[BattlefieldSpawner] processTerminalCapture: unable to resolve terminal for player " .. tostring(playerID))
		screenplay:clearCaptureState(playerID, pPlayer)
		return 0
	end

	state.terminalID = SceneObject(pTerminal):getObjectID()
	local serializedCapture = screenplay:serializeCaptureState(state)
	writeData(captureDataKey, serializedCapture)
	writeScreenPlayData(pPlayer, "BattlefieldSpawner", "captureState", serializedCapture)

	if (CreatureObject(pPlayer):isInCombat() or CreatureObject(pPlayer):isIncapacitated() or CreatureObject(pPlayer):isDead()) then
		CreatureObject(pPlayer):sendSystemMessage(screenplay.notifyMessagePrefix .. " Capture interrupted by combat.")
		screenplay:clearCaptureState(playerID, pPlayer)
		return 0
	end

	if (not CreatureObject(pPlayer):isInRangeWithObject(pTerminal, 6)) then
		CreatureObject(pPlayer):sendSystemMessage(screenplay.notifyMessagePrefix .. " Capture interrupted. You moved out of range.")
		screenplay:clearCaptureState(playerID, pPlayer)
		return 0
	end

	if (not CreatureObject(pPlayer):isOvert()) then
		CreatureObject(pPlayer):sendSystemMessage(screenplay.notifyMessagePrefix .. " Capture interrupted. You are no longer Overt.")
		screenplay:clearCaptureState(playerID, pPlayer)
		return 0
	end

	local playerFaction = CreatureObject(pPlayer):getFaction()

	if (playerFaction ~= FACTIONIMPERIAL and playerFaction ~= FACTIONREBEL) then
		CreatureObject(pPlayer):sendSystemMessage(screenplay.notifyMessagePrefix .. " Capture interrupted. You are no longer factioned.")
		screenplay:clearCaptureState(playerID, pPlayer)
		return 0
	end

	local currentX = SceneObject(pPlayer):getWorldPositionX()
	local currentY = SceneObject(pPlayer):getWorldPositionY()
	local dx = currentX - state.startX
	local dy = currentY - state.startY

	if ((dx * dx + dy * dy) > (screenplay.captureMovementTolerance * screenplay.captureMovementTolerance)) then
		state.startTs = getTimestampMilli()
		state.startX = currentX
		state.startY = currentY
		local resetCapture = screenplay:serializeCaptureState(state)
		writeData(captureDataKey, resetCapture)
		writeScreenPlayData(pPlayer, "BattlefieldSpawner", "captureState", resetCapture)
		CreatureObject(pPlayer):sendSystemMessage(screenplay.notifyMessagePrefix .. " Movement detected. Capture timer restarted.")
		createEvent(screenplay.captureTerminalTickMs, "BattlefieldSpawner", "processTerminalCapture", pPlayer, "")
		return 0
	end

	local elapsedMs = getTimestampMilli() - state.startTs

	if (elapsedMs < screenplay.captureTerminalDelayMs) then
		local remainingSeconds = math.ceil((screenplay.captureTerminalDelayMs - elapsedMs) / 1000)
		print("[BattlefieldSpawner] Capture in progress, " .. remainingSeconds .. " seconds remaining")
		createEvent(screenplay.captureTerminalTickMs, "BattlefieldSpawner", "processTerminalCapture", pPlayer, "")
		return 0
	end

	local terminalFaction = TangibleObject(pTerminal):getFaction()

	if (terminalFaction == playerFaction) then
		CreatureObject(pPlayer):sendSystemMessage(screenplay.notifyMessagePrefix .. " Your faction already controls this terminal.")
		screenplay:clearCaptureState(playerID, pPlayer)
		return 0
	end

	TangibleObject(pTerminal):setFaction(playerFaction)
	screenplay:refreshTerminalForNearbyPlayers(pTerminal, screenplay.noBuildRadius)

	local playerName = CreatureObject(pPlayer):getFirstName()
	local factionName = screenplay:getFactionDisplayName(playerFaction)

	print("[BattlefieldSpawner] " .. playerName .. " successfully captured terminal for " .. factionName)
	CreatureObject(pPlayer):sendSystemMessage(screenplay.notifyMessagePrefix .. " You captured the battlefield terminal for " .. factionName .. ".")

	local activePlanetName = screenplay.activePlanetName

	if (activePlanetName ~= nil and activePlanetName ~= "" and type(activePlanetName) == "string") then
		broadcastToGalaxy(nil, screenplay.notifyMessagePrefix .. " " ..playerName .. " captured the battlefield terminal on " .. screenplay:getDisplayPlanetName(activePlanetName) .. " for " .. factionName .. ".")
	end

	screenplay:clearCaptureState(playerID, pPlayer)

	return 0
end

function BattlefieldSpawner:spawnActiveArea(location, num, planetName)
	if num <= 0 or num > #location then
		return
	end

	local sceneObjectTable = location[num]

	local pActiveArea = spawnActiveArea(planetName, "object/active_area.iff", sceneObjectTable[2], sceneObjectTable[3], sceneObjectTable[4], self.noBuildRadius, 0)

	if (pActiveArea ~= nil) then
		ActiveArea(pActiveArea):setNoBuildArea(true)
		ActiveArea(pActiveArea):setNoSpawnArea(true)
		table.insert(self.activeAreaObjectIDs, SceneObject(pActiveArea):getObjectID())
		createObserver(ENTEREDAREA, "BattlefieldSpawner", "notifyEnteredBattlefieldArea", pActiveArea)
	end
end

function BattlefieldSpawner:notifyEnteredBattlefieldArea(pArea, pPlayer)
	if (pArea == nil or pPlayer == nil or not SceneObject(pArea):isActiveArea() or not SceneObject(pPlayer):isPlayerCreature()) then
		return 0
	end
	
	-- Get the screenplay instance
	local screenplay = getBattlefieldScreenPlay()

	if (CreatureObject(pPlayer):getFaction() == 0) then
		screenplay:expelFromBattlefieldArea(pArea, pPlayer)
		CreatureObject(pPlayer):sendSystemMessage(screenplay.notifyMessagePrefix .. " You must be factioned and Overt to enter this battlefield zone.")
		return 0
	end

	if (not CreatureObject(pPlayer):isOvert()) then
		screenplay:expelFromBattlefieldArea(pArea, pPlayer)
		CreatureObject(pPlayer):sendSystemMessage(screenplay.notifyMessagePrefix .. " You must be Overt to enter this battlefield zone.")

		local playerID = SceneObject(pPlayer):getObjectID()
		local now = getTimestampMilli()
		local promptDataKey = playerID .. ":battlefieldOvertPromptTimestamp"
		local lastPromptTs = readData(promptDataKey)

		if (lastPromptTs == nil) then
			lastPromptTs = 0
		end

		if (now - lastPromptTs >= screenplay.overtPromptCooldownMs) then
			local suiManager = LuaSuiManager()
			suiManager:sendConfirmSui(pPlayer, pPlayer, "BattlefieldSpawner", "overtConfirmCallback", screenplay.notifyMessagePrefix .. " Entering this battlefield requires Overt status. Switch to Overt now?", "Go Overt")
			writeData(promptDataKey, now)
		end

		return 0
	end

	return 0
end

function BattlefieldSpawner:overtConfirmCallback(pCreature, pSui, eventIndex)
	local cancelPressed = (eventIndex == 1)

	if (pCreature == nil or cancelPressed or not SceneObject(pCreature):isPlayerCreature()) then
		return 0
	end
	
	-- Get the screenplay instance
	local screenplay = getBattlefieldScreenPlay()

	if (CreatureObject(pCreature):getFaction() == 0) then
		CreatureObject(pCreature):sendSystemMessage(screenplay.notifyMessagePrefix .. " You are not factioned and cannot go Overt.")
		return 0
	end

	if (not CreatureObject(pCreature):isOvert()) then
		CreatureObject(pCreature):setFactionStatus(2)
		CreatureObject(pCreature):sendSystemMessage(screenplay.notifyMessagePrefix .. " You are now Overt. Re-enter the battlefield zone.")
	end

	return 0
end

function BattlefieldSpawner:expelFromBattlefieldArea(pArea, pPlayer)
	local playerX = SceneObject(pPlayer):getWorldPositionX()
	local playerY = SceneObject(pPlayer):getWorldPositionY()

	local areaX = SceneObject(pArea):getWorldPositionX()
	local areaY = SceneObject(pArea):getWorldPositionY()

	local diffY = playerY - areaY
	local diffX = playerX - areaX

	local angle = math.atan2(diffY, diffX)
	local currentDistance = math.sqrt((diffX * diffX) + (diffY * diffY))
	local radius = currentDistance + self.entryExpelDistance

	local newX = areaX + (math.cos(angle) * radius)
	local newY = areaY + (math.sin(angle) * radius)
	local newZ = getTerrainHeight(pPlayer, newX, newY)

	CreatureObject(pPlayer):teleport(newX, newZ, newY, 0)
end
