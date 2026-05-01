FakeName Changer — README

What it does

FakeName Changer is a PS Vita homebrew app that lets you rename LiveArea bubble titles without editing each game’s PARAM.SFO.

It reads your installed bubbles from the Vita’s app.db, lets you change the displayed names, creates backups, and then reboots the system so the LiveArea refreshes with the new titles.

Requirements

- Modded PS Vita / PSTV
- VitaShell installed
- HENkaku / Enso or another working homebrew setup
- The FakeNameChanger.vpk file

Installation

1. Copy FakeNameChanger.vpk to your PS Vita.
   - USB mode through VitaShell works fine.
   - You can place it anywhere easy to find, like:
     - ux0:/downloads/
     - ux0:/VPK/

2. Open VitaShell.

3. Find the VPK file.

4. Press X on FakeNameChanger.vpk.

5. Choose Install.

6. When installation finishes, return to the LiveArea.

7. Launch FakeName Changer from the new bubble.

How to use

1. Open FakeName Changer.

2. Use the D-Pad or Left Stick to move through your bubbles.

3. Use L / R to page faster through the list.

4. Highlight the bubble you want to rename.

5. Press X.

6. Type the new name.

7. Confirm the keyboard entry.

8. Repeat this for as many bubble names as you want.

9. When finished, press Start to reboot and apply the changes.

Controls

Button                Action
------------------------------------------------------------
D-Pad / Left Stick   Move through bubbles
L / R                Page through list
X                    Rename selected bubble
Square               Create backup
Select               Refresh bubble list
Triangle             Restore backup and reboot
Start                Apply changes and reboot
Home Button          Locks after first save

Important notes

- This app changes only the display title shown on the LiveArea.
- It does not modify PARAM.SFO.
- After renaming bubbles, you must reboot for the changes to fully show.
- The app makes backups in:

ux0:/data/FakeNameChanger/

Backup files include:

app_original_first_run.db
app_before_last_patch.db

Restore backup

If something looks wrong:

1. Open FakeName Changer.
2. Press Triangle.
3. The app restores the last backup.
4. The Vita reboots.

Recommended use

Rename all the bubbles you want in one session, then press Start once at the end to apply everything.
