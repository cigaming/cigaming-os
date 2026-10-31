# CiGaming OS

A Debian-based Linux distribution — the real-hardware sibling of the browser OS at [os.cigaming.dev](https://os.cigaming.dev).

Like Ubuntu is to Debian, CiGaming OS is Debian 13 "trixie" underneath, with its own identity, its own packages and its own apt repository on top. Debian keeps doing security updates for the 70,000 packages underneath; we ship the parts that make it *ours*.

| Edition | Who it's for | Installer |
|---|---|---|
| **Desktop** | Streamers, gamers, the community — KDE Plasma, OBS, Steam, Discord, Prism Launcher | Calamares (graphical) |
| **Server** | The fleet — Node + PM2, PostgreSQL, Caddy, SSH, firewall, auto security updates | Debian installer (text) |

## How it fits together

```
 Debian trixie (main contrib non-free non-free-firmware)      ← security updates from Debian
        +
 repo.cigaming.dev  (suite "cub")                             ← updates from us
   cigamingos-branding   name, os-release, wallpaper, GRUB, boot splash, KDE colors
   cigamingos-tools      `cigaming` command + first-boot app installer
   cigamingos-keyring    our signing key + apt source
   cigamingos-desktop    metapackage: the desktop + streaming apps
   cigamingos-gaming     metapackage: Steam, Proton, GameMode, MangoHud, Wine, Java
   cigamingos-server     metapackage: the fleet server stack
   cigamingos-installer  Calamares branding (live USB only)
        =
 live-build → cigamingos-1.0.0-desktop-amd64.iso / …-server-amd64.iso
```

Because everything is a normal `.deb`, changing the wallpaper or adding an app to every CiGaming OS machine is just: bump `VERSION`, push a tag, and everyone gets it in their next `apt upgrade`.

## Quick start

On a **Debian trixie** machine or VM (Ubuntu's live-build is too old):

```bash
make deps          # live-build, reprepro, librsvg, shellcheck…
make key           # one time: creates the repo signing key (see "Your repo")
make packages      # builds build/debs/*.deb
make desktop       # → dist/cigamingos-1.0.0-desktop-amd64.iso
make server        # → dist/cigamingos-1.0.0-server-amd64.iso
make test-vm       # boot the newest ISO in QEMU
```

The desktop ISO is around 4–5 GB and needs ~25 GB free disk while building. Expect 30–60 minutes the first time; later builds reuse the package cache.

Flash to USB with Balena Etcher / Rufus (DD mode), or `sudo dd if=dist/….iso of=/dev/sdX bs=4M status=progress oflag=sync`.

Live USB login: user **cub**, no password.

## Branding — match the web OS

Every color, the name, version and codename live in **`branding/palette.env`**. The current colors are a lion-cub night palette I picked; swap in the exact hex values from os.cigaming.dev and run `make packages` — the wallpaper, logo, GRUB background, boot splash, KDE color scheme, installer and repo page all regenerate from it.

Artwork sources:
- `branding/logo.svg` — the cub mark (used for icons, boot splash, installer)
- `branding/wallpaper.svg` — default wallpaper, also the login screen

Both use `{{TOKENS}}` filled from the palette. Replace them with your own art any time; keep the tokens if you want palette changes to flow through.

## Your repo

The repo is **static files** — no server code. Two ways to host it:

**A. GitHub Pages (default).** CI publishes `build/repo-public/` to Pages on every push to `main`. Point a `CNAME` for `repo.cigaming.dev` at `<your-github-user>.github.io` and set the custom domain in the repo's Pages settings.

**B. Your own Caddy.** Download the `repo-site` artifact from any CI run and copy it to the folder in `repo/Caddyfile`. Works on the Windows Caddy box.

**Signing key setup (once):**
1. `make key` → creates `keys/cigamingos-archive.asc` (public, commit it) and `keys/private/cigamingos-archive.sec` (private).
2. GitHub → Settings → Secrets and variables → Actions → **`REPO_SIGNING_KEY`** = contents of the `.sec` file.
3. Back up `keys/private/` offline and delete it from the working copy. If this key is lost, every installed machine has to be told about a new one.

Until the repo is online, ISOs still build — `build.sh` notices and leaves the CiGaming repo out of that image.

### Turn an existing Debian machine into CiGaming OS

```bash
curl -fsSL https://repo.cigaming.dev/convert.sh | sudo sh -s -- desktop   # or gaming, server, base
```

Removing it puts stock Debian back exactly: `sudo apt purge 'cigamingos-*'`.

## Releasing

1. Edit `VERSION` (and `OS_VERSION` in `palette.env` for a new major/minor).
2. Add patch notes to `CHANGELOG.md` — they become the GitHub release text and ship inside every package.
3. `git tag v1.0.1 && git push --tags`

CI builds the packages, signs and publishes the repo, builds both ISOs and attaches them to a GitHub release. ISOs over GitHub's 2 GB asset limit are split into parts with rejoin instructions.

Pushes to `main` only build packages + repo (fast); run the workflow manually to get ISOs without tagging.

## The `cigaming` command

```
cigaming fetch     system info with the cub
cigaming update    apt full-upgrade + Flatpak updates
cigaming apps      install the default Flatpak apps (/etc/cigamingos/flatpaks.list)
cigaming nvidia    install NVIDIA drivers
cigaming edition   which editions are installed
```

## The welcome app

`cigamingos-welcome` opens once on each user's first login (never on the live USB or for root) and can be re-opened from the app menu. Two files control it — both are ordinary config files, so local edits survive updates:

- `/etc/cigamingos/welcome.conf` — SnuggleSMP server address, website and community links, and the help link. Empty values hide that part of the page.
- `/etc/cigamingos/welcome-apps.json` — the app picker: Flathub ID, name, category, description, and whether it's ticked by default.

To change them for everyone, edit the copies in `packages/cigamingos-welcome/etc/cigamingos/` and ship a new version. `cigamingos-welcome --screenshot DIR` renders every page to PNGs.

## Design notes (why it's built this way)

- **Debian's files are diverted, not overwritten.** `os-release`, `/etc/issue` and `/etc/issue.net` are moved aside with `dpkg-divert`, so Debian upgrades never fight us and removing our package restores them.
- **`VERSION_CODENAME` stays `trixie`.** Third-party installers (NodeSource, Tailscale, etc.) build apt URLs from it. Our own codename is in `CIGAMINGOS_CODENAME=cub`.
- **GRUB says "CiGaming OS" but the EFI folder stays `/EFI/debian`.** Debian derives the EFI folder from the distributor name, and the Secure Boot-signed shim/GRUB only work from `/EFI/debian`. `etc/default/grub.d/cigamingos.cfg` gives the menu our name and everything else "Debian".
- **Discord, Prism Launcher are Flatpaks installed on first boot** because they aren't in Debian; baking them into the ISO would go stale immediately.
- **No Docker on the server edition**, matching how the fleet runs today.

## Layout

```
branding/        palette.env, logo.svg, wallpaper.svg
packages/        one folder per .deb (DEBIAN/ + files; *.in files are templated)
editions/        live-build config layered onto each ISO: common/, desktop/, server/
repo/            reprepro config, repo landing page, Caddyfile
scripts/         render-assets, build-packages, repo-keygen, repo-publish, convert.sh
build.sh         builds one ISO
.github/         CI: lint → packages → repo → ISOs → release
```

## Roadmap ideas

- CorsiOS / NoniOS / SolaeOS / AxeonosOS / Echo flavours — same base, different `palette.env` + wallpaper, like the web OS family
- Package the streamer tools (DeskLayer, OverlayHub companion) as `.deb`s in the repo
- Plymouth and SDDM themes that mirror the web OS boot sequence
