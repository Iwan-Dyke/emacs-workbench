;;; workflows/command-centre-svg.el -*- lexical-binding: t; -*-

;; SVG renderer for the IC (individual contributor) command centre view.

(require 'svg)

(defvar workbench-cc--buffer-name)
(defvar workbench-jira-wip-limit)

(declare-function workbench-cc--error-p "command-centre-data")
(declare-function workbench-cc--error-reason "command-centre-data")

;;; ── Theme Helpers ──────────────────────────────────────────────────────────

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

;;; ── SVG Drawing ────────────────────────────────────────────────────────────

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

;;; ── Main SVG Render ────────────────────────────────────────────────────────

(defun workbench-cc--render (data)
  "Render DATA as a visual SVG dashboard."
  (let* ((buf (get-buffer-create workbench-cc--buffer-name))
         (win (or (get-buffer-window buf) (selected-window)))
         (scale (max 1 (or (and (fboundp 'frame-scale-factor) (frame-scale-factor)) 1)))
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
      (svg-text svg (format "%s, %s" greeting
                                    (car (split-string (or user-full-name "User"))))
                :x pad :y (funcall s 28) :font-size font-lg :font-weight "bold"
                :fill fg :font-family "monospace")
      (svg-text svg (plist-get data :time)
                :x (- w pad (funcall s 220)) :y (funcall s 28) :font-size font-md
                :fill dim :font-family "monospace")
      (setq y (+ bar-h section-gap)))

    ;; ── WIP Gauge + Jira ──
    (let* ((tickets-raw (plist-get data :tickets))
           (tickets-error (workbench-cc--error-p tickets-raw))
           (tickets (if tickets-error '() tickets-raw))
           (wip-count (length tickets))
           (wip-limit workbench-jira-wip-limit)
           (gauge-r (funcall s 42))
           (gauge-cx (+ pad gauge-r (funcall s 10)))
           (gauge-cy (+ y gauge-r))
           (gauge-width (funcall s 10))
           (angle (min 359.9 (* 360.0 (/ (min (float wip-count) wip-limit) wip-limit))))
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
            (svg-text svg (if tickets-error
                              (format "⚠ %s" (workbench-cc--error-reason tickets-raw))
                            "No active tickets")
                      :x tx :y ty :font-size font-sm
                      :fill (if tickets-error red dim) :font-family "monospace")
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
                                      (max 1 (/ (- w tx (funcall s 140)) (funcall s 8)))))
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
                                  (max 1 (/ (- w tx (funcall s 180)) (funcall s 7))))
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
        (let* ((next-raw (plist-get data :next))
               (next-err (workbench-cc--error-p next-raw))
               (next-items (if next-err '() next-raw)))
          (if (null next-items)
              (progn
                (svg-text svg (if next-err
                                  (format "⚠ %s" (workbench-cc--error-reason next-raw))
                                "Queue empty")
                          :x pad :y ny :font-size font-sm
                          :fill (if next-err red dim) :font-family "monospace")
                (setq ny (+ ny line-h)))
            (dolist (item next-items)
              (svg-text svg (format "%s  %s" (plist-get item :key)
                                    (truncate-string-to-width (plist-get item :summary)
                                      (max 1 (/ (- half-w (funcall s 80)) (funcall s 8)))))
                        :x pad :y ny :font-size font-sm
                        :fill fg :font-family "monospace")
              (setq ny (+ ny line-h)))))
        ;; Done tickets
        (let* ((done-raw (plist-get data :done))
               (done-err (workbench-cc--error-p done-raw))
               (done-items (if done-err '() done-raw)))
          (if (null done-items)
              (progn
                (svg-text svg (if done-err
                                  (format "⚠ %s" (workbench-cc--error-reason done-raw))
                                "Nothing recent")
                          :x col2-x :y dy :font-size font-sm
                          :fill (if done-err red dim) :font-family "monospace")
                (setq dy (+ dy line-h)))
            (dolist (item done-items)
              (svg-text svg (format "%s  %s" (plist-get item :key)
                                    (truncate-string-to-width (plist-get item :summary)
                                      (max 1 (/ (- half-w (funcall s 80)) (funcall s 8)))))
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
                          (max 1 (/ (- w pad (funcall s 60)) (funcall s 7))))
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
                          (max 1 (/ (- w (funcall s 320)) (funcall s 7))))
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
