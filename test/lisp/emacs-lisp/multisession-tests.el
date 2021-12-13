;;; multisession-tests.el --- Tests for multisession.el  -*- lexical-binding: t; -*-

;; Copyright (C) 2021 Free Software Foundation, Inc.

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;;; Code:

(require 'multisession)
(require 'ert)
(require 'ert-x)
(require 'cl-lib)

(ert-deftest multi-test-simple ()
  (skip-unless (sqlite-available-p))
  (let ((multisession-database-file (make-temp-name "/tmp/multi"))
        (user-init-file "/tmp/foo.el"))
    (unwind-protect
        (progn
          (define-multisession-variable foo 0
            ""
            :synchronized t)
          (should (= (multisession-value foo) 0))
          (cl-incf (multisession-value foo))
          (should (= (multisession-value foo) 1))
          (call-process
           (concat invocation-directory invocation-name)
           nil t nil
           "-Q" "-batch"
           "--eval" (prin1-to-string
                     `(progn
                        (require 'multisession)
                        (let ((multisession-database-file
                               ,multisession-database-file)
                              (user-init-file "/tmp/foo.el"))
                          (define-multisession-variable foo 0
                            ""
                            :synchronized t)
                          (cl-incf (multisession-value foo))))))
          (should (= (multisession-value foo) 2)))
      (when (file-exists-p multisession-database-file)
        (delete-file multisession-database-file)
        (sqlite-close multisession--db)
        (setq multisession--db nil)))))

(ert-deftest multi-test-busy ()
  (skip-unless (sqlite-available-p))
  (let ((multisession-database-file (make-temp-name "/tmp/multi"))
        (user-init-file "/tmp/bar.el")
        proc)
    (unwind-protect
        (progn
          (define-multisession-variable bar 0
            ""
            :synchronized t)
          (should (= (multisession-value bar) 0))
          (cl-incf (multisession-value bar))
          (should (= (multisession-value bar) 1))
          (setq proc
                (start-process
                 "other-emacs"
                 nil
                 (concat invocation-directory invocation-name)
                 "-Q" "-batch"
                 "--eval" (prin1-to-string
                           `(progn
                              (require 'multisession)
                              (let ((multisession-database-file
                                     ,multisession-database-file)
                                    (user-init-file "/tmp/bar.el"))
                                (define-multisession-variable bar 0
                                  "" :synchronized t)
                                (dotimes (i 1000)
                                  (cl-incf (multisession-value bar))))))))
          (while (process-live-p proc)
            (ignore-error 'sqlite-locked-error
              (cl-incf (multisession-value bar)))
            (sleep-for 0.1))
          (message "bar ends up as %s" (multisession-value bar))
          (should (< (multisession-value bar) 1003)))
      (when (file-exists-p multisession-database-file)
        (delete-file multisession-database-file)
        (sqlite-close multisession--db)
        (setq multisession--db nil)))))

;;; multisession-tests.el ends here
