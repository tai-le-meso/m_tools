# First-time GitHub repo setup

Everything needed to get this project from a local folder to a repo that builds, publishes
signed releases, and serves the install page. Do it once; after that, releasing is just
`git tag`.

Steps 1–4 get you a working repo. Step 5 is required before anyone can install a signed
build. Step 6 publishes the install page.

---

## 1. Create the repo and push

The folder isn't a git repo yet, so start there:

```sh
cd /path/to/m_tools
git init -b main
git add .
git commit -m "Initial commit: m_tools internal developer toolbox"
```

Create an **empty** repo on GitHub — no README, no .gitignore, no license, since this
project already has its own — then:

```sh
git remote add origin git@github.com:ORG/m_tools.git
git push -u origin main
```

`.gitignore` already excludes `build/`, `*.dmg`, `*.p12`, and `.DS_Store`, so no build
artifacts or certificates get committed. Worth confirming with `git status` before that
first commit.

> **Naming:** whatever you use for `ORG/m_tools` has to match `REPO_URL` in
> `docs/index.html` (step 6) and the clone URL. Renaming later means editing one line.

## 2. Set repo visibility and access

- **Visibility:** private, or internal if you're on GitHub Enterprise. Not public — this is
  an internal tool.
- **Access:** give the whole engineering team at least **Read**. They need it to see
  Releases (to download the app) and to file issues. Without this the install page's
  download links 404 for everyone but you.
- **Issues:** leave enabled — the install page links to them for bug reports.

## 3. Confirm CI runs

`.github/workflows/ci.yml` builds the app, icon, and DMG and runs the logic tests on every
push and PR. It should go green on the first push. If Actions is disabled org-wide, enable
it under **Settings → Actions → General → Allow all actions**.

There's no Xcode project here, so a compile error can't be caught in an editor — this
workflow is the safety net. Consider protecting `main` (**Settings → Branches → Add rule**)
and requiring the `build` check to pass before merge.

## 4. Set up the release signing certificate

Releases are signed with one shared identity so that if the app ever requests a permission
grant, users keep it across updates — macOS ties the grant to the signing certificate, not
the app name or path. Ad-hoc signatures change every build and would reset it.

1. **Create the cert** — Keychain Access → *Certificate Assistant → Create a Certificate*:
   - Name: **`m_tools-release`** (exactly — `build.sh` looks it up by name)
   - Identity Type: *Self Signed Root*
   - Certificate Type: *Code Signing*
2. **Export it** — right-click the cert → *Export* → `m_tools-release.p12`, set a password.
3. **Add two repository secrets** — **Settings → Secrets and variables → Actions → New
   repository secret**:
   | Secret | Value |
   |---|---|
   | `RELEASE_CERT_P12_BASE64` | `base64 -i m_tools-release.p12 \| pbcopy`, then paste |
   | `RELEASE_CERT_PASSWORD` | the password from step 2 |
4. **Pin the cert** — get its SHA-1 from `security find-identity -p codesigning` and set
   `RELEASE_CERT_SHA` at the top of `build.sh`. A build signed by any other identity then
   hard-fails instead of quietly shipping. It's blank by default so the build works before
   this step is done.
5. **Store the `.p12` somewhere safe** (a password manager or the team vault) and delete
   your local copy. Losing it means future releases get a *different* identity, which
   resets any permission grants users have. `.gitignore` already blocks `*.p12` from being
   committed, but don't rely on that alone.

## 5. Cut the first release

```sh
# VERSION in build.sh must equal the tag — the workflow checks and fails if they disagree.
git tag 0.1.0
git push origin 0.1.0
```

`.github/workflows/release.yml` then rebuilds from the tag, signs with `m_tools-release`,
renames the DMG to `m_tools-0.1.0.dmg`, and publishes it as a GitHub Release. Confirm the
asset appears under **Releases** — the install page's download button points at
`/releases/latest`, so nothing works until at least one release exists.

## 6. Publish the install page

`docs/index.html` is the page your team uses to install and update the app.

1. **Point it at the repo** — open `docs/index.html`, find `REPO_URL` near the bottom, and
   replace the placeholder:
   ```js
   const REPO_URL = "https://github.com/ORG/m_tools";
   ```
   Every download, release, tag, and issue link on the page is derived from that one
   constant.
2. **Enable Pages** — **Settings → Pages → Source: Deploy from a branch**, branch `main`,
   folder `/docs`. The page lands at `https://ORG.github.io/m_tools/`.
   - On a **private** repo, GitHub Pages needs GitHub Enterprise Cloud. If Pages isn't
     available, the file is fully self-contained — copy it to any intranet host, or just
     send people the raw file. It has no build step and no local assets.
3. **Share the link** and tell people the first launch needs right-click → Open (the page
   explains why, since the app is signed with an internal cert rather than a paid Apple
   Developer ID).

## Per-release checklist

Once the above is done, shipping an update is:

1. Bump `VERSION` in `build.sh`.
2. Update `docs/index.html`: `<body data-version="...">` and add a release-notes block
   (there's a commented template in the Releases section showing the markup).
3. Commit, then `git tag <version> && git push origin <version>`.

---

## Which secrets and settings live where

| What | Where | Why |
|---|---|---|
| `RELEASE_CERT_P12_BASE64` | Actions secret | Lets CI sign the release build |
| `RELEASE_CERT_PASSWORD` | Actions secret | Unlocks that `.p12` |
| `RELEASE_CERT_SHA` | `build.sh` (committed) | Not secret — a cert fingerprint, used to reject a build signed by the wrong identity |
| `REPO_URL` | `docs/index.html` (committed) | Generates every GitHub link on the install page |
| `VERSION` | `build.sh` (committed) | Must equal the release tag |
| `m_tools-release.p12` | Team vault, **never committed** | Losing it resets users' permission grants on future updates |
