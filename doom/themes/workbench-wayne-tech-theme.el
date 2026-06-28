;;; workbench-wayne-tech-theme.el --- dark blues, greys, blacks, whites -*- lexical-binding: t; no-byte-compile: t; -*-
;;; Commentary:
;;; A clean dark tech theme — steel blues, cool greys, high contrast.
;;; Code:

(require 'doom-themes)

(def-doom-theme workbench-wayne-tech
  "Dark tech theme: blues, greys, blacks, whites."
  :family 'workbench-wayne-tech
  :background-mode 'dark

  ;; name        default       256         16
  ((bg         '("#0a0e14" "black"     "black"        ))
   (fg         '("#d4d7e0" "#dfdfdf"   "brightwhite"  ))
   (bg-alt     '("#0f1319" "black"     "black"        ))
   (fg-alt     '("#6b7089" "#6b6b6b"   "white"        ))

   (base0      '("#060810" "black"     "black"        ))
   (base1      '("#0b0f18" "#1e1e1e"   "brightblack"  ))
   (base2      '("#12161f" "#2e2e2e"   "brightblack"  ))
   (base3      '("#1a1e27" "#262626"   "brightblack"  ))
   (base4      '("#2d3340" "#3f3f3f"   "brightblack"  ))
   (base5      '("#4a5168" "#525252"   "brightblack"  ))
   (base6      '("#6b7089" "#6b6b6b"   "brightblack"  ))
   (base7      '("#9aa0b0" "#979797"   "brightblack"  ))
   (base8      '("#e8eaf0" "#dfdfdf"   "white"        ))

   (grey       base4)
   (red        '("#e06c75" "#ff6655"   "red"          ))
   (orange     '("#d19a66" "#dd8844"   "brightred"    ))
   (green      '("#7ec49c" "#99bb66"   "green"        ))
   (teal       '("#56b6c2" "#44b9b1"   "brightgreen"  ))
   (yellow     '("#e5c07b" "#ECBE7B"   "yellow"       ))
   (blue       '("#4fa6ed" "#51afef"   "brightblue"   ))
   (dark-blue  '("#1a5fb4" "#2257A0"   "blue"         ))
   (magenta    '("#bf68d9" "#c678dd"   "brightmagenta"))
   (violet     '("#a9a1e1" "#a9a1e1"   "magenta"      ))
   (cyan       '("#73c7d4" "#46D9FF"   "brightcyan"   ))
   (dark-cyan  '("#3e7d8a" "#5699AF"   "cyan"         ))

   ;; Syntax classes
   (highlight    blue)
   (vertical-bar (doom-darken base1 0.1))
   (selection    dark-blue)
   (builtin      blue)
   (comments     base5)
   (doc-comments (doom-lighten base5 0.2))
   (constants    violet)
   (functions    cyan)
   (keywords     blue)
   (methods      cyan)
   (operators    base7)
   (type         teal)
   (strings      green)
   (variables    base8)
   (numbers      orange)
   (region       `(,(doom-lighten (car bg-alt) 0.15) ,@(doom-lighten (cdr base1) 0.35)))
   (error        red)
   (warning      yellow)
   (success      green)
   (vc-modified  orange)
   (vc-added     green)
   (vc-deleted   red)

   ;; Theme-specific
   (modeline-fg          fg)
   (modeline-fg-alt      base5)
   (modeline-bg          (doom-darken base2 0.1))
   (modeline-bg-alt      (doom-darken base2 0.2))
   (modeline-bg-inactive base1)
   (modeline-bg-inactive-alt base0))

  ;;;; Face overrides
  (((line-number &override) :foreground base4)
   ((line-number-current-line &override) :foreground base8)
   (mode-line :background modeline-bg :foreground modeline-fg)
   (mode-line-inactive :background modeline-bg-inactive :foreground modeline-fg-alt)
   (mode-line-emphasis :foreground blue)
   (doom-modeline-bar :background blue)
   (doom-modeline-buffer-file :inherit 'mode-line-buffer-id :weight 'bold)
   (treemacs-root-face :foreground blue :weight 'bold :height 1.1)
   (treemacs-git-modified-face :foreground orange)
   (treemacs-git-added-face :foreground green))

  ;;;; Variable overrides
  ())

;;; workbench-wayne-tech-theme.el ends here
