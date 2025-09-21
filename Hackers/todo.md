# TODO

## Course API
[ ] POST courses from Golf Course API or manually added (with unique ID)
[ ] GET courses from Hackers API and cross-merge with Golf Course API, keeping ours if dupe

When a user selects the configuration for their game, the confirmation to play will save the course to the Hackers API,
construct the round model with this data, adding the current user as a player and creator, and then segue to the game
lobby view. 

## Creating Game Lobby
[X] Determine data model for rounds in Cloud Firestore
[X] POST new round with share code and test accessing lobby
[ ] Online and offline player management view
[ ] Display course info in Lobbby
[ ] Lock down traditional format in Lobby


