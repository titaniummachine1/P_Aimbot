![](https://api.visitorbadge.io/api/VisitorHit?user=titaniummachine1&repo=P_Aimbot&countColor=%237B1E7A)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub issues](https://img.shields.io/github/issues/titaniummachine1/P_Aimbot.svg)](https://github.com/titaniummachine1/P_Aimbot/issues)
[![GitHub forks](https://img.shields.io/github/forks/titaniummachine1/P_Aimbot.svg)](https://github.com/titaniummachine1/P_Aimbot/network)
[![GitHub stars](https://img.shields.io/github/stars/titaniummachine1/P_Aimbot.svg)](https://github.com/titaniummachine1/P_Aimbot/stargazers)
# P_Aimbot
## This script REQUIRES [lnxLib](https://github.com/lnx00/Lmaobox-Library/releases/latest/) and [ImMenu](https://github.com/lnx00/Lmaobox-ImMenu/blob/main/src/ImMenu.lua). It will NOT work without these two luas.
### Projectile aimbot lua for lmaobox.


[![Download Latest](https://img.shields.io/github/downloads/titaniummachine1/P_Aimbot/total.svg?style=for-the-badge&logo=download&label=Download%20Latest)](https://github.com/titaniummachine1/P_Aimbot/releases/latest/download/Aimbot.lua)

### Features
- Main tab
  - Silent aim toggle
  - Auto shoot toggle
  - Aim fov slider
  - Minimum hitchanche slider

- Advanced tab
   - Strafe prediction toggle
   - Maximum prediction ticks slider
   - Prediction accuracy slider
   - Strafe samples slider
 
- Visuals tab
  - Enable toggle
      - Visualize path toggle
         - Path style selection (Line | Alt Line | Dashed )
      - Visualize hitchanche
      - Crosshair
      - Visualize hit pos
      - Nullcore pred visuals

- Config tab
   - Create/Save config
   - Load config

![image](https://github.com/titaniummachine1/P_Aimbot/assets/78664175/0f7da659-1928-4bb5-919f-d928efc36db7)
![image](https://github.com/titaniummachine1/P_Aimbot/assets/78664175/6b436cca-6359-477b-b38f-bbc4cc1409f4)

Known Issues
1. Keybind Conflict: LBox vs Lua Hitchance Check
Issue: A conflict between the LBox framework and the Lua script occurs when they both attempt to manage the same keybind for shooting. This results in the hitchance check being fully ignored.
Cause: Both LBox and the Lua script use the same keybind for the GUI control, leading to overlapping behavior.
Potential Solution: Consider separating keybinds for LBox and the Lua script to avoid conflicts or implementing a priority system that ensures the hitchance check executes as intended.
2. OnAttack Not Triggering with Mouse 1 (M1)
Issue: The OnAttack function does not work when bound to Mouse 1 (M1).
Cause: The OnAttack bind needs to remain active for a period of time, but M1 triggers rapidly and momentarily, causing the script to fail to detect the attack properly.
Potential Solution: Use an alternative keybind for attack detection or rework the function to account for short-duration activations.
3. Hitchance Check Optimization
Issue: The hitchance check is currently dependent on pre-made predictions, which may lead to less accurate results during continuous tracking of moving targets.
Potential Improvement: Optimize the hitchance calculation to run as part of a continuous prediction system rather than relying solely on already-made predictions. This will improve consistency for dynamic and fast-moving targets.
