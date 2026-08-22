;;; workflows/org.el -*- lexical-binding: t; -*-

;; Org workflow module (ADR 0065).
;; Provides: org-roam setup, jira.org sync from shared Jira cache,
;; custom agenda views, ADR discovery, capture templates.

(require 'cl-lib)

;;; ── Org Directory ──────────────────────────────────────────────────────────

(setq org-directory "~/org/")

(after! org
  (setq org-agenda-files (list (expand-file-name "jira.org" org-directory)
                               (expand-file-name "inbox.org" org-directory)
                               (expand-file-name "projects/" org-directory)
                               (expand-file-name "weeknotes/" org-directory))))

;;; ── Org-roam ───────────────────────────────────────────────────────────────

(after! org-roam
  (setq org-roam-directory org-directory
        org-roam-db-location (expand-file-name ".org-roam.db" org-directory))
  ;; Ensure the DB is built on first use
  (unless (file-exists-p org-roam-db-location)
    (org-roam-db-sync)))

;;; ── Jira → Org Sync ────────────────────────────────────────────────────────

(defvar workbench-org--jira-file nil
  "Path to the generated jira.org file.")

(defun workbench-org--jira-file ()
  "Return the path to jira.org, ensuring org-directory exists."
  (or workbench-org--jira-file
      (setq workbench-org--jira-file
            (expand-file-name "jira.org" org-directory))))

(defun workbench-org--format-ticket (ticket)
  "Format TICKET plist as an org heading string."
  (let ((key (plist-get ticket :key))
        (summary (plist-get ticket :summary))
        (type (or (plist-get ticket :type) "Story"))
        (updated (or (plist-get ticket :updated) "")))
    (concat "* TODO " key " " summary "\n"
            ":PROPERTIES:\n"
            ":ID: " key "\n"
            ":TYPE: WorkItem\n"
            ":ISSUE_TYPE: " type "\n"
            ":STATUS: In Progress\n"
            ":UPDATED: " updated "\n"
            ":END:\n")))

(defun workbench-org--write-jira-file (tickets)
  "Write TICKETS to jira.org. Only writes if content has changed.
When TICKETS is an error plist, refuses to write to avoid wiping valid content."
  (if (workbench-jira-error-p tickets)
      (progn
        (message "workbench-org: skipping jira.org write — fetch returned an error")
        nil)
    (let* ((file (workbench-org--jira-file))
           (dir (file-name-directory file))
           (content (concat "#+title: Jira — In Progress\n"
                            "#+filetags: :jira:generated:\n\n"
                            (if (null tickets)
                                "No tickets loaded.\n"
                              (mapconcat #'workbench-org--format-ticket tickets "\n"))))
           (existing (when (file-exists-p file)
                       (with-temp-buffer
                         (insert-file-contents file)
                         (buffer-string)))))
      (unless (equal content existing)
        (make-directory dir t)
        (with-temp-file file
          (insert content))))))

(defun workbench-org-sync-jira ()
  "Sync In Progress tickets from the shared Jira cache to jira.org.
When called interactively, ensures the cache is populated first.
When called from the refresh hook, the cache is already fresh."
  (interactive)
  (when (called-interactively-p 'any)
    (workbench-jira-ensure-cache))
  (let ((tickets (workbench-jira-cache-tickets)))
    (workbench-org--write-jira-file tickets)))

;; Hook into the shared Jira refresh so jira.org stays current
(add-hook 'workbench-jira-after-refresh-hook #'workbench-org-sync-jira)

;;; ── Agenda Views ───────────────────────────────────────────────────────────

;; The stale view needs a custom skip function that checks UPDATED property.
;; This is a simple approach — if the UPDATED value is within 14 days, skip it.
(defun workbench-org--stale-skip ()
  "Skip entry if UPDATED property is within 14 days or missing.
Entries with unparseable dates (e.g. relative strings from jira-cli) are NOT
skipped — they appear in the stale view so the user can investigate."
  (let ((updated (org-entry-get nil "UPDATED")))
    (if updated
        (let ((days (workbench-jira-days-since-update updated)))
          (if (and days (< days 14))
              (org-end-of-subtree t)  ; skip: recently updated
            nil))  ; don't skip: genuinely stale OR unparseable (show both)
      (org-end-of-subtree t))))

(after! org
  (setq org-agenda-custom-commands
        '(("d" "Today — In Progress + scheduled"
           ((todo "TODO"
                  ((org-agenda-overriding-header "In Progress (Jira)")
                   (org-agenda-files (list (expand-file-name "jira.org" org-directory)))))
            (agenda ""
                    ((org-agenda-span 'day)
                     (org-agenda-overriding-header "Scheduled Today")))))
          ("w" "Weeknotes" alltodo ""
           ((org-agenda-overriding-header "Weeknotes")
            (org-agenda-files (list (expand-file-name "weeknotes/" org-directory)))))
          ("s" "Stale — no update 14+ days"
           ((todo "TODO"
                  ((org-agenda-overriding-header "Stale Items (14+ days)")
                   (org-agenda-files (list (expand-file-name "jira.org" org-directory)))
                   (org-agenda-skip-function #'workbench-org--stale-skip)))))
          ("i" "Inbox — uncategorised"
           ((alltodo ""
                     ((org-agenda-overriding-header "Inbox")
                      (org-agenda-files (list (expand-file-name "inbox.org" org-directory))))))))))

(defun workbench-org/open-weeknote ()
  "Open the current week's weeknote file."
  (interactive)
  (let* ((week (format-time-string "%Y-W%V"))
         (file (expand-file-name (format "weeknotes/%s.org" week) org-directory)))
    (find-file file)))

;;; ── Capture Templates ──────────────────────────────────────────────────────

(after! org
  (setq org-capture-templates
        '(("n" "Note" entry
           (file+headline "~/org/notes/notes.org" "Notes")
           "* %?\n:PROPERTIES:\n:ID: %(org-id-new)\n:TYPE: Note\n:CREATED: %U\n:END:\n\n"
           :empty-lines 1)
          ("d" "Decision" entry
           (file+headline "~/org/projects/decisions.org" "Decisions")
           "* %?\n:PROPERTIES:\n:ID: %(org-id-new)\n:TYPE: Decision\n:CREATED: %U\n:END:\n\n** Context\n\n** Decision\n\n** Consequences\n\n"
           :empty-lines 1)
          ("m" "Meeting" entry
           (file+headline "~/org/notes/meetings.org" "Meetings")
           "* %? :meeting:\n:PROPERTIES:\n:ID: %(org-id-new)\n:TYPE: Note\n:CREATED: %U\n:END:\n\n** Attendees\n\n** Discussion\n\n** Actions\n\n"
           :empty-lines 1))))

;;; ── ADR Discovery ──────────────────────────────────────────────────────────

(defvar workbench-org-adr-scan-root "~/code/"
  "Root directory to scan for repos containing design_decisions/.")

(defun workbench-org--adr-repos ()
  "Return list of directories under `workbench-org-adr-scan-root' with design_decisions/.
Skips symlinks to prevent traversal into unexpected locations."
  (let ((root (expand-file-name workbench-org-adr-scan-root)))
    (when (file-directory-p root)
      (seq-filter (lambda (d)
                    (and (not (file-symlink-p d))
                         (file-directory-p (expand-file-name "design_decisions" d))))
                  (directory-files root t "^[^.]" t)))))

(defun workbench-org--adr-files (repo-dir)
  "Return markdown ADR files in REPO-DIR/design_decisions/."
  (let ((dd (expand-file-name "design_decisions" repo-dir)))
    (when (file-directory-p dd)
      (directory-files dd t "\\.md$" t))))

(defun workbench-org--adr-title (file)
  "Extract the title from an ADR markdown FILE (first # heading)."
  (with-temp-buffer
    (insert-file-contents file nil 0 500)
    (goto-char (point-min))
    (if (re-search-forward "^#\\s-+\\(.+\\)" nil t)
        (match-string 1)
      (file-name-sans-extension (file-name-nondirectory file)))))

(defun workbench-org--adr-node-id (repo-name filename)
  "Generate a stable node ID from REPO-NAME and FILENAME."
  (format "%s/%s" repo-name (file-name-sans-extension filename)))

(defun workbench-org--adr-node-file (repo-name)
  "Return the org file path for ADR nodes from REPO-NAME."
  (expand-file-name (format "projects/%s-adrs.org" repo-name) org-directory))

(defun workbench-org-discover-adrs ()
  "Scan repos for ADRs and create/update org-roam nodes.
Creates one org file per repo in ~/org/projects/ containing ADR nodes.
Only rewrites files whose content has changed, and only triggers
org-roam-db-sync when at least one file was updated."
  (interactive)
  (let ((repos (workbench-org--adr-repos))
        (total 0)
        (changed 0))
    (dolist (repo repos)
      (let* ((repo-name (file-name-nondirectory repo))
             (adr-files (workbench-org--adr-files repo))
             (org-file (workbench-org--adr-node-file repo-name))
             (entries nil))
        (dolist (adr-file adr-files)
          (let* ((filename (file-name-nondirectory adr-file))
                 (node-id (workbench-org--adr-node-id repo-name filename))
                 (title (workbench-org--adr-title adr-file)))
            (push (concat "* " title "\n"
                          ":PROPERTIES:\n"
                          ":ID: " node-id "\n"
                          ":TYPE: Decision\n"
                          ":SOURCE: " adr-file "\n"
                          ":PROJECT: " repo-name "\n"
                          ":END:\n"
                          "[[file:" adr-file "][Source]]\n")
                  entries)
            (cl-incf total)))
        (when entries
          (make-directory (file-name-directory org-file) t)
          (let ((content (concat "#+title: " repo-name " — ADRs\n"
                                 "#+filetags: :adr:" repo-name ":\n\n"
                                 (mapconcat #'identity (nreverse entries) "\n")))
                (existing (when (file-exists-p org-file)
                            (with-temp-buffer
                              (insert-file-contents org-file)
                              (buffer-string)))))
            (unless (equal content existing)
              (with-temp-file org-file
                (insert content))
              (cl-incf changed))))))
    ;; Only rebuild roam DB if content actually changed
    (when (and (> changed 0) (fboundp 'org-roam-db-sync))
      (org-roam-db-sync))
    (message "ADR discovery: found %d ADRs across %d repos (%d files updated)"
             total (length repos) changed)))

;;; ── Open Agenda ────────────────────────────────────────────────────────────

(defun workbench-org/open-agenda ()
  "Open the org agenda dispatcher."
  (interactive)
  (org-agenda nil "d"))

(defun workbench-org/open-jira-file ()
  "Open jira.org directly."
  (interactive)
  (find-file (workbench-org--jira-file)))

(provide 'workbench-org)
