# Deploying m_tools on managed Macs

For IT / whoever runs the MDM. The short version: **push the `.pkg` via MDM and neither
prompt ever appears** — no admin password, no "unidentified developer" warning — even though
the app is signed with an internal self-signed certificate rather than an Apple Developer ID.

---

## The two prompts are unrelated

This is the part worth getting straight, because they have different causes and different
fixes, and conflating them leads to chasing the wrong solution (usually "we need to pay for
a Developer ID", which isn't true for MDM deployment).

| Prompt | Why it happens | Fixed by |
|---|---|---|
| **"Enter your password to allow this"** when dragging to `/Applications` | `/Applications` is only writable by admins. On a managed Mac most users are standard users, so every install *and every update* asks for credentials they may not have. | Installing as **root** (MDM), or installing to **`~/Applications`** instead. |
| **"m_tools cannot be opened because the developer cannot be verified"** | Gatekeeper evaluates the `com.apple.quarantine` extended attribute that browsers stamp onto downloads. Because the app isn't notarized, that evaluation fails. | Delivering the app **without a quarantine attribute** — which is exactly what an MDM install does. |

The second row is the important one: **Gatekeeper only gates quarantined files.** Files an
MDM lays down as root are never quarantined, so Gatekeeper never evaluates the signature at
all. Notarization would also solve it, but it isn't required if the app never arrives via a
browser download.

## Recommended: push the .pkg via MDM

### Build it

```sh
./build.sh --pkg          # → m_tools-<version>.pkg (plus the .app and .dmg)
```

The package installs `m_tools.app` into `/Applications` with `root:wheel` ownership.

| Property | Value |
|---|---|
| Package identifier | `io.internal.mtools` |
| Install location | `/Applications/m_tools.app` |
| Version | matches `VERSION` in `build.sh` and the release tag |
| Signed | Only if an `m_tools-installer` identity exists locally — **not required**, see below |
| Scripts | None — a plain payload-only package |

### Deploy it

The package is an ordinary payload-only `.pkg`, so every MDM handles it with its standard
"deploy a package" mechanism:

- **Jamf Pro** — upload to Jamf Admin / Jamf Cloud Distribution Point, then a Policy with a
  Packages payload, scoped to the target smart group. Trigger: recurring check-in.
- **Kandji** — Library → Add New → *Custom App*, install type *Installer Package*.
- **Microsoft Intune** — *macOS app (PKG)*. Intune requires a **signed** package with a
  Developer ID Installer certificate, so this is the one platform where self-signing isn't
  enough; wrap it as a `.pkg` inside Intune's macOS app wrapper, or use a shell script
  deployment instead.
- **Mosyle** — Management → Custom Commands / *Install PKG*, or host it and use `installer`
  in a shell command.

### Why signing the package doesn't matter here

An MDM install runs as root and is not subject to Gatekeeper's user-facing checks, so an
unsigned or self-signed package installs silently. Signing with our own self-signed identity
adds no trust that a real Developer ID Installer certificate would — the CA isn't trusted by
Apple either way. `build.sh --pkg` signs the package only if an `m_tools-installer` identity
happens to exist locally, and prints a note when it doesn't. Intune is the exception noted
above.

### Updates

Pushing a newer package over an existing install just replaces the bundle — no admin prompt,
no re-approval, no user action. Because every release is signed with the same
`m_tools-release` identity, macOS treats it as the same app across updates, so any future
permission grant survives (the grant is keyed to the certificate, not the app's name or
path).

> Quit the app before or during the update if it's running. It's a menu bar app, so users
> often leave it running for weeks. A `postinstall` script doing
> `pkill -x m_tools || true` can be added to the package if replacing a running bundle turns
> out to be a problem in practice — it hasn't been needed so far, since macOS tolerates
> replacing a running app's bundle and the change takes effect on next launch.

---

## Fallback: self-install with no admin rights

For anyone not yet enrolled, or when you'd rather not involve MDM. This needs **no admin
password at all**, because it avoids `/Applications` entirely.

`~/Applications` is a per-user application folder macOS has always honored — Spotlight and
Launchpad index it, and it's owned by the user, so no authentication is involved.

```sh
# 1. Create the per-user Applications folder (only needed once)
mkdir -p ~/Applications

# 2. Mount the DMG and copy the app there
hdiutil attach ~/Downloads/m_tools-*.dmg
cp -R /Volumes/m_tools/m_tools.app ~/Applications/
hdiutil detach /Volumes/m_tools

# 3. Remove the download quarantine flag, so Gatekeeper doesn't gate first launch
xattr -dr com.apple.quarantine ~/Applications/m_tools.app

# 4. Launch
open ~/Applications/m_tools.app
```

Step 3 is what replaces the right-click → Open dance. It's the same decision the user makes
by clicking "Open Anyway", just expressed as a command — it removes the attribute Gatekeeper
keys off, rather than weakening any system-wide security setting. Worth being explicit with
people about that, so it doesn't look like an arbitrary "run this to disable security" step.

Updates are the same four commands again, and still never ask for a password.

## What paying for a Developer ID would change

Not required for the MDM path, but for completeness: an Apple Developer Program membership
($99/yr) provides a Developer ID Application certificate and access to notarization. With
those, the downloaded DMG would launch with no warning on any Mac, enrolled or not, and the
website's plain "drag to Applications" instructions would work as-is for admin users. It
would **not** remove the admin prompt for writing to `/Applications` — nothing signing-related
does, since that's a filesystem permission, not a trust decision.

---

## Quick reference

| Scenario | Admin needed? | Gatekeeper prompt? |
|---|---|---|
| MDM pushes the `.pkg` | No — runs as root | No — MDM files aren't quarantined |
| User drags DMG → `/Applications` | Yes, every update | Yes, once per install |
| User copies to `~/Applications` + `xattr -dr` | No | No |
| Notarized build, dragged to `/Applications` | Yes, every update | No |
