# Option+Left/Right = word jump.
# Ghostty/cmux send CSI 1;3D / 1;3C (see macos-option-as-alt in ghostty config).
# Ghostty 1.3.x silently drops keybinds on alt+arrow_left/right, so this must
# live here rather than in the terminal config.
bindkey "^[[1;3D" backward-word
bindkey "^[[1;3C" forward-word
