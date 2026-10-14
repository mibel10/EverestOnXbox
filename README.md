# EverestOnXbox
# A project to try to port everest mod loader for celeste to Xbox developer mode
EverestOnXbox is a porting project to try and recompile Celeste with Everest + Strawberry jam into a UWP app that can run on Xbox One & Series consoles with dev mode activated
# Status
The game's steam version sucesfully compiled into a .appx file running on UWP platform that works on Xbox One with saves working and fully playable
# Guide
Install the game on steam with the opengl beta branch
Run the Prepare-Steam-UWP.ps1 script
After that run Build-Xbox.ps1
At the end it will generate a unsigned .appx,you need to create your own certificate with CN=CelesteUWP and sign the appx with it
After that install the appx into the xbox console and its done!
# Todo
Make a script to automatically decompile celeste steam source code and adapt it into UWP

Try and get everest working (will probably need to do some changes in the source code)

# Disclaimers
This is still EXTREMELY work in progress,expect rough edges!
You need to have the game purchased on steam in order to use this
