Plan for Blastroids 2 Expansionc
Feature 1: 3x3 Screen Grid System
Current state: The game uses simple screen wrapping (0-127 pixels) where crossing any edge loops to the opposite side.
Implementation approach:
Add grid position tracking (grid_x, grid_y ranging from 0-2)
Modify wrapping logic:
Left/Right edges: Move to adjacent screen (grid_x ± 1)
Top edge: Move up one row (grid_y - 1), or if at top row (grid_y=0), wrap to bottom of same column (grid_y=2)
Bottom edge: Move down one row (grid_y + 1), or if at bottom row (grid_y=2), wrap to top of same column (grid_y=0)
Store asteroid positions with grid coordinates
Handle screen transitions for player, asteroids, and bullets
Potentially show mini-map or grid indicator in HUD

Feature 2: Arcade-Style Flashing Bullets
Current state: Bullets are drawn as simple cyan pixels (color 10).
Implementation approach:
Add animation frame counter to each bullet
Cycle through PICO-8's bright colors:
Color 7 (white) - brightest
Color 10 (light yellow)
Color 12 (light blue)
Or alternate between 7 (white) and 6 (light gray) for classic arcade effect
Use modulo on bullet age to create flashing effect (every 2-4 frames)
Optionally increase bullet pixel size to 2x2 during "bright" frames for extra impact

Feature 3: Secondary Weapon System
Two options to choose from:
Option A: Homing Missiles
Track nearest asteroid
Curved trajectory toward target
Limited ammo or cooldown timer
Small explosion radius on impact
Visual: Red/orange missile sprite with exhaust trail
Option B: Chain Lightning
Fires from ship toward nearest asteroid
Jumps to 2-3 additional nearby asteroids
Damage scales down with each jump
Cooldown-based (not ammo)
Visual: Animated lightning arc (cycling white/cyan/blue)
Recommendation: Chain lightning is more unique and visually impressive, plus it's better suited for PICO-8's limited sprites.
Common implementation:
Bind to button 5 (O button)
Add cooldown/charge meter to HUD
Add new particle effects and sound
Balance damage/cooldown to make it powerful but not overpowered