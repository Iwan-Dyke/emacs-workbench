;;; system/visual.el -*- lexical-binding: t; -*-

;; Visual enhancements for workbench buffers:
;;   - lin: subtle hl-line styling for selection-oriented buffers
;;   - org-modern: clean org headings, tags, timestamps in agenda
;;   - hl-line: enabled in custom dashboard/list modes

;;; ── Lin (enhanced hl-line for list buffers) ────────────────────────────────

(after! lin
  ;; Lin remaps hl-line-face buffer-locally for selection-oriented modes.
  ;; These are our custom modes where line-based navigation is primary.
  (setq lin-mode-hooks
        '(workbench-repos-mode-hook
          workbench-cc-mode-hook
          org-agenda-mode-hook
          dired-mode-hook)))

;; Enable lin in our custom modes
(add-hook 'workbench-repos-mode-hook #'lin-mode)
(add-hook 'workbench-cc-mode-hook #'lin-mode)

;; Enable hl-line in project dashboard (not a lin candidate since it's
;; not strictly line-selection, but the highlight helps readability)
(add-hook 'special-mode-hook
          (lambda ()
            (when (string-prefix-p "*workbench:" (buffer-name))
              (hl-line-mode 1))))

;;; ── Org-modern (clean org visuals) ─────────────────────────────────────────

(after! org
  (when (fboundp 'global-org-modern-mode)
    (setq org-modern-star '("◉" "○" "◈" "◇" "▸")
          org-modern-table nil            ; keep org tables as-is
          org-modern-list '((?- . "•")
                            (?+ . "◦"))
          org-modern-checkbox '((?X . "☑")
                                (?- . "◧")
                                (?\s . "☐"))
          org-modern-tag t
          org-modern-timestamp t
          org-modern-priority t
          org-modern-progress t
          org-modern-keyword t
          org-modern-block-fringe t)
    (global-org-modern-mode 1)))

;;; ── Agenda visual tweaks ───────────────────────────────────────────────────

(after! org-agenda
  ;; Lin handles hl-line in agenda. Add visual breathing room.
  (setq org-agenda-block-separator ?─
        org-agenda-time-grid '((daily today require-timed)
                               (800 1000 1200 1400 1600 1800 2000)
                               " ┄┄┄┄┄ " "┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄")))

(provide 'workbench-visual)
;;; visual.el ends here
