(in-package :freetype2)

 ;; Face

(defmethod print-object ((object ft-face) stream)
  (print-unreadable-object (object stream :type t :identity nil)
    (format stream "\"~A ~A\" {#x~8,'0X}"
                (ft-face-family-name object)
                (ft-face-style-name object)
                (pointer-address (fw-ptr object)))))

(defun check-font-file (pathname)
  (with-foreign-object (c-open-args 'ft-open-args)
    (with-foreign-string (cpathname (namestring pathname))
      (let ((args (%make-ft-open-args :ptr c-open-args)))
        (setf (ft-open-args-flags args) :pathname
              (ft-open-args-memory-base args) (null-pointer)
              (ft-open-args-memory-size args) 0
              (ft-open-args-pathname args) cpathname
              (ft-open-args-stream args) nil
              (ft-open-args-driver args) nil
              (ft-open-args-num-params args) 0
              (ft-open-args-params args) (null-pointer))
        (ft-open-face *library* c-open-args -1 (null-pointer))))))

(export 'check-font-file)

(defun new-face (pathname &optional (index 0) (library *library*))
  (make-wrapper (face &face ft-face)
    (ft-new-face library (namestring pathname) index &face)
    (ft-done-face (p* &face))))

(export 'new-face)

(defun fixed-face-p (face)
  (not (null (find :fixed-width (ft-face-face-flags face)))))

(export 'fixed-face-p)

(defun set-char-size (face char-width char-height horz-resolution vert-resolution)
  (ft-error (ft-set-char-size face char-width char-height
                              horz-resolution vert-resolution)))

(export 'set-char-size)

(defun set-pixel-sizes (face pixel-width pixel-height)
  (ft-error (ft-set-pixel-sizes face pixel-width pixel-height)))

(export 'set-pixel-sizes)

(defun get-char-index (face char-or-code)
  (etypecase char-or-code
    (character (ft-get-char-index face (char-code char-or-code)))
    (integer (ft-get-char-index face char-or-code))))

(export 'get-char-index)

(defun load-glyph (face glyph-index &optional (load-flags :default))
  (ft-error (ft-load-glyph face glyph-index load-flags)))

(export 'load-glyph)

(defun load-char (face char-or-code &optional (load-flags :default))
  (load-glyph face (get-char-index face char-or-code) load-flags))

(export 'load-char)

(defun set-transform (face matrix delta)
  (let ((ft-matrix (convert-matrix matrix))
        (ft-vector (convert-vector delta)))
    (ft-set-transform face ft-matrix ft-vector)))

(export 'set-transform)

(defun get-kerning (face char1 char2 &optional mode)
  (let ((index1 (get-char-index face char1))
        (index2 (get-char-index face char2)))
    (with-foreign-object (v 'ft-vector)
      (ft-error (ft-get-kerning face index1 index2 (or mode :default) v))
      (let ((kern (freetype2-types::%ft-vector-x v)))
        (if (or mode (fixed-face-p face))
            kern
            (ft-26dot6-to-float kern))))))

(export 'get-kerning)

(defun get-string-kerning (face string &optional mode)
  (let ((kern (make-array (length string) :initial-element 0)))
    (loop for i from 0 below (1- (length string))
          as c1 = (aref string i)
          as c2 = (aref string (1+ i))
          do (setf (aref kern i)
                   (get-kerning face c1 c2 mode)))
    kern))

(export 'get-string-kerning)

(defun get-track-kerning (face point-size degree)
  (with-foreign-object (akerning 'ft-fixed)
    (setf (mem-ref akerning 'ft-fixed) 0)
    (ft-error (ft-get-track-kerning face point-size degree akerning))
    (mem-ref akerning 'ft-fixed)))

(export 'get-track-kerning)

(defun get-glyph-name (face char-or-code)
  (with-foreign-pointer (buffer 64 len)
    (ft-error (ft-get-glyph-name face (get-char-index face char-or-code)
                                 buffer len))
    (foreign-string-to-lisp buffer :max-chars len)))

(export 'get-glyph-name)

(defun get-advance (face char-or-code &optional load-flags)
  (let ((gindex (get-char-index face char-or-code))
        (flags-value (convert-to-foreign load-flags 'ft-load-flags))
        (fast-flag (convert-to-foreign '(:fast-advance-only) 'ft-load-flags))
        (vert-flag (convert-to-foreign '(:vertical-layout) 'ft-load-flags)))
    (with-foreign-object (padvance 'ft-fixed)
      (if (eq :ok (ft-get-advance face gindex (logior flags-value fast-flag) padvance))
          (mem-ref padvance 'ft-fixed)
          (let ((advance (ft-glyphslot-advance (ft-face-glyph face))))
            (load-glyph face gindex load-flags)
            (ft-26dot6-to-float (if (logtest vert-flag flags-value)
                                    (ft-vector-y advance)
                                    (ft-vector-x advance))))))))

(export 'get-advance)

(defun get-string-advances (face string &optional load-flags)
  (let ((advance (make-array (length string) :element-type 'float
                                             :initial-element 0.0)))
    (loop for c across string
          for i from 0
          do (setf (aref advance i)
                   (get-advance face c load-flags)))
    advance))

(export 'get-string-advances)
