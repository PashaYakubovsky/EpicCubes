extends Node

const PORT = 4433

func _ready():
	# Start paused
	get_tree().paused = true
	# You can save bandwith by disabling server relay and peer notifications.
	multiplayer.server_relay = false

	# Automatically start the server in headless mode.
	if DisplayServer.get_name() == "headless":
		print("Automatically starting dedicated server")
		_on_host_pressed.call_deferred()


func _on_host_pressed():
	# Start as the server
	var peer = ENetMultiplayerPeer.new()
	print("Starting ENet server on port %d using UDP transport." % PORT) # Log transport and port

	var result = peer.create_server(PORT)
	
	# Check if we succeeded in creating a server
	if result != OK:
		OS.alert("Failed to start multiplayer server with error code: %d" % result)
		push_error("Failed to start multiplayer server with error code: %d" % result) # Log the error
		return
		
	# Check the initial connection status of the peer
	match peer.get_connection_status():
		MultiplayerPeer.CONNECTION_CONNECTING:
			print("Connection is being established.")
		MultiplayerPeer.CONNECTION_CONNECTED:
			print("Successfully connected to the server.")
		MultiplayerPeer.CONNECTION_DISCONNECTED:
			OS.alert("Failed to start multiplayer server, not connected.")
			push_error("Peer is disconnected. Failed to start multiplayer server.") # Log the error
			return
	
	multiplayer.multiplayer_peer = peer
	start_game()  # Assuming 'start_game()' is defined elsewhere in your script.


func _on_connect_pressed():
	# Start as client
	var txt : String = $UI/Net/Options/Remote.text
	if txt == "":
		OS.alert("Need a remote to connect to.")
		return
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(txt, PORT)
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		OS.alert("Failed to start multiplayer client")
		return
	multiplayer.multiplayer_peer = peer
	start_game()

func start_game():
	# Hide the UI and unpause to start the game.
	$UI.hide()
	get_tree().paused = false
	# Only change level on the server.
	# Clients will instantiate the level via the spawner.
	if multiplayer.is_server():
		change_level.call_deferred(load("res://level.tscn"))


# Call this function deferred and only on the main authority (server).
func change_level(scene: PackedScene):
	# Remove old level if any.
	var level = $Level
	for c in level.get_children():
		level.remove_child(c)
		c.queue_free()
	# Add new level.
	level.add_child(scene.instantiate())

# The server can restart the level by pressing HOME.
func _input(event):
	if not multiplayer.is_server():
		return
	if event.is_action("ui_home") and Input.is_action_just_pressed("ui_home"):
		change_level.call_deferred(load("res://level.tscn"))
