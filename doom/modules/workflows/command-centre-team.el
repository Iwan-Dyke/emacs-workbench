;;; workflows/command-centre-team.el -*- lexical-binding: t; -*-

;; Team lead text renderer for the command centre.

(require 'nerd-icons nil t)

(defvar workbench-cc--buffer-name)
(defvar workbench-cc--data)

(declare-function workbench-jira-days-since-update "modules/tools/jira")
(declare-function workbench-jira-error-p "modules/tools/jira")
(declare-function workbench-jira-error-reason "modules/tools/jira")

;;; ── Helpers ────────────────────────────────────────────────────────────────

(defun workbench-cc--icon (fn name &optional face)
  "Call nerd-icons FN with NAME, applying FACE. Returns empty string if unavailable."
  (if (fboundp fn)
      (let ((icon (funcall fn name)))
        (if face (propertize icon 'face face) icon))
    ""))

(defun workbench-cc--tl-separator ()
  "Insert a visual separator line."
  (insert "  " (propertize "────────────────────────────────────────────────────────\n" 'face 'shadow)))

(defun workbench-cc--infra-pip (label up)
  "Return a status pip string for LABEL with UP state."
  (concat (propertize "●" 'face (if up 'success 'error))
          " "
          (propertize label 'face (if up 'default 'shadow))))

(defun workbench-cc--render-fetch-error (reason)
  "Insert an error indicator for a failed Jira fetch with REASON."
  (insert "    "
          (workbench-cc--icon 'nerd-icons-mdicon "nf-md-alert_circle" 'error)
          " "
          (propertize (format "Fetch failed: %s" reason) 'face 'error)
          "\n"))

(defun workbench-cc--valid-ticket-key-p (key)
  "Return non-nil if KEY matches the Jira ticket key format (e.g. DPT-42)."
  (and (stringp key)
       (string-match-p "\\`[A-Z][A-Z0-9]+-[0-9]+\\'" key)))

(defun workbench-cc--open-ticket-at-point ()
  "Open the Jira ticket at point in a browser.
In team-lead (text) view, reads the ticket key from text properties.
In IC (SVG) view, text properties are not available — prompts for the key
from the cached ticket list instead."
  (interactive)
  (if-let ((key (get-text-property (point) 'workbench-cc-ticket-key)))
      (progn
        (unless (workbench-cc--valid-ticket-key-p key)
          (user-error "Invalid ticket key format: %s" key))
        (start-process "jira-open" nil "jira" "open" key)
        (message "Opening %s..." key))
    ;; No text property (IC/SVG view) — offer ticket selection from cached data
    (if (and workbench-cc--data
             (plist-get workbench-cc--data :tickets)
             (not (workbench-jira-error-p (plist-get workbench-cc--data :tickets))))
        (let* ((tickets (plist-get workbench-cc--data :tickets))
               (choices (mapcar (lambda (tkt)
                                  (format "%s  %s"
                                          (plist-get tkt :key)
                                          (plist-get tkt :summary)))
                                tickets))
               (selection (completing-read "Open ticket: " choices nil t))
               (selected-key (car (split-string selection " " t))))
          (unless (workbench-cc--valid-ticket-key-p selected-key)
            (user-error "Invalid ticket key format: %s" selected-key))
          (start-process "jira-open" nil "jira" "open" selected-key)
          (message "Opening %s..." selected-key))
      (user-error "No tickets available. Refresh with R"))))

;;; ── Team Lead Renderer ─────────────────────────────────────────────────────

(defun workbench-cc--render-team-lead (data)
  "Render DATA as a rich text dashboard in the command centre buffer."
  (let* ((buf (get-buffer-create workbench-cc--buffer-name))
         (wip-tickets (plist-get data :wip))
         (next-tickets (plist-get data :next))
         (done-tickets (plist-get data :done))
         (attention (plist-get data :attention))
         (infra (plist-get data :infra))
         (wip-error (workbench-jira-error-p wip-tickets))
         (next-error (workbench-jira-error-p next-tickets))
         (done-error (workbench-jira-error-p done-tickets))
         (wip-count (if wip-error 0 (length wip-tickets)))
         (wip-limit workbench-jira-team-wip-limit)
         (team-label (or workbench-jira-team-name "Team")))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)

        ;; ── Header ──
        (let* ((hour (string-to-number (format-time-string "%H")))
               (greeting (cond ((< hour 12) "Good morning")
                               ((< hour 17) "Good afternoon")
                               (t "Good evening")))
               (name (car (split-string (or user-full-name "User")))))
          (insert "\n")
          (insert "  "
                  (workbench-cc--icon 'nerd-icons-mdicon "nf-md-view_dashboard" 'font-lock-keyword-face)
                  " "
                  (propertize (format "%s, %s" greeting name) 'face '(:weight bold :height 1.3))
                  "\n")
          (insert "  "
                  (propertize (format "Team Lead · %s" team-label) 'face 'shadow)
                  "    "
                  (propertize (plist-get data :time) 'face 'shadow)
                  "\n\n"))

        ;; ── WIP Gauge ──
        (let* ((gauge-width 20)
               (filled (min gauge-width (round (* gauge-width (/ (float wip-count) (max 1 wip-limit))))))
               (empty (max 0 (- gauge-width filled)))
               (gauge-face (cond ((>= wip-count (+ wip-limit 2)) 'error)
                                 ((>= wip-count wip-limit) 'warning)
                                 (t 'success))))
          (insert "  "
                  (workbench-cc--icon 'nerd-icons-mdicon "nf-md-gauge" gauge-face)
                  " WIP "
                  (propertize (format "%d" wip-count) 'face `(:inherit ,gauge-face :weight bold))
                  (propertize (format "/%d " wip-limit) 'face 'shadow)
                  (propertize (make-string filled ?█) 'face gauge-face)
                  (propertize (make-string empty ?░) 'face 'shadow))
          (when (> wip-count wip-limit)
            (insert " " (propertize "⚠ OVER LIMIT" 'face 'error)))
          (insert "\n\n"))

        ;; ── Separator ──
        (workbench-cc--tl-separator)

        ;; ── IN PROGRESS ──
        (insert "  "
                (workbench-cc--icon 'nerd-icons-mdicon "nf-md-lightning_bolt" 'font-lock-keyword-face)
                " "
                (propertize (format "IN PROGRESS (%d)" wip-count) 'face '(:weight bold :height 1.1))
                "\n\n")
        (cond
         (wip-error
          (workbench-cc--render-fetch-error (workbench-jira-error-reason wip-tickets)))
         ((null wip-tickets)
          (insert "    " (propertize "(empty)" 'face 'shadow) "\n"))
         (t
          (dolist (tkt wip-tickets)
            (let* ((key (plist-get tkt :key))
                   (summary (plist-get tkt :summary))
                   (assignee (plist-get tkt :assignee))
                   (days (workbench-jira-days-since-update (plist-get tkt :updated)))
                   (comment (plist-get tkt :comment-snippet))
                   (stale (and days (> days 3)))
                   (very-stale (and days (> days (/ workbench-jira-stale-days 2))))
                   (status-face (cond (very-stale 'error) (stale 'warning) (t 'success))))
              ;; Line 1: status pip + key + summary
              (insert "  "
                      (propertize "●" 'face status-face)
                      " "
                      (workbench-cc--icon 'nerd-icons-mdicon "nf-md-ticket_outline" status-face)
                      " "
                      (propertize key 'face 'font-lock-constant-face
                                  'workbench-cc-ticket-key key
                                  'mouse-face 'highlight)
                      "  "
                      (propertize (or summary "") 'face 'default)
                      "\n")
              ;; Line 2: assignee + days
              (insert "    "
                      (workbench-cc--icon 'nerd-icons-octicon "nf-oct-person" 'shadow)
                      " "
                      (propertize (or assignee "") 'face 'shadow)
                      "  ")
              (when days
                (insert (workbench-cc--icon 'nerd-icons-octicon "nf-oct-clock" 'shadow)
                        " "
                        (propertize (format "%.0fd" days) 'face status-face)))
              (insert "\n")
              ;; Line 3: last comment
              (if comment
                  (insert "    "
                          (workbench-cc--icon 'nerd-icons-octicon "nf-oct-comment" 'shadow)
                          " "
                          (propertize (truncate-string-to-width comment 80) 'face 'shadow)
                          "\n")
                (insert "    "
                        (workbench-cc--icon 'nerd-icons-octicon "nf-oct-comment" 'shadow)
                        " "
                        (propertize "no comment" 'face '(:inherit shadow :slant italic))
                        "\n"))
              (insert "\n")))))

        ;; ── Separator ──
        (workbench-cc--tl-separator)

        ;; ── NEXT ──
        (insert "  "
                (workbench-cc--icon 'nerd-icons-mdicon "nf-md-target" 'font-lock-keyword-face)
                " "
                (propertize (format "NEXT (%d)" (if next-error 0 (length next-tickets))) 'face '(:weight bold :height 1.1))
                "\n\n")
        (cond
         (next-error
          (workbench-cc--render-fetch-error (workbench-jira-error-reason next-tickets)))
         ((null next-tickets)
          (insert "    " (propertize "(empty)" 'face 'shadow) "\n"))
         (t
          (dolist (tkt next-tickets)
            (let ((key (plist-get tkt :key))
                  (summary (plist-get tkt :summary))
                  (assignee (plist-get tkt :assignee)))
              (insert "  "
                      (propertize "○" 'face 'shadow)
                      " "
                      (workbench-cc--icon 'nerd-icons-mdicon "nf-md-ticket_outline" 'shadow)
                      " "
                      (propertize key 'face 'font-lock-constant-face
                                  'workbench-cc-ticket-key key
                                  'mouse-face 'highlight)
                      "  "
                      (propertize (or summary "") 'face 'default)
                      "  "
                      (workbench-cc--icon 'nerd-icons-octicon "nf-oct-person" 'shadow)
                      " "
                      (propertize (or assignee "") 'face 'shadow)
                      "\n")))))
        (insert "\n")

        ;; ── Separator ──
        (workbench-cc--tl-separator)

        ;; ── DONE ──
        (insert "  "
                (workbench-cc--icon 'nerd-icons-mdicon "nf-md-trophy" 'success)
                " "
                (propertize (format "DONE (%d)" (if done-error 0 (length done-tickets))) 'face '(:weight bold :height 1.1))
                "\n\n")
        (cond
         (done-error
          (workbench-cc--render-fetch-error (workbench-jira-error-reason done-tickets)))
         ((null done-tickets)
          (insert "    " (propertize "(empty)" 'face 'shadow) "\n"))
         (t
          (dolist (tkt done-tickets)
            (let ((key (plist-get tkt :key))
                  (summary (plist-get tkt :summary)))
              (insert "  "
                      (propertize "✓" 'face 'success)
                      " "
                      (workbench-cc--icon 'nerd-icons-mdicon "nf-md-rocket_launch" 'success)
                      " "
                      (propertize key 'face '(:inherit success :weight bold)
                                  'workbench-cc-ticket-key key
                                  'mouse-face 'highlight)
                      "  "
                      (propertize (or summary "") 'face 'shadow)
                      "\n")))))
        (insert "\n")

        ;; ── Separator ──
        (workbench-cc--tl-separator)

        ;; ── ATTENTION ──
        (insert "  "
                (workbench-cc--icon 'nerd-icons-mdicon "nf-md-alert" (if attention 'warning 'success))
                " "
                (propertize (format "ATTENTION (%d)" (length attention))
                            'face `(:weight bold :height 1.1
                                    :foreground ,(face-foreground (if attention 'warning 'success) nil t)))
                "\n\n")
        (if (null attention)
            (insert "    "
                    (workbench-cc--icon 'nerd-icons-octicon "nf-oct-check" 'success)
                    " "
                    (propertize "No items need attention" 'face 'success)
                    "\n")
          (dolist (item attention)
            (let* ((days (plist-get item :days))
                   (stale workbench-jira-stale-days)
                   (face (cond ((> days stale) 'error) ((> days (/ stale 2)) 'warning) (t 'shadow)))
                   (icon (cond ((> days stale) (workbench-cc--icon 'nerd-icons-mdicon "nf-md-fire" 'error))
                               ((> days (/ stale 2)) (workbench-cc--icon 'nerd-icons-mdicon "nf-md-alert" 'warning))
                               (t (workbench-cc--icon 'nerd-icons-mdicon "nf-md-eye" 'shadow)))))
              (insert "  "
                      icon
                      " "
                      (propertize (plist-get item :key) 'face `(:inherit ,face :weight bold)
                                  'workbench-cc-ticket-key (plist-get item :key)
                                  'mouse-face 'highlight)
                      "  "
                      (workbench-cc--icon 'nerd-icons-octicon "nf-oct-person" face)
                      " "
                      (propertize (or (plist-get item :assignee) "") 'face 'default)
                      "  "
                      (workbench-cc--icon 'nerd-icons-octicon "nf-oct-clock" face)
                      " "
                      (propertize (format "%.0f days" days) 'face face)
                      "  "
                      (propertize (or (plist-get item :reason) "") 'face 'shadow)
                      "\n"))))
        (insert "\n")

        ;; ── Separator ──
        (workbench-cc--tl-separator)

        ;; ── INFRA ──
        (let ((containers (plist-get infra :containers)))
          (insert "  "
                  (workbench-cc--icon 'nerd-icons-mdicon "nf-md-server" 'shadow)
                  " "
                  (propertize "INFRA" 'face '(:weight bold))
                  "   "
                  (workbench-cc--infra-pip "Colima" (plist-get infra :colima))
                  "   "
                  (workbench-cc--infra-pip "Docker" (> (length containers) 0))
                  (if (> (length containers) 0)
                      (propertize (format " (%d)" (length containers)) 'face 'shadow) "")
                  "   "
                  (workbench-cc--infra-pip "Spark" (plist-get infra :spark))
                  "\n\n"))

        ;; ── Footer ──
        (insert "  "
                (propertize "[r]" 'face 'font-lock-keyword-face) "edraw  "
                (propertize "[R]" 'face 'font-lock-keyword-face) "efetch  "
                (propertize "[RET]" 'face 'font-lock-keyword-face) " open ticket  "
                (propertize "[q]" 'face 'font-lock-keyword-face) "uit"
                "\n")

        (goto-char (point-min))))
    buf))
