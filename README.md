# HexPass

A gopass manager for the Omarchy bar.

## Features

- Search every entry in your gopass store.
- Copy passwords, usernames, URLs, and TOTP codes.
- Reveal passwords in place.
- Add, edit, and delete entries or an entire app folder.
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

## Requirements

- Omarchy 4 with the Quickshell shell.
- `gopass` in `PATH`.
- `git` for sync.
- `wl-clipboard` for copying.

gopass uses your normal gpg-agent or age setup.

## Notes

- Runs as your user. No sudo.
- Settings live on the HexPass entry in `~/.config/omarchy/shell.json` and only change when you click a setting.
- `./install.sh` replaces only `~/.config/omarchy/plugins/rezydev.hexpass`.

## License

MIT. See [LICENSE](LICENSE).

## Credit

[rezydev.com](https://rezydev.com/)
