<div align="center">
  <h1><code>TF2-ProperClassWeaponAnimations</code></h1>
  <p>
    <strong>Proper animations for all weapons, even if the class isn't supposed to use it.</strong>
  </p>
  <p style="margin-bottom: 0.5ex;">
    <img
        src="https://img.shields.io/github/downloads/Zabaniya001/TF2-ProperClassWeaponAnimations/total"
    />
    <img
        src="https://img.shields.io/github/last-commit/Zabaniya001/TF2-ProperClassWeaponAnimations"
    />
    <img
        src="https://img.shields.io/github/issues/Zabaniya001/TF2-ProperClassWeaponAnimations"
    />
    <img
        src="https://img.shields.io/github/issues-closed/Zabaniya001/TF2-ProperClassWeaponAnimations"
    />
    <img
        src="https://img.shields.io/github/repo-size/Zabaniya001/TF2-ProperClassWeaponAnimations"
    />
    <img
        src="https://img.shields.io/github/workflow/status/Zabaniya001/TF2-ProperClassWeaponAnimations/Compile%20and%20release"
    />
  </p>
</div>

## Requirements ##
- [TF2Utils](https://github.com/nosoop/SM-TFUtils)
- [TF_ECON_DATA](https://github.com/nosoop/SM-TFEconData)

## Installation ##
1. Grab the latest release from the release page and unzip it in your sourcemod folder.
2. Restart the server or type `sm plugins load TF2-ProperClassWeaponAnimations` in the console to load the plugin.

## Convars ##
- **sm_tf2-properclassweaponanimations_playermodelbonemerge**: Whether or not you want to have the player's model ( what others see ) have proper animations for the unintended weapon. Note that this will create one more entity. DEFAULT: enabled ( 1 )

## TO-DOs ##
- Hiding the client's model hides all shadows emitted from them. Find a way to enable them.
- Weapon taunts work just fine. However, if you try to use a normal taunt that your class would be able to do while using an "unintended" weapon, the animation will just be the idle animation. It's an easy fix, tho `CTFPlayer::Taunt` doesn't get called for non-weapon taunts (??).

## Build ##
This plugin gets built by my other project [SPDependy](https://www.github.com/Zabaniya001/SPDependy).