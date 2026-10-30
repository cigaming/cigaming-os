# CiGaming OS patch notes

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
