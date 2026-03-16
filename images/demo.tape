Output images/demo.gif

Set FontFamily "JetBrainsMono Nerd Font"
Set FontSize 18
Set Width 1200
Set Height 340
Set Padding 20
Set MarginFill "#1e1e2e"
Set WindowBar "Colorful"
Set TypingSpeed 0ms
Set Theme {
  "name": "StatusLine",
  "black": "#1e1e2e",
  "red": "#f38ba8",
  "green": "#a6e3a1",
  "yellow": "#f9e2af",
  "blue": "#89b4fa",
  "magenta": "#cba6f7",
  "cyan": "#94e2d5",
  "white": "#cdd6f4",
  "background": "#1e1e2e",
  "foreground": "#cdd6f4"
}

Type "export PS1=''"
Enter
Type "clear"
Enter
Sleep 500ms

# Full tier -- catppuccin-mocha (default)
Type "printf '\033[1;97m catppuccin-mocha -- full tier\033[0m\n'"
Enter
Type "cat test/fixtures/full.json | COLUMNS=140 sh main.sh"
Enter
Sleep 3s

Type "clear"
Enter
Sleep 300ms

# Full tier -- dracula
Type "printf '\033[1;97m dracula -- full tier\033[0m\n'"
Enter
Type "cat test/fixtures/full.json | COLUMNS=140 CLAUDE_STATUSLINE_THEME=dracula sh main.sh"
Enter
Sleep 3s

Type "clear"
Enter
Sleep 300ms

# Full tier -- nord
Type "printf '\033[1;97m nord -- full tier\033[0m\n'"
Enter
Type "cat test/fixtures/full.json | COLUMNS=140 CLAUDE_STATUSLINE_THEME=nord sh main.sh"
Enter
Sleep 3s

Type "clear"
Enter
Sleep 300ms

# Full tier -- bluloco-dark
Type "printf '\033[1;97m bluloco-dark -- full tier\033[0m\n'"
Enter
Type "cat test/fixtures/full.json | COLUMNS=140 CLAUDE_STATUSLINE_THEME=bluloco-dark sh main.sh"
Enter
Sleep 3s

Type "clear"
Enter
Sleep 300ms

# Compact tier
Type "printf '\033[1;97m compact tier (80-119 cols)\033[0m\n'"
Enter
Type "cat test/fixtures/full.json | COLUMNS=100 sh main.sh"
Enter
Sleep 3s

Type "clear"
Enter
Sleep 300ms

# Micro tier
Type "printf '\033[1;97m micro tier (< 80 cols)\033[0m\n'"
Enter
Type "cat test/fixtures/full.json | COLUMNS=60 sh main.sh"
Enter
Sleep 3s
