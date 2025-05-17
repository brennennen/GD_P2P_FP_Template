# GD_P2P_FP_Template
A peer-to-peer first-person template for creating games in godot.

## Setup
* Requires manually install addons to save on repo size.
  * addons:
	* godotsteam
	* steam-multiplayer-peer
	* imgui-godot
* Some larger art assets that are "work in progress" have also not been committed to prevent too much lfs churn and repo size issues.


## TODO
* fix issues around initial spawning with running animation and teleporting to 0,0,0 visually
* imgui: add count of sent messages? received messages? packet loss? sent bytes? received bytes?
* remove and re-spawn player pawns when loading new scenes? or just move them?
* fade to black when changing levels?
* fix issues around simulated proxies
* allow multiplayer mode editor to also listen on a part like direct connect hosting 
* add "start-falling" animation to blend the end of the jump into the falling animation
* bug: snake people - fix: go out of boxing mode when crouching. upperbody blend is just for standing up?
* todo: add fishing pole bones to rig and property to snap to hands
