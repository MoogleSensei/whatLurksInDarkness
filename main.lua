-- Flashlight as an Unconventional Weapon!... Game!
-- Tentatively titled:
--
-- What Lurks in the Dark
--
-- Written by Sean Miller
-- 04/19/2015
--
-- This is my 48 hour Ludum Dare 32 Compo entry.
-- Full disclosure, this is the first game I ever made.
-- And it's a MESS.
-- Having fun reading this nonsense
debug = false

local inspect = require('inspect')
Camera = require('hump/camera')

-- Map stuff, should be moved to function to provide capability of loading different maps
tileLoader = require('AdvTileLoader')
tileLoader.Loader.path = 'maps/'

pauseScreen = love.graphics.newImage('assets/pauseScreen.png')
startScreen = love.graphics.newImage('assets/titleSplash.jpg')
victoryScreen = love.graphics.newImage('assets/victoryScreen.jpg')
testFont = love.graphics.newFont('assets/flashFont.ttf',32)
love.graphics.setFont(testFont)

titleMusic = love.audio.newSource('assets/titleMusic.wav', 'stream')
gameMusic = love.audio.newSource('assets/gameMusic.mp3', 'stream')
titleMusic:setVolume(0.1) -- 10% of ordinary volume
gameMusic:setVolume(0.07) -- 10% of ordinary volume
stateTransTimer = 30

function love.load(args, tmpMapStr)
	local mapStr = tmpMapStr or ''
	if mapStr == 'victory' then
		state = 'victoryState'
	elseif mapStr == '' then
		state = 'startScreenState'
		playerDeathCount = 0
	else
		map = tileLoader.Loader.load(mapStr)
		groundLayer = map('Ground')
		darknessLayer = map('Darkness')

		tiles = {}
		for id, tile in pairs(map.tiles) do
		    if tile.properties.name then
		        tiles[tile.properties.name] = tile
		    end
		end
		tileWidth,tileHeight = 32,32
		enemies = {}
		lightStones = {}
		winGoal = 0
		winCond = 0

		-- This is to extract your player, enemies, and light stones from the objects layer
		for i,obj in pairs(map('Objects').objects) do
			if obj.name == 'Player' then
				playerObject = obj
			end
			if obj.name == 'Enemy' then
				table.insert(enemies,obj)
			end
			if obj.name == 'Light Stone' then
				table.insert(lightStones,obj)
				winGoal = winGoal + 1
			end
		end
		player = convertPlayer(playerObject)
		for i,enemy in ipairs(enemies) do
			enemies[i] = convertEnemy(enemy)
		end
		for i,lightStone in ipairs(lightStones) do
			lightStones[i] = convertLightStone(lightStone)
		end
		cam = Camera(player.x,player.y)
		state = 'gameState'
		currentLevel = mapStr
	end
	if mapStr == '' then nextLevel = 'level1.tmx' end
	if mapStr == 'level1.tmx' then nextLevel = 'level2.tmx' end
	if mapStr == 'level2.tmx' then nextLevel = 'level3.tmx' end
	if mapStr == 'level3.tmx' then nextLevel = 'level4.tmx' end
	if mapStr == 'level4.tmx' then nextLevel = 'level5.tmx' end
	if mapStr == 'level5.tmx' then nextLevel = 'level6.tmx' end
	if mapStr == 'level6.tmx' then nextLevel = 'victory' end
end

function love.update(dt)
	stateTransTimer = stateTransTimer - 1
	if state == 'victoryState' then
		if not(titleMusic:isPlaying()) then
			titleMusic:play()
		end
		if love.keyboard.isDown('f') and stateTransTimer <= 0 then
			stateTransTimer = 30
			state = 'startScreenState'
		end
	elseif state == 'startScreenState' then
		if not(titleMusic:isPlaying()) then
			titleMusic:play()
		end
		if love.keyboard.isDown('escape') then love.event.quit() end
		if love.keyboard.isDown('f') and stateTransTimer <= 0 then
			stateTransTimer = 30
			love.load(nil,'level1.tmx')
		end
	elseif state == 'pauseState' then
		if gameMusic:isPlaying() then
			gameMusic:pause()
		end
		if not(titleMusic:isPlaying()) then
			titleMusic:play()
		end
		if love.keyboard.isDown('escape') then love.event.quit() end
		if love.keyboard.isDown('f') then state = 'gameState' end
	elseif state == 'gameState' then
		if titleMusic:isPlaying() then
			titleMusic:stop()
		end
		if not(gameMusic:isPlaying()) then
			gameMusic:play()
		end
		if love.keyboard.isDown('escape') then love.event.quit() end
		if love.keyboard.isDown(' ') and not(player.isAWinner) then state = 'pauseState' end
		if player.isAWinner then
			if love.keyboard.isDown('f') then
				for i,lightStone in ipairs(lightStones) do
					lightStone.tone:stop()
				end
				if nextLevel == 'victory' then
					state = 'victoryState'
					stateTransTimer = 10
					gameMusic:stop()
					titleMusic:play()
				else
					love.load(nil,nextLevel)
				end
			end
		elseif player.alive then
			if love.keyboard.isDown('w', 'up') then player.y = player.y - 400*dt end
			if love.keyboard.isDown('a', 'left') then player.x = player.x - 400*dt end
			if love.keyboard.isDown('s', 'down') then player.y = player.y + 400*dt end
			if love.keyboard.isDown('d', 'right') then player.x = player.x + 400*dt end
			player:testCollision()
			letThereBeLight()
			for i,enemy in ipairs(enemies) do
				if enemy.isFleeing then
					enemy:flee(player,dt)
				else
					enemy:chase(player,dt)
				end
				enemy:update()
				enemy:testCollision()
			end
		else
			if love.keyboard.isDown('f') then
				playerDeathCount = playerDeathCount + 1
				love.load(nil,currentLevel)
			end
		end
		winCond = 0
		for i,lightStone in ipairs(lightStones) do
			lightStone:update()
			if lightStone.isShining then
				winCond = winCond + 1
				if winCond >= winGoal then
					player.isAWinner = true
				end
			end
		end
		cam:lookAt(player.x,player.y)
	end
end

function love.draw(dt)
	if state == 'victoryState' then
		love.graphics.draw(victoryScreen,0,0)
		love.graphics.printf('Death count: '..playerDeathCount,0,0,love.graphics:getWidth(),'left')
	elseif state == 'startScreenState' then
		love.graphics.draw(startScreen,0,0)
	elseif state == 'pauseState' then
		love.graphics.printf('Game paused\nPress "F" to continue...',0,love.graphics:getHeight()/2-32,love.graphics:getWidth(),'center')
	elseif state == 'gameState' then
		cam:attach()
		map:forceRedraw()
		map:draw()
		map:setDrawRange(cam.x-love.graphics.getWidth()/2,cam.y-love.graphics.getHeight()/2,cam.x+love.graphics.getWidth()/2,cam.y+love.graphics.getHeight()/2)
		player:draw()
		for i,enemy in ipairs(enemies) do
			enemy:draw()
		end
		for i,lightStone in ipairs(lightStones) do
			lightStone:draw()
		end
		cam:detach()
		if player.isAWinner then
			love.graphics.setColor(0,0,0)
				love.graphics.rectangle('fill',love.graphics:getWidth()/4,2*love.graphics:getHeight()/5,love.graphics:getWidth()/2,love.graphics:getHeight()/5)
			love.graphics.setColor(255,255,255)
			love.graphics.printf('Well done!\nPress "F" to continue...',0,love.graphics.getHeight()/2-32,love.graphics:getWidth(),'center')
		elseif not(player.alive) then
			love.graphics.setColor(0,0,0)
				love.graphics.rectangle('fill',love.graphics:getWidth()/4,2*love.graphics:getHeight()/5,love.graphics:getWidth()/2,love.graphics:getHeight()/5)
			love.graphics.setColor(255,255,255)
			love.graphics.printf('You died...\nPress "F" to try again...',0,love.graphics.getHeight()/2-32,love.graphics:getWidth(),'center')
		end
		love.graphics.printf('Death count: '..playerDeathCount,0,0,love.graphics:getWidth(),'left')
		-- For testing/debugging
		-- if debug then
		-- 	love.graphics.print('Light Stones: '..winCond..'/'..winGoal,0,0)
		-- 	for i,enemy in ipairs(enemies) do
		-- 		love.graphics.print('Enemy '..i..': '..enemy.HP..'/'..enemy.HPMax,0,(i+1)*32)
		-- 	end
		-- end
	end
end

-- Change player into its own custom layer to do stuff
function convertPlayer( oldPlayer )
	local player = {x = oldPlayer.x, y = oldPlayer.y}
	player.name = oldPlayer.name
	player.image = love.graphics.newImage('assets/player.png')
	player.width = player.image:getWidth()
	player.height = player.image:getHeight()
	player.quad = love.graphics.newQuad(0,0,32,32,player.image:getWidth(),player.image:getHeight())
	player.alive = true
	player.isAWinner = false
	player.angle = 0
	function player:draw()
		love.graphics.draw(self.image,self.quad,self.x,self.y,-self.angle*math.pi/180,1,1,self.width/2,self.height/2)
	end
	function player:testCollision()
		local wasdVals = {up = 320, left = 320, down = 320, right = 320}
		local xVal = (self.x-self.width/2)/tileWidth
		local yVal = (self.y-self.height/2)/tileHeight
		-- local x,y = self.x-self.width,self.y-self.height
		-- [1][2]
		-- [3][4]
		local quad1Collision = groundLayer(math.floor(xVal),math.floor(yVal)).properties['solid'] == 'yes'
		local quad2Collision = groundLayer(math.ceil(xVal),math.floor(yVal)).properties['solid'] == 'yes'
		local quad3Collision = groundLayer(math.floor(xVal),math.ceil(yVal)).properties['solid'] == 'yes'
		local quad4Collision = groundLayer(math.ceil(xVal),math.ceil(yVal)).properties['solid'] == 'yes'
		if quad1Collision and quad2Collision and quad3Collision then
			self.x = math.ceil(xVal)*tileWidth+self.width/2
			self.y = math.ceil(yVal)*tileHeight+self.height/2
		elseif quad1Collision and quad2Collision and quad4Collision then
			self.x = math.floor(xVal)*tileWidth+self.width/2
			self.y = math.ceil(yVal)*tileHeight+self.height/2
		elseif quad1Collision and quad3Collision and quad4Collision then
			self.x = math.ceil(xVal)*tileWidth+self.width/2
			self.y = math.floor(yVal)*tileHeight+self.height/2
		elseif quad2Collision and quad3Collision and quad4Collision then
			self.x = math.floor(xVal)*tileWidth+self.width/2
			self.y = math.floor(yVal)*tileHeight+self.height/2
		elseif quad1Collision and quad2Collision then
			self.y = math.ceil(yVal)*tileHeight+self.height/2
		elseif quad1Collision and quad3Collision then
			self.x = math.ceil(xVal)*tileWidth+self.width/2
		elseif quad1Collision and quad4Collision then
			if love.keyboard.isDown('w', 'up') or love.keyboard.isDown('d', 'right') then
				self.x = math.floor(xVal)*tileWidth+self.width/2
				self.y = math.ceil(yVal)*tileHeight+self.height/2
			elseif love.keyboard.isDown('s', 'down') or love.keyboard.isDown('a', 'left') then
				self.x = math.ceil(xVal)*tileWidth+self.width/2
				self.y = math.floor(yVal)*tileHeight+self.height/2
			end
		elseif quad2Collision and quad3Collision then
			if love.keyboard.isDown('w', 'up') or love.keyboard.isDown('d', 'right') then
				self.x = math.ceil(xVal)*tileWidth+self.width/2
				self.y = math.floor(yVal)*tileHeight+self.height/2
			elseif love.keyboard.isDown('s', 'down') or love.keyboard.isDown('a', 'left') then
				self.x = math.floor(xVal)*tileWidth+self.width/2
				self.y = math.ceil(yVal)*tileHeight+self.height/2
			end
		elseif quad2Collision and quad4Collision then
			self.x = math.floor(xVal)*tileWidth+self.width/2
		elseif quad3Collision and quad4Collision then
			self.y = math.floor(yVal)*tileHeight+self.height/2
		elseif quad1Collision and love.keyboard.isDown('w', 'up') then
			self.y = math.ceil(yVal)*tileHeight+self.height/2
		elseif quad1Collision and love.keyboard.isDown('a', 'left') then
			self.x = math.ceil(xVal)*tileWidth+self.width/2
		elseif quad2Collision and love.keyboard.isDown('w', 'up') then
			self.y = math.ceil(yVal)*tileHeight+self.height/2
		elseif quad2Collision and love.keyboard.isDown('d', 'right') then
			self.x = math.floor(xVal)*tileWidth+self.width/2
		elseif quad3Collision and love.keyboard.isDown('s', 'down') then
			self.y = math.floor(yVal)*tileHeight+self.height/2
		elseif quad3Collision and love.keyboard.isDown('a', 'left') then
			self.x = math.ceil(xVal)*tileWidth+self.width/2
		elseif quad4Collision and love.keyboard.isDown('s', 'down') then
			self.y = math.floor(yVal)*tileHeight+self.height/2
		elseif quad4Collision and love.keyboard.isDown('d', 'right') then
			self.x = math.floor(xVal)*tileWidth+self.width/2
		end
		local checkX,checkY = self.x-self.width/2,self.y-self.height/2
		for i,enemy in ipairs(enemies) do
			if enemy.alive then
				if checkX <= enemy.x-enemy.width/2+enemy.width and enemy.x-enemy.width/2 <= checkX and checkY <= enemy.y-enemy.height/2+enemy.height and enemy.y-enemy.height/2 <= checkY then
					player.alive = false
				end
				if checkX+self.width <= enemy.x-enemy.width/2+enemy.width and enemy.x-enemy.width/2 <= checkX+self.width and checkY <= enemy.y-enemy.height/2+enemy.height and enemy.y-enemy.height/2 <= checkY then
					player.alive = false
				end
				if checkX <= enemy.x-enemy.width/2+enemy.width and enemy.x-enemy.width/2 <= checkX and checkY+self.height <= enemy.y-enemy.height/2+enemy.height and enemy.y-enemy.height/2 <= checkY+self.height then
					player.alive = false
				end
				if checkX+self.width <= enemy.x-enemy.width/2+enemy.width and enemy.x-enemy.width/2 <= checkX+self.width and checkY+self.height <= enemy.y-enemy.height/2+enemy.height and enemy.y-enemy.height/2 <= checkY+self.height then
					player.alive = false
				end
			end
		end
		if debug then player.alive = true end
	end
	oldPlayer.visible = false
	return player
end

-- Change enemy into its own custom layer to do stuff
function convertEnemy( oldEnemy )
	local enemy = {x = oldEnemy.x, y = oldEnemy.y}
	enemy.name = oldEnemy.name
	enemy.image = love.graphics.newImage('assets/enemy.png')
	enemy.width = 32
	enemy.height = 32
	local fullQuad = love.graphics.newQuad(0,0,enemy.width,enemy.height,enemy.image:getDimensions())
	local hurtQuad = love.graphics.newQuad(32,0,enemy.width,enemy.height,enemy.image:getDimensions())
	local deadQuad = love.graphics.newQuad(0,32,enemy.width,enemy.height,enemy.image:getDimensions())
	enemy.quad = emptyQuad
	enemy.quad = love.graphics.newQuad(0,0,32,32,enemy.image:getWidth(),enemy.image:getHeight())
	enemy.visible = false
	enemy.HPMax = 160
	enemy.HP = enemy.HPMax
	enemy.isLitUp = false
	enemy.alive = true
	enemy.isFleeing = false
	enemy.angle = 0
	enemy.voices = {}
	local groan1 = love.audio.newSource('assets/groan1.wav','static')
	groan1:setVolume(0.13)
	table.insert(enemy.voices,groan1)
	local groan2 = love.audio.newSource('assets/groan2.wav','static')
	groan2:setVolume(0.13)
	table.insert(enemy.voices,groan2)
	local groan3 = love.audio.newSource('assets/groan3.wav','static')
	groan3:setVolume(0.13)
	table.insert(enemy.voices,groan3)
	local croak1 = love.audio.newSource('assets/croak1.wav','static')
	croak1:setVolume(0.11)
	table.insert(enemy.voices,croak1)
	local croak2 = love.audio.newSource('assets/croak2.wav','static')
	croak2:setVolume(0.11)
	table.insert(enemy.voices,croak2)
	local croak3 = love.audio.newSource('assets/croak3.wav','static')
	croak3:setVolume(0.17)
	table.insert(enemy.voices,croak3)
	enemy.currentVoice = 1
	enemy.minVoiceTimer = 30
	enemy.maxVoiceTimer = 10*enemy.minVoiceTimer
	enemy.voiceTimer = enemy.minVoiceTimer
	enemy.isMakingNoise = false
	function enemy:draw()
		if enemy.isLitUp then
			love.graphics.draw(self.image,self.quad,self.x,self.y,-self.angle*math.pi/180,1,1,self.width/2,self.height/2)
		end
	end
	function enemy:chase( preyObject, dt )
		if self.alive then
			local preyX, preyY = preyObject.x,preyObject.y
			if preyY <= self.y then self.y = self.y - 200*dt end
			if preyX <= self.x then self.x = self.x - 200*dt end
			if preyY > self.y then self.y = self.y + 200*dt end
			if preyX > self.x then self.x = self.x + 200*dt end
		end
	end
	function enemy:flee( preyObject, dt )
		if self.alive then
			local preyX, preyY = preyObject.x,preyObject.y
			if preyY <= self.y then self.y = self.y + 256*dt end
			if preyX <= self.x then self.x = self.x + 256*dt end
			if preyY > self.y then self.y = self.y - 256*dt end
			if preyX > self.x then self.x = self.x - 256*dt end
		end
	end
	function enemy:update()
		if self.alive then
			local playerProx = math.dist(player.x,player.y,enemy.x-enemy.width/2,enemy.y-enemy.height/2)
			enemy.voiceTimer = enemy.voiceTimer - 1
			if playerProx <= 256 then
				if enemy.voiceTimer <= 0 then
					enemy.voices[enemy.currentVoice]:play()
					enemy.currentVoice = math.random(1,5)
					enemy.voiceTimer = math.random()*(enemy.maxVoiceTimer-enemy.minVoiceTimer)+enemy.minVoiceTimer
				end
			else
				enemy.voices[enemy.currentVoice]:stop()
			end
			if self.isFleeing then
				self.quad = hurtQuad
				self.angle = 180-math.angle(enemy.x,enemy.y,player.x,player.y)*180/math.pi
			else
				self.quad = fullQuad
				self.angle = -math.angle(enemy.x,enemy.y,player.x,player.y)*180/math.pi
			end
			if self.isLitUp then
				self.HP = self.HP - 2
				if self.HP <= 0 then
					enemy.voices[6]:play()
					self.HP = 0
					self.alive = false
				elseif self.HP <= 0.25*self.HPMax then
					self.isFleeing = true
				end
				self.visible = true
			elseif self.HP <= 0.25*self.HPMax then
				self.isFleeing = true
				self.HP = self.HP + 1
				if self.HP >= self.HPMax then
					self.isFleeing = false
					self.HP = self.HPMax
				elseif self.HP >= 0.75*self.HPMax then
					self.isFleeing = false
					self.HP = self.HPMax
				end
			else
				self.HP = self.HP + 1
				if self.HP >= self.HPMax then
					self.isFleeing = false
					self.HP = self.HPMax
				elseif self.HP >= 0.75*self.HPMax then
					self.isFleeing = false
					self.HP = self.HPMax
				end
			end
		else
			self.quad = deadQuad
		end
	end
	function enemy:testCollision()
		-- if self.alive then
			local wasdVals = {up = 320, left = 320, down = 320, right = 320}
			local xVal = (self.x-self.width/2)/tileWidth
			local yVal = (self.y-self.height/2)/tileHeight
			-- [1][2]
			-- [3][4]
			local quad1Collision = groundLayer(math.floor(xVal),math.floor(yVal)).properties['solid'] == 'yes'
			local quad2Collision = groundLayer(math.ceil(xVal),math.floor(yVal)).properties['solid'] == 'yes'
			local quad3Collision = groundLayer(math.floor(xVal),math.ceil(yVal)).properties['solid'] == 'yes'
			local quad4Collision = groundLayer(math.ceil(xVal),math.ceil(yVal)).properties['solid'] == 'yes'
			if quad1Collision and quad2Collision and quad3Collision then
				self.x = math.ceil(xVal)*tileWidth+self.width/2
				self.y = math.ceil(yVal)*tileHeight+self.height/2
			elseif quad1Collision and quad2Collision and quad4Collision then
				self.x = math.floor(xVal)*tileWidth+self.width/2
				self.y = math.ceil(yVal)*tileHeight+self.height/2
			elseif quad1Collision and quad3Collision and quad4Collision then
				self.x = math.ceil(xVal)*tileWidth+self.width/2
				self.y = math.floor(yVal)*tileHeight+self.height/2
			elseif quad2Collision and quad3Collision and quad4Collision then
				self.x = math.floor(xVal)*tileWidth+self.width/2
				self.y = math.floor(yVal)*tileHeight+self.height/2
			elseif quad1Collision and quad2Collision then
				self.y = math.ceil(yVal)*tileHeight+self.height/2
			elseif quad1Collision and quad3Collision then
				self.x = math.ceil(xVal)*tileWidth+self.width/2
			elseif quad1Collision and quad4Collision then
					self.x = math.floor(xVal)*tileWidth+self.width/2
					self.y = math.ceil(yVal)*tileHeight+self.height/2
			elseif quad2Collision and quad3Collision then
					self.x = math.ceil(xVal)*tileWidth+self.width/2
					self.y = math.floor(yVal)*tileHeight+self.height/2
			elseif quad2Collision and quad4Collision then
				self.x = math.floor(xVal)*tileWidth+self.width/2
			elseif quad3Collision and quad4Collision then
				self.y = math.floor(yVal)*tileHeight+self.height/2
			elseif quad1Collision then
				self.y = math.ceil(yVal)*tileHeight+self.height/2
			elseif quad2Collision then
				self.y = math.ceil(yVal)*tileHeight+self.height/2
			elseif quad3Collision then
				self.y = math.floor(yVal)*tileHeight+self.height/2
			elseif quad4Collision then
				self.y = math.floor(yVal)*tileHeight+self.height/2
			end
		-- end
	end
	oldEnemy.visible = false
	return enemy
end

function convertLightStone( oldLightStone )
	local lightStone = {x = oldLightStone.x, y = oldLightStone.y}
	lightStone.name = oldLightStone.name
	lightStone.image = love.graphics.newImage('assets/light_stone.png')
	lightStone.width = 32
	lightStone.height = 32
	local emptyQuad = love.graphics.newQuad(0,0,lightStone.width,lightStone.height,lightStone.image:getDimensions())
	local chargingQuad = love.graphics.newQuad(0,32,lightStone.width,lightStone.height,lightStone.image:getDimensions())
	local shiningQuad = love.graphics.newQuad(32,32,lightStone.width,lightStone.height,lightStone.image:getDimensions())
	lightStone.quad = emptyQuad
	lightStone.HPMax = 5000
	lightStone.HP = 0
	lightStone.visible = false
	lightStone.isShining = false
	lightStone.isCharging = false
	lightStone.tone = love.audio.newSource('assets/toneC6.wav','static')
	lightStone.tone:setVolume(0.0025)
	lightStone.minPitch = 0.5*lightStone.tone:getPitch()
	lightStone.currentPitch = lightStone.minPitch
	lightStone.maxPitch = 8*lightStone.minPitch
	lightStone.isMakingNoise = false
	function lightStone:draw()
		if self.visible then
			love.graphics.draw(self.image,self.quad,self.x,self.y)
		end
	end
	function lightStone:update()
		local playerProx = math.dist(player.x,player.y,lightStone.x-lightStone.width/2,lightStone.y-lightStone.height/2)
		if playerProx <= 192 then
			lightStone.tone:setPitch(lightStone.currentPitch)
			if not(lightStone.tone:isPlaying()) then
				lightStone.tone:play()
				lightStone.tone:setLooping()
			end
		else
			lightStone.tone:stop()
		end
		if self.isCharging then
			self.quad = chargingQuad
			self.visible = true
			self.HP = self.HP + 75
			if self.HP >= self.HPMax then
				self.HP = self.HPMax
				self.quad = shiningQuad
				self.isShining = true
			end
		elseif self.isShining then
			self.quad = shiningQuad
			self.visible = true
			self.HP = self.HP - 10
			if self.HP <= 0 then
				self.HP = 0
				self.quad = emptyQuad
				self.isShining = false
			end
		else
			self.quad = emptyQuad
			self.visible = false
			self.HP = self.HP - 1
			if self.HP <= 0 then
				self.HP = 0
			end
		end
		lightStone.currentPitch = (lightStone.HP/lightStone.HPMax)*(lightStone.maxPitch-lightStone.minPitch)+lightStone.minPitch
	end
	oldLightStone.visible = false
	return lightStone
end

-- Generate the lights
function letThereBeLight()
	for x,y,tile in darknessLayer:iterate() do
		darknessLayer:set(x,y,tiles['darkness'])
	end
	for i,enemy in ipairs(enemies) do
		enemy.visible = false
		enemy.isLitUp = false
	end
	for i,lightStone in ipairs(lightStones) do
		lightStone.visible = false
		lightStone.isCharging = false
	end
	for x,y,tile in groundLayer:iterate() do
		if tile.properties['light'] == 'source' then
			staticLights(tile, x*tileWidth,y*tileHeight,tile.properties['light_distance']*tileWidth,5.625)
		end
	end
	local mouseX,mouseY = love.mouse.getPosition()
	mouseX,mouseY = cam:worldCoords(mouseX,mouseY)
	local flashlightAngle = -math.angle(player.x,player.y,mouseX,mouseY)*180/math.pi
	player.angle = flashlightAngle
	checkIfLight(player,245,flashlightAngle)
	for i,lightStone in ipairs(lightStones) do
		if lightStone.isShining then
			staticLights(lightStone,lightStone.x,lightStone.y,192,5.625)
		end
	end
end

-- For tiles that emit light
function staticLights( lightObj, x, y, radius, angleStep )
	for theta = -180, 180,angleStep do
		local phi = theta
		local finalRadius = radius
		if theta > 180 then phi = 360 - theta end
		if theta < -180 then phi = 360 + theta end
		for r = 0.1, radius,0.5 do
			local checkX,checkY = x+(r*math.cos(-theta*math.pi/180)),y+(r*math.sin(-theta*math.pi/180))
			local tileX,tileY = math.round(checkX/tileWidth),math.round(checkY/tileHeight)
			--check if tiles are important: solid or enemy
			if tileX >= 0 and tileX < map.width and tileY >= 0 and tileY < map.height then
				if groundLayer(tileX,tileY).properties['solid'] == 'yes' and not(tileX == x/tileWidth and tileY == y/tileHeight) then
					darknessLayer:set(tileX,tileY,tiles['transparent'])
					finalRadius = r
					break
				else
					darknessLayer:set(tileX,tileY,tiles['transparent'])
				end
			end
		end
		for i,enemy in ipairs(enemies) do
			if math.dist(enemy.x-enemy.width/2,enemy.y-enemy.height/2,x,y) < 1.11*finalRadius and (-math.angle(x,y,enemy.x-enemy.width/2,enemy.y-enemy.height/2)*180/math.pi <= phi+5 and -math.angle(x,y,enemy.x-enemy.width/2,enemy.y-enemy.height/2)*180/math.pi >= phi-5) then
				enemy.isLitUp = true
			end
		end
		for i,lightStone in ipairs(lightStones) do
			if math.dist(lightStone.x,lightStone.y,x,y) < 1.11*finalRadius and lightStone ~= lightObj and (-math.angle(x,y,lightStone.x,lightStone.y)*180/math.pi <= phi+5 and -math.angle(x,y,lightStone.x,lightStone.y)*180/math.pi >= phi-5) then
				lightStone.isCharging = true
			end
		end
	end
end

-- For the player's light
function checkIfLight( source, radius, angle )
	local x,y = source.x,source.y
	for theta = angle-17, angle+17,0.5 do
		local phi = theta
		local finalRadius = radius
		if theta > 180 then phi = 360 - theta end
		if theta < -180 then phi = 360 + theta end
		for r = 0.1, radius,0.1 do
			local checkX,checkY = x+(r*math.cos(-phi*math.pi/180)),y+(r*math.sin(-phi*math.pi/180))
			local tileX,tileY = math.round(checkX/tileWidth),math.round(checkY/tileHeight)
			--check if tiles are important: solid or enemy
			if groundLayer(tileX,tileY).properties['solid'] == 'yes' then
				darknessLayer:set(tileX,tileY,tiles['transparent'])
				finalRadius = r
				break
			else
				darknessLayer:set(tileX,tileY,tiles['transparent'])
			end
		end

		for i,enemy in ipairs(enemies) do
			if math.dist(enemy.x-enemy.width/2,enemy.y-enemy.height/2,x,y) < 1.11*finalRadius and (-math.angle(x,y,enemy.x-enemy.width/2,enemy.y-enemy.height/2)*180/math.pi <= phi+5 and -math.angle(x,y,enemy.x-enemy.width/2,enemy.y-enemy.height/2)*180/math.pi >= phi-5) then
				enemy.isLitUp = true
			end
		end
		for i,lightStone in ipairs(lightStones) do
			if math.dist(lightStone.x,lightStone.y,x,y) < 1.11*finalRadius and (-math.angle(x,y,lightStone.x,lightStone.y)*180/math.pi <= phi+5 and -math.angle(x,y,lightStone.x,lightStone.y)*180/math.pi >= phi-5) then
				lightStone.isCharging = true
			end
		end
	end
	for theta = -180, 180,1 do
		local finalRadius = 41
		for r = 0.1, 41,0.5 do
			local checkX,checkY = x+(r*math.cos(-theta*math.pi/180)),y+(r*math.sin(-theta*math.pi/180))
			local tileX,tileY = math.round(checkX/tileWidth),math.round(checkY/tileHeight)
			--check if tiles are important: solid or enemy
			if groundLayer(tileX,tileY).properties['solid'] == 'yes' then
				darknessLayer:set(tileX,tileY,tiles['transparent'])
				finalRadius = r
				break
			else
				darknessLayer:set(tileX,tileY,tiles['transparent'])
			end
		end

		for i,enemy in ipairs(enemies) do
			if math.dist(enemy.x-enemy.width/2,enemy.y-enemy.height/2,x,y) < 1.11*finalRadius then
				enemy.isLitUp = true
			end
		end
		for i,lightStone in ipairs(lightStones) do
			if math.dist(lightStone.x,lightStone.y,x,y) < 1.11*finalRadius then
				lightStone.isCharging = true
			end
		end
	end
end

function love.focus( f )
	if not f then
		state = 'pauseState'
	end
end

function math.angle(x1,y1, x2,y2) return math.atan2(y2-y1, x2-x1) end
function math.round(n, deci) deci = 10^(deci or 0) return math.floor(n*deci+.5)/deci end
function math.dist(x1,y1, x2,y2) return ((x2-x1)^2+(y2-y1)^2)^0.5 end
