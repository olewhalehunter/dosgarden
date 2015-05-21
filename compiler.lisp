;;;;
;;;; lisp compiler for 16 bit DOS
;;;; asssembly TASM game development
;;;; using SBCL, DOSBox, TASM
;;;;
;;;; License : GNU AGPL3
;;;;
;;;; To do:
;;;; palette.dat -> r,g,b(0-3F), 3f=63
;;;; color storage, distance 
;;;; spriteset -> file converter
;;;; lisp DSL/vm

(load "resources.lisp")


(defun init-vars ()
  (defparameter asm-file-name "test.asm")
  (defparameter asm-string "")

  (defparameter img-file-loc 
    "C:\\TASM\\TASM\\IMAGES.TXT") ; IMG_FNAME
)

(defmacro concat (&body body) 
  `(concatenate 'string ,@body))
(defmacro o (&body body) 
  "Line by line output to assembly file output string."
  `(setq asm-string 
	(concat asm-string (concat ,@body) "~%")))

(defun flush-registers ()
(o 
"PUSH AX
PUSH BX
PUSH CX
PUSH DX"))
(defun unflush-registers ()
(o 
"POP AX
POP BX
POP CX
POP DX"))
(defmacro label (l-name &rest body)
  `(progn 
     (o (concatenate 'string ,l-name ":"))
     ,@body
     (o (concatenate 'string "END " ,l-name)))
)
(defun call (proc-name)
  (o "CALL " proc-name))

(defun asm-header () "Write model, stack, and data headers."
  (o
".MODEL SMALL
.STACK 100H
.DATA
OUTMSG DB '...', 0AH, '$'
EXTRA DB 'eeeeeeee->', '$'
WAVE_SIZE DW 1
FILE_SIZE DW 10
IMG_FNAME DB '" img-file-loc "', 0
PAL_FNAME DB 'PALETTE.dat', 0
FILE_HANDLE DW 0
FILE_BUFFER DB 100 DUP (?), '$'
PALETTE_BUFFER DB 768 DUP (?)
.CODE
JMP START
"))
(defun set-video-mode (mode)
  (o
"MOV AX, " mode "
MOV AH, 0
INT 10H"))
(defun init-data ()
  (o
"MOV AX, @DATA 
MOV DS, AX"))
(defun end-program ()
  (o
"MOV AL, 0 		
MOV AH, 4CH
INT 21H"))

(defun proc-file-read () "FILE_READ /IMG_FNAME -> FILE_BUFFER"
  (o
"FILE_READ PROC NEAR
 PUSH AX
 PUSH BX
 PUSH CX
 PUSH DX

 MOV AH, 3DH
 MOV AL, 0
 MOV DX, OFFSET IMG_FNAME
 INT 21H
 MOV FILE_HANDLE, AX
	
 MOV AH, 3FH
 MOV CX, FILE_SIZE
 MOV DX, OFFSET FILE_BUFFER
 MOV BX, FILE_HANDLE
 INT 21H

 ;; MOV BX, FILE_HANDLE	
 ;; MOV AH,3EH
 ;; INT 21H 
	
 POP DX
 POP CX
 POP BX
 POP AX
 RET
ENDP
"))

(defun write-to-video ()
  (o
"mov ax, 0a000h
mov es, ax	
xor di, di 
vidloop:
mov byte [es:di], di
inc di
cmp di, 0ffh	
jne vidloop"))
(defun write-palette-to-file ()
  (o
"xor di, di
xor dl, dl
readpal:

mov bh, dl
mov ax, 1007h
int 10h ;; load color register # to BX

mov bl, dl
MOV AX, 1015h
INT 10H 
mov [ds:PALETTE_BUFFER+di], DH
inc di
mov [ds:PALETTE_BUFFER+di], CH
inc di
mov [ds:PALETTE_BUFFER+di], CL
inc di ;; rgb values -> buffer

inc dl
cmp di, 02FDh
jne readpal

MOV AX, 3D01h
MOV DX, OFFSET PAL_FNAME
INT 21H
MOV FILE_HANDLE, AX ;; open file and assign handle

mov ah, 40h
mov bx, FILE_HANDLE
mov cx, 02FDh  ;; 256*3=768
lea dx, PALETTE_BUFFER
INT 21h         ;; write palette to file

"))

(defun define-asm-main ()
  "Write main entry point for program."
  ;; (write-to-video)
  ;; (call "FILE_READ")
  (write-palette-to-file)
  (print "."))
(defun define-asm-procs ()
  "Write asm procedures to source."
  (proc-file-read)
  (proc-init-palette))
(defun compile-asm-string ()
  "Compile lisp to TASM assembly string."
  (asm-header)
  (define-asm-procs)
  (label 
   "START"
   (set-video-mode "13h")
   (init-data)
   (define-asm-main)
   (end-program)))
(defun compile-asm-file ()
  (init-vars)
  "Write assembly string to file."
   (if (probe-file asm-file-name)
      (delete-file asm-file-name)
      (print "Source assembly not found, skipped deletion."))
  (with-open-file (str asm-file-name
                     :direction :output
                     :if-does-not-exist :create)
    (compile-asm-string)
    (format str (concatenate 'string asm-string "~%"))))

(compile-asm-file)
