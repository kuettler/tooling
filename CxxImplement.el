;;
;; Simple emacs binding for C++ implementation generation script CxxImplement
;;

(require 'sourcepair)

(defun cpp-generate-source ()
  "Generate cpp source stubs out of header file, leave current
implementation in place."
  (interactive)
  (let ((header-file (buffer-file-name)))
	(if (member (concat "." (file-name-extension header-file)) sourcepair-header-extensions)
		(let ((buffer (sourcepair-load)))
		  (if (stringp buffer)
			  nil
			(let ((source-file (buffer-file-name buffer)))
			  (save-some-buffers (not compilation-ask-about-save)
								 compilation-save-buffers-predicate)
			  (shell-command-on-region 1 (+ 1 (buffer-size buffer))
									   (concat "CxxImplement -o - " header-file)
									   buffer t)
			)))
	  (message (concat "Only works on header files"))
	  )))
