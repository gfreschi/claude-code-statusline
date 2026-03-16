Output images/demo.gif

Set FontFamily "JetBrainsMono Nerd Font"
Set FontSize 18
Set Width 1200
Set Height 600
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
Type "sh images/render-demo.sh"
Enter
Sleep 35s
