; Este es un programa machote para un .COM               
include vjmacros.ASM

todo segment

    assume  cs:todo, ds:todo, ss:todo

    org 100h

    start: jmp inicio 
    ; ------------------------
    ; Declaracion de variables
    ; ------------------------
    
    ; Inicia con color blanco pues es el default
    saved db 1111b

    ; Posicion inicial del mouse sobre el canvas
    cursorX dw 300
    cursorY dw 300

    cursorColor db black
    
    ; Empieza con el pixel por default
    toolSelected dw 01h

    x0 dw -1
    y0 dw -1

    x1 dw -1
    y1 dw -1

    x2 dw -1
    y2 dw -1

    lastLineSize dw 00h

    listColores db black, blue, green, cyan, red, magenta
                db brown, yellow, white, 00h

    ; ------------------------
    ; Auxiliares
    ; ------------------------

    ; E: N/A
    ; S: AL - ASCII digitado
    ;    AH - Scan Code
    ; D: Retorna en AX los datos de la tecla digitada
    pKeyPressed proc
        mov ah, 10h
        int 16h
        ret
    pKeyPressed endP

    ; E/S: N/A
    ; D: Hace un delay de medio segundo
    pDelay proc
        pushs <ax, cx, dx>

        mov cx, 00h
        mov dx, 0640h
        mov ah, 86h
        int 15h 
        
        pops <dx, cx, ax>

        ret
    pDelay endP 

    ; ------------------------
    ; Logica
    ; ------------------------

    ; E: CursorX - PosX
    ;    CursorY - PosY
    ; S: AL - Color
    ; D: Retorna el color de un pixel en 
    pGetPixelColor proc
        pushs <bx, cx, dx>
        
        mov ah, 0Dh
        mov bh, 00h

        mov cx, cursorX
        mov dx, cursorY

        int 10h

        pops <dx, cx, bx>

        ret
    pGetPixelColor endP

    ; E: X0 - EL x inicial
    ;    Y0 - El y inicial
    ;    X1 - El x final
    ;    Y1 - El y final
    ; S: lastLineSize - Tamano de la linea
    ; D: Dibuja una linea en pantalla
    pBresenham proc 
        pushs <ax, bx, cx, dx>
        ; Variables para el algoritmo
        pBresenham_x     equ word ptr [bp-2]
        pBresenham_y     equ word ptr [bp-4]
        pBresenham_dx    equ word ptr [bp-6]
        pBresenham_dy    equ word ptr [bp-8]
        pBresenham_incYi equ word ptr [bp-10]
        pBresenham_incXi equ word ptr [bp-12]
        pBresenham_incYr equ word ptr [bp-14]
        pBresenham_incXr equ word ptr [bp-16]
        pBresenham_Av    equ word ptr [bp-18]
        pBresenham_AvR   equ word ptr [bp-20]
        pBresenham_AvI   equ word ptr [bp-22]
        
        ; Reservar espacio
        push bp
        mov bp, sp

        sub bp, 22

        ; Inicializacion de variables
        mov pBresenham_x, 0
        mov pBresenham_y, 0
        mov pBresenham_dx, 0
        mov pBresenham_dy, 0
        mov pBresenham_incYi, 0
        mov pBresenham_incXi, 0
        mov pBresenham_incYr, 0
        mov pBresenham_incXr, 0
        mov pBresenham_Av, 0
        mov pBresenham_AvR, 0
        mov pBresenham_AvI, 0

        ; Logica del algoritmo

        ; dy = y1 - y0
        mov ax, y1
        mov bx, y0

        sub ax, bx

        mov pBresenham_dy, ax

        ; dy = x1 - x0
        mov ax, x1
        mov bx, x0

        sub ax, bx

        mov pBresenham_dx, ax

        ; Incremento en y para las secciones de avance 
        ; inclinado
        mov bx, pBresenham_dy
        jmpifs bx, pBresenham_dyneg
            ; incYi = 1
            mov pBresenham_incYi, 1
            jmp pBresenham_dyif_end

        pBresenham_dyneg:
            ; dy = -dy
            c2 pBresenham_dy
            ; incYi = -1
            mov pBresenham_incYi, -1

        pBresenham_dyif_end:

        ; Incremento en x para las secciones de avance 
        ; inclinado
        mov bx, pBresenham_dx
        jmpifs bx, pBresenham_dxneg
            mov pBresenham_incXi, 1
            jmp pBresenham_dxif_end

        pBresenham_dxneg:
            c2 pBresenham_dx
            mov pBresenham_incXi, -1

        pBresenham_dxif_end:

        ; Incremento para las secciones de avance recto
        mov ax, pBresenham_dx
        mov bx, pBresenham_dy

        jmpifl ax, bx, pBresenham_dx_less_dy
            ; incYr = 0
            mov pBresenham_incYr, 0
            ; incXr = incXi
            mov ax, pBresenham_incXi
            mov pBresenham_incXr, ax
            jmp pBresenham_dx_less_dy_end
        pBresenham_dx_less_dy:
            ; incXr = 0
            mov pBresenham_incXr, 0
            ; incYr = incYi
            mov ax, pBresenham_incYi
            mov pBresenham_incYr, ax
            ; dx <=> dy
            xchgV pBresenham_dx, pBresenham_dy 

        pBresenham_dx_less_dy_end:

        ; Inicializar algunas variables
        ; x = x0
        mov ax, x0
        mov pBresenham_x, ax

        ; y = y0
        mov ax, y0
        mov pBresenham_y, ax

        ; avR = 2 * dy
        clean <dx>
        mov ax, pBresenham_dy
        mov bx, 2
        mul bx

        mov pBresenham_avR, ax

        ; av = avR - dx
        mov ax, pBresenham_avR
        mov bx, pBresenham_dx
        sub ax, bx
        
        mov pBresenham_aV, ax

        ; avI = av - dx
        mov ax, pBresenham_aV
        mov bx, pBresenham_dx
        sub ax, bx
        
        mov pBresenham_aVi, ax

        ; Bucle para el trazado de lineas
        mov lastLineSize, 00h
        pBresenham_trazado:
            ; Dibujamos el pixel
            mov dx, pBresenham_y
            mov cx, pBresenham_x
            mov al, cursorColor

            call pDrawPixel
            inc lastLineSize

            ; Condicion parada
            mov ax, pBresenham_x
            jmpifn ax, x1, pBresenham_trazado_ok

            mov ax, pBresenham_y
            jmpif ax, y1, pBresenham_end_trazado

            pBresenham_trazado_ok:

            ; Comparamos si av >= 0
            mov ax, pBresenham_aV
            jmpifs ax, pBresenham_av_signed
                ; X = X + IncXi
                mov ax, pBresenham_x
                mov bx, pBresenham_IncXi

                add ax, bx
                mov pBresenham_x, ax

                ; Y = Y + IncYi
                mov ax, pBresenham_y
                mov bx, pBresenham_IncYi

                add ax, bx
                mov pBresenham_y, ax

                ; aV = av + avI
                mov ax, pBresenham_aV
                mov bx, pBresenham_aVi

                add ax, bx
                mov pBresenham_aV, ax

                jmp pBresenham_av_signed_endif
            pBresenham_av_signed:
                ; X = X + IncXr
                mov ax, pBresenham_x
                mov bx, pBresenham_IncXr

                add ax, bx
                mov pBresenham_x, ax

                ; Y = Y + IncYr
                mov ax, pBresenham_y
                mov bx, pBresenham_IncYr

                add ax, bx
                mov pBresenham_y, ax

                ; aV = av + aVr
                mov ax, pBresenham_aV
                mov bx, pBresenham_aVr

                add ax, bx
                mov pBresenham_aV, ax

            pBresenham_av_signed_endif:
            jmp pBresenham_trazado
        pBresenham_end_trazado:

        ; Recuperar el BP
        pop bp

        pops <dx, cx, bx, ax>

        ret
    pBresenham endP

    ; D: Dibuja un pentagono
    ; N: No hace validaciones
    pPentagon proc
        push ax

        ; Declaracion de variables
        pDrawPentagon_mid_dis   equ word ptr [bp-2]
        pDrawPentagon_line_size equ word ptr [bp-4]

        ; Reservar espacio
        push bp
        mov bp, sp
        sub bp, 4

        movV y1, y0

        ; if x0 <= x1
        mov ax, x0
        jmpifle ax, x1, pPentagon_x0_gend
            xchgV x0, x1
            xchgV y0, y1
        pPentagon_x0_gend:

        ; Se dibuja la linea
        call pBresenham

        mov ax, lastLineSize
        mov pDrawPentagon_line_size, ax

        ; mid_dis = lastLineSize / 2
        divide lastLineSize, 2

        mov pDrawPentagon_mid_dis, ax

        ; Calculos los puntos de
        ; la segunda linea
        ; x0 = x1
        ; y0 = y1
        movV x0, x1
        movV y0, y1

        ; y0 += lastLineSize
        mov ax, y1
        add ax, lastLineSize

        mov y1, ax

        ; x1 += pDrawPentagon_mid_dis
        mov ax, pDrawPentagon_mid_dis
        add x1, ax

        ; Se dibuja la linea
        pushs <pDrawPentagon_mid_dis, pDrawPentagon_line_size>
        call pBresenham
        pops <pDrawPentagon_line_size, pDrawPentagon_mid_dis>

        ; Calculos los puntos de
        ; la tercera linea
        movV x0, x1
        movV y0, y1

        ; x1 -= 2*pDrawPentagon_mid_dis
        mov ax, pDrawPentagon_mid_dis
        sub x1, ax
        sub x1, ax

        ; y1 += line_size
        mov ax, pDrawPentagon_line_size
        add y1, ax

        ; Se dibuja la linea
        pushs <pDrawPentagon_mid_dis, pDrawPentagon_line_size>
        call pBresenham
        pops <pDrawPentagon_line_size, pDrawPentagon_mid_dis>

        ; Calculos los puntos de
        ; la cuarta linea
        movV x0, x1
        movV y0, y1

        ; x1 -= 2*pDrawPentagon_mid_dis
        mov ax, pDrawPentagon_mid_dis
        sub x1, ax
        sub x1, ax

        mov ax, pDrawPentagon_line_size
        sub y1, ax

        ; Se dibuja la linea
        pushs <pDrawPentagon_mid_dis, pDrawPentagon_line_size>
        call pBresenham
        pops <pDrawPentagon_line_size, pDrawPentagon_mid_dis>

        ; Calculos los puntos de
        ; la quinta linea
        movV x0, x1
        movV y0, y1

        mov ax, pDrawPentagon_mid_dis
        add x1, ax

        mov ax, pDrawPentagon_line_size
        sub y1, ax

        ; Se dibuja la linea
        pushs <pDrawPentagon_mid_dis, pDrawPentagon_line_size>
        call pBresenham
        pops <pDrawPentagon_line_size, pDrawPentagon_mid_dis>

        ; Se recupera el bp
        pop bp

        pop ax

        ret
    pPentagon endP

    pHexagon proc
        push ax

        ; Declaracion de variables
        pDrawHexagon_mid_dis   equ word ptr [bp-2]
        pDrawHexagon_line_size equ word ptr [bp-4]

        ; Reservar espacio
        push bp
        mov bp, sp
        sub bp, 4

        movV y1, y0

        ; if x0 <= x1
        mov ax, x0
        jmpifle ax, x1, pHexagon_x0_gend
            xchgV x0, x1
            xchgV y0, y1
        pHexagon_x0_gend:

        ; Se dibuja la linea
        call pBresenham

        mov ax, lastLineSize
        mov pDrawHexagon_line_size, ax

        ; mid_dis = lastLineSize / 2
        divide lastLineSize, 2

        mov pDrawHexagon_mid_dis, ax

        ; Calculos los puntos de
        ; la segunda linea
        ; x0 = x1
        ; y0 = y1
        movV x0, x1
        movV y0, y1

        ; y0 += lastLineSize
        mov ax, y1
        add ax, lastLineSize

        mov y1, ax

        ; x1 += pDrawHexagon_mid_dis
        mov ax, pDrawHexagon_mid_dis
        add x1, ax

        ; Se dibuja la linea
        pushs <pDrawHexagon_mid_dis, pDrawHexagon_line_size>
        call pBresenham
        pops <pDrawHexagon_line_size, pDrawHexagon_mid_dis>

        ; Calculos los puntos de
        ; la tercera linea
        movV x0, x1
        movV y0, y1

        ; x1 -= 2*pDrawHexagon_mid_dis
        mov ax, pDrawHexagon_mid_dis
        sub x1, ax

        ; y1 += line_size
        mov ax, pDrawHexagon_line_size
        add y1, ax

        ; Se dibuja la linea
        pushs <pDrawHexagon_mid_dis, pDrawHexagon_line_size>
        call pBresenham
        pops <pDrawHexagon_line_size, pDrawHexagon_mid_dis>

        ; Calculos los puntos de
        ; la cuarta linea
        movV x0, x1
        movV y0, y1

        ; x1 -= 2*pDrawHexagon_mid_dis
        mov ax, pDrawHexagon_line_size
        sub x1, ax

        ; Se dibuja la linea
        pushs <pDrawHexagon_mid_dis, pDrawHexagon_line_size>
        call pBresenham
        pops <pDrawHexagon_line_size, pDrawHexagon_mid_dis>

        ; Calculos los puntos de
        ; la quinta linea
        movV x0, x1
        movV y0, y1

        mov ax, pDrawHexagon_mid_dis
        sub x1, ax

        mov ax, pDrawHexagon_line_size
        sub y1, ax

        ; Se dibuja la linea
        pushs <pDrawHexagon_mid_dis, pDrawHexagon_line_size>
        call pBresenham
        pops <pDrawHexagon_line_size, pDrawHexagon_mid_dis>

        ; Calculos los puntos de
        ; la sexta linea
        movV x0, x1
        movV y0, y1

        mov ax, pDrawHexagon_mid_dis
        add x1, ax

        mov ax, pDrawHexagon_line_size
        sub y1, ax

        ; Se dibuja la linea
        pushs <pDrawHexagon_mid_dis, pDrawHexagon_line_size>
        call pBresenham
        pops <pDrawHexagon_line_size, pDrawHexagon_mid_dis>


        ; Se recupera el bp
        pop bp

        pop ax

        ret
    pHexagon endP

    ; D: Se encarga de dibujar un rectangulo
    ; N: Este no valida las entradas
    pRectangle proc
        pushs <x0, y0, x1, y1>

        ; Dibujamos la primera linea
        ; Se guarda el y1
        push y1

        movV y1, y0

        call pBresenham

        pop y1
        
        ; Dibujamos la segunda linea
        push x0

        movV x0, x1

        call pBresenham

        pop x0
        
        ; Dibujamos la tercera linea
        push y0

        ; y0 = y1
        movV y0, y1

        call pBresenham

        pop y0

        ; Dibujamos la cuarta linea
        push x1

        ; x1 = x0
        movV x1, x0

        call pBresenham

        pop x1

        pops <y1, x1, y0, x0>

        ret 
    pRectangle endP

    ; D: Dibuja un triangulo
    ; N: No valida las entradas
    pTriangle proc
        pushs <x0, y0, x1, y1, x2, y2>
        
        ; Se dibuja la primera linea
        call pBresenham

        ; Se dibuja la segunda linea
        pushs <x1, y1>

        movV x1, x2
        movV y1, y2

        call pBresenham

        ; Se dibuja la tercera linea
        pops <y1, x1>

        movV x0, x2
        movV y0, y2

        call pBresenham
        
        pops <y2, x2, y1, x1, y0, x0>

        ret
    pTriangle endP

    ; E: AH - ScanCode
    ; D: Se encarga de mover el cursor sobre el canvas
    pMoverCursor proc
        pushs <ax, bx, cx, dx>

        mov cx, cursorX
        mov dx, cursorY
        mov al, saved
        call pDrawPixel

        ; Tecla izquierda
        jmpifn ah, ARROW_LEFT, pMoverCursor_right
        sub cursorX, 0Ah
        jmp pMoverCursor_key_pressed

        ; Tecla derecha
        pMoverCursor_right:
        jmpifn ah, ARROW_RIGHT, pMoverCursor_up
        add cursorX, 0Ah
        jmp pMoverCursor_key_pressed

        ; Tecla arriba
        pMoverCursor_up:
        jmpifn ah, ARROW_UP, pMoverCursor_down
        sub cursorY, 0Ah
        jmp pMoverCursor_key_pressed

        ; Tecla abajo
        pMoverCursor_down:
        jmpifn ah, ARROW_DOWN, pMoverCursor_cleft
        add cursorY, 0Ah
        jmp pMoverCursor_key_pressed

        ; Tecla ctrl + izquierda
        pMoverCursor_cleft:
        jmpifn ah, CTRL_ARROW_LEFT, pMoverCursor_cright
        sub cursorX, 01h
        jmp pMoverCursor_key_pressed
        
        ; Tecla ctrl + derecha
        pMoverCursor_cright:
        jmpifn ah, CTRL_ARROW_RIGHT, pMoverCursor_cup
        add cursorX, 01h
        jmp pMoverCursor_key_pressed

        ; Tecla ctrl + arriba
        pMoverCursor_cup:
        jmpifn ah, CTRL_ARROW_UP, pMoverCursor_cdown
        sub cursorY, 01h
        jmp pMoverCursor_key_pressed

        ; Tecla ctrl + abajo
        pMoverCursor_cdown:
        jmpifn ah, CTRL_ARROW_DOWN, pMoverCursor_nokey
        add cursorY, 01h

        pMoverCursor_key_pressed:
        call pCorregirPos
        
        call pGetPixelColor
        mov saved, al

        pMoverCursor_nokey:

        pops <dx, cx, bx, ax>

        ret
    pMoverCursor endP

    ; D: Corrige la posicion x y del cursor si hace falta
    pCorregirPos proc

        ; X es menor que el limite lateral izquierdo
        jmpifg cursorX, INICIO_X, pCorregirPos_x_mayor
        mov cursorX, FINAL_X
        jmp pCorregirPos_ok

        ; X es mayor que el limite lateral derecho
        pCorregirPos_x_mayor:
        jmpifl cursorX, FINAL_X, pCorregirPos_y_menor
        mov cursorX, INICIO_X
        jmp pCorregirPos_ok

        ; Y es menor que el limite superior
        pCorregirPos_y_menor:
        jmpifg cursorY, INICIO_Y, pCorregirPos_y_mayor
        mov cursorY, FINAL_Y
        jmp pCorregirPos_ok
        
        ; Y es menor que el limite inferior
        pCorregirPos_y_mayor:
        jmpifl cursorY, FINAL_Y, pCorregirPos_ok
        mov cursorY, INICIO_Y

        pCorregirPos_ok:

        ret
    pCorregirPos endP

    ; E: AH - Scan Code
    ; D: Basado en las teclas F determina el 
    ;    tool selected
    pFKeys proc
        
        jmpifn ah, F1_KEY, pFKeys_f2
            movV toolSelected, COD_PIXEL
            jmp pFKeys_fclear
        pFKeys_f2:
            jmpifn ah, F2_KEY, pFKeys_f3
            movV toolSelected, COD_LINE
            jmp pFKeys_fclear
        pFKeys_f3:
            jmpifn ah, F3_KEY, pFKeys_f4
            movV toolSelected, COD_RECTANGLE
            jmp pFKeys_fclear
        pFKeys_f4:
            jmpifn ah, F4_KEY, pFKeys_f5
            movV toolSelected, COD_SQUARE
            jmp pFKeys_fclear
        pFKeys_f5:
            jmpifn ah, F5_KEY, pFKeys_f6
            movV toolSelected, COD_SCALENE
            jmp pFKeys_fclear
        pFKeys_f6:
            jmpifn ah, F6_KEY, pFKeys_f7
            movV toolSelected, COD_ISOSCELES
            jmp pFKeys_fclear
        pFKeys_f7:
            jmpifn ah, F7_KEY, pFKeys_f8
            movV toolSelected, COD_EQUILATERO
            jmp pFKeys_fclear
        pFKeys_f8:
            jmpifn ah, F8_KEY, pFKeys_f9
            movV toolSelected, COD_PENTAGON
            jmp pFKeys_fclear
        pFKeys_f9:
            jmpifn ah, F9_KEY, pFKeys_fend
            movV toolSelected, COD_HEXAGON
        
        pFKeys_fclear:
            movV x0, -1
            movV y0, -1
            movV x1, -1
            movV y1, -1
            movV x2, -1
            movV y2, -1
        pFKeys_fend:

        ret
    pFKeys endP

    ; E: AH - Scan Code
    ; D: Se encarga de decidir que hacer
    ;    con los eventos de teclado
    pController proc
        jmpifn toolSelected, COD_PIXEL, pController_line
            call pDrawPoint
            jmp pController_end
        pController_line:
        jmpifn toolSelected, COD_LINE, pController_rectangle
            call pDrawLine
            jmp pController_end
        pController_rectangle:
        jmpifn toolSelected, COD_RECTANGLE, pController_square
            call pDrawRectangle
            jmp pController_end
        pController_square:
        jmpifn toolSelected, COD_SQUARE, pController_scalene
            call pDrawSquare
            jmp pController_end
        pController_scalene:
        jmpifn toolSelected, COD_SCALENE, pController_isosceles
            call pDrawScalene
            jmp pController_end
        pController_isosceles:
        jmpifn toolSelected, COD_ISOSCELES, pController_equilatero
            call pDrawIsosceles
            jmp pController_end
        pController_equilatero:
        jmpifn toolSelected, COD_EQUILATERO, pController_pentagon
            call pDrawEquilatero
            jmp pController_end
        pController_pentagon:
        jmpifn toolSelected, COD_PENTAGON, pController_hexagon
            call pDrawPentagon
            jmp pController_end
        pController_hexagon:
        jmpifn toolSelected, COD_HEXAGON, pController_end
            call pDrawHexagon
            jmp pController_end
        pController_end:

        ret
    pController endP

    ; Dibuja un punto en la posicion actual del cursor
    ; Nota: La diferencia con pDrawPixel es que este 
    ;       permite mantener el color sobre la pantalla
    pDrawPoint proc
        pushs <ax, cx, dx>

        mov cx, cursorX
        mov dx, cursorY

        mov al, cursorColor
        mov saved, al

        call pDrawPixel

        pops <dx, cx, ax>

        ret
    pDrawPoint endP

    ; ------------------------
    ; Render
    ; ------------------------
    
    ; D: Activa el modo grafico 
    ;    en 640x480px 16 colores
    pModoGrafico proc
        push ax
        mov ah, 00h
        mov al, 12h

        int 10h

        pop ax

        ret
    pModoGrafico endP

    ; E: BH - Color
    ;    CL - Columna inicio
    ;    CH - Fila inicio
    ;    DL - Columna final
    ;    DH - Fila final
    ; D: Pinta ciertas columnas y filas
    pDraw proc
        pushs <ax, bx, cx, dx>
        mov ah, 06h
        mov al, 00h

        int 10h

        pops <dx, cx, bx, ax>
        ret
    pDraw endP

    ; E/S: N/A
    ; D: Renderiza la base
    pRenderBase proc
        pushs <bx, cx, dx>

        ; Pinta la pantalla de blanco
        mov bh, white

        mov cl, 00h
        mov ch, 00h

        mov dl, 80
        mov dh, 30

        call pDraw

        pops <dx, cx, bx>

        ret
    pRenderBase endP

    pRenderTools proc
        pushs <ax, bx, cx, dx, di, x0, y0, x1, y1, x2, y2>

        ; Pinta la barra de herramientas
        mov bh, darkGray

        mov cl, 00h
        mov ch, 00h

        mov dl, 4
        mov dh, 30

        call pDraw
        
        ; Dibujamos los colores
        mov cl, 00h
        mov dl, 4

        mov ch, 00h
        mov dh, 00h

        lea di, listColores
        pRenderTools_colors:
            mov bh, byte ptr [di]

            inc ch
            inc dh

            call pDraw

            inc di
            mov al, [di]
        jmpifn al, 00h, pRenderTools_colors

        ; Dibujamos las herramientas

        ; Herramienta pixel
        mov bh, lightGray
        mov cl, 00h
        mov dl, 4
        mov ch, 11
        mov dh, 11

        call pDraw

        mov dx, 185
        mov cx, 20
        mov al, cursorColor
        call pDrawPixel

        ; Herramienta linea
        mov x0, 10
        mov x1, 30
        mov y0, 200
        mov y1, 200

        call pBresenham

        ; Triangulo isosceles
        mov bh, lightGray
        mov cl, 00h
        mov dl, 4
        mov ch, 13
        mov dh, 13

        call pDraw

        mov x0, 15
        mov x1, 25
        mov x2, 20
        mov y0, 220
        mov y1, 220
        mov y2, 210

        call pTriangle

        ; Triangulo equilatero

        mov x0, 10
        mov x1, 20
        mov x2, 30
        mov y0, 240
        mov y1, 230
        mov y2, 240

        call pTriangle

        ; Triangulo escaleno
        mov bh, lightGray
        mov cl, 00h
        mov dl, 4
        mov ch, 15
        mov dh, 15

        call pDraw

        mov x0, 10
        mov x1, 30
        mov x2, 30
        mov y0, 245
        mov y1, 250
        mov y2, 245

        call pTriangle

        ; Rectangulo

        mov x0, 10
        mov x1, 30
        mov y0, 260
        mov y1, 270

        call pRectangle

        ; Cuadrado
        mov bh, lightGray
        mov cl, 00h
        mov dl, 4
        mov ch, 17
        mov dh, 17

        call pDraw

        mov x0, 15
        mov x1, 25
        mov y0, 275
        mov y1, 285

        call pRectangle

        ; Hexagono
        mov x0, 20
        mov x1, 25
        mov y0, 290
        mov y1, 290

        call pHexagon

        ; Pentagono
        mov bh, lightGray
        mov cl, 00h
        mov dl, 4
        mov ch, 19
        mov dh, 19

        call pDraw

        mov x0, 20
        mov x1, 25
        mov y0, 308
        mov y1, 308

        call pPentagon

        ; Poligono libre
        mov x0, 10
        mov x1, 30
        mov y0, 323
        mov y1, 327

        call pBresenham
        mov x0, 30
        mov x1, 20
        mov y0, 327
        mov y1, 330

        call pBresenham

        pops <y2, x2, y1, x1, y0, x0, di, dx, cx, bx, ax>

        ret 
    pRenderTools endP

    ; E: DX - Coordenada Y
    ;    CX - Coordenada X
    ;    AL - Color
    ; D: Permite dibujar un pixel en pantalla
    pDrawPixel proc
        pushs <ax, bx, cx, dx>
        clean <bx>

        mov ah, 0Ch

        int 10h

        pops <dx, cx, bx, ax>

        ret
    pDrawPixel endP

    ; D: Se encarga de dibujar una linea
    pDrawLine proc
        push ax

        ; si x0 es -1, se establece el primer punto
        mov ax, x0
        jmpifn ax, -1, pDrawLine_x0_nz
            ; x0 = cursorX
            movV x0, cursorX

            ; y0 = cursorY
            movV y0, cursorY

            jmp pDrawLine_x0_endif
        pDrawLine_x0_nz:
            ; x1 = cursorX
            movV x1, cursorX

            ; y1 = cursorY
            movV y1, cursorY

            ; Se dibuja la linea
            call pBresenham

            ; y0 = 0 : x0 = 0
            ; y1 = 0 : x1 = 0
            mov y0, -1
            mov x0, -1
            mov y1, -1
            mov x1, -1
        pDrawLine_x0_endif:

        pop ax

        ret
    pDrawLine endP

    ; E: x0 - X Inicial
    ;    y0 - Y Inicial
    ;    x1 - X Final
    ;    y1 - Y Final
    ; D: Dibuja un rectangulo en pantalla
    ; N: Este valida las entradas
    pDrawRectangle proc
        push ax

        ; si x0 es -1, se establece el primer punto
        mov ax, x0
        jmpifn ax, -1, pDrawRectangle_x0_nz
            ; x0 = cursorX
            movV x0, cursorX

            ; y0 = cursorY
            movV y0, cursorY

            jmp pDrawRectangle_x0_endif
        pDrawRectangle_x0_nz:
            ; x1 = cursorX
            movV x1, cursorX

            ; y1 = cursorY
            movV y1, cursorY

            call pRectangle

            ; y0 = -1 : x0 = -1
            ; y1 = -1 : x1 = -1
            mov y0, -1
            mov x0, -1
            mov y1, -1
            mov x1, -1
        pDrawRectangle_x0_endif:

        pop ax

        ret
    pDrawRectangle endP

    ; D: Se encarga de dibujar un cuadrado
    pDrawSquare proc 
        push ax

        ; Inicializacion de variables
        pDrawSquare_dis equ word ptr [bp-2]

        ; Reservar espacio
        push bp
        mov bp, sp

        sub bp, 2

        ; si x0 es -1, se establece el primer punto
        mov ax, x0
        jmpifn ax, -1, pDrawSquare_x0_nz
            ; x0 = cursorX
            movV x0, cursorX

            ; y0 = cursorY
            movV y0, cursorY

            jmp pDrawSquare_x0_endif
        pDrawSquare_x0_nz:
            ; x1 = cursorX
            movV x1, cursorX

            ; y1 = cursorY
            movV y1, cursorY

            ; Distancia entre x0 y x1
            ; ax = abs(x0 - x1)
            mov ax, x0
            sub ax, x1

            absolute ax

            mov pDrawSquare_dis, ax

            ; Agregamos el lado a la altura
            mov ax, y0
            add ax, pDrawSquare_dis

            mov y1, ax

            ; Si se pasa del limite lo movemos
            ; hacia arriba
            mov ax, y1
            jmpifle ax, FINAL_Y, pDrawSquare_ok
                mov ax, y0
                sub ax, pDrawSquare_dis
                mov y1, ax
            pDrawSquare_ok:
            
            ; Dibujamos el cuadrado
            call pRectangle

            ; y0 = -1 : x0 = -1
            ; y1 = -1 : x1 = -1
            mov y0, -1
            mov x0, -1
            mov y1, -1
            mov x1, -1

            ; Dibujamos sobre la posicion del mouse
            ; Dibujamos porque el mouse le cae encima
            mov al, cursorColor
            mov saved, al
        pDrawSquare_x0_endif:

        ; Se recupera el bp
        pop bp

        pop ax

        ret
    pDrawSquare endP

    ; D: Dibuja un triangulo isosceles
    pDrawIsosceles proc 
        push ax

        ; Inicializacion de variables
        pDrawIsosceles_dis equ word ptr [bp-2]

        ; Reservar espacio
        push bp
        mov bp, sp

        sub bp, 2

        ; Logica del programa

        ; si x0 es -1, se establece el primer punto
        mov ax, x0
        jmpifn ax, -1, pDrawIsosceles_x0_nz
            ; x0 = cursorX
            movV x0, cursorX

            ; y0 = cursorY
            movV y0, cursorY

            jmp pDrawIsosceles_x0_endif
        pDrawIsosceles_x0_nz:
            ; x1 = cursorX
            movV x1, cursorX

            ; y1 = cursorY
            movV y1, cursorY

            ; y2 = y1
            movV y2, y1

            ; Calculamos la distancia
            ; dis = abs(x1 - x0)
            mov ax, x1
            sub ax, x0

            absolute ax

            mov pDrawIsosceles_dis, ax

            ; if x0 <= x1
            mov ax, x0
            jmpifg ax, x1, pDrawIsosceles_x0_great
                mov ax, x0
                sub ax, pDrawIsosceles_dis

                mov x2, ax

                jmp pDrawIsosceles_x0_gend
            pDrawIsosceles_x0_great:                
                mov ax, x0
                add ax, pDrawIsosceles_dis

                mov x2, ax

            pDrawIsosceles_x0_gend:

            call pTriangle

            ; y0 = 0 : x0 = 0
            ; y1 = 0 : x1 = 0
            ; y2 = 0 : x2 = 0
            mov y0, -1
            mov x0, -1
            mov y1, -1
            mov x1, -1
            mov y2, -1
            mov x2, -1
        pDrawIsosceles_x0_endif:

        ; Se recupera el bp
        pop bp

        pop ax

        ret
    pDrawIsosceles endP

    ; D: Dibuja un triangulo equilatero
    pDrawEquilatero proc
        push ax

        ; si x0 es -1, se establece el primer punto
        mov ax, x0
        jmpifn ax, -1, pDrawEquilatero_x0_nz
            ; x0 = cursorX
            movV x0, cursorX

            ; y0 = cursorY
            movV y0, cursorY

            jmp pDrawEquilatero_x0_endif
        pDrawEquilatero_x0_nz:
            ; x1 = cursorX
            movV x1, cursorX

            ; y1 = cursorY
            movV y1, cursorY

            ; y2 = y1
            movV y2, y1

            call pBresenham

            ; if x0 <= x1
            mov ax, x0
            jmpifg ax, x1, pDrawEquilatero_x0_great
                ; x2 = x1 - lastLineSize
                mov ax, x1
                sub ax, lastLineSize

                absolute ax

                mov x2, ax

                jmp pDrawEquilatero_x0_gend
            pDrawEquilatero_x0_great:
                ; x2 = x1 + lastLineSize
                mov ax, x1
                add ax, lastLineSize

                mov x2, ax
            pDrawEquilatero_x0_gend:

            ; Dibujamos la segunda linea
            pushs <x1, y1>

            movV x1, x2
            movV y1, y2

            call pBresenham

            pops <y1, x1>       

            ; Dibujamos la tercera linea
            movV x0, x2
            movV y0, y2

            call pBresenham     

            ; Dibujamos sobre la posicion del mouse
            ; Dibujamos porque el mouse le cae encima
            mov al, cursorColor
            mov saved, al

            ; y0 = 0 : x0 = 0
            ; y1 = 0 : x1 = 0
            ; y2 = 0 : x2 = 0
            mov y0, -1
            mov x0, -1
            mov y1, -1
            mov x1, -1
            mov y2, -1
            mov x2, -1
        pDrawEquilatero_x0_endif:

        pop ax

        ret
    pDrawEquilatero endP

    ; Dibuja un triangulo escaleno
    pDrawScalene proc
        push ax

        ; si x0 es -1, se establece el primer punto
        mov ax, x0
        jmpifn ax, -1, pDrawScalene_x0_nz
            ; x0 = cursorX
            movV x0, cursorX

            ; y0 = cursorY
            movV y0, cursorY

            jmp pDrawScalene_x1_endif
        pDrawScalene_x0_nz:
        mov ax, x1
        jmpifn ax, -1, pDrawScalene_x1_nz
            ; x1 = cursorX
            movV x1, cursorX

            ; y1 = cursorY
            movV y1, cursorY

            jmp pDrawScalene_x1_endif
        pDrawScalene_x1_nz:
            ; x1 = cursorX
            movV x2, cursorX

            ; y1 = cursorY
            movV y2, cursorY

            call pTriangle

            ; Dibujamos sobre la posicion del mouse
            ; Dibujamos porque el mouse le cae encima
            mov al, cursorColor
            mov saved, al

            ; y0 = 0 : x0 = 0
            ; y1 = 0 : x1 = 0
            ; y2 = 0 : x2 = 0
            mov y0, -1
            mov x0, -1
            mov y1, -1
            mov x1, -1
            mov y2, -1
            mov x2, -1
        pDrawScalene_x1_endif:

        pop ax

        ret
    pDrawScalene endP
    
    ; E: AH - Scan code
    ; Dibuja un poligono libre
    pPolygon proc
        push ax

        jmpifn ah, 1Ch, pPolygon_nenter
            movV x1, -1
            movV y1, -1
            movV x0, -1
            movV y0, -1
            jmp pPolygon_x0_endif
        pPolygon_nenter:

        ; si x0 es -1, se establece el primer punto
        mov ax, x0
        jmpifn ax, -1, pPolygon_x0_nz
            ; x0 = cursorX
            movV x0, cursorX

            ; y0 = cursorY
            movV y0, cursorY

            jmp pPolygon_x0_endif
        pPolygon_x0_nz:
            ; x1 = cursorX
            movV x1, cursorX

            ; y1 = cursorY
            movV y1, cursorY

            ; Se dibuja la linea
            call pBresenham

            ; y0 = y1 : x0 = x1
            movV x0, x1
            movV y0, y1
            mov y1, -1
            mov x1, -1
        pPolygon_x0_endif:

        pop ax

        ret
    pPolygon endP

    ; Dibuja un pentagono
    pDrawHexagon proc
        push ax
        
        ; Logica del programa

        ; si x0 es -1, se establece el primer punto
        mov ax, x0
        jmpifn ax, -1, pDrawHexagon_x0_nz
            ; x0 = cursorX
            movV x0, cursorX

            ; y0 = cursorY
            movV y0, cursorY

            jmp pDrawHexagon_x0_endif
        pDrawHexagon_x0_nz:
            ; x1 = cursorX
            movV x1, cursorX

            ; y1 = cursorY
            movV y1, cursorY

            call pHexagon

            ; y0 = 0 : x0 = 0
            ; y1 = 0 : x1 = 0
            mov y0, -1
            mov x0, -1
            mov y1, -1
            mov x1, -1
        pDrawHexagon_x0_endif:

        pop ax

        ret
    pDrawHexagon endP

    ; Dibuja un pentagono
    pDrawPentagon proc
        push ax

        ; si x0 es -1, se establece el primer punto
        mov ax, x0
        jmpifn ax, -1, pDrawPentagon_x0_nz
            ; x0 = cursorX
            movV x0, cursorX

            ; y0 = cursorY
            movV y0, cursorY

            jmp pDrawPentagon_x0_endif
        pDrawPentagon_x0_nz:
            ; x1 = cursorX
            movV x1, cursorX

            ; y1 = cursorY
            movV y1, cursorY

            call pPentagon

            ; y0 = 0 : x0 = 0
            ; y1 = 0 : x1 = 0
            mov y0, -1
            mov x0, -1
            mov y1, -1
            mov x1, -1
        pDrawPentagon_x0_endif:

        pop ax

        ret
    pDrawPentagon endP

    ; D: Se encarga de renderizar la posicion actual del mouse
    pRenderCursor proc
        pushs <ax, cx, dx>

        mov dx, cursorY
        mov cx, cursorX

        mov al, cursorColor

        call pDrawPixel

        pops <dx, cx, ax>
        
        ret
    pRenderCursor endP

    ; Esta funcion se encarga de renderizar todo
    pRun proc
        call pRenderBase
        call pRenderTools
        pRun_running:
            call pRenderCursor
            call pKeyPressed
            call pMoverCursor

            ; -----------------------------
            ; Deteccion de eventos
            ; -----------------------------
            call pFkeys

            ; -----------------------------
            ; Evento de dibujar
            ; -----------------------------
            jmpif ah, SPACE_BAR, pRun_event_ok
            jmpifn ah, ENTER_KEY, pRun_end_event
            pRun_event_ok:
            call pController
            jmp pRun_ok

            ; -----------------------------
            ; Evento de terminar
            ; -----------------------------
            pRun_end_event:
            jmpif ah, SCAPE, pRun_ended
            call pDelay
            pRun_ok: jmp pRun_running
        pRun_ended:

        ret
    pRun endP

    inicio: 
        call pModoGrafico

        call pRun

        mov ax, 4C00h    ; protocolo de finalización del programa.
        int 21h

todo ends

end start
