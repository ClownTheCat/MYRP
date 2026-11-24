MYRP Admin Build Access v1.0

INSTALL:
1. Extract the archive into:
   garrysmod/gamemodes/myrp/
   The final plugin path must be:
   garrysmod/gamemodes/myrp/schema/plugins/myrp_admin_build/
2. Restart the server completely.
3. Reconnect with an Admin or Superadmin account.

BEHAVIOR:
- Only players for whom Garry's Mod reports Player:IsAdmin() may open Q (Spawn Menu).
- Server-side CanTool blocks toolgun use by non-admins.
- Server-side spawn hooks block props, SENTs, NPCs, vehicles, ragdolls, effects and SWEP spawning/giving by non-admins.
- Admins and Superadmins retain access.
- C / Helix inventory is not modified.

TEST:
1. As Superadmin, press Q and test a prop and a tool.
2. Temporarily set a test account to user and reconnect.
3. As user, Q should not open. If they obtain a toolgun by another route, its tools should be denied; spawn attempts should also be denied.
4. Check server console for [MYRP:ADMIN_BUILD] DENY entries.

NOTES:
This plugin uses the built-in Player:IsAdmin() check, which normally recognizes Garry's Mod Admin and Superadmin status (including ULX-managed groups). It does not grant admin rights; ULX remains responsible for group assignment.
