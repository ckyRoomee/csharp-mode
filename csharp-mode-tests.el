(require 'ert)
(require 'cl-lib)
(require 'csharp-mode)
(require 'cl)
(require 'package)

;; development only packages, not declared as a package-dependency
(package-initialize)
(add-to-list 'package-archives '("melpa" . "https://stable.melpa.org/packages/"))

;; assess depends on dash 2.12.1, which is no longer available
;; installing dash, resolves 2.13.0, and fixes this broken dependency.
(dolist (p '(dash assess))
  (when (not (package-installed-p p))
    (package-refresh-contents)
    (package-install p)))

;;; test-helper functions

(defmacro assess-face-in-text= (testee &rest assessments)
  (when assessments
    (let* ((text (car assessments))
           (face (cadr assessments))
           (rest (cddr assessments)))
      `(progn
         (require 'assess)
         (should (assess-face-at= ,testee 'csharp-mode ,text ,face))
         (assess-face-in-text= ,testee ,@rest)))))

(defmacro assess-face-in-file= (file-name &rest assessments)
  (let* ((find-file-hook nil) ;; disable vc-mode hooks
         (buffer (find-file-read-only file-name))
         (contents (buffer-substring-no-properties (point-min) (point-max))))
    (kill-buffer buffer)
    `(assess-face-in-text= ,contents ,@assessments)))

;;; actual tests

(ert-deftest activating-mode-doesnt-cause-failure ()
  (with-temp-buffer
    (csharp-mode)
    (should
     (equal 'csharp-mode major-mode))))

(defvar debug-res nil)

(ert-deftest fontification-of-literals-detects-end-of-strings ()
  (assess-face-in-file= "./test-files/fontification-test.cs"
                        "bool1"      'font-lock-type-face
                        "Reference1" 'font-lock-variable-name-face
                        "false"      'font-lock-constant-face
                        "bool2"      'font-lock-type-face
                        "Reference2" 'font-lock-variable-name-face
                        "true"       'font-lock-constant-face
                        ))

(ert-deftest fontification-of-literals-allows-multi-line-strings ()
  (require 'assess)
  (should (assess-face-at=
           "string Literal = \"multi-line\nstring\";"
           'csharp-mode
           ;; should be interpreted as error
           18 'font-lock-warning-face
           ))
  (should (assess-face-at=
           "string Literal = @\"multi-line\nstring\";"
           'csharp-mode
           ;; should not be interpreted as error because of @
           19 'font-lock-string-face
           )))

(ert-deftest fontification-of-compiler-directives ()
  ;; this replaces the manual test of
  ;; test-files/fontification-test-compiler-directives.cs, but file
  ;; has been kept around to assist manual testing/verification.
  (assess-face-in-file= "test-files/fontification-test-compiler-directives.cs"
                        "strReference" 'font-lock-string-face
                        "strVerification" 'font-lock-string-face
                        "singleQuote" 'font-lock-string-face
                        "doubleQuote" 'font-lock-string-face)

  (assess-face-in-text=
   "#region test\nbool bar = true;"
   ;; should not be interpreted as string because of trailing \!
   "bool" 'font-lock-type-face
   "bar"  'font-lock-variable-name-face
   "true" 'font-lock-constant-face
   )
  (should (assess-face-at=
           "#region test'\nx = true;"
           'csharp-mode
           ;; should not be interpreted as string because of trailing \!
           "true" 'font-lock-constant-face
           ))
  (should (assess-face-at=
           "#region test\"\nx = true;"
           'csharp-mode
           ;; should not be interpreted as string because of trailing \!
           "true" 'font-lock-constant-face
           )))

(ert-deftest fontification-of-compiler-directives-after-comments ()
  (assess-face-in-file= "./test-files/fontification-test-compiler-directives-with-comments.cs"
                        "case1" 'font-lock-comment-face
                        "case2" 'font-lock-comment-face))

(ert-deftest fontification-of-method-names ()
  (assess-face-in-file= "./test-files/imenu-method-test.cs"
                        "OpenWebServicesAsync" 'font-lock-function-name-face
                        "ToString"             'font-lock-function-name-face
                        "Equals"               'font-lock-function-name-face
                        "AbstractMethod"       'font-lock-function-name-face
                        "UnsafeCopy"           'font-lock-function-name-face
                        ;; "GenericMethod1"       'font-lock-function-name-face
                        ;; "GenericMethod2"       'font-lock-function-name-face
                        ))

(ert-deftest fontification-of-using-statements ()
  (assess-face-in-file= "./test-files/using-fontification.cs"
                        "using" 'font-lock-keyword-face
                        "Reference" 'font-lock-constant-face
                        "Under_scored" 'font-lock-constant-face
                        "WithNumbers09.Ok" 'font-lock-constant-face
                        ))

(ert-deftest fontification-of-namespace-statements ()
  (assess-face-in-file= "./test-files/namespace-fontification.cs"
                        "namespace" 'font-lock-keyword-face
                        "Reference" 'font-lock-constant-face
                        "Under_scored" 'font-lock-constant-face
                        "WithNumbers09.Ok" 'font-lock-constant-face
                        ))

(defun list-repeat-once (mylist)
  (append mylist mylist))

(ert-deftest build-warnings-and-errors-are-parsed ()
  (dolist (test-case
           `(("./test-files/msbuild-warning.txt" ,csharp-compilation-re-msbuild-warning
              ,(list-repeat-once
                '("Class1.cs"
                  "Folder\\Class1.cs"
                  "Program.cs"
                  "Program.cs")))
             ("./test-files/msbuild-error.txt" ,csharp-compilation-re-msbuild-error
              ,(list-repeat-once
                '("Folder\\Class1.cs")))
             ("./test-files/msbuild-concurrent-warning.txt" ,csharp-compilation-re-msbuild-warning
              ,(list-repeat-once
                '("Program.cs")))
             ("./test-files/msbuild-concurrent-error.txt" ,csharp-compilation-re-msbuild-error
              ,(list-repeat-once
                '("Program.cs")))
             ("./test-files/msbuild-square-brackets.txt" ,csharp-compilation-re-msbuild-error
              ,(list-repeat-once
                '("Properties\\AssemblyInfo.cs"
                  "Program.cs"
                  "Program.cs")))
             ("./test-files/msbuild-square-brackets.txt" ,csharp-compilation-re-msbuild-warning
              ,(list-repeat-once
                '("Program.cs")))
             ("./test-files/xbuild-warning.txt" ,csharp-compilation-re-xbuild-warning
              ,(list-repeat-once
                '("/Users/jesseblack/Dropbox/barfapp/ConsoleApplication1/ClassLibrary1/Class1.cs"
                  "/Users/jesseblack/Dropbox/barfapp/ConsoleApplication1/ClassLibrary1/Folder/Class1.cs"
                  "/Users/jesseblack/Dropbox/barfapp/ConsoleApplication1/ConsoleApplication1/Program.cs"
                  "/Users/jesseblack/Dropbox/barfapp/ConsoleApplication1/ConsoleApplication1/Program.cs"
                  "/Users/jesseblack/Dropbox/barfapp/ConsoleApplication1/ConsoleApplication1/Program.cs")))
             ("./test-files/xbuild-error.txt" ,csharp-compilation-re-xbuild-error
              ,(list-repeat-once
                '("/Users/jesseblack/Dropbox/barfapp/ConsoleApplication1/ClassLibrary1/Folder/Class1.cs")))
             ("./test-files/devenv-error.txt" ,csharp-compilation-re-xbuild-error
              ("c:\\working_chad\\dev_grep\\build_grep_database\\databaseconnection.cpp"
               "c:\\working_chad\\dev_grep\\build_grep_database\\databaseconnection.cpp"
               "c:\\working_chad\\dev_grep\\build_grep_database\\databaseconnection.cpp"))
             ("./test-files/devenv-error.txt" ,csharp-compilation-re-xbuild-warning
              ("c:\\working_chad\\dev_grep\\build_grep_database\\databaseconnection.cpp"))
             ("./test-files/devenv-mixed-error.txt" ,csharp-compilation-re-xbuild-error
              ("C:\\inservice\\SystemTesting\\OperateDeviceProxy\\OperateDevice_Proxy\\Program.cs"
               "C:\\inservice\\SystemTesting\\OperateDeviceProxy\\OperateDevice_Proxy\\Program.cs"
               "C:\\inservice\\SystemTesting\\OperateDeviceProxy\\OperateDevice_Proxy\\Program.cs"
               "c:\\inservice\\systemtesting\\operationsproxy\\operationsproxy.cpp"
               "c:\\inservice\\systemtesting\\operationsproxy\\operationsproxy.cpp"
               "c:\\inservice\\systemtesting\\operationsproxy\\operationsproxy.cpp"))))

    (let* ((file-name (car test-case))
           (regexp    (cadr test-case))
           (matched-file-names (cl-caddr test-case))
           (times     (length matched-file-names))
           (find-file-hook '()) ;; avoid vc-mode file-hooks when opening!
           (buffer (find-file-read-only file-name)))
      ;; (message (concat "Testing compilation-log: " file-name))
      (dotimes (number times)
        (let* ((expected (nth number matched-file-names)))
          ;; (message (concat "- Expecting match: " expected))
          (re-search-forward regexp)
          (should
           (equal expected (match-string 1)))))
      (kill-buffer buffer))))

(defun imenu-get-item (index haystack)
  (let ((result))
    (dolist (item index)
      (when (not result)
        (let ((name (car item))
              (value (cdr item)))
          (if (string-prefix-p haystack name)
              (setq result item)
            (when (listp value)
              (setq result (imenu-get-item value haystack)))))))
    result))

(defmacro def-imenutest (testname filename &rest items)
  `(ert-deftest ,testname ()
     (let* ((find-file-hook nil) ;; avoid vc-mode file-hooks when opening!
            (buffer         (find-file-read-only ,filename))
            (index          (csharp--imenu-create-index-function)))
       (dolist (item ',items)
         (should (imenu-get-item index item)))
       (kill-buffer buffer))))

(def-imenutest imenu-parsing-supports-generic-parameters
  "./test-files/imenu-generics-test.cs" 
  "(method) NoGeneric(" "(method) OneGeneric<T>(" "(method) TwoGeneric<T1,T2>(")

(def-imenutest imenu-parsing-supports-comments
  "./test-files/imenu-comment-test.cs"
  "(method) HasNoComment(" "(method) HasComment(" "(method) CommentedToo(")

(def-imenutest imenu-parsing-supports-explicit-interface-properties
  "./test-files/imenu-interface-property-test.cs"
  "(prop) IImenuTest.InterfaceString")

(def-imenutest imenu-parsing-supports-explicit-interface-methods
  "./test-files/imenu-interface-property-test.cs"
  "(method) IImenuTest.MethodName")

(def-imenutest imenu-parsing-provides-types-with-namespace-names
  "./test-files/imenu-namespace-test.cs"
  "class ImenuTest.ImenuTestClass"
  "interface ImenuTest.ImenuTestInterface"
  "enum ImenuTest.ImenuTestEnum")

(def-imenutest imenu-parsing-supports-fields-keywords
  "./test-files/imenu-field-keyword-test.cs"
  "(field) TestBool"
  "(field) CommentedField"
  "(field) _MultiLineComment"
  "(field) VolatileTest"
  "(field) m_Member")

(def-imenutest imenu-parsing-supports-method-keywords
  "./test-files/imenu-method-test.cs"
  "(method) GetTickCount64("
  "(method) OpenWebServiceAsync("
  "(method) ToString("
  "(method) AbstractMethod("
  "(method) UnsafeCopy("
  "(method) GenericMethod1<T>"
  "(method) GenericMethod2<T1,T2>"
  "(method) NestedGeneric")

(def-imenutest imenu-parsing-supports-delegates
  "./test-files/imenu-delegate-test.cs"
  "delegate PromptCallback"
  "delegate PromptStateCallback"
  "delegate PromptStateCallback<T>"
  "delegate Foobar.TargetCallback"
  "delegate Foobar.TargetStateCallback"
  "delegate Foobar.TargetStateCallback<T>")

(ert-deftest imenu-indexing-resolves-correct-container ()
  (let* ((testcase-no-namespace '( ("class Global" . 10)
                                   (("namespace_a" . 20) ("namespace_b" . 30))
                                   nil))
         (testcase-namespace-a  '( ("class A" . 10)
                                   (("namespace_a" . 0) ("namespace_b" . 30))
                                   "namespace_a"))
         (testcase-namespace-b  '( ("class B" . 40)
                                   (("namespace_a" . 0) ("namespace_b" . 30))
                                   "namespace_b"))
         (testcases             (list testcase-no-namespace
                                      testcase-namespace-a
                                      testcase-namespace-b)))
    (dolist (testcase testcases)
      (let ((class      (car testcase))
            (namespaces (cadr testcase))
            (expected   (caddr testcase)))
        (should (equal expected
                       (csharp--imenu-get-container-name class namespaces)))))))

(ert-deftest imenu-indexing-resolves-correct-name ()
  (let* ((testcase-no-namespace '( ("class Global" . 10)
                                   (("namespace_a" . 20) ("namespace_b" . 30))
                                   "class Global"))
         (testcase-namespace-a  '( ("class A" . 10)
                                   (("namespace_a" . 0) ("namespace_b" . 30))
                                   "class namespace_a.A"))
         (testcase-namespace-b  '( ("class B" . 40)
                                   (("namespace_a" . 0) ("namespace_b" . 30))
                                   "class namespace_b.B"))
         (testcases             (list testcase-no-namespace
                                      testcase-namespace-a
                                      testcase-namespace-b)))
    (dolist (testcase testcases)
      (let ((class      (car testcase))
            (namespaces (cadr testcase))
            (expected   (caddr testcase)))
        (should (equal expected
                       (csharp--imenu-get-class-name class namespaces)))))))

(ert-deftest imenu-transforms-index-correctly ()
  ;; this test-case checks for the following aspects of the transformation:
  ;; 1. hierarchial nesting
  ;; 2. sorting of members
  (should (equalp
           '(("class A" . (("( top )" . 20)
                           ("(method) method_a1" . 30)
                           ("(method) method_a2" . 25)))
             ("class B" . (("( top )" . 0)
                           ("(method) method_b1" . 15)
                           ("(method) method_b2" . 10))))

           (csharp--imenu-transform-index
            '(("class" .  (("class B" . 0)  ("class A" . 20)))
              ("method" . (("method_b2" . 10) ("method_b1" . 15)
                           ("method_a2" . 25) ("method_a1" . 30))))))))

(ert-deftest imenu-transforms-index-correctly-with-namespaces ()
  ;; this test-case checks for the following aspects of the transformation:
  ;; 1. hierarchial nesting
  ;; 2. sorting of members
  (should (equalp
           '(("class ns.A" . (("( top )" . 20)
                           ("(method) method_a1" . 30)
                           ("(method) method_a2" . 25)))
             ("class ns.B" . (("( top )" . 0)
                           ("(method) method_b1" . 15)
                           ("(method) method_b2" . 10))))

           (csharp--imenu-transform-index
            '(("namespace" . (("ns" . 0)))
              ("class" .  (("class B" . 0)  ("class A" . 20)))
              ("method" . (("method_b2" . 10) ("method_b1" . 15)
                           ("method_a2" . 25) ("method_a1" . 30))))))))

(defvar csharp-hook1 nil)
(defvar csharp-hook2 nil)

(ert-deftest activating-mode-triggers-all-hooks ()
  (add-hook 'csharp-mode-hook (lambda () (setq csharp-hook1 t)))
  (add-hook 'prog-mode-hook   (lambda () (setq csharp-hook2 t)))

  (with-temp-buffer
    (csharp-mode)
    (should (equal t (and csharp-hook1
                          csharp-hook2)))))

(defvar c-mode-hook-run nil)
(ert-deftest avoid-runing-c-mode-hook ()
  (add-hook 'c-mode-hook (lambda () (setq c-mode-hook-run t)))

  (with-temp-buffer
    (csharp-mode)
    (should-not c-mode-hook-run)))

(ert-deftest indentation-rules-should-be-as-specified-in-test-doc ()
  (let* ((buffer (find-file "test-files/indentation-tests.cs"))
         (orig-content)
         (indented-content))
    ;; double-ensure mode is active
    (csharp-mode)

    (setq orig-content (buffer-substring-no-properties (point-min) (point-max)))
    (indent-region (point-min) (point-max))
    (setq indented-content (buffer-substring-no-properties (point-min) (point-max)))

    (should (equal orig-content indented-content))))

(ert-deftest region-directive-comment-movement ()
  (find-file "test-files/region-fontification.cs")
  (csharp-mode)
  (goto-char (point-min))
  (search-forward "#region ")
  (forward-word 1)
  (forward-word -1)
  (should (looking-at "fontifies")))

(ert-deftest fontification-of-regions ()
  (require 'assess)
  (require 'm-buffer)
  (find-file "test-files/region-fontification.cs")
  (csharp-mode)
  (let ((buf (current-buffer)))
    ;; look for 'a region comment' - should always be a comment
    (should (assess-face-at= buf 'csharp-mode (lambda (buf) (m-buffer-match buf "a region comment")) 'font-lock-comment-face))
    ;; look for 'string' - should always be a type
    (should (assess-face-at= buf 'csharp-mode (lambda (buf) (m-buffer-match buf "string")) 'font-lock-type-face))))

(ert-deftest activating-mode-doesnt-clobber-global-adaptive-fill-regexp ()
  (let ((before adaptive-fill-regexp))
    (with-temp-buffer
      (csharp-mode))
    (should
     (equal before adaptive-fill-regexp))))

(ert-deftest activating-mode-style-defaults-to-csharp ()
  (let ((c-default-style "defaultc#"))
    (with-temp-buffer
      (csharp-mode)
      (should
       (equal "defaultc#" c-indentation-style))))
  (let ((c-default-style '((csharp-mode . "defaultc#fromlist")
                           (java-mode . "defaultjava"))))
    (with-temp-buffer
      (csharp-mode)
      (should
       (equal "defaultc#fromlist" c-indentation-style))))
  (let (c-default-style)
    (with-temp-buffer
      (csharp-mode)
      (should
       (equal "C#" c-indentation-style)))))

(ert-deftest inside-bracelist-test ()
  (let ((c-default-style "defaultc#"))
    (with-temp-buffer
      (csharp-mode)
      (insert "public class A { public void F() {")
      (call-interactively #'newline))))

;;(ert-run-tests-interactively t)
;; (local-set-key (kbd "<f6>") '(lambda ()
;;                               (interactive)
;;                               (ert-run-tests-interactively t)))
