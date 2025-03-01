;;; lsp-booster.el --- LSP Booster minor mode  -*- lexical-binding: t -*-
;;
;; Copyright (C) 2024, 2025 Taro Sato
;;
;; Author: Taro Sato <okomestudio@gmail.com>
;; URL: https://github.com/okomestudio/lsp-booster.el
;; Version: 1.1
;; Keywords: utility
;; Package-Requires: ((emacs "30.1") (lsp-mode "9.0.1"))
;;
;;; License:
;;
;; This file is not part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;
;;; Commentary:
;;
;; `lsp-booster' minor mode. See and install the `emacs-lsp-booster'
;; program from https://github.com/blahgeek/emacs-lsp-booster.
;;
;; The purpose of this minor mode is to allow on-fly activation and
;; deactivation of LSP booster.
;;
;;; Code:

(require 'lsp-mode)

(defun lsp-booster--json-parse (fn &rest args)
  "Advise (FN ARGS) to parse bytecode instead of JSON."
  (or
   (when (equal (following-char) ?#)
     (let ((bytecode (read (current-buffer))))
       (when (byte-code-function-p bytecode)
         (funcall bytecode))))
   (apply fn args)))

(defun lsp-booster--final-command (fn cmd &optional test?)
  "Advise FN to prepend `emacs-lsp-booster' to CMD if TEST? is nil."
  (let ((orig-result (funcall fn cmd test?)))
    (if (and (not test?)                              ; for check lsp-server-present?
             (not (file-remote-p default-directory))  ; see lsp-resolve-final-command, it would add extra shell wrapper
             lsp-use-plists
             (not (functionp 'json-rpc-connection))   ; native json-rpc
             (executable-find "emacs-lsp-booster"))
        (progn
          (when-let ((command-from-exec-path (executable-find (car orig-result))))  ; resolve command from exec-path (in case not found in $PATH)
            (setcar orig-result command-from-exec-path))
          (message "Using emacs-lsp-booster for %s!" orig-result)
          (if (version< emacs-version "30")
              (cons "emacs-lsp-booster" orig-result)
            (append '("emacs-lsp-booster" "--disable-bytecode" "--") orig-result)))
      orig-result)))

(defun lsp-booster--workspace-shutdown-all ()
  "Shut down all running LSP servers.
The function returns LSP servers that have been shut down."
  (let ((workspaces (lsp-workspaces)))
    (dolist (workspace workspaces)
      (lsp-workspace-shutdown workspace))
    workspaces))

;;;###autoload
(define-minor-mode lsp-booster-mode
  "Minor mode for de/activating emacs-lsp-booster with language servers.
When called from Lisp, the mode command toggles the mode if the
argument is 'toggle, disables the mode if the argument is a
non-positive integer, and enables the mode otherwise (including
if the argument is omitted or nil or a positive integer)."
  :group 'lsp
  :lighter "lsp-booster-mode"
  (setq lsp-booster--json-parser
        (if (progn (require 'json)
                   (fboundp 'json-parse-buffer))
            #'json-parse-buffer
          #'json-read))

  (let ((workspaces (and (featurep 'lsp-mode)
                         (lsp-booster--workspace-shutdown-all))))
    (cond
     (lsp-booster-mode
      (unless (executable-find "emacs-lsp-booster")
        (setq lsp-booster-mode nil)
        (user-error "`emacs-lsp-booster' is not found"))
      (message "lsp-booster-mode on")

      (if (version< emacs-version "30")
          (advice-add lsp-booster--json-parser :around
                      #'lsp-booster--json-parse))
      (advice-add #'lsp-resolve-final-command :around
                  #'lsp-booster--final-command))
     (t
      (message "lsp-booster-mode off")
      (advice-remove #'lsp-resolve-final-command
                     #'lsp-booster--final-command)
      (if (version< emacs-version "30")
          (advice-remove lsp-booster--json-parser
                         #'lsp-booster--json-parse))))
    (when workspaces
      (lsp-deferred))))

(provide 'lsp-booster)
;;; lsp-booster.el ends here
