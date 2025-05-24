# GD_P2P_FP_Template
A multiplayer first-person template for creating casual games in godot.


## Netcode Model and Tradeoffs
1 player hosts the game as the "server" and all other players join that persons game as "clients". Client's are allowed to directly move their pawn to allow for minimal latency between pressing an input that moves the player and seeing the movement take place (i.e. client's are "predicting" that the server will allow the movement). However, all client's actions are also sent to the server where they are also "played" (i.e. the server still has ultimate authority). If the client makes a move the server does not agree with, then the client's pawn is "reconciled" (rubber banded) back to where the server believes the client should be. Tuning how "tolerant" the server is with weird client movement events is a large decision point. If you are too intolerant, then you may rubberband the client whenever there is even a little bit of latency or packet loss. If you are too tolerant, then you allow for folks to cheat with speed/fly/no-clip hacks easily. This project generally leans towards the "too tolerant" side of this debate.

Another way to put it, there is a generally a "trade-off triangle" between: Simplicity, Client Responsiveness, and Fairness. The model implemented in this repo is very simple and offers great client responsiveness, but does so at the cost of fairness and the ability to detect/prevent cheating. This model is suited for casual co-op games where you generally trust the lobby you are playing with and trust the lobby to kick bad actors out of the game. Games that use similar approaches to this are minecraft/overcooked/phasmaphobia/lethal company/etc. If you are making a game where fairness and cheat detection/prevention is a higher priority than simplicity and client responsiveness, you should probably use a different model (ex: either do a pure server side authority model and be prepared to pay for hosting servers close to your player bases or look into complex event queue/rollback systems like [netfox](https://github.com/foxssake/netfox)).


## Core Features
[x] Client initial game state, level, and pawn state synchronization on joining a game.
[x] Support for direct connect and steam lobbies.
[x] "Play in editor" lobby support to allow running arbitrary levels quickly.
[x] Level changing mechanisms to bring the lobby along when the server loads a new level.
[x] "Client Prediction" pawn controller netcode to allow responsive client movement with server authority for cheat detection.
	[x] Server collision/no-clip cheat detection and reconciliation.
	[-] Server speed/fly cheat detection and reconciliation (partially implemented, not-implemented for grapple hook swinging or other complex movement yet).
[x] Optimized player movement packet sizes (1.6kBs per player moving)
[x] Several "mini-game" implementations (racing, fighting, puzzle solving, etc.) to find "unknown unknowns" and iron out corner cases.


## Extra Features
[x] - Fully animated 3rd person character pawn for visualizing peers.
	[x] - Animation blending between lower and upper body to support holding various equipment while walking/running/crouching/jumping/etc.
[ ] - Fully animated first person character pawn for visualizing your own actions.
[x] - Grapple hook to implementand test highly variable velocity based movement
[ ] - Inventory system
[ ] - Horse/vehicle system to test complex local authority management.
[ ] - In-game latency simulation (use clumsy/external tools for most latency/packet drop simulation, but having some in-game tools is nice (do not have access to much in godot at the moment though, can really only tinker with when multiplayer poll is called)).
[ ] - VOIP over secondary channels or steam voip integration


## Mini games
[x] - Race - Race other players from start point to an end point, dodging obstacles and other players
as you go.
[ ] - Last Man Standing - Fight on a platform, knock the other players off, the last player on the
platform wins.
[ ] - Jousting - TODO
[ ] - Fishing - TODO

## Setup
* Requires manually install addons to save on repo size.
  * addons:
	* godotsteam
	* steam-multiplayer-peer
	* imgui-godot
* Some larger art assets that are "work in progress" have also not been committed to prevent too much lfs churn and repo size issues.
