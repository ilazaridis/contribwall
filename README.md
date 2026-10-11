<p align="center">
  <img src="docs/hero.png" alt="contribwall" width="100%">
</p>

<h3 align="center">Your GitHub contributions, full screen.</h3>

<p align="center">
  A black wall. One big number. Your last two weeks in green.<br>
  Point a spare monitor at it and forget it's there.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-000?style=flat-square&logo=apple&logoColor=white" alt="macOS">
  <img src="https://img.shields.io/badge/license-MIT-217a3c?style=flat-square" alt="MIT">
</p>

<br>

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/ilazaridis/contribwall/main/install.sh | sh
```

Rather not use a terminal? [Download the zip](https://github.com/ilazaridis/contribwall/archive/refs/heads/main.zip),
unzip it, and double-click **Install.command**.

It asks which screen to use, then lights it up. It comes back on its own after a reboot.

<br>

## Use

```sh
contribwall                 # put it on screen
contribwall displays        # list your screens
contribwall display         # choose one
contribwall range month     # week · 14 · month · any 1–90
contribwall awake on        # stop the screens sleeping
contribwall off             # take it off
```

`contribwall status` tells you what's running and what it's showing.

<br>

## Needs

**macOS** · **python3 3.7+** (`xcode-select --install`) · **[GitHub CLI](https://cli.github.com)**, signed in ·
**Chrome**, Brave, Edge or Chromium in `/Applications`

It reads *your* contributions through your own `gh` login, so there's no token to
paste anywhere. Private contributions count too, once you grant `read:user` —
the installer offers to ask for it.

<br>

## Settings

`~/.config/contribwall/config.json`

| | | |
|---|---|---|
| `days` | how far back the bars go, `1`–`90` | next refresh |
| `ramp` | `darker` or `brighter` — which end of the green is a busy day | next refresh |
| `refreshSeconds` | how often it checks, `5`–`3600` | next refresh |
| `display` | screen name fragment, or `""` for the second one | run `contribwall` |
| `port` | local port, default `8723` | restart the server, then `contribwall` |

<br>

## How it works

A small Python server asks the GitHub CLI for your contribution calendar and
serves one page on `127.0.0.1`. A browser window sits fullscreen on your screen
and re-polls it every minute. Two `launchd` agents keep the server up and put the
window back after a reboot. contribwall itself talks to nothing but GitHub and
that local port.

<br>

## Uninstall

```sh
~/.local/share/contribwall/uninstall.sh
```

Or double-click **Uninstall.command**. Your settings survive; delete
`~/.config/contribwall` to finish the job.

<br>

<p align="center"><sub>MIT · built for a spare monitor that deserved better</sub></p>
