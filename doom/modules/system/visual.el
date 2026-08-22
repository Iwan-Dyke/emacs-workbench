;;; system/visual.el -*- lexical-binding: t; -*-

;; Visual enhancements for workbench buffers:
;;   - lin: subtle hl-line styling for selection-oriented buffers
;;   - org-modern: clean org headings, tags, timestamps in agenda
;;   - hl-line: enabled in custom dashboard/list modes

(defvar workbench/profile)  ; defined in system/core.el

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
(defun workbench--maybe-enable-hl-line ()
  "Enable hl-line in workbench special-mode buffers."
  (when (string-prefix-p "*workbench:" (buffer-name))
    (hl-line-mode 1)))

(add-hook 'special-mode-hook #'workbench--maybe-enable-hl-line)

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

;;; ── Pulsar (phosphor persistence — flash line on jump) ──────────────────────

(after! pulsar
  (when (fboundp 'pulsar-global-mode)
    (setq pulsar-face 'pulsar-green
          pulsar-delay 0.04
          pulsar-iterations 8)
    (pulsar-global-mode 1)))

;;; ── Dimmer (phosphor decay — fade inactive windows) ────────────────────────

(after! dimmer
  (when (fboundp 'dimmer-mode)
    (setq dimmer-fraction 0.4)
    ;; Don't dim certain buffers where visibility matters
    (setq dimmer-exclusion-regexp-list
          '("\\*Minibuf" "\\*which-key" "\\*Messages"))
    (when (fboundp 'dimmer-configure-magit)
      (dimmer-configure-magit))
    (dimmer-mode 1)))

;;; ── Matrix-specific visual enhancements ────────────────────────────────────

(defun workbench--matrix-theme-active-p ()
  "Return non-nil if the matrix theme is currently loaded."
  (memq 'workbench-matrix custom-enabled-themes))

(defun workbench--apply-matrix-visuals ()
  "Apply extra visual settings when matrix theme is active."
  (when (workbench--matrix-theme-active-p)
    ;; Extra line-spacing for CRT scanline row separation feel
    (setq-default line-spacing 2)))

(defun workbench--remove-matrix-visuals ()
  "Remove matrix-specific visual settings."
  (setq-default line-spacing nil))

;; Apply/remove matrix visuals on theme switch
(add-hook 'doom-load-theme-hook
          (lambda ()
            (if (workbench--matrix-theme-active-p)
                (workbench--apply-matrix-visuals)
              (workbench--remove-matrix-visuals))))

;;; ── Zone-matrix screensaver ────────────────────────────────────────────────

(after! zone
  (when (and (require 'zone-matrix nil t)
             (string= workbench/profile "personal"))
    (setq zone-programs [zone-matrix])
    (when (fboundp 'zone-when-idle)
      (zone-when-idle 300))))

;;; visual.el ends here
