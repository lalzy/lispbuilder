;; This file contains some useful functions for using SDL_ttf from Common lisp
;; 2006 (c) Rune Nesheim, see LICENCE.
;; 2007 (c) Luke Crook

(in-package #:lispbuilder-sdl)

(defmethod _draw-string-blended-*_ ((string string) (x integer) (y integer) justify (surface sdl-surface) (font ttf-font) (color color))
  (with-surface (font-surface (_render-string-blended_ string font color nil nil) t)
    (set-surface-* font-surface :x x :y y)
    (blit-surface font-surface surface))
  surface)

(defmethod _render-string-blended_ ((string string) (font ttf-font) (color color) free cache)
  (let ((surf nil))
    (with-foreign-color-copy (col-struct color)
      (setf surf (make-instance 'surface :fp (sdl-ttf-cffi::render-text-blended (fp font) string
                                                                                (if (cffi:foreign-symbol-pointer "TTF_glue_RenderText_Blended")
                                                                                  col-struct
                                                                                  (+ (ash (b color) 16)
                                                                                     (ash (g color) 8)
                                                                                     (r color)))))))
    (when cache
      (setf (cached-surface font) surf))
    surf))


;;; UTF8 wrappers

(defmethod _draw-utf8-blended-*_ ((string string) (x integer) (y integer) justify (surface sdl-surface) (font ttf-font) (color color))
  (with-surface (font-surface (_render-utf8-blended_ string font color nil nil) t)
    (set-surface-* font-surface :x x :y y)
    (blit-surface font-surface surface))
  surface)

(defmethod _render-utf8-blended_ ((string string) (font ttf-font) (color color) free cache)
  (let ((surf nil))
    (with-foreign-color-copy (col-struct color)
      (setf surf (make-instance 'surface :fp (sdl-ttf-cffi::render-utf8-blended (fp font) string
                                                                                (if (cffi:foreign-symbol-pointer "TTF_glue_RenderText_Blended")
                                                                                  col-struct
                                                                                  (+ (ash (b color) 16)
                                                                                     (ash (g color) 8)
                                                                                     (r color)))))))
    (when cache
      (setf (cached-surface font) surf))
    surf))
