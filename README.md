# HexPass

A gopass manager for the Omarchy bar.

## Features

- Search every entry in your gopass store.
- Copy passwords, usernames, URLs, and TOTP codes.
- Reveal passwords in place.
- Add, edit, and delete entries.
- Generate passwords with gopass (cryptic, XKCD, memorable).
- Sync with git and refresh changes made on another device.
- Show branch, ahead/behind, and dirty state.
- Clear the clipboard automatically.
- Run fsck, audit, and doctor from settings.

## Install

```bash
./install.sh
```

Or install from git:

```bash
omarchy plugin add git@github.com:Rezy-Dev/HexPass.git --enable --yes
```

The git remote uses SSH, so make sure your key is loaded (`ssh-add -l`).

## Remove

```bash
omarchy plugin remove rezydev.hexpass
```

## Credit

[rezydev.com](https://rezydev.com/)
