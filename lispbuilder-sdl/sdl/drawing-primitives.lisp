;; SDL (Simple Media Layer) library using CFFI for foreign function interfacing...
;; (C)2006 Justin Heyes-Jones <justinhj@gmail.com> and Luke Crook <luke@balooga.com>
;; Thanks to Frank Buss and Surendra Singh
;; see COPYING for license
;; This file contains some useful functions for using SDL from Common lisp
;; using sdl.lisp (the CFFI wrapper)

(in-package #:lispbuilder-sdl)

;; Coefficients for Matrix M
;; For catmull-rom-spline
(defvar *M11*	 0.0)
(defvar *M12*	 1.0)
(defvar *M13*	 0.0)
(defvar *M14*	 0.0)
(defvar *M21*	-0.5)
(defvar *M22*	 0.0)
(defvar *M23*	 0.5)
(defvar *M24*	 0.0)
(defvar *M31*	 1.0)
(defvar *M32*	-2.5)
(defvar *M33*	 2.0)
(defvar *M34*	-0.5)
(defvar *M41*	-0.5)
(defvar *M42*	 1.5)
(defvar *M43*	-1.5)
(defvar *M44*	 0.5)

;; (defun bounds-collision? (bounds1 bounds2)
;;   (let ((collision? nil))
;;     (destructuring-bind (s1-x1 s1-y1 s1-x2 s1-y2)
;; 	(coerce bounds1 'list)
;;       (destructuring-bind (s2-x1 s2-y1 s2-x2 s2-y2)
;; 	  (coerce bounds2 'list)
;; 	(if (and (> s1-x2 s2-x1)
;; 		 (> s1-y2 s2-y1)
;; 		 (< s1-y1 s2-y2)
;; 		 (< s1-x1 s2-x2))
;; 	    (setf collision? t))))
;;     collision?))

(defun generate-bezier (x0 y0 x1 y1 x2 y2 x3 y3 &key (segments 20))
  (let ((gx0 x0) (gy0 y0)
	(gx1 x1) (gy1 y1)
	(gx3 x3) (gy3 y3)
	(point-list nil)
	(du (/ 1.0 segments)))
    (let ((cx (* (- gx1 gx0) 3))
	  (cy (* (- gy1 gy0) 3))
	  (px (* (- x2 gx1) 3))
	  (py (* (- y2 gy1) 3)))
      (let ((bx (- px cx))
	    (by (- py cy))
	    (ax (- gx3 px gx0))
	    (ay (- gy3 py gy0)))
	(push (point :x gx0 :y gy0) point-list)
	(loop for n from 0 below (1- segments)
	   do (let* ((u (* n du))
		     (u^2 (* u u))
		     (u^3 (expt u 3)))
		(push (point :x (+ (* ax u^3)
				   (* bx u^2)
				   (* cx u)
				   gx0)
			     :y (+ (* ay u^3)
				   (* by u^2)
				   (* cy u)
				   gy0))
		      point-list)))
	(push (point :x gx3
		     :y gy3)
	      point-list)))))

(defun catmull-rom-spline (val v0 v1 v2 v3)
  (let ((c1 0) (c2 0) (c3 0) (c4 0))
    (setf c1                 (* *M12* v1)
	  c2 (+ (* *M21* v0)              (* *M23* v2))
	  c3 (+ (* *M31* v0) (* *M32* v1) (* *M33* v2) (* *M34* v3))
	  c4 (+ (* *M41* v0) (* *M42* v1) (* *M43* v2) (* *M44* v3)))
    (+ c1 (* val (+ c2 (* val (+ c3 (* c4 val))))))))

(defun draw-bezier (vertices
		    &key (clipping t) (surface *default-surface*) (color *default-color*) (segments 20) (style :SOLID)
                    (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  (if gfx-loaded-p
    (gfx-draw-bezier vertices :surface surface :color color :segments segments :style style)
    (_draw-bezier_ vertices :clipping clipping :surface surface :color color :segments segments :style style :gfx-loaded-p gfx-loaded-p)))

(defun _draw-bezier_ (vertices
		    &key (clipping t) (surface *default-surface*) (color *default-color*) (segments 20) (style :SOLID)
                    (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  "Draw a bezier curve of [COLOR](#color) to [SURFACE](#surface). The shape of the Bezier curve is defined by several control points.
A control point is a vertex containing an X and Y coordinate pair.

##### Parameters

* `:VERTICES` is a list of control points of [POINT](#point).
* `:STYLE` describes the line style used to draw the curve and may be one of
`:SOLID`, `:DASH`, or `:POINTS`. Use `:SOLID` to draw a single continuous line through the specified waypoints.
Use `:DASH` to draw a line between alternate waypoint pairs. Use `:POINTS` to draw a single pixel at each waypoint.
* `:SEGMENTS` is the number of line segments used to draw the curve.
The default is 20 segments if unspecified. The greater the number of segments,
the smoother the curve.
* `:SURFACE` is the target [SURFACE](#surface).
* `:COLOR` is the line color, of [COLOR](#color) or [COLOR-A](#color-a).
* `:CLIPPING` when left as the default value `T` will ensure that the shape is clipped to the dimensions of `SURFACE`.
SDL will core dump if pixels are drawn outside a surface. It is slower, but safer to leave `CLIPPING` as `T`.

##### Example

    \(DRAW-BEZIER \(LIST \(SDL:POINT :X 60  :Y 40\)
                         \(SDL:POINT :X 160 :Y 10\)
                         \(SDL:POINT :X 170 :Y 150\)
                         \(SDL:POINT :X 60 :Y 150\)\)
                   :style :SOLID\)

##### Packages

* Also supported in _LISPBUILDER-SDL-GFX_
* `:STYLE` is ignored in `LISPBUILDER-SDL-GFX`."
  ;; Create the curve between each successive group of four control points in the list.
  (loop
     for p1 in vertices
     for p2 in (cdr vertices)
     for p3 in (cddr vertices)
     for p4 in (cdddr vertices)
     do (draw-shape (generate-bezier (x p1) (y p1)
				     (x p2) (y p2)
				     (x p3) (y p3)
				     (x p4) (y p4)
				     :segments segments)
		    :clipping clipping :surface surface :color color :style style
                    :gfx-loaded-p gfx-loaded-p)))

(defmacro with-bezier ((&optional (style :SOLID) (segments 20)) &body body)
  "Draw a bezier curve of `\*DEFAULT-COLOR\*` to `\*DEFAULT-SURFACE\*`.
The shape of the Bezier curve is defined by control points.
A control point is a vertex containing an X and Y coordinate pair.

The number of segments `SEGENTS` used to draw the Bezier curve defaults to 10.
The greater the number of segments, the smoother the Bezier curve.

##### Local Methods

A vertex may be added using:
* `ADD-VERTEX` which accepts an `POINT`, or
* `ADD-VERTEX-*` which is the x/y spread version

`ADD-VERTEX` and `ADD-VERTEX-*` are valid only within the scop of `WITH-BEZIER`.

##### Parameters

* `STYLE` is one of `:SOLID`, `:DASH`, or `:POINTS`.
When `STYLE` is `:SOLID`, a single continuous line is drawn through the
specified waypoints.
When `STYLE` is `:DASH`, a line is drawn to alternate waypoint pairs.
When `STYLE` is `:POINTS`, a single point is drawn at each waypoint.
* `SEGMENTS` is the number of segments used to draw the Bezier curve.
Default is 20 segments if unspecified. The greater the number of segments,
the smoother the curve.

##### Example

    \(SDL:WITH-COLOR \(COL \(SDL:COLOR\)\)
       \(WITH-BEZIER \(\)
         \(ADD-VERTEX-* 60  40\)
         \(ADD-VERTEX-* 160 10\)
         \(ADD-VERTEX-* 170 150\)
         \(ADD-VERTEX-* 60  150\)\)\)

##### Packages

* Also supported in _LISPBUILDER-SDL-GFX_"
  (let ((point-list (gensym "point-list-")))
    `(let ((,point-list nil))
       (labels ((add-vertex (point)
		  (setf ,point-list (append ,point-list (list point))))
		(add-vertex-* (x y)
		  (add-vertex (point :x x :y y))))
	 (declare (ignorable #'add-vertex #'add-vertex-*))
	 ,@body)
       (draw-bezier ,point-list :style ,style :segments ,segments))))

(defmacro with-curve ((&optional (style :SOLID) (segments 20)) &body body)
  "Draw a Cattmul-Rom spline of `\*DEFAULT-COLOR\*` to `\*DEFAULT-SURFACE\*`.
The shape of the curve is defined by waypoints.
A waypoint is a vertex containing an X and Y coordinate pair.

##### Local Methods

A vertex may be added using:
* `ADD-VERTEX` which accepts an `SDL:POINT`, or
* `ADD-VERTEX-*` which is the x/y spread version

`ADD-VERTEX` and `ADD-VERTEX-*` are valid only within the scope of `WITH-CURVE`.

##### Parameters

* `STYLE` describes the line style used to draw the curve and may be one of
`:SOLID`, `:DASH`, or `:POINTS`.
Use `:SOLID` to draw a single continuous line through the specified waypoints.
Use `:DASH` to draw a line between alternate waypoint pairs.
Use `:POINTS` to draw a single pixel at each waypoint.
* `SEGMENTS` is the number of segments used to draw the Catmull-Rom spline.
Default is 20 segments if unspecified. The greater the number of segments,
the smoother the spline.

##### Example

    \(SDL:WITH-COLOR \(COL \(SDL:COLOR\)\)
       \(WITH-CURVE \(:SOLID 30\)
         \(ADD-VERTEX-* 60  40\)
         \(ADD-VERTEX-* 160 10\)
         \(ADD-VERTEX-* 170 150\)
         \(ADD-VERTEX-* 60  150\)\)\)

##### Packages

* Also supported in _LISPBUILDER-SDL-GFX_"
  (let ((point-list (gensym "point-list-")))
    `(let ((,point-list nil))
       (labels ((add-vertex (point)
		  (setf ,point-list (append ,point-list (list point))))
		(add-vertex-* (x y)
		  (declare (type fixnum x y))
		  (add-vertex (point :x x :y y))))
	 (declare (ignorable #'add-vertex #'add-vertex-*))
	 ,@body)
       (draw-curve ,point-list :style ,style :segments ,segments))))

(defmacro with-shape ((&optional (style :SOLID)) &body body)
  "Draw a polygon of `\*DEFAULT-COLOR\*` to `\*DEFAULT-SURFACE\*`.

##### Local Methods

A vertex may be added using:
* `ADD-VERTEX` which accepts an `SDL:POINT`, or
* `ADD-VERTEX-*` which is the x/y spread version

ADD-VERTEX and ADD-VERTEX-* are valid only within the scop of WITH-SHAPE.

##### Parameters

* `STYLE` describes the line style used to draw the shape and may be one of
`:SOLID`, `:DASH`, or `:POINTS`.
Use `:SOLID` to draw a single continuous line through the specified waypoints.
Use `:DASH` to draw a line between alternate waypoint pairs.
Use `:POINTS` to draw a single pixel at each waypoint.

##### Example

    \(SDL:WITH-COLOR \(COL \(SDL:COLOR\)\)
       \(WITH-SHAPE \(:POINTS\)
         \(ADD-VERTEX-* 60  40\)
         \(ADD-VERTEX-* 160 10\)
         \(ADD-VERTEX-* 170 150\)
         \(ADD-VERTEX-* 60  150\)\)\)

##### Packages

* Also supported in _LISPBUILDER-SDL-GFX_"
  (let ((point-list (gensym "point-list-")))
    `(let ((,point-list nil))
       (labels ((add-vertex (point)
		  (setf ,point-list (append ,point-list (list point))))
		(add-vertex-* (x y)
		  (declare (type fixnum x y))
		  (add-vertex (point :x x :y y))))
	 (declare (ignorable #'add-vertex #'add-vertex-*))
	 ,@body)
       (draw-shape ,point-list :style ,style))))

(defun generate-curve (p1 p2 p3 p4 segments)
  (let ((step-size 0)
	(points nil))
    (when (or (null segments) (= segments 0))
      (setf segments (distance p2 p3)))
    (setf step-size (coerce (/ 1 segments) 'float))
    (setf points (loop for i from 0.0 below 1.0 by step-size
		    collecting (point :x (catmull-rom-spline i (x p1) (x p2)
							     (x p3) (x p4))
				      :y (catmull-rom-spline i (y p1) (y p2)
							     (y p3) (y p4)))))
    ;; NOTE: There must be a more efficient way to add the first and last points to the point list.
    (push p2 points)
    (nconc points (list p3))))

(defun draw-curve (vertices &key (clipping t) (surface *default-surface*) (color *default-color*)
		   (segments 20) (style :SOLID) (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  "Draw a Cattmul-Rom spline of [COLOR](#color) to [SURFACE](#surface).
The shape of the curve is defined by waypoints.
A waypoint is a vertex containing an X and Y coordinate pair.

##### Parameters

* `VERTICES` is a list of waypoints or vetices for the spline, of [POINT](#point)
* `STYLE` describes the line style used to draw the curve and may be one of
`:SOLID`, `:DASH`, or `:POINTS`.
Use `:SOLID` to draw a single continuous line through the specified waypoints.
Use `:DASH` to draw a line between alternate waypoint pairs.
Use `:POINTS` to draw a single pixel at each waypoint.
* `SEGMENTS` is the number of segments used to draw the Catmull-Rom spline.
Default is 20 segments if unspecified. The greater the number of segments,
the smoother the spline.
* `:SURFACE` is the target [SURFACE](#surface).
* `:COLOR` is the line color, of [COLOR](#color) or [COLOR-A](#color-a).
* `:CLIPPING` when left as the default value `T` will ensure that the shape is clipped to the dimensions of `SURFACE`.
SDL will core dump if pixels are drawn outside a surface. It is slower, but safer to leave `CLIPPING` as `T`.

##### Example

    \(DRAW-CURVE \(LIST \(SDL:POINT :X 60  :Y 40\)
	    	  \(SDL:POINT :X 160 :Y 10\)
		  \(SDL:POINT :X 170 :Y 150\)
		  \(SDL:POINT :X 60  :Y 150\)\)\)

##### Packages

* Also supported in _LISPBUILDER-SDL-GFX_"
  (loop
     for p1 in vertices
     for p2 in (cdr vertices)
     for p3 in (cddr vertices)
     for p4 in (cdddr vertices)
     do (draw-shape (generate-curve p1 p2 p3 p4 segments)
		    :style style :clipping clipping :surface surface :color color :gfx-loaded-p gfx-loaded-p)))

(defun draw-shape (vertices &key (clipping t) (surface *default-surface*) (color *default-color*)
		   (style :SOLID) (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  "Draw a polygon of [COLOR](#color) to [SURFACE](#surface) using `VERTICES`.

##### Parameters

* `VERTICES` is a list of vertices, of `POINT`
* `STYLE` describes the line style used to draw the polygon and may be one of
`:SOLID`, `:DASH`, or `:POINTS`.
Use `:SOLID` to draw a single continuous line through the specified waypoints.
Use `:DASH` to draw a line between alternate waypoint pairs.
Use `:POINTS` to draw a single pixel at each waypoint.
* `:SURFACE` is the target [SURFACE](#surface).
* `:COLOR` is the line color, of [COLOR](#color) or [COLOR-A](#color-a).
* `:CLIPPING` when left as the default value `T` will ensure that the shape is clipped to the dimensions of `SURFACE`.
SDL will core dump if pixels are drawn outside a surface. It is slower, but safer to leave `CLIPPING` as `T`.

##### Example

    \(DRAW-SHAPE \(LIST \(SDL:POINT :X 60  :Y 40\)
		    \(SDL:POINT :X 160 :Y 10\)
		    \(SDL:POINT :X 170 :Y 150\)
   		    \(SDL:POINT :X 60  :Y 150\)\)\)

##### Packages

* Also supported in _LISPBUILDER-SDL-GFX_"
  (unless surface
    (setf surface *default-display*))
  (check-type surface sdl-surface)
  (check-type color color)
  (case style
    (:solid
     (loop
	for p1 in vertices
	for p2 in (cdr vertices)
	do (draw-line p1 p2
		      :clipping clipping
		      :surface surface :color color :gfx-loaded-p gfx-loaded-p)))
    (:dash
     (do* ((p1 vertices (if (cdr p1)
			  (cddr p1)
			  nil))
	   (p2 (cdr p1) (cdr p1)))
	  ((or (null p2)
	       (null p1)))
       (draw-line (first p1) (first p2)
		  :clipping clipping
		  :surface surface :color color :gfx-loaded-p gfx-loaded-p)))
    (:points
     (loop for point in vertices
	do (draw-pixel point
		       :clipping clipping
		       :surface surface
		       :color color)))))

(defun draw-line-* (x0 y0 x1 y1 &key (surface *default-surface*) (color *default-color*) (clipping t) (aa nil)
                       (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  "Draws a line of [COLOR](#color) to [SURFACE](#surface).

##### Parameters

* `X0` `Y0` are the start X/Y coordinates of the line, of `INTEGER`.
* `X1` `Y1` are the end X/Y coordinates of the line, of `INTEGER`.
* `:AA` determines if the line is to be drawn using antialiasing. _NOTE_: Supported only in `LISPBUILDER-SDL-GFX`, otherwise ignored.
* `:SURFACE` is the target [SURFACE](#surface).
* `:COLOR` is the line color, of [COLOR](#color) or [COLOR-A](#color-a).
* `:CLIPPING` when left as the default value `T` will ensure that the shape is clipped to the dimensions of `SURFACE`.
SDL will core dump if pixels are drawn outside a surface. It is slower, but safer to leave `CLIPPING` as `T`.

##### Packages

* Also supported in _LISPBUILDER-SDL-GFX_
* `:AA` ignored in _LISPBUILDER-SDL_"
  (declare (ignorable clipping aa))
  (if gfx-loaded-p
    (gfx-draw-line-* x0 y0
                     x1 y1
                     :color color :surface surface :aa aa)
    (_draw-line-*_ x0 y0
                   x1 y1
                   :clipping clipping :color color :surface surface :aa aa)))

(defun _draw-line-*_ (x0 y0 x1 y1 &key (surface *default-surface*) (color *default-color*) (clipping t) (aa nil))
  (declare (ignorable aa)
           (type fixnum x0 y0 x1 y1))
  (unless surface
    (setf surface *default-display*))
  (check-type surface sdl-surface)
  (check-type color color)
  (cond
   ((eq x0 x1)
    ;; Optimization. If (eq x0 x1) then draw using vline.
    (_draw-vline_ x0 y0 y1 :surface surface :color color :clipping nil))
   ((eq y0 y1)
    ;; Optimization. If (eq y0 y1) then draw using hline.
    (_draw-hline_ x0 x1 y0 :surface surface :color color :clipping nil))
   (t
    (when clipping
      ;; simple clipping, should be improved with Cohen-Sutherland line clipping
      (let ((inside 0)
            (left 1)
            (right 2)
            (bottom 4)
            (top 8)

            (xmax (width surface))
            (ymax (height surface)))

        (flet ((out-code (x y)
                 (let ((code inside))
                   (cond ((< x 0) (setq code (logior left code)))
                         ((< xmax x) (setq code (logior right code))))
                   (cond ((< y 0) (setq code (logior top code)))
                         ((< ymax y) (setq code (logior bottom code))))
                   code)))
          (let ((oc0 (out-code x0 y0))
                (oc1 (out-code x1 y1))
                (accept nil))
            (loop
               (cond ((= 0 (logior oc0 oc1))
                      (progn
                        (format t "accepted~%")
                        (setq accept t)
                        (return)))
                     ((\= 0 (logand oc0 oc1)) (return)))
               (let* (x y
                        (first (\= oc0 0)) 
                        (oco (if first oc0 oc1)))
                 (cond ((\= 0 (logand oco bottom))
                        (setq x (+ x0 (* (- x1 x0) (floor (/ (- ymax y0) (- y1 y0)))))
                              y ymax))
                       ((\= 0 (logand oco top))
                        (setq x (+ x0 (* (- x1 x0) (floor (/ (- y0) (- y1 y0)))))
                              y 0))
                       ((\= 0 (logand oco right))
                        (setq y (+ y0 (* (- y1 y0) (floor (/ (- xmax x0) (- x1 x0)))))
                              x xmax))
                       ((\= 0 (logand oco left))
                        (setq y (+ y0 (* (- y1 y0) (floor (/ (- x0) (- x1 x0)))))
                              x 0)))
                 (if first
                     (setq x0 x y0 y oc0 (out-code x y))
                     (setq x1 x y1 y oc1 (out-code x y)))))
            (unless accept (return-from _draw-line-*_))))))
    (format t "accepted?~%")
    
    ;; draw line with Bresenham algorithm
    (let ((x 0) (y 0) (e 0) (dx 0) (dy 0)
          (color (map-color color surface)))
      (declare (type fixnum x y dx dy)
               (type (unsigned-byte 32) color))
      (when (> x0 x1)
        (rotatef x0 x1)
        (rotatef y0 y1))
      (setf e 0)
      (setf x x0)
      (setf y y0)
      (setf dx (- x1 x0))
      (setf dy (- y1 y0))

      (with-pixel (pix (fp surface))
                  (if (>= dy 0)
                    (if (>= dx dy)
                      (loop for x from x0 to x1 do
                            (write-pixel pix x y color)
                            (if (< (* 2 (+ e dy)) dx)
                              (incf e dy)
                              (progn
                                (incf y)
                                (incf e (- dy dx)))))
                      (loop for y from y0 to y1 do
                            (write-pixel pix x y color)
                            (if (< (* 2 (+ e dx)) dy)
                              (incf e dx)
                              (progn
                                (incf x)
                                (incf e (- dx dy))))))
                    (if (>= dx (- dy))
                      (loop for x from x0 to x1 do
                            (write-pixel pix x y color)
                            (if (> (* 2 (+ e dy)) (- dx))
                              (incf e dy)
                              (progn
                                (decf y)
                                (incf e (+ dy dx)))))
                      (progn
                        (rotatef x0 x1)
                        (rotatef y0 y1)
                        (setf x x0)
                        (setf dx (- x1 x0))
                        (setf dy (- y1 y0))
                        (loop for y from y0 to y1 do
                              (write-pixel pix x y color)
                              (if (> (* 2 (+ e dx)) (- dy))
                                (incf e dx)
                                (progn
                                  (decf x)
                                  (incf e (+ dx dy)))))))))))))

(defun draw-line (p1 p2 &key (surface *default-surface*) (color *default-color*) (clipping t) (aa nil) (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  "See [DRAW-LINE-*](#draw-line-*).

##### Parameters

* `P1` and `P2` are the start and end x/y co-ordinates of the line, of `POINT`.

##### Packages

* Also supported in _LISPBUILDER-SDL-GFX_"
    (check-types point p1 p2)
    (draw-line-* (x p1) (y p1)
                 (x p2) (y p2)
                 :clipping clipping :color color :surface surface :aa aa :gfx-loaded-p gfx-loaded-p))

(defun draw-vline (x y0 y1 &key (surface *default-surface*) (color *default-color*) (clipping nil) (template nil)
                     (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  (declare (ignorable clipping template))
  (if gfx-loaded-p
    (gfx-draw-vline x y0 y1 :surface surface :color color)
    (_draw-vline_ x y0 y1 :surface surface :color color :clipping clipping :template template)))

(defun _draw-vline_ (x y0 y1 &key (surface *default-surface*) (color *default-color*) (clipping nil) (template nil))
  "Draw a vertical line of [COLOR](#color) from `Y0` to `Y1` through `X` onto [SURFACE](#surface).

##### Parameters

* `X` is the horizontal `INTEGER` coordinate that the vertical line must intersect.
* `Y0` and `Y1` are the vertical start and end points of the line, of `INTEGER`.
* `:SURFACE` is the target [SURFACE](#surface).
* `:COLOR` is the line color, of [COLOR](#color) or [COLOR-A](#color-a).
* `:CLIPPING` is `NIL` The default is `NIL` as the SDL library will perform the necessary clipping automatically.
* `:TEMPLATE` specifies an optional [RECTANGLE](#rectangle) to fill the surface. Will not free `TEMPLATE`.

##### Packages

* Also supported in _LISPBUILDER-SDL-GFX_"
  (declare (type fixnum x y0 y1))
  (unless surface
    (setf surface *default-display*))
  (check-type surface sdl-surface)
  (check-type color color)
  (when (> y0 y1)
    (rotatef y0 y1))
  (if template
      (sdl-base::fill-surface (fp surface)
			      (map-color-* (r color) (g color) (b color) (a color) surface)
			      :template (sdl-base::rectangle-from-edges-* x y0 x y1 (fp template))
			      :clipping clipping
			      :update nil)
      (sdl-base::with-rectangle (template)
	(sdl-base::fill-surface (fp surface)
				(map-color-* (r color) (g color) (b color) (a color) surface)
				:template (sdl-base::rectangle-from-edges-* x y0 x y1 template)
				:clipping clipping
				:update nil))))

(defun draw-hline (x0 x1 y &key (surface *default-surface*) (color *default-color*) (clipping nil) (template nil)
                      (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  (declare (ignorable clipping template))
  (if gfx-loaded-p
    (gfx-draw-hline x0 x1 y :surface surface :color color)
    (_draw-hline_ x0 x1 y :surface surface :color color :clipping clipping :template template)))

(defun _draw-hline_ (x0 x1 y &key (surface *default-surface*) (color *default-color*) (clipping nil) (template nil))
  "Draw a horizontal line of [COLOR](#color) from `X0` to `X1` through `Y` onto onto [SURFACE](#surface).

##### Parameters

* `X0` and `X1` are the horizontal start and end points of the line, of type `INTEGER`.
* `Y` is the vertical `INTEGER` coordinate that the horizontal line must intersect.
* `:SURFACE` is the target [SURFACE](#surface).
* `:COLOR` is the line color, of [COLOR](#color) or [COLOR-A](#color-a).
* `:CLIPPING` is `NIL` The default is `NIL` as the SDL library will perform the necessary clipping automatically.
* `:TEMPLATE` specifies an optional [RECTANGLE](#rectangle) to fill the surface. Will not free `TEMPLATE`.

##### Packages

* Also supported in _LISPBUILDER-SDL-GFX_"
  (declare (type fixnum x0 x1 y))
  (unless surface
    (setf surface *default-display*))
  (check-type surface sdl-surface)
  (check-type color color)
  (when (> x0 x1)
    (rotatef x0 x1))
  (if template
      (sdl-base::fill-surface (fp surface)
			      (map-color-* (r color) (g color) (b color) (a color) surface)
			      :template (sdl-base::rectangle-from-edges-* x0 y x1 y (fp template))
			      :clipping clipping
			      :update nil)
      (sdl-base::with-rectangle (template)
	(sdl-base::fill-surface (fp surface)
				(map-color-* (r color) (g color) (b color) (a color) surface)
				:template (sdl-base::rectangle-from-edges-* x0 y x1 y template)
				:clipping clipping
				:update nil))))

(defun draw-box (rect &key
		 (clipping nil) (surface *default-surface*)
		 (color *default-color*) (stroke-color nil) (alpha nil))
  "See [DRAW-BOX-*](#draw-box-*).

##### Parameters
* `RECT` is [RECTANGLE](#rectangle).

##### Packages

* Also supported in _LISPBUILDER-SDL-GFX_"
  (unless surface
    (setf surface *default-display*))
  (check-type surface sdl-surface)
  (check-type color color)
  (when stroke-color
    (check-type stroke-color color))
  (check-type rect rectangle)
  (let* ((width  (width rect))
	 (height (height rect))
	 (x (x rect))
	 (y (y rect))
	 (surf (if alpha (create-surface width height :alpha alpha :pixel-alpha (a color)) surface)))
    (fill-surface color :surface surf :template (if alpha nil rect) :clipping clipping)
    (when stroke-color
      (draw-rectangle-* (if alpha 0 x) (if alpha 0 y) width height
			:surface surf :clipping clipping :color stroke-color :alpha nil))
    (when alpha
      (draw-surface-at-* surf x y :surface surface)
      (free surf)))
  rect)

(defun draw-box-* (x y w h &key (clipping nil) (surface *default-surface*) (color *default-color*) (stroke-color nil) (alpha nil) (gfx-loaded-p *gfx-loaded-p*))
  "Draws a filled rectangle of [COLOR](#color) to [SURFACE](#surface).

##### Parameters

* `X` and `Y` are the `INTEGER` coordinates of the top-left corner of the rectangle.
* `W` and `H` are the width and height of the rectangle, of type `INTEGER`.
* `:SURFACE` is the target [SURFACE](#surface).
* `:COLOR` is the line color, of [COLOR](#color) or [COLOR-A](#color-a).
* `:STROKE-COLOR` when not `NIL` will draw a `1` pixel line of color `COLOR` around the perimiter of the box.
* `:ALPHA` when between `0` and `255` is used as the alpha transparency value when blitting the rectangle onto `SURFACE`.
*Note:* An intermediate surface is created, the rectangle is drawn onto this intermediate surface and then this surface
is blitted to `SURFACE`.
* `:CLIPPING` is `NIL` The default is `NIL` as the SDL library will perform the necessary clipping automatically.


##### Packages

* Also supported in _LISPBUILDER-SDL-GFX_"
  (if gfx-loaded-p
    (draw-box-edges-* x y (+ x w) (+ y h) :surface surface :color color)
    (with-rectangle (template (rectangle :x x :y y :w w :h h))
      (draw-box template :clipping clipping :surface surface :color color
                :stroke-color stroke-color :alpha alpha))))

(defun draw-box-edges-* (x0 y0 x1 y1
                            &key (clipping nil) (surface *default-surface*) (color *default-color*) (stroke-color nil) (alpha nil)
                            (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  (declare (ignorable clipping alpha stroke-color))
  (if (and gfx-loaded-p (not stroke-color))
    (gfx-draw-box-edges-* x0 y0 x1 y1 :surface surface :color color)
    (_draw-box-edges-*_ x0 y0 x1 y1 :surface surface :color color :clipping clipping :stroke-color stroke-color :alpha alpha)))

(defun _draw-box-edges-*_ (x1 y1 x2 y2 &key (clipping nil) (surface *default-surface*) (color *default-color*) (stroke-color nil) (alpha nil))
  "Draws a filled rectangle of [COLOR](#color) to [SURFACE](#surface).

##### Parameters

* `X0` and `Y0` are the `INTEGER` coordinates of the top-left corner of the rectangle.
* `X1` and `Y1` are the `INTEGER` coordinates of the bottom-right corner of the rectangle.
* `:SURFACE` is the target [SURFACE](#surface).
* `:COLOR` is the line color, of [COLOR](#color) or [COLOR-A](#color-a).
* `:STROKE-COLOR` when not `NIL` will draw a `1` pixel line of color `COLOR` around the perimiter of the box.
* `:ALPHA` when between `0` and `255` is used as the alpha transparency value when blitting the rectangle onto `SURFACE`.
*Note:* An intermediate surface is created, the rectangle is drawn onto this intermediate surface and then this surface
is blitted to `SURFACE`.
* `:CLIPPING` is `NIL` The default is `NIL` as the SDL library will perform the necessary clipping automatically.

##### Packages

* Also supported in _LISPBUILDER-SDL-GFX_"
  (with-rectangle (template (rectangle-from-edges-* x1 y1 x2 y2))
    (draw-box template :clipping clipping :surface surface :color color
	      :stroke-color stroke-color :alpha alpha)))

(defun draw-rectangle (rect &key (clipping nil) (surface *default-surface*) (color *default-color*) (alpha nil))
  "See [DRAW-RECTANGLE-*](#draw-rectangle-*).

##### Parameters

* `RECT` is [RECTANGLE](#rectangle).

##### Packages

* Also supported in _LISPBUILDER-SDL-GFX_"
  (check-type rect rectangle)
  (draw-rectangle-* (x rect) (y rect)
		    (width rect) (height rect)
		    :clipping clipping :surface surface :color color :alpha alpha)
  surface)

(defun draw-rectangle-* (x y w h &key (clipping nil) (surface *default-surface*) (color *default-color*) (alpha nil))
  "Draw a rectangle outline of [COLOR](#color) to [SURFACE](#surface).

##### Parameters

* `X` and `Y` are the `INTEGER` coordinates of the top-left corner of the rectangle.
* `W` and `H` are the width and height of the rectangle, of type `INTEGER`.
* `:SURFACE` is the target [SURFACE](#surface).
* `:COLOR` is the line color, of [COLOR](#color) or [COLOR-A](#color-a).
* `:ALPHA` when between `0` and `255` is used as the alpha transparency value when blitting the rectangle onto `SURFACE`.
*Note:* An intermediate surface is created, the rectangle is drawn onto this intermediate surface and then this surface
is blitted to `SURFACE`.
* `:CLIPPING` is `NIL` The default is `NIL` as the SDL library will perform the necessary clipping automatically.

##### Packages

* Also supported in _LISPBUILDER-SDL-GFX_"
  (unless surface
    (setf surface *default-display*))
  (check-type surface sdl-surface)
  (check-type color color)
  (let ((x+width  (1- (+ x w)))
	(y+height (1- (+ y h))))
    (let ((surf (if alpha (create-surface w h :alpha alpha :pixel-alpha (a color)) surface))
	  (x (if alpha 0 x))
	  (y (if alpha 0 y)))
      (with-rectangle (template (rectangle))
	(_draw-hline_ x x+width y :surface surf :color color :clipping clipping :template template)
	(_draw-hline_ x x+width y+height :surface surf :color color :clipping clipping :template template)
	(_draw-vline_ x y y+height :surface surf :color color :clipping clipping :template template)
	(_draw-vline_ x+width y y+height :surface surf :color color :clipping clipping :template template))
      (when alpha
	(draw-surface-at-* surf x y :surface surface)
	(free surf))))
  surface)

;; (defun draw-rectangle-points (p1 p2 &key (clipping t) (surface *default-surface*) (color *default-color*))
;;   "Given a surface pointer draw a rectangle with the specified x,y, width, height and color"
;;   (draw-rectangle-xy (x p1) (y p1) (x p2) (y p2)
;; 		     :clipping clipping :surface surface :color color))


(defun draw-rectangle-edges-* (x0 y0 x1 y1
                                  &key (clipping nil) (surface *default-surface*) (color *default-color*) (alpha nil) (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  (declare (ignorable clipping alpha))
  (if gfx-loaded-p
    (gfx-draw-rectangle-edges-* x0 y0 x1 y1 :surface surface :color color)
    (_draw-rectangle-edges-*_ x0 y0 x1 y1 :surface surface :color color :clipping clipping :alpha alpha)))

(defun _draw-rectangle-edges-*_ (x0 y0 x1 y1
			       &key (clipping nil) (surface *default-surface*) (color *default-color*) (alpha nil))
  "Draw a rectangle outline of [COLOR](#color) to [SURFACE](#surface).

##### Parameters

* `X0` and `Y0` are the `INTEGER` coordinates of the top-left corner of the rectangle.
* `X0` and `Y0` are the `INTEGER` coordinates of the bottom-right corner of the rectangle.
* `:SURFACE` is the target [SURFACE](#surface).
* `:COLOR` is the line color, of [COLOR](#color) or [COLOR-A](#color-a).
* `:ALPHA` when between `0` and `255` is used as the alpha transparency value when blitting the rectangle onto `SURFACE`.
*Note:* An intermediate surface is created, the rectangle is drawn onto this intermediate surface and then this surface
is blitted to `SURFACE`.
* `:CLIPPING` is `NIL` The default is `NIL` as the SDL library will perform the necessary clipping automatically.

##### Packages

* Also supported in _LISPBUILDER-SDL-GFX_"
  (check-type surface sdl-surface)
  (check-type color color)
  (with-rectangle (template (rectangle-from-edges-* x0 y0 x1 y1))
    (draw-rectangle template :surface surface :clipping clipping :color color :alpha alpha))
  surface)

(defun draw-pixel (point &key (clipping t) (surface *default-surface*) (color *default-color*) (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  "See [DRAW-PIXEL-*](#draw-pixel-*).

##### Parameters

* `POINT` is the [POINT](#point) coordinates of the pixel.

##### Packages

* Also supported in _LISPBUILDER-SDL-GFX_"
  (check-type point point)
  (draw-pixel-* (x point) (y point) :clipping clipping :surface surface :color color :gfx-loaded-p gfx-loaded-p))

(defun draw-pixel-* (x y &key (clipping t) (surface *default-surface*) (color *default-color*) (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  (if gfx-loaded-p
    (gfx-draw-pixel-* x y :surface surface :color color)
    (_draw-pixel-*_ x y :clipping clipping :surface surface :color color)))

(defun _draw-pixel-*_ (x y &key (clipping t) (surface *default-surface*) (color *default-color*))
  "Draw a single pixel of [COLOR](#color) to the [SURFACE](#surface) at the specified `X` and `Y` coordiates.

##### Parameters

* `X` and `Y` specify the coordinates of the pixel, and are of type `INTEGER`.
* `:SURFACE` is the target [SURFACE](#surface).
* `:COLOR` is the pixel color, of [COLOR](#color) or [COLOR-A](#color-a).
* `:CLIPPING` when left as the default value `T` will ensure that the pixel is clipped to the dimensions of `SURFACE`.
SDL will core dump if pixels are drawn outside a surface. It is slower, but safer to leave `CLIPPING` as `T`.

##### Packages

* Also supported in _LISPBUILDER-SDL-GFX_"
  (unless surface
    (setf surface *default-display*))
  (check-type surface sdl-surface)
  (check-type color color)
  (when clipping
    (sdl-base::check-bounds 0 (- (width surface) 1) x)
    (sdl-base::check-bounds 0 (- (height surface) 1) y))
  (with-pixel (pix (fp surface))
              (write-pixel pix x y (map-color color surface)))
      surface)

(defun read-pixel (point &key (clipping t) (surface *default-surface*))
  "See [READ-PIXEL-*](#read-pixel-*).

##### Parameters

* `POINT` is the [POINT](#point) coordinates of the pixel.

##### Packages

* Also supported in _LISPBUILDER-SDL-GFX_"
  (check-type point point)
  (read-pixel-* (x point) (y point) :clipping clipping :surface surface))

(defun read-pixel-* (x y &key (clipping t) (surface *default-surface*))
  "Read the [COLOR](#color) of the pixel at `X` and `Y` coordiates from [SURFACE](#surface).

##### Parameters

* `X` and `Y` specify the coordinates of the pixel, and are of type `INTEGER`.
* `:SURFACE` is the target [SURFACE](#surface).
* `:COLOR` is the pixel color, of [COLOR](#color) or [COLOR-A](#color-a).
* `:CLIPPING` when left as the default value `T` will ensure that the pixel is clipped to the dimensions of `SURFACE`.
SDL will core dump if pixels are drawn outside a surface. It is slower, but safer to leave `CLIPPING` as `T`.

##### Packages

* Also supported in _LISPBUILDER-SDL-GFX_"
  (when clipping
    (sdl-base::check-bounds 0 (- (width surface) 1) x)
    (sdl-base::check-bounds 0 (- (height surface) 1) y))
  (with-pixel (surf (fp surface))
    (multiple-value-bind (rgba r g b a)
        (read-pixel surf x y)
      (declare (ignore rgba))
      (color :r r :g g :b b :a a))))

(defun draw-filled-circle (p1 r &key (surface *default-surface*) (color *default-color*) (stroke-color nil) (alpha nil)
                              (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  "See [DRAW-FILLED-CIRCLE-*](#draw-filled-circle-*).

##### Parameters

* `P1` is the [POINT](#point) coordinates coordinate of the center of the filled circle.

##### Packages

* Also supported in _LISPBUILDER-SDL-GFX_"
  (check-type p1 point)
  (draw-filled-circle-* (x p1) (y p1) r
			:surface surface :color color :stroke-color stroke-color :alpha alpha :gfx-loaded-p gfx-loaded-p))

(defun draw-filled-circle-* (x0 y0 r &key (surface *default-surface*) (color *default-color*) (stroke-color nil) (alpha nil)
                                (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  (declare (ignorable stroke-color alpha))
  (if (and gfx-loaded-p (not stroke-color))
    (gfx-draw-filled-circle-* x0 y0 r :surface surface :color color)
    (_draw-filled-circle-*_ x0 y0 r :surface surface :color color :stroke-color stroke-color :alpha alpha)))

(defun _draw-filled-circle-*_ (x0 y0 r &key (surface *default-surface*) (color *default-color*) (stroke-color nil) (alpha nil))
  "Draws a filled circle of [COLOR](#color) to [SURFACE](#surface).

##### Parameters

* `X0` and `Y0` specify the center coordinate of the circle, of type `INTEGER`.
* `R` is the circle radius, of type `INTEGER`.
* `:SURFACE` is the target [SURFACE](#surface).
* `:COLOR` is the line color, of [COLOR](#color) or [COLOR-A](#color-a).
* `:STROKE-COLOR` when not `NIL` will draw a `1` pixel line of color `COLOR` around the perimiter of the box.
* `:ALPHA` when between `0` and `255` is used as the alpha transparency value when blitting the rectangle onto `SURFACE`.
*Note:* An intermediate surface is created, the rectangle is drawn onto this intermediate surface and then this surface
is blitted to `SURFACE`.

##### Packages

* Also supported in _LISPBUILDER-SDL-GFX_"
  (declare (type fixnum x0 y0 r)
           (optimize (speed 3)(safety 0)))
  (unless surface
    (setf surface *default-display*))
  (check-type surface sdl-surface)
  (check-type color color)
  (if stroke-color
      (check-type stroke-color color))

  (let ((surf (if alpha (create-surface (the fixnum (1+ (the fixnum (* r 2))))
					(the fixnum (1+ (the fixnum (* r 2))))
					:alpha alpha
					:pixel-alpha (a color))
		  surface)))
    (let ((x0 (if alpha r x0))
	  (y0 (if alpha r y0)))
      (declare (type fixnum x0 y0))
      (let ((f (- 1 r))
	    (ddf-x 0)
	    (ddf-y (the fixnum (* -2 r))))
	(declare (type fixnum f ddf-x ddf-y))
	(with-rectangle (template (rectangle))
	  (_draw-vline_ x0 (the fixnum (+ y0 r)) (the fixnum (- y0 r)) :color color :surface surf :clipping nil :template template)
	  (_draw-hline_ (the fixnum (+ x0 r)) (the fixnum (- x0 r)) y0 :color color :surface surf :clipping nil :template template))
	(do ((x 0)
	     (y r))
	    ((<= y x))
	  (declare (type fixnum x y))
	  (when (>= f 0)
	    (decf y)
	    (incf ddf-y 2)
	    (incf f ddf-y))
	  (incf x)
	  (incf ddf-x 2)
	  (incf f (1+ ddf-x))
	  (with-rectangle (template (rectangle))
	    (_draw-hline_ (the fixnum (+ x0 x)) (the fixnum (- x0 x)) (the fixnum (+ y0 y)) :color color :surface surf :clipping nil
			:template template)
	    (_draw-hline_ (the fixnum (+ x0 x)) (the fixnum (- x0 x)) (the fixnum (- y0 y)) :color color :surface surf :clipping nil
			:template template)
	    (_draw-hline_ (the fixnum (+ x0 y)) (the fixnum (- x0 y)) (the fixnum (+ y0 x)) :color color :surface surf :clipping nil
			:template template)
	    (_draw-hline_ (the fixnum (+ x0 y)) (the fixnum(- x0 y))  (the fixnum (- y0 x)) :color color :surface surf :clipping nil
			:template template)))

	;; Draw the circle outline when a color is specified.
	(when stroke-color
	  (_draw-circle-*_ x0 y0 r :surface surf :color stroke-color))))

    (when alpha
      (draw-surface-at-* surf (the fixnum (- x0 r)) (the fixnum (- y0 r)) :surface surface)
      (free surf)))
  surface)

(defun draw-circle (p1 r &key
		    (surface *default-surface*)
		    (color *default-color*)
		    (alpha nil)
		    (aa nil) (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  "See [DRAW-CIRCLE-*](#draw-circle-*).

##### Parameters

* `P1` is the [POINT](#point) coordinates at the center of the circle.

##### Packages

* Also supported in _LISPBUILDER-SDL-GFX_
* `:AA` ignored in _LISPBUILDER-SDL_"
  (check-type p1 point)
  (draw-circle-* (x p1) (y p1) r
		 :surface surface :color color :alpha alpha :aa aa :gfx-loaded-p gfx-loaded-p))

(defun draw-circle-* (x0 y0 r &key
                         (surface *default-surface*)
                         (color *default-color*)
                         (alpha nil)
                         (aa nil) (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  (declare (ignorable alpha))
  (if gfx-loaded-p
    (gfx-draw-circle-* x0 y0 r :surface surface :color color :aa aa)
    (_draw-circle-*_ x0 y0 r :surface surface :color color :aa aa :alpha alpha)))

(defun _draw-circle-*_ (x0 y0 r &key
		      (surface *default-surface*)
		      (color *default-color*)
		      (alpha nil)
		      (aa nil))
  "Draws a circle circumference of [COLOR](#color) to [SURFACE](#surface).
Use [DRAW-FILLED-CIRCLE-*](#draw-filled-circle-*) to draw a filled circle.

##### Parameters

* `X` and `Y` specify the center coordinate of the circle, of type `INTEGER`.
* `R` is the circle r, of type `INTEGER`.
* `:AA` determines if the line is to be drawn using antialiasing.
* `:SURFACE` is the target [SURFACE](#surface).
* `:COLOR` is the line color, of [COLOR](#color) or [COLOR-A](#color-a).
* `:ALPHA` when between `0` and `255` is used as the alpha transparency value when blitting the rectangle onto `SURFACE`.
*Note:* An intermediate surface is created, the rectangle is drawn onto this intermediate surface and then this surface
is blitted to `SURFACE`.

##### Packages

* Also supported in _LISPBUILDER-SDL-GFX_
* `:AA` ignored in _LISPBUILDER-SDL_"
  (declare (ignore aa))
  (unless surface
    (setf surface *default-display*))
  (check-type surface sdl-surface)
  (check-type color color)
  (let ((f (- 1 r))
	(ddf-x 0)
	(ddf-y (* -2 r)))
    (labels ((in-bounds (x y w h)
	       (if (and (>= x 0) (< x w)
			(>= y 0) (< y h))
		   t
		   nil)))

      (let* ((width (if alpha (1+ (* r 2)) (width surface)))
	     (height (if alpha (1+ (* r 2)) (height surface)))
	     (surf (if alpha (create-surface width height :alpha alpha :pixel-alpha (a color)) surface))
	     (col (map-color color surf)))
	(let ((x0 (if alpha r x0))
	      (y0 (if alpha r y0)))

	  (let ((x-pos 0) (y-pos 0))
	    (with-pixel (pix (fp surf))
	      (setf x-pos x0
		    y-pos (+ y0 r))
	      (when (in-bounds x-pos y-pos width height)
		(write-pixel pix x-pos y-pos col))
	      (setf x-pos x0
		    y-pos (- y0 r))
	      (when (in-bounds x-pos y-pos width height)
		(write-pixel pix x-pos y-pos col))
	      (setf x-pos (+ x0 r)
		    y-pos y0)
	      (when (in-bounds x-pos y-pos width height)
		(write-pixel pix x-pos y-pos col))
	      (setf x-pos (- x0 r)
		    y-pos y0)
	      (when (in-bounds x-pos y-pos width height)
		(write-pixel pix x-pos y-pos col))
	      (do ((x 0)
		   (y r))
		  ((<= y x))
		(when (>= f 0)
		  (decf y)
		  (incf ddf-y 2)
		  (incf f ddf-y))

		(incf x)
		(incf ddf-x 2)
		(incf f (1+ ddf-x))

		(setf x-pos (+ x0 x)
		      y-pos (+ y0 y))
		(when (in-bounds x-pos y-pos width height)
		  (write-pixel pix x-pos y-pos col)) ;     setPixel(x0 + x, y0 + y);
		(setf x-pos (- x0 x)
		      y-pos (+ y0 y))
		(when (in-bounds x-pos y-pos width height)
		  (write-pixel pix x-pos y-pos col)) ;     setPixel(x0 - x, y0 + y);
		(setf x-pos (+ x0 x)
		      y-pos (- y0 y))
		(when (in-bounds x-pos y-pos width height)
		  (write-pixel pix x-pos y-pos col)) ;     setPixel(x0 + x, y0 - y);
		(setf x-pos (- x0 x)
		      y-pos (- y0 y))
		(when (in-bounds x-pos y-pos width height)
		  (write-pixel pix x-pos y-pos col)) ;     setPixel(x0 - x, y0 - y);
		(setf x-pos (+ x0 y)
		      y-pos (+ y0 x))
		(when (in-bounds x-pos y-pos width height)
		  (write-pixel pix x-pos y-pos col)) ;     setPixel(x0 + y, y0 + x);
		(setf x-pos (- x0 y)
		      y-pos (+ y0 x))
		(when (in-bounds x-pos y-pos width height)
		  (write-pixel pix x-pos y-pos col)) ;     setPixel(x0 - y, y0 + x);
		(setf x-pos (+ x0 y)
		      y-pos (- y0 x))
		(when (in-bounds x-pos y-pos width height)
		  (write-pixel pix x-pos y-pos col)) ;     setPixel(x0 + y, y0 - x);
		(setf x-pos (- x0 y)
		      y-pos (- y0 x))
		(when (in-bounds x-pos y-pos width height)
		  (write-pixel pix x-pos y-pos col)) ;     setPixel(x0 - y, y0 - x);
		))))

	(when alpha
	  (draw-surface-at-* surf (- x0 r) (- y0 r) :surface surface)
	  (free surf)))))
    surface)

(defun draw-trigon (p1 p2 p3 &key (surface *default-surface*) (color *default-color*) (clipping t) (aa nil)
                       (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  (declare (ignorable clipping))
  (if gfx-loaded-p
    (gfx-draw-trigon p1 p2 p3 :surface surface :color color :aa aa)
    (_draw-trigon_ p1 p2 p3 :surface surface :color color :aa aa :clipping clipping)))

(defun _draw-trigon_ (p1 p2 p3 &key (surface *default-surface*) (color *default-color*) (clipping t) (aa nil))
  "Draw the outline of a trigon or triangle, of [COLOR](#color) to [SURFACE](#surface).
Use [DRAW-FILLED-TRIGON-*](#draw-filled-trigon-*) to draw a filled trigon.

##### Parameters

* `P1`, `P2` and `P3` specify the vertices of the trigon, of type `SDL:POINT`.
* `:AA` determines if the line is to be drawn using antialiasing.
* `:SURFACE` is the target [SURFACE](#surface).
* `:COLOR` is the pixel color, of [COLOR](#color) or [COLOR-A](#color-a).
* `:CLIPPING` when left as the default value `T` will ensure that the pixel is clipped to the dimensions of `SURFACE`.
SDL will core dump if pixels are drawn outside a surface. It is slower, but safer to leave `CLIPPING` as `T`.

##### Packages

* Also supported in _LISPBUILDER-SDL-GFX_
* `:AA` ignored in _LISPBUILDER-SDL_"
  (declare (ignore aa))
  (check-types point p1 p2 p3)
  (check-type color color)
  (unless surface
    (setf surface *default-display*))
  (_draw-line-*_ (x p1) (y p1) (x p2) (y p2) :surface surface :color color :clipping clipping)
  (_draw-line-*_ (x p2) (y p2) (x p3) (y p3) :surface surface :color color :clipping clipping)
  (_draw-line-*_ (x p3) (y p3) (x p1) (y p1) :surface surface :color color :clipping clipping))

(defun draw-filled-trigon (p1 p2 p3 &key (surface *default-surface*) (color *default-color*) (clipping t) (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  "Draw a filled trigon of [COLOR](#color) to the [SURFACE](#surface)

##### Parameters

* `P1`, `P2` and `P3` specify the vertices of the trigon, of type `SDL:POINT`.
* `:SURFACE` is the target [SURFACE](#surface).
* `:COLOR` is the pixel color, of [COLOR](#color) or [COLOR-A](#color-a).

##### Packages

* Supported in _LISPBUILDER-SDL-GFX_"
  (declare (ignorable clipping))
  (if gfx-loaded-p
    (gfx-draw-filled-trigon p1 p2 p3 :surface surface :color color)))

(defun draw-polygon (vertices &key (surface *default-surface*) (color *default-color*) (clipping t) (aa nil) (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  (declare (ignorable clipping))
  (if gfx-loaded-p
    (gfx-draw-polygon vertices :surface surface :color color :aa aa)
    (_draw-polygon_ vertices :surface surface :color color :aa aa :clipping clipping :gfx-loaded-p gfx-loaded-p)))

(defun _draw-polygon_ (vertices &key (surface *default-surface*) (color *default-color*) (clipping t) (aa nil) (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  "Draw the circumference of a polygon of [COLOR](#color) to [SURFACE](#surface) using the vertices in `POINTS`.
Use [DRAW-FILLED-POLYGON-*](#draw-filled-polygon-*) to draw a filled polygon.

##### Parameters

* `:POINTS` is the list of vertices for the polygon. `POINTS` is a list of `POINT`s.
* `:AA` determines if the line is to be drawn using antialiasing.
* `:SURFACE` is the target [SURFACE](#surface).
* `:COLOR` is the pixel color, of [COLOR](#color) or [COLOR-A](#color-a).
* `:CLIPPING` when left as the default value `T` will ensure that the pixel is clipped to the dimensions of `SURFACE`.
SDL will core dump if pixels are drawn outside a surface. It is slower, but safer to leave `CLIPPING` as `T`.

##### Packages

* Also supported in _LISPBUILDER-SDL-GFX_
* `:AA` ignored in _LISPBUILDER-SDL_"
  (declare (ignore aa))
  (check-type vertices (and list (not null)) "POINTs must be a LIST of POINTs")
  (unless surface
    (setf surface *default-display*))
  (check-type color color)
  (draw-shape vertices :style :solid :clipping clipping :surface surface :color color :gfx-loaded-p gfx-loaded-p))

(defun draw-filled-polygon (vertices &key (surface *default-surface*) (color *default-color*) (clipping t) (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  "Draw a filled polygon of [COLOR](#color) to the [SURFACE](#surface)

##### Parameters

* `VERTICES` is the list of vertices of type `SDL:POINT`.
* `:SURFACE` is the target [SURFACE](#surface).
* `:COLOR` is the pixel color, of [COLOR](#color) or [COLOR-A](#color-a).

##### Packages

* Supported in _LISPBUILDER-SDL-GFX_"
  (declare (ignorable clipping))
  (if gfx-loaded-p
    (gfx-draw-filled-polygon vertices :surface surface :color color)))

;; Placeholders for LISPBUILDERL-SDL-GFX

(defun draw-ellipse (p1 rx ry &key (surface sdl:*default-surface*) (color sdl:*default-color*) (aa nil) (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  "See [DRAW-ELLIPSE-*](#draw-ellipse-*).

##### Parameters

* `P1` is the [POINT](#point) coordinates at the center of the ellipse.

##### Packages

* Supported in _LISPBUILDER-SDL-GFX_"
  (draw-ellipse-* (x p1) (y p1) rx ry :surface surface :color color :aa aa :gfx-loaded-p gfx-loaded-p))

(defun draw-ellipse-* (x y rx ry &key (surface sdl:*default-surface*) (color sdl:*default-color*) (aa nil) (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  "Draws an ellipse circumference of [COLOR](#color) to the [SURFACE](#surface).
Use [DRAW-FILLED-ELLIPSE-*](#draw-filled-ellipse-*) to draw a filled ellipse.

##### Parameters

* `X` and `Y` specify the center coordinate of the ellipse, of type `INTEGER`.
* `RX` and `RY` specify the ellipse radius, of type `INTEGER`.
* `:SURFACE` is the target [SURFACE](#surface).
* `:COLOR` is the pixel color, of [COLOR](#color) or [COLOR-A](#color-a).

##### Packages

* Supported in _LISPBUILDER-SDL-GFX_"
  (declare (ignorable x y rx ry surface color aa))
  (if gfx-loaded-p
    (gfx-draw-ellipse-* x y rx ry :surface surface :color color :aa aa)))

(defun draw-filled-ellipse (p1 rx ry &key (surface sdl:*default-surface*) (color sdl:*default-color*) (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  "See [DRAW-FILLED-ELLIPSE-*](#draw-filled-ellipse-*).

##### Parameters

* `P1` is the [POINT](#point) coordinates at the center of the filled ellipse.

##### Packages

* Supported in _LISPBUILDER-SDL-GFX_"
  (draw-filled-ellipse-* (x p1) (y p1) rx ry :surface surface :color color :gfx-loaded-p gfx-loaded-p))

(defun draw-filled-ellipse-* (x y rx ry &key (surface sdl:*default-surface*) (color sdl:*default-color*) (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  "Draws a filled ellipse of [COLOR](#color) to the [SURFACE](#surface).

##### Parameters

* `X` and `Y` specify the center coordinate of the ellipse, of type `INTEGER`.
* `RX` and `RY` specify the ellipse radius, of type `INTEGER`.
* `:SURFACE` is the target [SURFACE](#surface).
* `:COLOR` is the pixel color, of [COLOR](#color) or [COLOR-A](#color-a).

##### Packages

* Supported in _LISPBUILDER-SDL-GFX_"
  (declare (ignorable x y rx ry surface color))
  (if gfx-loaded-p
    (gfx-draw-filled-ellipse-* x y rx ry :surface surface :color color)))

(defun draw-pie (p1 rad start end &key (surface sdl:*default-surface*) (color sdl:*default-color*) (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  "See [DRAW-PIE-*](#draw-pie-*).

##### Parameters

* `P1` is the [POINT](#point) coordinates at the center of the pie.

##### Packages

* Supported in _LISPBUILDER-SDL-GFX_"
  (draw-pie-* (x p1) (y p1) rad start end :surface surface :color color :gfx-loaded-p gfx-loaded-p))

(defun draw-pie-* (x y rad start end &key (surface sdl:*default-surface*) (color sdl:*default-color*) (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  "Draws a pie of [COLOR](#color) to the [SURFACE](#surface).
Use [DRAW-FILLED-PIE-*](#draw-filled-pie-*) to draw a filled pie.

##### Parameters

* `X` and `Y` specify the center coordinate of the pie, of type `INTEGER`.
* `RAD` is the pie radius, of type `INTEGER`.
* `START` is the pie start, of type `INTEGER`.
* `END` is the pie end, of type `INTEGER`.
* `:SURFACE` is the target [SURFACE](#surface).
* `:COLOR` is the pixel color, of [COLOR](#color) or [COLOR-A](#color-a).

##### Packages

* Supported in _LISPBUILDER-SDL-GFX_"
  (declare (ignorable x y rad start end surface color))
  (if gfx-loaded-p
    (gfx-draw-pie-* x y rad start end :surface surface :color color)))

(defun draw-filled-pie (p1 rad start end &key (surface sdl:*default-surface*) (color sdl:*default-color*) (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  "See [DRAW-FILLED-PIE-*](#draw-filled-pie-*).

##### Parameters

* `P1` is the [POINT](#point) coordinates at the center of the filled pie.

##### Packages

* Supported in _LISPBUILDER-SDL-GFX_"
  (draw-filled-pie-* (x p1) (y p1) rad start end :surface surface :color color :gfx-loaded-p gfx-loaded-p))

(defun draw-filled-pie-* (x y rad start end &key (surface sdl:*default-surface*) (color sdl:*default-color*) (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  "Draws a filled pie of [COLOR](#color) to the [SURFACE](#surface)

##### Parameters

* `X` and `Y` specify the center coordinate of the pie, of type `INTEGER`.
* `RAD` is the pie radius, of type `INTEGER`.
* `START` is the pie start, of type `INTEGER`.
* `END` is the pie end, of type `INTEGER`.
* `:SURFACE` is the target [SURFACE](#surface).
* `:COLOR` is the pixel color, of [COLOR](#color) or [COLOR-A](#color-a).

##### Packages

* Supported in _LISPBUILDER-SDL-GFX_"
  (declare (ignorable x y rad start end surface color))
  (if gfx-loaded-p
    (gfx-draw-filled-pie-* x y rad start end :surface surface :color color)))

(defun draw-arc (p1 rad start end &key (surface sdl:*default-surface*) (color sdl:*default-color*) (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  (draw-arc-* (sdl:x p1) (sdl:y p1) rad start end :surface surface :color color :gfx-loaded-p gfx-loaded-p))

(defun draw-arc-* (x y rad start end &key (surface sdl:*default-surface*) (color sdl:*default-color*) (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  (if gfx-loaded-p
    (gfx-draw-arc-* x y rad start end :surface surface :color color)))

(defun rotate-surface (degrees &key (surface sdl:*default-surface*) (free nil) (zoom 1) (smooth nil) (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  (declare (ignorable free))
  (if gfx-loaded-p
    (gfx-roto-zoom-surface degrees zoom smooth :surface surface)
    (_rotate-surface_ degrees :surface surface :free free :zoom zoom :smooth smooth)))

(defun rotate-surface-xy (degrees &key (surface sdl:*default-surface*) (free nil) (zoomx 1) (zoomy 1) (smooth nil)
                                  (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
    "Returns a new [SURFACE](#surface) rotated to `DEGREES`.

##### Parameters

* `DEGREES` is the rotation in degrees.
* `:SURFACE` is the surface to rotate [SURFACE](#surface).
* `:FREE` when `T` will free `SURFACE`.
* `:ZOOMX` and `ZOOMY` are the the scaling factors.
A negative scaling factor will flip the corresponding axis.
_Note_: Flipping is only supported with anti-aliasing turned off.
* `:SMOOTH` when `T` will anti-aliase the new surface.

##### Packages

* Supported in _LISPBUILDER-SDL-GFX_
* _LISPBUILDER-SDL-GFX_ ignores `:FREE`."
  (declare (ignorable free))
  (if gfx-loaded-p
    (gfx-roto-zoom-xy degrees zoomx zoomy smooth :surface surface)))

(defun roto-zoom-surface (angle zoom smooth &key (surface sdl:*default-surface*) (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  (check-type surface sdl:surface)
  (if gfx-loaded-p
    (gfx-roto-zoom-surface angle zoom smooth :surface surface)))

(defun roto-zoom-xy (angle zoomx zoomy smooth &key (surface sdl:*default-surface*) (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  (check-type surface sdl:surface)
  (if gfx-loaded-p
    (gfx-roto-zoom-xy angle zoomx zoomy smooth :surface surface)))

(defun roto-zoom-size (width height angle zoom &key (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  (if gfx-loaded-p
    (gfx-roto-zoom-size width height angle zoom)))

(defun roto-zoom-size-xy (width height angle zoomx zoomy &key (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  (if gfx-loaded-p
    (gfx-roto-zoom-size-xy width height angle zoomx zoomy)))

(defun zoom-surface (zoomx zoomy &key (surface *default-surface*) (free nil) (smooth nil) (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  "Returns a new [SURFACE](#surface) scaled to `ZOOMX` and `ZOOMY`.

##### Parameters

* `:ZOOMX` and `ZOOMY` are the scaling factors.
A negative scaling factor will flip the corresponding axis.
_Note_: Flipping is only supported with anti-aliasing turned off.
* `:SURFACE` is the surface to rotate [SURFACE](#surface).
* `:FREE` when `T` will free `SURFACE`.
* `:SMOOTH` when `T` will anti-aliase the new surface.

##### Packages

* Supported in _LISPBUILDER-SDL-GFX_
* _LISPBUILDER-SDL-GFX_ ignores `:FREE`."
  (declare (ignorable zoomx zoomy surface free smooth))
  (if gfx-loaded-p
    (gfx-zoom-surface zoomx zoomy :surface surface :smooth smooth :free free)))

(defun zoom-surface-size (width height zoomx zoomy &key (gfx-loaded-p sdl-cffi::*gfx-loaded-p*))
  (if gfx-loaded-p
    (gfx-zoom-surface-size width height zoomx zoomy)))

;;; Anthony Fairchild.
;;; http://article.gmane.org/gmane.lisp.cl-lispbuilder.general/559
(defun _rotate-surface_ (degrees &key (surface *default-surface*) (free nil) (zoom 1) (smooth nil))
  "Returns a new [SURFACE](#surface) rotated to `DEGREES`.

##### Parameters

* `DEGREES` is the rotation in degrees.
* `:SURFACE` is the surface to rotate [SURFACE](#surface).
* `:FREE` when `T` will free `SURFACE`.
* `:ZOOM` is the scaling factor.
* `:SMOOTH` when `T` will anti-aliase the new surface.

##### Packages

* Also supported in _LISPBUILDER-SDL-GFX_
* _LISPBUILDER-SDL_ supports rotations of only `0`, `90`, `180`, or `270` degrees.
_LISPBUILDER-SDL-GFX_ supports any rotation.
* _LISPBUILDER-SDL_ ignores `:SMOOTH`. _LISPBUILDER-SDL-GFX_ supports `:SMOOTH`.
* _LISPBUILDER-SDL_ ignores `:ZOOM`. _LISPBUILDER-SDL-GFX_ supports `:ZOOM`.
* _LISPBUILDER-SDL-GFX_ ignores `:FREE`."
  (declare (ignore zoom smooth)
           (type fixnum degrees)
 	   (optimize (speed 3)(safety 0)))
  (unless (member degrees '(0 90 180 270))
    (error "ERROR, ROTATE-SURFACE: degrees ~A is not one of 0, 90, 180 or 270" degrees))
  (if (= 0 degrees)
      ;; in the case of 0 degrees, just return the surface
      (let ((new-surf (copy-surface :surface surface)))
	(when free
	  (free surface))
	new-surf)
      ;; else do rotation
      (let* ((even (evenp (/ degrees 90)))
	     (w (width surface))
	     (h (height surface))
	     (new-w (if even w h))
	     (new-h (if even h w)))
	(declare (type fixnum w h new-w new-h))
	(with-surfaces ((src surface free)
			(dst (make-instance 'surface
					    :using-surface surface
					    :width new-w :height new-h
					    :bpp (bit-depth surface)
					    :enable-alpha (alpha-enabled-p surface)
					    :enable-color-key (color-key-enabled-p surface)
					    :alpha (when (alpha-enabled-p surface) (alpha surface))
					    :color-key (when (color-key-enabled-p surface) (color-key surface))
					    :pixel-alpha (pixel-alpha-enabled-p surface)) nil))
	  (let ((new-x (case degrees
			 (90  #'(lambda (x y)
				  (declare (ignore x)(type fixnum x y))
				  (the fixnum (+ (the fixnum (1- new-w)) (the fixnum (- 0 y))))))
			 (180 #'(lambda (x y)
				  (declare (ignore y)(type fixnum x y))
				  (the fixnum (+ (the fixnum (1- new-w)) (the fixnum (- 0 x))))))
			 (270 #'(lambda (x y)
				  (declare (ignore x)(type fixnum x y))
				  y))
			 (otherwise #'(lambda (x y)
					(declare (ignore y)(type fixnum x y))
					x))))
		(new-y (case degrees
			 (90  #'(lambda (x y)
				  (declare (ignore y)(type fixnum x y))
				  x))
			 (180 #'(lambda (x y)
				  (declare (ignore x)(type fixnum x y))
				  (the fixnum (+ (the fixnum (1- new-h)) (the fixnum(- 0 y))))))
			 (270 #'(lambda (x y)
				  (declare (ignore y)(type fixnum x y))
				  (the fixnum (+ (the fixnum (1- new-h)) (the fixnum (- 0 x))))))
			 (otherwise  #'(lambda (x y)
					 (declare (ignore x)(type fixnum x y))
					 y)))))
 	    (declare (type fixnum w h))
	    (with-pixels ((src (fp src))
			  (dst (fp dst)))
	      (loop :for x :from 0 :to (1- w)
		 :do (loop :for y :from 0 :to (1- h)
			:do (write-pixel dst
					 (funcall new-x x y)
					 (funcall new-y x y)
					 (read-pixel src x y))))))
	  dst))))


(defun draw-aa-line (p1 p2 &key (surface sdl:*default-surface*) (color sdl:*default-color*) (gfx-loaded-p *gfx-loaded-p*))
  (sdl:check-types sdl:point p1 p2)
  (if gfx-loaded-p
    (sdl::gfx-draw-aa-line-* (sdl:x p1) (sdl:y p1) (sdl:x p2) (sdl:y p2) :surface surface :color color)))

(defun draw-aa-line-* (x1 y1 x2 y2 &key (surface sdl:*default-surface*) (color sdl:*default-color*) (gfx-loaded-p *gfx-loaded-p*))
  (if gfx-loaded-p
    (sdl::gfx-draw-aa-line-* x1 y1 x2 y2 :surface surface :color color)))

(defun draw-aa-circle (p1 r &key (surface sdl:*default-surface*) (color sdl:*default-color*) (gfx-loaded-p *gfx-loaded-p*))
  (check-type p1 sdl:point)
  (if gfx-loaded-p
    (gfx-draw-aa-circle-* (sdl:x p1) (sdl:y p1) r :surface surface :color color)))

(defun draw-aa-circle-* (x y r &key (surface sdl:*default-surface*) (color sdl:*default-color*) (gfx-loaded-p *gfx-loaded-p*))
  (if gfx-loaded-p
    (gfx-draw-aa-circle-* x y r :surface surface :color color)))

(defun draw-aa-ellipse (p1 rx ry &key (surface sdl:*default-surface*) (color sdl:*default-color*) (gfx-loaded-p *gfx-loaded-p*))
  (check-type p1 sdl:point)
  (if gfx-loaded-p
    (gfx-draw-aa-ellipse-* (sdl:x p1) (sdl:y p1) rx ry :surface surface :color color)))

(defun draw-aa-ellipse-* (x y rx ry &key (surface sdl:*default-surface*) (color sdl:*default-color*) (gfx-loaded-p *gfx-loaded-p*))
  (if gfx-loaded-p
    (gfx-draw-aa-ellipse-* x y rx ry :surface surface :color color)))

(defun draw-aa-trigon (p1 p2 p3 &key (surface sdl:*default-surface*) (color sdl:*default-color*) (gfx-loaded-p *gfx-loaded-p*))
  (sdl:check-types sdl:point p1 p2 p3)
  (unless surface
    (setf surface sdl:*default-display*))
  (check-type surface sdl:sdl-surface)
  (check-type color sdl:color)
  (if gfx-loaded-p
    (gfx-draw-aa-trigon p1 p2 p3 :surface surface :color color)))

(defun draw-aa-polygon (vertices &key (surface sdl:*default-surface*) (color sdl:*default-color*) (gfx-loaded-p *gfx-loaded-p*))
  (check-type vertices (and list (not null)) "Vertices must be a LIST of SDL:POINTs")
  (unless surface
    (setf surface sdl:*default-display*))
  (check-type surface sdl:sdl-surface)
  (check-type color sdl:color)
  (if gfx-loaded-p
    (gfx-draw-aa-polygon vertices :surface surface :color color)))


;; SDL_gfx 2.0.16
;; (defun shrink-surface (factor-x factor-y &key (surface sdl:*default-surface*))
;;   "Returns a new 32bit or 8bit SDl:SURFACE from the SDL:SURFACE :SURFACE.
;;     FACTOR-X and FACTOR-Y are the shrinking ratios \(i.e. 2=1/2 the size,
;;     3=1/3 the size, etc.\) The destination surface is antialiased by averaging
;;     the source box RGBA or Y information. If the surface is not 8bit
;;     or 32bit RGBA/ABGR it will be converted into a 32bit RGBA format on the fly."
;;   (check-type surface sdl:surface)
;;   (sdl:surface (sdl-gfx-cffi::shrinkSurface (sdl:fp surface) factor-x factor-y)))

