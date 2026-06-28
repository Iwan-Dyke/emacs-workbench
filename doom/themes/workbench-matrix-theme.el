;;; workbench-matrix-theme.el --- black and green -*- lexical-binding: t; no-byte-compile: t; -*-
;;; Commentary:
;;; The Matrix — pure black background, phosphor green foreground.
;;; Code:

(require 'doom-themes)

(def-doom-theme workbench-matrix
  "Black and green terminal theme."
  :family 'workbench-matrix
  :background-mode 'dark

  ;; name        default       256         16
  ((bg         '("#000000" "black"     "black"        ))
   (fg         '("#00ff41" "#00ff00"   "green"        ))
   (bg-alt     '("#050a05" "black"     "black"        ))
   (fg-alt     '("#1a7a2e" "#005f00"   "green"        ))

   (base0      '("#000000" "black"     "black"        ))
   (base1      '("#021a02" "#1e1e1e"   "brightblack"  ))
   (base2      '("#0a2a0a" "#2e2e2e"   "brightblack"  ))
   (base3      '("#0f3a0f" "#262626"   "brightblack"  ))
   (base4      '("#1a4a1a" "#3f3f3f"   "brightblack"  ))
   (base5      '("#2d6b2d" "#525252"   "brightblack"  ))
   (base6      '("#3d8b3d" "#6b6b6b"   "brightblack"  ))
   (base7      '("#5aad5a" "#979797"   "brightblack"  ))
   (base8      '("#b0ffb0" "#dfdfdf"   "white"        ))

   (grey       base4)
   (red        '("#ff2020" "#ff6655"   "red"          ))
   (orange     '("#7aff41" "#dd8844"   "brightred"    ))
   (green      '("#00ff41" "#00ff00"   "green"        ))
   (teal       '("#00cc66" "#44b9b1"   "brightgreen"  ))
   (yellow     '("#80ff00" "#ECBE7B"   "yellow"       ))
   (blue       '("#00ff99" "#51afef"   "brightblue"   ))
   (dark-blue  '("#006633" "#2257A0"   "blue"         ))
   (magenta    '("#00ff80" "#c678dd"   "brightmagenta"))
   (violet     '("#66ffaa" "#a9a1e1"   "magenta"      ))
   (cyan       '("#33ffcc" "#46D9FF"   "brightcyan"   ))
   (dark-cyan  '("#00804d" "#5699AF"   "cyan"         ))

   ;; Syntax classes — everything green-shifted
   (highlight    green)
   (vertical-bar (doom-darken base3 0.2))
   (selection    dark-blue)
   (builtin      green)
   (comments     base5)
   (doc-comments base6)
   (constants    teal)
   (functions    fg)
   (keywords     green)
   (methods      cyan)
   (operators    base7)
   (type         yellow)
   (strings      teal)
   (variables    base8)
   (numbers      orange)
   (region       `(,(doom-lighten (car bg-alt) 0.15) ,@(doom-lighten (cdr base1) 0.35)))
   (error        red)
   (warning      yellow)
   (success      green)
   (vc-modified  yellow)
   (vc-added     green)
   (vc-deleted   red)

   ;; Theme-specific
   (modeline-fg          fg)
   (modeline-fg-alt      base5)
   (modeline-bg          base2)
   (modeline-bg-alt      base1)
   (modeline-bg-inactive base1)
   (modeline-bg-inactive-alt base0))

  ;;;; Face overrides
  (((line-number &override) :foreground base4)
   ((line-number-current-line &override) :foreground green)
   (mode-line :background modeline-bg :foreground modeline-fg)
   (mode-line-inactive :background modeline-bg-inactive :foreground modeline-fg-alt)
   (mode-line-emphasis :foreground green)
   (cursor :background green)
   (doom-modeline-bar :background green)
   (doom-modeline-buffer-file :inherit 'mode-line-buffer-id :weight 'bold)
   (treemacs-root-face :foreground green :weight 'bold :height 1.1)
   (treemacs-git-modified-face :foreground yellow)
   (treemacs-git-added-face :foreground green))

  ;;;; Variable overrides
  ())

;;; workbench-matrix-theme.el ends here
