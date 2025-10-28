# Godot Multiplayer Template

A modular multiplayer game template for Godot 4.x with GDScript, featuring the BugsBuzzy Crash Bash game.

## Project Structure

```
├── autoloads/           # Singleton scripts
│   ├── NetworkManager.gd    # Handles networking (host/join/leave)
│   ├── PlayerManager.gd     # Manages player data and synchronization
│   └── ChatManager.gd       # Handles chat system
├── scripts/             # Game scripts
│   ├── Lobby.gd             # Main lobby interface
│   ├── MultiplayerGameScene.gd # Main game scene controller
│   ├── Player.gd            # 3D player character with movement
│   ├── CameraController.gd  # Camera system with shake effects
│   ├── ball.gd              # Ball physics with multiplayer sync
│   ├── ball_spawner.gd      # Ball spawning system
│   └── player_body.gd       # Player collision and scoring
├── scenes/              # Scene files
│   ├── MultiplayerGameScene.tscn # The 3D Crash Bash game
│   ├── ball.tscn             # Ball scene
│   ├── ball_spawner.tscn     # Ball spawner scene
│   ├── corner.tscn           # Corner barriers
│   └── crash_bash_player.tscn # Player character scene
├── materials/           # 3D materials
├── models/              # 3D models and assets
├── lobby.tscn          # Lobby scene (main scene)
└── project.godot       # Project configuration
```

## Features

### Modular Architecture
- **NetworkManager**: Handles all networking operations (host, join, leave)
- **PlayerManager**: Manages player data, names, and synchronization
- **ChatManager**: Handles chat messages with proper name display

### Lobby System
- Enter username and host/join games
- Real-time player list updates
- Chat system with proper name display (shows "You" for own messages)
- Host can start the game to transition to the Crash Bash game scene

### Crash Bash Game Scene
- 3D physics-based gameplay
- Players control characters in a 50x50 arena
- Bouncing balls spawn and move around the arena
- Players can be hit by balls and lose points
- Real-time multiplayer synchronization of:
  - Player positions and rotations
  - Ball positions and velocities
  - Game state and scoring
- Third-person camera with smooth following
- Camera shake effects for impacts

## How to Use

1. **Host a Game**:
   - Enter your username
   - Click "Host Game"
   - Share your IP address with other players

2. **Join a Game**:
   - Enter your username
   - Enter the host's IP address
   - Click "Join Game"

3. **In-Game**:
   - Use WASD keys to move your character
   - Shift to run faster
   - Avoid the bouncing balls to stay alive
   - Each player sees all other players with their names
   - Click "Back to Lobby" to return to the lobby

## Technical Details

- Uses Godot's built-in multiplayer system with ENet
- Port 9001 for network communication
- 3D physics-based gameplay with Jolt Physics engine
- Real-time synchronization of player positions, ball physics, and game state
- Automatic scene transitions between lobby and game
- Proper player data synchronization across all clients
- Host-authoritative ball spawning and physics

## Customization

The template is designed to be easily extensible:

- Add new game mechanics by extending `GameScene.gd`
- Modify player appearance by editing `PlayerCube.gd`
- Add more lobby features by extending `Lobby.gd`
- Customize networking behavior in the Manager classes

## Requirements

- Godot 4.x
- Network connectivity for multiplayer functionality
