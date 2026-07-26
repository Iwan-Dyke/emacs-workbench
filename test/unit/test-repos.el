;;; test/unit/test-repos.el --- Tests for repos workspace -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

;; Load test helper and source
(require 'test-helper)
(workbench-test-load-module "modules/workflows/repos-data.el")

;;; ── Scanner ────────────────────────────────────────────────────────────────

(ert-deftest repos/scan-finds-git-dirs ()
  "Scanner finds directories containing .git."
  (workbench-test-with-temp-dir root
    (let ((repo1 (expand-file-name "project-a" root))
          (repo2 (expand-file-name "project-b" root))
          (not-repo (expand-file-name "notes" root)))
      (make-directory repo1)
      (make-directory (expand-file-name ".git" repo1))
      (make-directory repo2)
      (make-directory (expand-file-name ".git" repo2))
      (make-directory not-repo)
      (let ((found (workbench-repos--scan-roots (list root))))
        (should (= (length found) 2))
        (should (member (file-truename repo1) (mapcar #'file-truename found)))
        (should (member (file-truename repo2) (mapcar #'file-truename found)))))))

(ert-deftest repos/scan-ignores-nested-git ()
  "Scanner does not descend into repos (no nested .git discovery)."
  (workbench-test-with-temp-dir root
    (let ((repo (expand-file-name "project" root))
          (nested (expand-file-name "project/vendor/dep" root)))
      (make-directory repo)
      (make-directory (expand-file-name ".git" repo))
      (make-directory nested t)
      (make-directory (expand-file-name ".git" nested))
      (let ((found (workbench-repos--scan-roots (list root))))
        (should (= (length found) 1))
        (should (equal (file-truename (car found)) (file-truename repo)))))))

(ert-deftest repos/scan-ignores-standard-dirs ()
  "Scanner skips node_modules, .venv, etc."
  (workbench-test-with-temp-dir root
    (let ((ignored (expand-file-name "node_modules/some-pkg" root)))
      (make-directory ignored t)
      (make-directory (expand-file-name ".git" ignored))
      (let ((found (workbench-repos--scan-roots (list root))))
        (should (= (length found) 0))))))

(ert-deftest repos/scan-handles-missing-root ()
  "Scanner gracefully handles non-existent root directories."
  (let ((found (workbench-repos--scan-roots (list "/nonexistent/path/xyz"))))
    (should (= (length found) 0))))

(ert-deftest repos/scan-multiple-roots ()
  "Scanner merges repos from multiple root directories."
  (workbench-test-with-temp-dir root1
    (workbench-test-with-temp-dir root2
      (let ((repo1 (expand-file-name "a" root1))
            (repo2 (expand-file-name "b" root2)))
        (make-directory repo1)
        (make-directory (expand-file-name ".git" repo1))
        (make-directory repo2)
        (make-directory (expand-file-name ".git" repo2))
        (let ((found (workbench-repos--scan-roots (list root1 root2))))
          (should (= (length found) 2)))))))

;;; ── Status parsing ─────────────────────────────────────────────────────────

(ert-deftest repos/parse-status-clean ()
  "Parses a clean repo status from git output."
  (cl-letf (((symbol-function 'workbench-repos--shell)
             (lambda (_dir &rest args)
               (pcase (car args)
                 ("git" (pcase (cadr args)
                          ("branch" "main")
                          ("status" "")
                          ("rev-list" "0\t0")
                          ("log" "2h ago")
                          ("stash" "")))))))
    (let ((status (workbench-repos--repo-status "/tmp/fake-repo")))
      (should (equal (plist-get status :branch) "main"))
      (should (equal (plist-get status :state) 'clean))
      (should (= (plist-get status :dirty) 0))
      (should (= (plist-get status :ahead) 0))
      (should (= (plist-get status :behind) 0)))))

(ert-deftest repos/parse-status-dirty ()
  "Parses a dirty repo with modified and untracked files."
  (cl-letf (((symbol-function 'workbench-repos--shell)
             (lambda (_dir &rest args)
               (pcase (car args)
                 ("git" (pcase (cadr args)
                          ("branch" "feature/x")
                          ("status" " M file1.py\n?? new.txt\n M file2.py")
                          ("rev-list" "2\t1")
                          ("log" "5m ago")
                          ("stash" "stash@{0}\nstash@{1}")))))))
    (let ((status (workbench-repos--repo-status "/tmp/fake-repo")))
      (should (equal (plist-get status :branch) "feature/x"))
      (should (equal (plist-get status :state) 'dirty))
      (should (= (plist-get status :dirty) 3))
      (should (= (plist-get status :ahead) 2))
      (should (= (plist-get status :behind) 1))
      (should (= (plist-get status :stash) 2)))))

(ert-deftest repos/parse-status-no-remote ()
  "Handles repos with no upstream (rev-list fails)."
  (cl-letf (((symbol-function 'workbench-repos--shell)
             (lambda (_dir &rest args)
               (pcase (car args)
                 ("git" (pcase (cadr args)
                          ("branch" "main")
                          ("status" "")
                          ("rev-list" nil)
                          ("log" "1d ago")
                          ("stash" "")))))))
    (let ((status (workbench-repos--repo-status "/tmp/fake-repo")))
      (should (= (plist-get status :ahead) 0))
      (should (= (plist-get status :behind) 0)))))

(ert-deftest repos/parse-status-detached-head ()
  "Handles detached HEAD (branch is empty)."
  (cl-letf (((symbol-function 'workbench-repos--shell)
             (lambda (_dir &rest args)
               (pcase (car args)
                 ("git" (pcase (cadr args)
                          ("branch" "")
                          ("status" "")
                          ("rev-list" nil)
                          ("log" "3d ago")
                          ("stash" "")))))))
    (let ((status (workbench-repos--repo-status "/tmp/fake-repo")))
      (should (equal (plist-get status :branch) "(detached)")))))

;;; ── Filtering ──────────────────────────────────────────────────────────────

(defvar test-repos--sample-statuses
  (list (list :name "alpha" :state 'clean :dirty 0 :ahead 0 :behind 0 :branch "main")
        (list :name "beta" :state 'dirty :dirty 3 :ahead 0 :behind 0 :branch "dev")
        (list :name "gamma" :state 'clean :dirty 0 :ahead 0 :behind 2 :branch "main")
        (list :name "delta" :state 'dirty :dirty 1 :ahead 1 :behind 0 :branch "feature/x")))

(ert-deftest repos/filter-all ()
  "Filter 'all' returns everything."
  (let ((result (workbench-repos--filter 'all test-repos--sample-statuses)))
    (should (= (length result) 4))))

(ert-deftest repos/filter-dirty ()
  "Filter 'dirty' returns only dirty repos."
  (let ((result (workbench-repos--filter 'dirty test-repos--sample-statuses)))
    (should (= (length result) 2))
    (should (cl-every (lambda (r) (eq (plist-get r :state) 'dirty)) result))))

(ert-deftest repos/filter-behind ()
  "Filter 'behind' returns repos with behind > 0."
  (let ((result (workbench-repos--filter 'behind test-repos--sample-statuses)))
    (should (= (length result) 1))
    (should (equal (plist-get (car result) :name) "gamma"))))

(ert-deftest repos/filter-clean ()
  "Filter 'clean' returns only clean repos."
  (let ((result (workbench-repos--filter 'clean test-repos--sample-statuses)))
    (should (= (length result) 2))
    (should (cl-every (lambda (r) (eq (plist-get r :state) 'clean)) result))))

(ert-deftest repos/filter-ahead ()
  "Filter 'ahead' returns repos with ahead > 0."
  (let ((result (workbench-repos--filter 'ahead test-repos--sample-statuses)))
    (should (= (length result) 1))
    (should (equal (plist-get (car result) :name) "delta"))))

;;; ── Sorting ────────────────────────────────────────────────────────────────

(ert-deftest repos/sort-by-name ()
  "Sort by name is alphabetical."
  (let ((result (workbench-repos--sort 'name test-repos--sample-statuses)))
    (should (equal (mapcar (lambda (r) (plist-get r :name)) result)
                   '("alpha" "beta" "delta" "gamma")))))

(ert-deftest repos/sort-by-status ()
  "Sort by status puts dirty first, then behind, then clean."
  (let ((result (workbench-repos--sort 'status test-repos--sample-statuses)))
    ;; dirty repos first
    (should (eq (plist-get (car result) :state) 'dirty))
    (should (eq (plist-get (cadr result) :state) 'dirty))))

(ert-deftest repos/sort-by-dirty-count ()
  "Sort by dirty count puts highest first."
  (let ((result (workbench-repos--sort 'dirty test-repos--sample-statuses)))
    (should (>= (plist-get (car result) :dirty)
                (plist-get (cadr result) :dirty)))))

;;; ── Search/fuzzy matching ──────────────────────────────────────────────────

(ert-deftest repos/search-matches-substring ()
  "Search filters repos by name substring."
  (let ((result (workbench-repos--search "alph" test-repos--sample-statuses)))
    (should (= (length result) 1))
    (should (equal (plist-get (car result) :name) "alpha"))))

(ert-deftest repos/search-case-insensitive ()
  "Search is case-insensitive."
  (let ((result (workbench-repos--search "BETA" test-repos--sample-statuses)))
    (should (= (length result) 1))))

(ert-deftest repos/search-empty-returns-all ()
  "Empty search returns all repos."
  (let ((result (workbench-repos--search "" test-repos--sample-statuses)))
    (should (= (length result) 4))))

(ert-deftest repos/search-no-match-returns-empty ()
  "Non-matching search returns empty list."
  (let ((result (workbench-repos--search "zzzzz" test-repos--sample-statuses)))
    (should (= (length result) 0))))

;;; ── Fetch/Pull eligibility ─────────────────────────────────────────────────

(ert-deftest repos/pullable-repos ()
  "Only clean repos with behind > 0 are pullable."
  (let ((result (workbench-repos--pullable test-repos--sample-statuses)))
    (should (= (length result) 1))
    (should (equal (plist-get (car result) :name) "gamma"))))

(ert-deftest repos/pullable-excludes-dirty ()
  "Dirty repos are never pullable even if behind."
  (let ((repos (list (list :name "x" :state 'dirty :dirty 1 :ahead 0 :behind 5 :branch "main"))))
    (should (= (length (workbench-repos--pullable repos)) 0))))

;;; ── Scanner edge cases ─────────────────────────────────────────────────────

(ert-deftest repos/scan-skips-symlinks ()
  "Scanner does not follow symlinks to avoid cycles."
  (workbench-test-with-temp-dir root
    (let ((repo (expand-file-name "real-project" root)))
      (make-directory repo)
      (make-directory (expand-file-name ".git" repo))
      ;; Create a symlink pointing back to root (cycle)
      (condition-case nil
          (make-symbolic-link root (expand-file-name "loop" root))
        (file-already-exists nil))
      (let ((found (workbench-repos--scan-roots (list root))))
        (should (= (length found) 1))))))

(ert-deftest repos/scan-deep-nesting ()
  "Scanner finds repos several levels deep."
  (workbench-test-with-temp-dir root
    (let ((deep (expand-file-name "org/team/project" root)))
      (make-directory deep t)
      (make-directory (expand-file-name ".git" deep))
      (let ((found (workbench-repos--scan-roots (list root))))
        (should (= (length found) 1))))))

(ert-deftest repos/scan-empty-root ()
  "Scanner handles empty root directory."
  (workbench-test-with-temp-dir root
    (let ((found (workbench-repos--scan-roots (list root))))
      (should (= (length found) 0)))))

(ert-deftest repos/scan-deduplicates ()
  "Scanner does not return the same repo twice even with overlapping roots."
  (workbench-test-with-temp-dir root
    (let ((repo (expand-file-name "project" root)))
      (make-directory repo)
      (make-directory (expand-file-name ".git" repo))
      ;; Scan the same root twice
      (let ((found (workbench-repos--scan-roots (list root root))))
        (should (= (length found) 1))))))

;;; ── Status edge cases ──────────────────────────────────────────────────────

(ert-deftest repos/parse-status-name-from-path ()
  "Status extracts repo name from the directory path."
  (cl-letf (((symbol-function 'workbench-repos--shell) (lambda (&rest _) nil)))
    (let ((status (workbench-repos--repo-status "/Users/dev/code/my-project")))
      (should (equal (plist-get status :name) "my-project")))))

(ert-deftest repos/parse-status-path-preserved ()
  "Status preserves the full path."
  (cl-letf (((symbol-function 'workbench-repos--shell) (lambda (&rest _) nil)))
    (let ((status (workbench-repos--repo-status "/Users/dev/code/my-project")))
      (should (equal (plist-get status :path) "/Users/dev/code/my-project")))))

(ert-deftest repos/parse-status-all-nil-is-safe ()
  "Status handles all git commands returning nil (broken repo)."
  (cl-letf (((symbol-function 'workbench-repos--shell) (lambda (&rest _) nil)))
    (let ((status (workbench-repos--repo-status "/tmp/broken-repo")))
      (should (equal (plist-get status :branch) "(detached)"))
      (should (equal (plist-get status :state) 'clean))
      (should (= (plist-get status :dirty) 0))
      (should (= (plist-get status :ahead) 0))
      (should (= (plist-get status :behind) 0))
      (should (= (plist-get status :stash) 0))
      (should (equal (plist-get status :last-commit) "")))))

(ert-deftest repos/parse-status-only-untracked ()
  "Repo with only untracked files is dirty."
  (cl-letf (((symbol-function 'workbench-repos--shell)
             (lambda (_dir &rest args)
               (pcase (car args)
                 ("git" (pcase (cadr args)
                          ("branch" "main")
                          ("status" "?? newfile.txt")
                          ("rev-list" "0\t0")
                          ("log" "1h ago")
                          ("stash" nil)))))))
    (let ((status (workbench-repos--repo-status "/tmp/repo")))
      (should (eq (plist-get status :state) 'dirty))
      (should (= (plist-get status :dirty) 1)))))

;;; ── Filter combinations ────────────────────────────────────────────────────

(ert-deftest repos/filter-unknown-returns-all ()
  "Unknown filter type returns all repos unchanged."
  (let ((result (workbench-repos--filter 'nonexistent test-repos--sample-statuses)))
    (should (= (length result) 4))))

(ert-deftest repos/filter-empty-list ()
  "Filtering an empty list returns empty."
  (should (null (workbench-repos--filter 'dirty '()))))

;;; ── Sort stability ─────────────────────────────────────────────────────────

(ert-deftest repos/sort-unknown-returns-copy ()
  "Unknown sort type returns a copy (not nil, not error)."
  (let ((result (workbench-repos--sort 'nonexistent test-repos--sample-statuses)))
    (should (= (length result) 4))))

(ert-deftest repos/sort-single-item ()
  "Sorting a single-item list works."
  (let ((repos (list (list :name "solo" :state 'clean :dirty 0 :ahead 0 :behind 0 :branch "main"))))
    (should (= (length (workbench-repos--sort 'name repos)) 1))))

(ert-deftest repos/sort-does-not-mutate ()
  "Sort returns a new list, doesn't mutate input."
  (let* ((repos (list (list :name "b" :state 'clean :dirty 0 :ahead 0 :behind 0 :branch "main")
                      (list :name "a" :state 'dirty :dirty 1 :ahead 0 :behind 0 :branch "dev")))
         (original-first (plist-get (car repos) :name)))
    (workbench-repos--sort 'name repos)
    (should (equal (plist-get (car repos) :name) original-first))))

;;; ── Search edge cases ──────────────────────────────────────────────────────

(ert-deftest repos/search-nil-query-returns-all ()
  "Nil query returns all repos."
  (let ((result (workbench-repos--search nil test-repos--sample-statuses)))
    (should (= (length result) 4))))

(ert-deftest repos/search-special-regex-chars ()
  "Search with regex special characters doesn't error."
  (let ((result (workbench-repos--search "al.ha" test-repos--sample-statuses)))
    ;; Should not match because . is escaped (not regex wildcard)
    (should (= (length result) 0))))

(ert-deftest repos/search-partial-match ()
  "Matches anywhere in name, not just prefix."
  (let ((result (workbench-repos--search "pha" test-repos--sample-statuses)))
    (should (= (length result) 1))
    (should (equal (plist-get (car result) :name) "alpha"))))

;;; ── Pullable edge cases ────────────────────────────────────────────────────

(ert-deftest repos/pullable-empty-list ()
  "Pullable on empty list returns empty."
  (should (null (workbench-repos--pullable '()))))

(ert-deftest repos/pullable-clean-not-behind ()
  "Clean repos with behind=0 are not pullable."
  (let ((repos (list (list :name "x" :state 'clean :dirty 0 :ahead 0 :behind 0 :branch "main"))))
    (should (null (workbench-repos--pullable repos)))))

;;; ── get-all-statuses ───────────────────────────────────────────────────────

(ert-deftest repos/get-all-statuses-maps-paths ()
  "get-all-statuses calls repo-status for each path."
  (let ((called '()))
    (cl-letf (((symbol-function 'workbench-repos--repo-status)
               (lambda (path)
                 (push path called)
                 (list :name (file-name-nondirectory path) :path path
                       :branch "main" :state 'clean :dirty 0
                       :ahead 0 :behind 0 :stash 0 :last-commit ""))))
      (let ((result (workbench-repos--get-all-statuses '("/a" "/b" "/c"))))
        (should (= (length result) 3))
        (should (= (length called) 3))))))

;;; ── Command logic ──────────────────────────────────────────────────────────

(ert-deftest repos/cycle-filter-wraps ()
  "Cycling filter wraps from last to first."
  (let ((workbench-repos--current-filter 'ahead))
    (cl-letf (((symbol-function 'workbench-repos--redraw) #'ignore))
      (workbench-repos-cycle-filter)
      (should (eq workbench-repos--current-filter 'all)))))

(ert-deftest repos/cycle-filter-advances ()
  "Cycling filter moves to next."
  (let ((workbench-repos--current-filter 'all))
    (cl-letf (((symbol-function 'workbench-repos--redraw) #'ignore))
      (workbench-repos-cycle-filter)
      (should (eq workbench-repos--current-filter 'dirty)))))

(ert-deftest repos/cycle-sort-wraps ()
  "Cycling sort wraps from last to first."
  (let ((workbench-repos--current-sort 'dirty))
    (cl-letf (((symbol-function 'workbench-repos--redraw) #'ignore))
      (workbench-repos-cycle-sort)
      (should (eq workbench-repos--current-sort 'name)))))

(ert-deftest repos/cycle-sort-advances ()
  "Cycling sort moves to next."
  (let ((workbench-repos--current-sort 'name))
    (cl-letf (((symbol-function 'workbench-repos--redraw) #'ignore))
      (workbench-repos-cycle-sort)
      (should (eq workbench-repos--current-sort 'status)))))

(ert-deftest repos/path-at-point-from-vtable ()
  "path-at-point returns :path from vtable-current-object."
  (cl-letf (((symbol-function 'vtable-current-object)
             (lambda () '(:name "test" :path "/code/test" :branch "main"))))
    (should (equal (workbench-repos--path-at-point) "/code/test"))))

(ert-deftest repos/path-at-point-nil-when-no-object ()
  "path-at-point returns nil when not on a vtable row."
  (cl-letf (((symbol-function 'vtable-current-object)
             (lambda () nil)))
    (should (null (workbench-repos--path-at-point)))))

(ert-deftest repos/filtered-view-applies-all-transforms ()
  "filtered-view applies filter, search, and sort in sequence."
  (let ((workbench-repos--statuses test-repos--sample-statuses)
        (workbench-repos--current-filter 'dirty)
        (workbench-repos--current-sort 'name)
        (workbench-repos--current-search ""))
    (let ((result (workbench-repos--filtered-view)))
      (should (= (length result) 2))
      (should (cl-every (lambda (r) (eq (plist-get r :state) 'dirty)) result)))))

(ert-deftest repos/filtered-view-with-search ()
  "filtered-view respects search term."
  (let ((workbench-repos--statuses test-repos--sample-statuses)
        (workbench-repos--current-filter 'all)
        (workbench-repos--current-sort 'name)
        (workbench-repos--current-search "gamma"))
    (let ((result (workbench-repos--filtered-view)))
      (should (= (length result) 1))
      (should (equal (plist-get (car result) :name) "gamma")))))

(provide 'test-repos)
;;; test-repos.el ends here
