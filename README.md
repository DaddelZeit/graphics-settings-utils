## Updates
- Slightly updated the update check system
- Slightly updated the save/load dialog system
- Slightly updated the profile manager
- Moved Keybinds to their own category
- Edit UI menu bar is now available in the main menu
- Added "Duplicate" and "Export" buttons to profile manager
- Added "Reset" button to Edit Window variables
- Added extensive DOF settings to Edit Window under "PostFX"
- Added Vibrancy settings to contrast/saturation
- Reduced profile editor launch time

## Additions
- Added new way to navigate the mod windows with a single keybind:
  > Press full keybind to open
  
  > Release and press the last part to cycle selector
  
  > Default: left ctrl + ^ (Adjustable)
- Added a loading spinner when applying a profile
- Added Settings Menu:
  > Auto Update Check
  
  > Auto Re-Apply
  
  > History Commit Timer
  
  > Max History Items

  > Debug utilities

  > "About": Version, Credits, Contact

- Added Photo tool:
  > Supersample controls
  
  > LOD/Terrain LOD/Groundcover scales
  
  > Motion Blur
  
  > Grid

- Added a dialog on de-install: "Remove all remnants?"

- Added an info card when the apply loop limit is reached
- Added an info card when CK Graphics is installed
- Added lualzw compression for profile exports
- Added chromatic abberation postfx

## Fixes
- Screen/display will no longer be applied again when loading (this reduces loading time in fullscreen)
- Generally reduced chance of an apply loop
- DOF and HDR settings now reset properly when changing presets
- Import process now won't overwrite installed profiles and instead prompt a unique name for each import
- Most game option menus now temporarily disable automatic apply
- Fixed scrollbar not working in Profile Manager
- Added more fallbacks to export/import functionality
  
- Moved display functions for widgets into their own file
- Moved search functionality into another module out of the profile manager
- Unified export options into a single module for sync, added settings keys to store changes
- (More optimisations and backend changes)

# Source
https://github.com/DaddelZeit/graphics-settings-utils/tree/v15

# V15.5
- Fixed removal popup check not correctly grabbing mod name
- Fixed changelog getting too big
- Version check can now work with decimals (this versions numbering will be slightly messed up)
