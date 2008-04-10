;;; -*- lisp -*-

(defpackage #:lispbuilder-sdl-mixer-system
  (:use #:cl #:asdf))
(in-package #:lispbuilder-sdl-mixer-system)

(defsystem lispbuilder-sdl-mixer
    :description "lispbuilder-sdl-mixer: SDL_mixer v1.2.8 library wrapper and tools"
    :long-description
    "lispbuilder-sdl-mixer uses CFFI to be highly compatible across lisp 
    implementations. It includes a selection of utilities to assist  
    game programming in Common Lisp."
    :version "0.2"
    :author "Luke Crook <luke@balooga.com>"
    :maintainer "Application Builder <application-builder@lispniks.com>"
    :licence "MIT"
    :depends-on (cffi lispbuilder-sdl-mixer-cffi)
    :components
    ((:module "sdl-mixer"
	      :components
	      ((:file "package")
	       (:file "mixer" :depends-on ("package"))))
     (:module "documentation"
	      :components
	      ((:doc-file "README")
	       (:doc-file "COPYING")
	       (:doc-file "CONTRIBUTORS")))
     (:module "build"
	      :components
	      ((:static-file "sdlmixerswig.i")))))
