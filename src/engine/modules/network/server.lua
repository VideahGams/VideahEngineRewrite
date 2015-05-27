local server = {}
local lube = require(engine.path .. 'libs.LUBE')
local serial = require(engine.path .. 'util.serial')

server.playerlist = {}

function server.start(port, gui)

	server.cfg = cfg.load("server")

	server.name = server.cfg.settings.name or "VideahServer"
	server.maxplayers = server.cfg.settings.maxplayers or 16
	server.map = server.cfg.settings.map

	love.window.setTitle(server.name)

	server._serv = lube.tcpServer()
	server._serv:listen(network._port)
	server._serv.callbacks.connect = server.onConnect
	server._serv.callbacks.recv = server.onReceive
	server._serv.callbacks.disconnect = server.onDisconnect
	server._serv.handshake = "997067"

	if gui then
		network.loadGUI()
	end

	function love.keypressed(key, isrepeat)

		console.keypressed(key, isrepeat)

	end

	map.loadmap(server.map)

	console.success("Successfully started server on port " .. network._port)

	network._hasLoaded = true

end

-----------------
--  CALLBACKS  --
-----------------

function server.onConnect(id)

end

function server.onReceive(data, id)

	local ok, packet = serial.load(data)

	hook.Call("ServerOnReceive", packet)

	if ok == nil then

		console.error("Corrupt packet received: " .. packet)
		return

	end
	
	if packet.ptype == "join" then -- a Player has joined the server.

		hook.Call("OnPlayerJoin", packet)

		print('Player ' .. packet.playername .. " (ID: " .. packet.playerid .. ") has joined the game")

		local playerinfo = {name = packet.playername, id = packet.playerid}

		table.insert(server.playerlist, playerinfo)

		local infopacket = {

			ptype = "si",
			data = {

				servername = server.name,
				numofplayers = server.getNumberOfPlayers(),
				maxplayers = server.maxplayers,
				mapname = map.currentmapname,
				playerlist = server.playerlist

			}

		}

		server.send(infopacket, id)

	elseif packet.ptype == "dc" then -- a Player has left the server.

		hook.Call("OnPlayerDisconnect", packet)

		packet.reason = packet.reason or "disconnect"

		print('Player ' .. packet.playername .. " has left the game. (Reason: " .. packet.reason .. ")")

		for i, player in ipairs(server.playerlist) do
			if packet.playerid == player.id then
				table.remove(server.playerlist, i)
				break
			end
		end

	elseif packet.ptype == "c" then -- a Player has sent a chat message.

		print(packet.playername .. ": " .. packet.data.msg) -- Print the message to the server console.

		server.send(packet) -- Send the message to all clients, including the sender.

	else

		console.error("Unknown packet received.")

	end

end

function server.onDisconnect(id)

	print("Client disconnected.")

end

-----------------
--  FUNCTIONS  --
-----------------

function server.send(data, id)

	id = id or nil

	local tbl = data
	local packagedtbl = serial.dump(tbl)
	if id == nil then
		server._serv:send(packagedtbl)
	else
		server._serv:send(packagedtbl, id)
	end

end

function server.say(msg)

	print("Server: " .. msg)

	local packet = {

		ptype = "c",
		playername = nil,
		data = {

			msg = msg

		}

	}

	server.send(packet)

end

function server.status()

	print("Number of Players: " .. server.getNumberOfPlayers() .. "/" .. server.maxplayers)

	for i, player in ipairs(server.playerlist) do
		print(i .. "	" .. player.name .. " (" .. player.id .. ")")
	end

end

function server.getNumberOfPlayers()

	return #server.playerlist

end

return server