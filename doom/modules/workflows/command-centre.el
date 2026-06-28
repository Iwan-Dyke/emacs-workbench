;;; workflows/command-centre.el -*- lexical-binding: t; -*-

;; SVG command centre dashboard replacing the Doom dashboard (work profile only).
;; Shows: Jira tickets, git repo status, recent commits, infrastructure health.
;; ADR 0058.

(require 'svg)

;;; ── Data Collection ────────────────────────────────────────────────────────

(defvar workbench-cc--jira-project "DPT")
(defvar workbench-cc--jira-user "iwan.dyke@dvla.gov.uk")
(defvar workbench-cc--code-root "~/code/")
(defvar workbench-cc--spark-url "http://localhost:8888")

(defun workbench-cc--shell (dir &rest args)
  "Run ARGS in DIR, return trimmed stdout or nil."
  (let ((default-directory (expand-file-name (or dir "~/"))))
    (with-temp-buffer
      (when (zerop (apply #'call-process (car args) nil t nil (cdr args)))
        (string-trim (buffer-string))))))

(defun workbench-cc--shell-lines (dir &rest args)
  "Run ARGS in DIR, return non-empty lines."
  (when-let ((out (apply #'workbench-cc--shell dir args)))
    (and (not (string-empty-p out))
         (split-string out "\n" t))))

(defun workbench-cc--jira-tickets ()
  "Fetch In Progress tickets. Returns list of plists."
  (let ((lines (workbench-cc--shell-lines
                nil "jira" "issue" "list"
                "-p" workbench-cc--jira-project
                "-a" workbench-cc--jira-user
                "-s" "In Progress"
                "--plain" "--no-headers"
                "--columns" "KEY,SUMMARY,TYPE,UPDATED")))
    (mapcar (lambda (line)
              (let ((parts (split-string line "\t+" nil)))
                (list :key (string-trim (or (nth 0 parts) ""))
                      :summary (string-trim (or (nth 1 parts) ""))
                      :type (string-trim (or (nth 2 parts) ""))
                      :updated (string-trim (or (nth 3 parts) "")))))
            (or lines '()))))

(defun workbench-cc--ticket-last-comment-date (key)
  "Get date of last comment on KEY, or nil."
  (when-let ((output (workbench-cc--shell
                      nil "jira" "issue" "view" key "--plain")))
    ;; Pattern: "Author • Date • Latest comment"
    (when (string-match "• \\([A-Z][a-z]+, [0-9]+ [A-Z][a-z]+ [0-9]+\\) •" output)
      (match-string 1 output))))

(defun workbench-cc--ticket-details (key)
  "Get extra details for KEY: last comment snippet and parent."
  (when-let ((output (workbench-cc--shell
                      nil "jira" "issue" "view" key "--comments" "1" "--plain")))
    (let ((parent nil) (comment nil))
      ;; Parent: look for "Parent: KEY" or linked feature
      (when (string-match "Parent:\\s-*\\([A-Z]+-[0-9]+\\)" output)
        (setq parent (match-string 1 output)))
      ;; Last comment body: first non-empty line after "Latest comment"
      (when (string-match "Latest comment[^\n]*\n\\(?:\\s-*\n\\)*\\s-*\\(.+\\)" output)
        (setq comment (string-trim (match-string 1 output))))
      (list :parent parent :comment comment))))

(defun workbench-cc--ticket-commented-today-p (key)
  "Return t if KEY has a comment from today."
  (when-let ((date-str (workbench-cc--ticket-last-comment-date key)))
    (let ((today (format-time-string "%d %b %y")))
      (string-match-p (regexp-quote today) date-str))))

(defun workbench-cc--days-since-update (updated-str)
  "Return days since UPDATED-STR, or nil if unparseable."
  (condition-case nil
      (let* ((time (date-to-time updated-str))
             (diff (time-subtract (current-time) time)))
        (/ (float-time diff) 86400.0))
    (error nil)))

(defun workbench-cc--recent-repos ()
  "Get repos you committed to recently, ordered by last commit date."
  (let* ((dirs (directory-files (expand-file-name workbench-cc--code-root) t "^[^.]" t))
         (git-dirs (seq-filter (lambda (d)
                                 (file-directory-p (expand-file-name ".git" d)))
                               dirs))
         (with-commit (seq-filter #'identity
                        (mapcar (lambda (d)
                                  (when-let ((date (workbench-cc--shell
                                                    d "git" "log" "-1"
                                                    "--author=iwan" "--format=%ct")))
                                    (cons d (string-to-number date))))
                                git-dirs)))
         (sorted (sort with-commit (lambda (a b) (> (cdr a) (cdr b))))))
    (seq-take (mapcar #'car sorted) 5)))

(defun workbench-cc--repo-status (dir)
  "Get git status plist for DIR."
  (let ((branch (workbench-cc--shell dir "git" "branch" "--show-current"))
        (dirty (workbench-cc--shell-lines dir "git" "status" "--porcelain"))
        (ab (workbench-cc--shell dir "git" "rev-list" "--left-right" "--count" "HEAD...@{upstream}"))
        (last-commit (workbench-cc--shell dir "git" "log" "-1" "--author=iwan" "--format=%ar"))
        (last-msg (workbench-cc--shell dir "git" "log" "-1" "--author=iwan" "--format=%s")))
    (let (ahead behind)
      (when (and ab (string-match "\\([0-9]+\\)\t\\([0-9]+\\)" ab))
        (setq ahead (string-to-number (match-string 1 ab))
              behind (string-to-number (match-string 2 ab))))
      (list :name (file-name-nondirectory dir)
            :branch (or branch "(detached)")
            :dirty (length (or dirty '()))
            :ahead (or ahead 0)
            :behind (or behind 0)
            :last-commit (or last-commit "")
            :last-msg (or last-msg "")))))

(defun workbench-cc--recent-commits ()
  "Get your commits from yesterday and today across ~/code/."
  (let ((repos (workbench-cc--recent-repos))
        (commits nil))
    (dolist (dir repos)
      (when-let ((lines (workbench-cc--shell-lines
                         dir "git" "log"
                         "--author=iwan" "--since=yesterday"
                         "--oneline" "--format=%h %s")))
        (dolist (line (seq-take lines 3))
          (push (list :repo (file-name-nondirectory dir) :msg line) commits))))
    (seq-take (nreverse commits) 8)))

(defun workbench-cc--infra-status ()
  "Check infrastructure health."
  (list :colima (not (null (workbench-cc--shell nil "colima" "status")))
        :containers (or (workbench-cc--shell-lines
                         nil "docker" "ps" "--format" "{{.Names}}")
                        '())
        :spark (condition-case nil
                   (eq 0 (call-process "curl" nil nil nil
                                       "-s" "-o" "/dev/null"
                                       "-w" "" "--max-time" "1"
                                       workbench-cc--spark-url))
                 (error nil))))

(defun workbench-cc--jira-done ()
  "Fetch recently Done tickets (last 5)."
  (let ((lines (workbench-cc--shell-lines
                nil "jira" "issue" "list"
                "-p" workbench-cc--jira-project
                "-a" workbench-cc--jira-user
                "-s" "Done"
                "--plain" "--no-headers"
                "--columns" "KEY,SUMMARY")))
    (seq-take
     (mapcar (lambda (line)
               (let ((parts (split-string line "\t+" nil)))
                 (list :key (string-trim (or (nth 0 parts) ""))
                       :summary (string-trim (or (nth 1 parts) "")))))
             (or lines '()))
     3)))

(defun workbench-cc--jira-next ()
  "Fetch Next queue tickets (top 3)."
  (let ((lines (workbench-cc--shell-lines
                nil "jira" "issue" "list"
                "-p" workbench-cc--jira-project
                "-s" "Next"
                "--plain" "--no-headers"
                "--columns" "KEY,SUMMARY,TYPE")))
    (seq-take
     (mapcar (lambda (line)
               (let ((parts (split-string line "\t+" nil)))
                 (list :key (string-trim (or (nth 0 parts) ""))
                       :summary (string-trim (or (nth 1 parts) ""))
                       :type (string-trim (or (nth 2 parts) "")))))
             (or lines '()))
     3)))

(defun workbench-cc--recent-commits ()
  "Get last 5 commits across all repos from the past 3 days, most recent first."
  (let* ((dirs (workbench-cc--recent-repos))
         (all nil))
    (dolist (dir dirs)
      (when-let ((lines (workbench-cc--shell-lines
                         dir "git" "log" "-5"
                         "--author=iwan" "--since=3 days ago"
                         "--format=%ct|%ar|%s")))
        (dolist (line lines)
          (let ((parts (split-string line "|" nil)))
            (push (list :epoch (string-to-number (or (nth 0 parts) "0"))
                        :repo (file-name-nondirectory dir)
                        :time (or (nth 1 parts) "")
                        :msg (or (nth 2 parts) ""))
                  all)))))
    (seq-take (sort all (lambda (a b)
                          (> (plist-get a :epoch) (plist-get b :epoch))))
              5)))

(defun workbench-cc--collect-all ()
  "Collect all dashboard data. Returns plist."
  (let* ((tickets (workbench-cc--jira-tickets))
         (tickets-with-status
          (mapcar (lambda (tkt)
                    (let* ((key (plist-get tkt :key))
                           (details (workbench-cc--ticket-details key))
                           (days (workbench-cc--days-since-update (plist-get tkt :updated))))
                      (append tkt
                              (list :logged-today
                                    (workbench-cc--ticket-commented-today-p key)
                                    :days-stale days
                                    :parent (plist-get details :parent)
                                    :comment (plist-get details :comment)))))
                  tickets)))
    (list :tickets tickets-with-status
          :done (workbench-cc--jira-done)
          :next (workbench-cc--jira-next)
          :repos (mapcar #'workbench-cc--repo-status (workbench-cc--recent-repos))
          :commits (workbench-cc--recent-commits)
          :infra (workbench-cc--infra-status)
          :time (format-time-string "%A %d %B, %H:%M"))))

;;; ── SVG Rendering ──────────────────────────────────────────────────────────

(defvar workbench-cc--buffer-name "*command-centre*")

(defun workbench-cc--theme-colour (face attr)
  "Get colour from FACE's ATTR, falling back to defaults."
  (or (face-attribute face attr nil t) "#ffffff"))

(defun workbench-cc--colours ()
  "Get theme-aware colour palette."
  (list :bg (workbench-cc--theme-colour 'default :background)
        :fg (workbench-cc--theme-colour 'default :foreground)
        :dim (workbench-cc--theme-colour 'shadow :foreground)
        :accent (workbench-cc--theme-colour 'font-lock-keyword-face :foreground)
        :green (workbench-cc--theme-colour 'success :foreground)
        :yellow (workbench-cc--theme-colour 'warning :foreground)
        :red (workbench-cc--theme-colour 'error :foreground)))

(defun workbench-cc--darken (colour amount)
  "Darken COLOUR hex string by AMOUNT (0-1)."
  (if (and colour (string-prefix-p "#" colour))
      (let* ((r (string-to-number (substring colour 1 3) 16))
             (g (string-to-number (substring colour 3 5) 16))
             (b (string-to-number (substring colour 5 7) 16)))
        (format "#%02x%02x%02x"
                (round (* r (- 1 amount)))
                (round (* g (- 1 amount)))
                (round (* b (- 1 amount)))))
    (or colour "#333333")))

(defun workbench-cc--lighten (colour amount)
  "Lighten COLOUR hex string by AMOUNT (0-1)."
  (if (and colour (string-prefix-p "#" colour))
      (let* ((r (string-to-number (substring colour 1 3) 16))
             (g (string-to-number (substring colour 3 5) 16))
             (b (string-to-number (substring colour 5 7) 16)))
        (format "#%02x%02x%02x"
                (min 255 (round (+ r (* (- 255 r) amount))))
                (min 255 (round (+ g (* (- 255 g) amount))))
                (min 255 (round (+ b (* (- 255 b) amount))))))
    (or colour "#444444")))

(defun workbench-cc--arc (svg cx cy r width start-deg end-deg colour)
  "Draw an arc on SVG from START-DEG to END-DEG."
  (let* ((start-rad (* (/ start-deg 180.0) float-pi))
         (end-rad (* (/ end-deg 180.0) float-pi))
         (x1 (+ cx (* r (cos start-rad))))
         (y1 (+ cy (* r (sin start-rad))))
         (x2 (+ cx (* r (cos end-rad))))
         (y2 (+ cy (* r (sin end-rad))))
         (large-arc (if (> (- end-deg start-deg) 180) 1 0))
         (d (format "M %f %f A %d %d 0 %d 1 %f %f"
                    x1 y1 r r large-arc x2 y2)))
    (dom-append-child svg
      (dom-node 'path `((d . ,d)
                        (fill . "none")
                        (stroke . ,colour)
                        (stroke-width . ,(number-to-string width))
                        (stroke-linecap . "round"))))))

(defun workbench-cc--render (data)
  "Render DATA as a visual SVG dashboard."
  (let* ((buf (get-buffer-create workbench-cc--buffer-name))
         (win (or (get-buffer-window buf) (selected-window)))
         (scale (or (and (fboundp 'frame-scale-factor) (frame-scale-factor)) 1))
         (w (round (* (window-pixel-width win) scale)))
         (h (round (* (window-pixel-height win) scale)))
         (colours (workbench-cc--colours))
         (bg (plist-get colours :bg))
         (fg (plist-get colours :fg))
         (dim (plist-get colours :dim))
         (accent (plist-get colours :accent))
         (green (plist-get colours :green))
         (yellow (plist-get colours :yellow))
         (red (plist-get colours :red))
         (svg (svg-create w h))
         (s (lambda (n) (round (* n scale))))
         (pad (funcall s 40))
         (y 0)
         (line-h (funcall s 22))
         (section-gap (funcall s 30))
         (font-lg (funcall s 20))
         (font-md (funcall s 14))
         (font-sm (funcall s 12))
         (font-xs (funcall s 10))
         (half-w (/ w 2)))

    ;; Background
    (svg-rectangle svg 0 0 w h :fill bg)

    ;; ── Header bar ──
    (let* ((bar-h (funcall s 44))
           (hour (string-to-number (format-time-string "%H")))
           (greeting (cond ((< hour 12) "Good morning")
                           ((< hour 17) "Good afternoon")
                           (t "Good evening"))))
      (svg-rectangle svg 0 0 w bar-h :fill (workbench-cc--lighten bg 0.05))
      (svg-text svg (format "%s, Iwan" greeting)
                :x pad :y (funcall s 28) :font-size font-lg :font-weight "bold"
                :fill fg :font-family "monospace")
      (svg-text svg (plist-get data :time)
                :x (- w pad (funcall s 220)) :y (funcall s 28) :font-size font-md
                :fill dim :font-family "monospace")
      (setq y (+ bar-h section-gap)))

    ;; ── WIP Gauge + Jira ──
    (let* ((tickets (plist-get data :tickets))
           (wip-count (length tickets))
           (wip-limit 9)
           (gauge-r (funcall s 42))
           (gauge-cx (+ pad gauge-r (funcall s 10)))
           (gauge-cy (+ y gauge-r))
           (gauge-width (funcall s 10))
           (angle (* 360.0 (/ (min (float wip-count) wip-limit) wip-limit)))
           (gauge-colour (cond ((>= wip-count wip-limit) red)
                               ((>= wip-count (- wip-limit 2)) yellow)
                               (t green))))
      ;; Background ring
      (svg-circle svg gauge-cx gauge-cy gauge-r
                  :fill "none" :stroke (workbench-cc--darken dim 0.6)
                  :stroke-width gauge-width)
      ;; Filled arc
      (when (> wip-count 0)
        (workbench-cc--arc svg gauge-cx gauge-cy gauge-r gauge-width
                           -90 (+ -90 angle) gauge-colour))
      ;; Centre text
      (svg-text svg (format "%d/%d" wip-count wip-limit)
                :x gauge-cx :y (+ gauge-cy (funcall s 6))
                :font-size font-lg :font-weight "bold"
                :fill fg :font-family "monospace" :text-anchor "middle")
      (svg-text svg "WIP"
                :x gauge-cx :y (+ gauge-cy (funcall s 22))
                :font-size font-xs :fill dim :font-family "monospace"
                :text-anchor "middle")

      ;; Tickets list (right of gauge)
      (let ((tx (+ pad (funcall s 120)))
            (ty y))
        (svg-text svg "IN PROGRESS"
                  :x tx :y ty :font-size font-md :font-weight "bold"
                  :fill accent :font-family "monospace")
        (setq ty (+ ty (funcall s 22)))
        (if (null tickets)
            (svg-text svg "No active tickets"
                      :x tx :y ty :font-size font-sm :fill dim :font-family "monospace")
          (dolist (ticket tickets)
            (let* ((key (plist-get ticket :key))
                   (summary (plist-get ticket :summary))
                   (ttype (plist-get ticket :type))
                   (days (plist-get ticket :days-stale))
                   (logged (plist-get ticket :logged-today))
                   (parent (plist-get ticket :parent))
                   (comment (plist-get ticket :comment))
                   (stale (and days (> days 2)))
                   (bar-colour (cond (logged green) (stale red) (t yellow)))
                   (type-short (cond ((string= ttype "Bug") "●")
                                     ((string= ttype "Feature") "◆")
                                     (t "■")))
                   (type-col (cond ((string= ttype "Bug") red)
                                   ((string= ttype "Feature") accent)
                                   (t fg))))
              ;; Coloured sidebar
              (svg-rectangle svg tx (- ty (funcall s 11)) (funcall s 3) (funcall s 32)
                             :fill bar-colour)
              ;; Type indicator + Key + Summary (line 1)
              (svg-text svg type-short
                        :x (+ tx (funcall s 10)) :y ty :font-size font-sm
                        :fill type-col :font-family "monospace")
              (svg-text svg (format "%s  %s" key
                                    (truncate-string-to-width summary
                                      (/ (- w tx (funcall s 140)) (funcall s 8))))
                        :x (+ tx (funcall s 24)) :y ty :font-size font-sm
                        :fill (if stale yellow fg) :font-family "monospace")
              ;; Days badge
              (when days
                (svg-text svg (format "%.0fd" days)
                          :x (- w pad (funcall s 40)) :y ty :font-size font-xs
                          :fill (if stale red dim) :font-family "monospace"))
              ;; Line 2: parent + last comment
              (let ((ty2 (+ ty (funcall s 16))))
                (when parent
                  (svg-text svg (format "↑%s" parent)
                            :x (+ tx (funcall s 24)) :y ty2 :font-size font-xs
                            :fill dim :font-family "monospace"))
                (when comment
                  (svg-text svg (truncate-string-to-width comment
                                  (/ (- w tx (funcall s 180)) (funcall s 7)))
                            :x (+ tx (funcall s (if parent 100 24))) :y ty2 :font-size font-xs
                            :fill dim :font-family "monospace")))
              (setq ty (+ ty (funcall s 42))))))
        (setq y (max (+ gauge-cy gauge-r (funcall s 15)) (+ ty (funcall s 5))))))

    (setq y (+ y section-gap))
    ;; Separator
    (svg-line svg pad y (- w pad) y
              :stroke (workbench-cc--darken dim 0.5) :stroke-width 1)
    (setq y (+ y section-gap))

    ;; ── Next Up + Recently Done (side by side) ──
    (let ((col2-x (+ pad half-w)))
      ;; Next Up (left)
      (svg-text svg "NEXT UP"
                :x pad :y y :font-size font-md :font-weight "bold"
                :fill accent :font-family "monospace")
      ;; Recently Done (right)
      (svg-text svg "RECENTLY DONE"
                :x col2-x :y y :font-size font-md :font-weight "bold"
                :fill accent :font-family "monospace")
      (let ((ny (+ y (funcall s 22)))
            (dy (+ y (funcall s 22))))
        ;; Next tickets
        (let ((next-items (plist-get data :next)))
          (if (null next-items)
              (progn
                (svg-text svg "Queue empty"
                          :x pad :y ny :font-size font-sm :fill dim :font-family "monospace")
                (setq ny (+ ny line-h)))
            (dolist (item next-items)
              (svg-text svg (format "%s  %s" (plist-get item :key)
                                    (truncate-string-to-width (plist-get item :summary)
                                      (/ (- half-w (funcall s 80)) (funcall s 8))))
                        :x pad :y ny :font-size font-sm
                        :fill fg :font-family "monospace")
              (setq ny (+ ny line-h)))))
        ;; Done tickets
        (let ((done-items (plist-get data :done)))
          (if (null done-items)
              (progn
                (svg-text svg "Nothing recent"
                          :x col2-x :y dy :font-size font-sm :fill dim :font-family "monospace")
                (setq dy (+ dy line-h)))
            (dolist (item done-items)
              (svg-text svg (format "%s  %s" (plist-get item :key)
                                    (truncate-string-to-width (plist-get item :summary)
                                      (/ (- half-w (funcall s 80)) (funcall s 8))))
                        :x col2-x :y dy :font-size font-sm
                        :fill green :font-family "monospace")
              (setq dy (+ dy line-h)))))
        (setq y (max ny dy))))

    (setq y (+ y section-gap))
    ;; Separator
    (svg-line svg pad y (- w pad) y
              :stroke (workbench-cc--darken dim 0.5) :stroke-width 1)
    (setq y (+ y section-gap))

    ;; ── Repositories ──
    (svg-text svg "REPOSITORIES"
              :x pad :y y :font-size font-md :font-weight "bold"
              :fill accent :font-family "monospace")
    (setq y (+ y (funcall s 22)))

    (dolist (repo (plist-get data :repos))
      (let* ((name (plist-get repo :name))
             (branch (plist-get repo :branch))
             (dirty (plist-get repo :dirty))
             (ahead (plist-get repo :ahead))
             (behind (plist-get repo :behind))
             (last-commit (plist-get repo :last-commit))
             (last-msg (plist-get repo :last-msg))
             (clean (zerop dirty))
             (col (if clean green yellow)))
        ;; Status block
        (svg-rectangle svg pad (- y (funcall s 10)) (funcall s 6) (funcall s 28)
                       :fill col :rx 1)
        (svg-text svg name
                  :x (+ pad (funcall s 16)) :y y :font-size font-sm
                  :fill fg :font-family "monospace" :font-weight "bold")
        (svg-text svg branch
                  :x (+ pad (funcall s 180)) :y y :font-size font-sm
                  :fill dim :font-family "monospace")
        (svg-text svg (if clean "✓" (format "%d changed" dirty))
                  :x (+ pad (funcall s 330)) :y y :font-size font-xs
                  :fill col :font-family "monospace")
        (when (or (> ahead 0) (> behind 0))
          (svg-text svg (format "%s%s"
                                (if (> ahead 0) (format "↑%d " ahead) "")
                                (if (> behind 0) (format "↓%d" behind) ""))
                    :x (+ pad (funcall s 420)) :y y :font-size font-xs
                    :fill dim :font-family "monospace"))
        (svg-text svg last-commit
                  :x (+ pad (funcall s 490)) :y y :font-size font-xs
                  :fill dim :font-family "monospace")
        ;; Second line: last commit message
        (when (not (string-empty-p last-msg))
          (svg-text svg (truncate-string-to-width last-msg
                          (/ (- w pad (funcall s 60)) (funcall s 7)))
                    :x (+ pad (funcall s 16)) :y (+ y (funcall s 16)) :font-size font-xs
                    :fill dim :font-family "monospace"))
        (setq y (+ y (funcall s 36)))))

    (setq y (+ y section-gap))
    (svg-line svg pad y (- w pad) y
              :stroke (workbench-cc--darken dim 0.5) :stroke-width 1)
    (setq y (+ y section-gap))

    ;; ── Standup — last 5 commits ──
    (svg-text svg "STANDUP"
              :x pad :y y :font-size font-md :font-weight "bold"
              :fill accent :font-family "monospace")
    (setq y (+ y (funcall s 22)))

    (let ((commits (plist-get data :commits)))
      (if (null commits)
          (progn
            (svg-text svg "No recent commits"
                      :x pad :y y :font-size font-sm :fill dim :font-family "monospace")
            (setq y (+ y line-h)))
        (dolist (c commits)
          (svg-text svg (plist-get c :time)
                    :x pad :y y :font-size font-xs
                    :fill dim :font-family "monospace")
          (svg-text svg (plist-get c :repo)
                    :x (+ pad (funcall s 110)) :y y :font-size font-xs
                    :fill accent :font-family "monospace")
          (svg-text svg (truncate-string-to-width (plist-get c :msg)
                          (/ (- w (funcall s 320)) (funcall s 7)))
                    :x (+ pad (funcall s 240)) :y y :font-size font-sm
                    :fill fg :font-family "monospace")
          (setq y (+ y line-h)))))

    (setq y (+ y section-gap))
    (svg-line svg pad y (- w pad) y
              :stroke (workbench-cc--darken dim 0.5) :stroke-width 1)
    (setq y (+ y section-gap))

    ;; ── Infrastructure ──
    (svg-text svg "INFRASTRUCTURE"
              :x pad :y y :font-size font-md :font-weight "bold"
              :fill accent :font-family "monospace")
    (setq y (+ y (funcall s 22)))

    (let* ((infra (plist-get data :infra))
           (containers (plist-get infra :containers))
           (pip-r (funcall s 5))
           (services `(("Colima" . ,(plist-get infra :colima))
                       ("Spark" . ,(plist-get infra :spark))
                       ("Docker" . ,(> (length containers) 0))))
           (indent (funcall s 24)))
      ;; Service pips vertically
      (dolist (svc services)
        (let ((label (car svc))
              (up (cdr svc)))
          (svg-circle svg (+ pad pip-r) y pip-r :fill (if up green red))
          (svg-text svg label
                    :x (+ pad (* pip-r 3)) :y (+ y (funcall s 4))
                    :font-size font-sm :fill fg :font-family "monospace")
          (setq y (+ y line-h))
          ;; Indent containers under Docker
          (when (and (string= label "Docker") containers)
            (dolist (name containers)
              (svg-circle svg (+ pad indent pip-r) y pip-r :fill green)
              (svg-text svg name
                        :x (+ pad indent (* pip-r 3)) :y (+ y (funcall s 4))
                        :font-size font-xs :fill dim :font-family "monospace")
              (setq y (+ y (funcall s 18))))))))

    ;; Insert into buffer
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert-image (svg-image svg :scale (/ 1.0 scale)))
        (goto-char (point-min))))
    buf))

;;; ── Lifecycle ──────────────────────────────────────────────────────────────

(defvar workbench-cc--timer nil "Auto-refresh timer.")
(defvar workbench-cc--data nil "Cached dashboard data.")

(defun workbench-cc-refresh ()
  "Refresh the command centre dashboard."
  (interactive)
  (setq workbench-cc--data (workbench-cc--collect-all))
  (workbench-cc--render workbench-cc--data))

(defun workbench-cc--maybe-refresh (&rest _)
  "Refresh if the command centre buffer is visible."
  (when (get-buffer-window workbench-cc--buffer-name)
    (workbench-cc-refresh)))

(defvar workbench-cc-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map "r" #'workbench-cc-refresh)
    (define-key map "q" #'quit-window)
    map))

(define-derived-mode workbench-cc-mode special-mode "CommandCentre"
  "Mode for the workbench command centre."
  (setq-local cursor-type nil)
  (setq-local buffer-read-only t))

(after! evil
  (evil-define-key 'normal workbench-cc-mode-map
    "r" #'workbench-cc-refresh
    "q" #'quit-window))

(defun workbench-cc-open ()
  "Open the command centre dashboard."
  (interactive)
  (let ((buf (workbench-cc-refresh)))
    (switch-to-buffer buf)
    (workbench-cc-mode)
    (unless workbench-cc--timer
      (setq workbench-cc--timer
            (run-at-time 300 300 #'workbench-cc--maybe-refresh)))))

(defun workbench-cc--startup ()
  "Show command centre on startup (work profile only)."
  (when (string= workbench/profile "work")
    ;; Suppress Doom's dashboard
    (setq +doom-dashboard-functions nil)
    ;; Create the buffer now (data fetch happens here)
    (workbench-cc-refresh)
    ;; Show command centre when a frame connects
    (add-hook 'server-after-make-frame-hook #'workbench-cc--show-on-frame)))

(defun workbench-cc--show-on-frame ()
  "Switch the new frame to the command centre buffer."
  (when-let ((buf (get-buffer workbench-cc--buffer-name)))
    (switch-to-buffer buf)
    (workbench-cc-mode)))

;; Run early so it suppresses doom dashboard before it renders
(add-hook 'doom-init-ui-hook #'workbench-cc--startup -90)

;; Redraw on window resize
(defun workbench-cc--on-resize (&optional _frame)
  "Redraw if command centre is visible."
  (when (and workbench-cc--data
             (get-buffer-window workbench-cc--buffer-name))
    (workbench-cc--render workbench-cc--data)))

(add-hook 'window-size-change-functions #'workbench-cc--on-resize)
