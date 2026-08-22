;;; packages.el -*- no-byte-compile: t; -*-

;; All packages pinned to known-good commits for supply chain security.
;; To update: change the :pin hash, then run `doom sync'.

(package! treemacs-evil :pin "2ab5a3c89fa0")
(package! org-roam :pin "903bd4ec56d2")
(package! ob-mermaid :pin "30c2da02e3d2")
(package! mermaid-mode :pin "804dbcb1452e")
(package! lin :pin "c16b7d061396")
(package! org-modern :pin "8775389d085a")
(package! pulsar :pin "6d54b123f319")
(package! dimmer :pin "bbab62f01d45")
(package! zone-matrix :recipe (:host github :repo "twitchy-ears/zone-matrix")
  :pin "508e2fa6f1d9")
