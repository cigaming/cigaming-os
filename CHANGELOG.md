# CiGaming OS patch notes

## 1.1.0 — the welcome update

**New: Welcome to CiGaming OS**
- A welcome app opens on your first login and walks you through:
  - **Pick your apps** — Discord, Vesktop, Chatterino, Spotify, Prism Launcher, Heroic, Lutris, GIMP and more, one click from Flathub.
  - **Set up Twitch** — remember your channel, quick links to it and your Creator Dashboard, and how to connect OBS.
  - **Join SnuggleSMP** — the server address with a copy button, Prism Launcher, and community links.
- Re-open it any time from the app menu: *Welcome to CiGaming OS*.
- `cigaming fetch` now shows your Twitch channel.

**Fixes**
- VMware and QEMU/Proxmox guest tools now come with the desktop and server (they stay idle on real hardware).
- VMware: the mouse no longer freezes in X11 sessions (GNOME on Xorg, Plasma X11).
- GNOME now shows the Cub Moon wallpaper instead of a plain blue background, in light and dark mode, with gold accents.
- `convert.sh` now switches the login screen to the CiGaming one (SDDM) and starts new users in Plasma (Wayland). GNOME stays installed and pickable.

## 1.0.1 — login screen glow-up

- The login screen now says **CiGaming OS** with the cub logo instead of "debian 13" — on both GNOME (GDM) and KDE (SDDM).
- KDE's login screen gets the Cub Moon background (without the name text, so the logo isn't doubled) and gold accents.
- New CiGaming OS logo set: name lockup, name + version lockup, and cream/dark badges replace Debian's everywhere the system asks for the "vendor" logo, such as the file manager badge.
- Removing CiGaming OS still restores Debian's logos.

## 1.0.0 "Cub" — first release

Built on Debian 13 "trixie".

**Two ISOs**
- **Desktop** — KDE Plasma, streaming, gaming and community edition, with the graphical Calamares installer.
- **Server** — headless fleet host with the Debian text installer.

**Look and feel**
- CiGaming OS name everywhere: `os-release`, login banner, KDE "About this System", installer, boot menus.
- Cub Moon wallpaper, matching SDDM login screen and lock screen.
- CiGaming color scheme for KDE (night/plum with lion-gold accents).
- Boot splash: the cub gently breathes while a gold progress bar fills; also handles the disk-unlock prompt on encrypted installs.
- Branded GRUB menu — the EFI folder stays `/EFI/debian` so Secure Boot keeps working.

**Desktop**
- OBS Studio with virtual camera, Kdenlive, Audacity, Krita, PipeWire audio.
- Steam (with Proton), GameMode, MangoHud, Vulkan, Wine, Java 21 for Minecraft.
- Discord, Prism Launcher and Flatseal install themselves from Flathub the first time you're online.

**Server**
- Node.js, npm and PM2, PostgreSQL, Caddy, SSH, ufw, fail2ban, automatic security updates. No Docker.
- Login message shows firewall status and how many PM2 apps are running.

**Tools**
- New `cigaming` command: `fetch`, `update`, `apps`, `nvidia`, `edition`, `version`.

**Our own package repo**
- `repo.cigaming.dev` delivers CiGaming OS updates through normal `apt upgrade`.
- Any Debian trixie machine can become CiGaming OS with `convert.sh`; removing the packages turns it back into stock Debian.
