# Themes

Four bundled themes, each showing all three model colors, context gauge states, and segment tones. Set your theme via environment variable:

```sh
export CLAUDE_STATUSLINE_THEME="catppuccin-mocha"
```

Want to create your own? See the [theme creation guide](CONTRIBUTING.md#adding-a-theme) or [port your existing terminal theme](CONTRIBUTING.md#porting-an-existing-terminal-theme).

---

<details open>
<summary><h2>catppuccin-mocha (default)</h2></summary>

<img src="images/theme-catppuccin-mocha.gif" alt="catppuccin-mocha theme preview" width="800">

Based on [Catppuccin Mocha](https://github.com/catppuccin/catppuccin), the highest-contrast dark flavor. Warm pastels on a deep navy background.

```sh
export CLAUDE_STATUSLINE_THEME="catppuccin-mocha"
```

| Role | Color | 256 | Hex |
|------|-------|-----|-----|
| Background | Base | 234 | `#1e1e2e` |
| Foreground | Text | 188 | `#cdd6f4` |
| Muted BG | Surface0 | 236 | `#313244` |
| Dim BG | Mantle | 233 | `#181825` |
| Blue (Sonnet) | Blue | 111 | `#89b4fa` |
| Gold (Opus) | Yellow | 223 | `#f9e2af` |
| Green | Green | 151 | `#a6e3a1` |
| Cyan (Haiku) | Teal | 158 | `#94e2d5` |
| Red | Red | 211 | `#f38ba8` |
| Orange | Peach | 216 | `#fab387` |
| Magenta | Mauve | 183 | `#cba6f7` |
| Dim text | Overlay0 | 243 | `#6c7086` |

**Overrides:** Sonnet BG deepened to 69, context gauge uses green-tinted dark (22) for healthy and dark red (52) for filling/critical.

</details>

---

<details>
<summary><h2>dracula</h2></summary>

<img src="images/theme-dracula.gif" alt="dracula theme preview" width="800">

Based on [Dracula](https://draculatheme.com). High contrast with vivid neon accents on a cool dark background.

```sh
export CLAUDE_STATUSLINE_THEME="dracula"
```

| Role | Color | 256 | Hex |
|------|-------|-----|-----|
| Background | Background | 236 | `#282a36` |
| Foreground | Foreground | 255 | `#f8f8f2` |
| Muted BG | Current Line | 238 | `#44475a` |
| Dim BG | darker | 234 | `#21222c` |
| Blue (Sonnet) | Purple | 141 | `#bd93f9` |
| Gold (Opus) | Yellow | 228 | `#f1fa8c` |
| Green | Green | 84 | `#50fa7b` |
| Cyan (Haiku) | Cyan | 117 | `#8be9fd` |
| Red | Red | 203 | `#ff5555` |
| Orange | Orange | 215 | `#ffb86c` |
| Magenta | Pink | 212 | `#ff79c6` |
| Dim text | Comment | 61 | `#6272a4` |

**Overrides:** None. Pure Dracula derivation.

</details>

---

<details>
<summary><h2>nord</h2></summary>

<img src="images/theme-nord.gif" alt="nord theme preview" width="800">

Based on [Nord](https://www.nordtheme.com). Muted arctic tones with lower contrast for a calm, focused aesthetic.

```sh
export CLAUDE_STATUSLINE_THEME="nord"
```

| Role | Color | 256 | Hex |
|------|-------|-----|-----|
| Background | Polar Night | 236 | `#2e3440` |
| Foreground | Snow Storm | 255 | `#eceff4` |
| Muted BG | Polar Night | 238 | `#3b4252` |
| Dim BG | Polar Night | 235 | `#2e3440` |
| Blue (Sonnet) | Frost | 110 | `#81a1c1` |
| Gold (Opus) | Aurora | 222 | `#ebcb8b` |
| Green | Aurora | 144 | `#a3be8c` |
| Cyan (Haiku) | Frost | 116 | `#88c0d0` |
| Red | Aurora | 167 | `#bf616a` |
| Orange | Aurora | 173 | `#d08770` |
| Magenta | Aurora | 139 | `#b48ead` |
| Dim text | Polar Night | 240 | `#4c566a` |

**Overrides:** Healthy context BG bumped to 23 (teal-tinted dark) for readability against Nord's muted palette.

</details>

---

<details>
<summary><h2>bluloco-dark</h2></summary>

<img src="images/theme-bluloco-dark.gif" alt="bluloco-dark theme preview" width="800">

Based on [Bluloco Dark](https://github.com/uloco/theme-bluloco-dark). Vivid accents with blue-leaning neutrals. Includes several contrast fixes for status line readability.

```sh
export CLAUDE_STATUSLINE_THEME="bluloco-dark"
```

| Role | Color | 256 | Hex |
|------|-------|-----|-----|
| Background | | 236 | `#282c34` |
| Foreground | | 249 | `#abb2bf` |
| Muted BG | | 237 | `#2c313a` |
| Dim BG | | 235 | `#262626` |
| Blue (Sonnet) | | 33 | `#3691ff` |
| Gold (Opus) | | 221 | `#f9c859` |
| Green | | 77 | `#3fc56b` |
| Cyan (Haiku) | | 80 | `#34bfd0` |
| Red | | 204 | `#ff6480` |
| Orange | | 209 | `#ff7b72` |
| Magenta | | 134 | `#b267e6` |
| Dim text | | 246 | `#636d83` |

**Overrides:** Sonnet BG deepened to 27 (less glare), warming context uses base BG (gold FG carries signal alone), filling context uses dark red (52), dim duration text bumped to 247 for readability.

</details>
