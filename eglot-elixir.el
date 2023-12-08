;;; eglot-elixir.el --- elixir-mode eglot integration  -*- lexical-binding: t; -*-

;; Copyright (C) 2021 Bart van Nierop

;; Author: Bart van Nierop <mail@bvnierop.nl>
;; Version: 0.1
;; Package-Requires: ((eglot "1.4") (elixir-mode "2.4"))
;; Keywords: languages
;; URL: https://github.com/bvnierop/eglot-elixir

;; This file is not part of GNU Emacs

;; Permission is hereby granted, free of charge, to any person
;; obtaining a copy of this software and associated documentation
;; files (the "Software"), to deal in the Software without
;; restriction, including without limitation the rights to use, copy,
;; modify, merge, publish, distribute, sublicense, and/or sell copies
;; of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:

;; The above copyright notice and this permission notice shall be
;; included in all copies or substantial portions of the Software.

;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
;; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
;; MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
;; NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
;; BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
;; ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
;; CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.

;;; Commentary:

;; Automatically download, install and keep up to date elixir-ls
;; (https://github.com/elixir-lsp/elixir-ls) and set it up for use
;; with eglot.
;;
;; Usage:
;;
;; ;; After eglot is loaded
;; (require 'eglot-elixir)
;;
;; This sets eglot up to use this packages' `eglot-elixir' function as
;; startup function for eglot for the `elixir-mode' major mode. Before
;; launching it will install / update elixir-ls.

;;; Code:

(require 'eglot)
(require 'elixir-mode)

(defgroup eglot-elixir nil
  "LSP support for the Elixir programming language, using elixir-ls."
  :group 'eglot)

(defcustom eglot-elixir-install-dir
  (locate-user-emacs-file "elixir-ls/")
  "Install directory for elixir-ls."
  :group 'eglot-elixir
  :type 'directory)

(defun eglot-elixir--version-file ()
  "Return the full path of the elixir-ls version file."
  (expand-file-name (concat eglot-elixir-install-dir ".version")))

(defun eglot-elixir--server-file ()
  "Return the full path of the elixir-ls server."
  (expand-file-name (concat eglot-elixir-install-dir "language_server.sh")))

(defun eglot-elixir--zip-file ()
  "Return the full path of the elixir-ls server."
  (expand-file-name (concat eglot-elixir-install-dir "elixir-ls.zip")))

(defvar eglot-elixir-github-version nil
  "The latest version number of elixir-ls")

(defun eglot-elixir--fetch-github-version ()
  "Retun the latest version of elixir-ls"
  (or eglot-elixir-github-version
  (with-temp-buffer
    (condition-case err
        (let ((json-object-type 'hash-table)
              (url-mime-accept-string "application/json"))
          (url-insert-file-contents "https://api.github.com/repos/elixir-lsp/elixir-ls/releases/latest")
          (goto-char (point-min))
          (setq eglot-elixir-github-version (gethash "tag_name" (json-read))))
      (file-error
       (warn "elixir-ls version check: %s" (error-message-string err)))))))

(defun eglot-elixir--install (version)
  "Downloads VERSION of elixir-ls and install in `eglot-elixir-install-dir'"

  (let ((url (format "https://github.com/elixir-lsp/elixir-ls/releases/download/%s/elixir-ls-%s.zip"
                     version version))
        (zip (eglot-elixir--zip-file)))
    (make-directory eglot-elixir-install-dir t)
    (url-copy-file url zip t)
    (let ((default-directory eglot-elixir-install-dir))
      (if (zerop (call-process "unzip" nil nil nil "-o" zip))
          (with-temp-file (expand-file-name (concat eglot-elixir-install-dir ".version"))
            (insert version))
        (error "Failed to unzip %s" zip)))))

(defun eglot-elixir--installed-version ()
  "Return the version string of elixir-ls"
  (condition-case err
      (with-temp-buffer
        (insert-file-contents (eglot-elixir--version-file))
        (buffer-string))
    (file-error nil)))

(defun eglot-elixir--up-to-date-p ()
  "Return t if the current installation is up to date."
  (equal (eglot-elixir--fetch-github-version) (eglot-elixir--installed-version)))

(defun eglot-elixir--ensure ()
  "Ensures the latest version of elixir-ls is installed."
  (unless (eglot-elixir--up-to-date-p)
    (eglot-elixir--install (eglot-elixir--fetch-github-version))))

;;;###autoload
(defun eglot-elixir (interactive)
  "Return eglot contact when elixir-lsp is installed. Automagically installs
elixir-lsp when called INTERACTIVE."
  (when interactive
    (eglot-elixir--ensure))
  (if (file-exists-p (eglot-elixir--server-file))
      `(eglot-elixir-ls ,(eglot-elixir--server-file))
    (warn "eglot-elixir: elixir-ls is missing. Execute `M-x eglot` in an Elixir buffer to install it.")))

(defclass eglot-elixir-ls (eglot-lsp-server) ()
  :documentation "lsp server Elixir based on elixir-ls")

(add-to-list 'eglot-server-programs `(elixir-mode . eglot-elixir))

(provide 'eglot-elixir)

;;; eglot-elixir.el ends here
