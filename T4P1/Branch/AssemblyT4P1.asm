


; PROJETO DE PROCESSADORES - ELC 1094 - PROF. CARARA
; PROCESSADOR R8
; CARLOS GEWEHR E EMILIO FERREIRA

; DESCRIÇÃO:
; PROCESSADOR R8 COM SUPORTE A INTERRUPÇÕES DE I/O

; APLICAÇÃO ATUAL:
; COMUNICAÇAO COM PERIFERICO "CRYPTOMESSAGE" VIA INTERRUPÇÃO

; CHANGELOG:
; v0.1 (Gewehr) - 06/05/2019 : Implementada logica de tratamento de interrupção
; v0.2 (Gewehr) - 07/05/2019 : Implementadas subrotinas GeraACK e LeCaracter

; TODO: (as of v0.2)
;  - Implementar subrotinas :  CalculaMagicNumberR8, CalculaCryptoKey

; OBSERVAÇÕES:
;   - O parametro ISR_ADDR deve ser setado para 0x"0001" na instanciação do processador na entity top level
;   - Respeitar o padrão de registradores estabelecidos
;   - Novas adições ao código deve ser o mais modular possível
;   - Subrotinas importantes devem começar com letra maiuscula
;   - Subrotinas auxiliares devem começar com letra minuscula e serem identada com 2 espaços
;   - Instruções devem ser identadas com 4 espaços

; REGISTRADORES:
; --------------------- r0  = 0
; --------------------- r2  = PARAMETRO para subrotina
; --------------------- r3  = PARAMETRO para subrotina
; --------------------- r14 = Retorno de subrotina
; --------------------- r15 = Retorno de subrotina

;////////////////////////////////////////////////////////////////////////////////////////////////////////////
; port_io[15] = data[7] (in/out)
; port_io[14] = data[6] (in/out)
; port_io[13] = data[5] (in/out)
; port_io[12] = data[4] (in/out)
; port_io[11] = data[3] (in/out)
; port_io[10] = data[2] (in/out)
; port_io[9]  = data[1] (in/out)
; port_io[8]  = data[0] (in/out)

; port_io[7] = Direção dos bits de dados (dataDD) (15 a 8) , 1 = entrada, 0 = saida (out)

; port_io[6] = Não utilizado (x)
; port_io[5] = Não utilizado (x)
; port_io[4] = Não utilizado (x)

; port_io[3] = data_av     (in)
; port_io[2] = keyExchange (in)
; port_io[1] = ack         (out)
; port_io[0] = eom         (in)

.org #0000h

.code

;-----------------------------------------------------BOOT---------------------------------------------------

    jmpd #setup                               ;Sempre primeira instrução do programa
    jmpd #InterruptionServiceRoutine          ;Sempre segunda instrução do programa

;---------------------------------------------CONFIGURAÇÃO INICIAL-------------------------------------------

setup:

;   Inicializa ponteiro da pilha para 0x"7FFF" (ultimo endereço no espaço de endereçamento da memoria
    ldh r0, #7Fh
    ldl r0, #FFh
    ldsp r0

;   Inicialização dos registradores
    xor r0, r0, r0
    xor r1, r1, r1
    xor r2, r2, r2
    xor r3, r3, r3
    xor r4, r4, r4
    xor r5, r5, r5
    xor r6, r6, r6
    xor r7, r7, r7
    xor r8, r8, r8
    xor r9, r9, r9
    xor r10, r10, r10
    xor r11, r11, r11
    xor r12, r12, r12
    xor r13, r13, r13
    xor r13, r13, r13
    xor r14, r14, r14
    xor r15, r15, r15

;   r1 <= &arrayPorta
    ldh r1, #arrayPorta ; Carrega &Porta
    ldl r1, #arrayPorta ; Carrega &Porta
    ld r1, r0, r1

;   Seta PortConfig
    ldl r4, #01h   ; Atualiza indexador de arrayPorta [ arrayPorta[r4] -> &PortConfig ]
    ldh r5, #FFh   ; r5 <= "11111111_00001101"
    ldl r5, #0Dh   ; bits 15 a 8 inicialmente são entrada, espera keyExchange
    st r5, r1, r4  ; PortConfig <= "11111111_0xxx1101"

;   Seta irqtEnable
    ldl r4, #03h   ; Atualiza indexador de arrayPorta [ arrayPorta[r4] -> &irqtEnable ]
    ldh r5, #00h   ; r5 <= "00000000_00000100"
    ldl r5, #04h   ; Habilita a interrupção no bit 2 (keyExchange)
    st r5, r1, r4  ; irqtEnable <= "00000000_0xxx0100"

;   Seta dataDD como '1', ack como '0'
    ldl r4, #0     ; Atualiza indexador de arrayPorta [ arrayPorta[r4] -> &PortData ]
    ldh r5, #00h   ; r5 <= "00000000_10000100"
    ldl r5, #80h   ; dataDD = '1', ACK = '0'
    st r5, r1, r4  ; portData <= "xxxxxxxx_1xxxxx0x"

;   Seta PortEnable
    ldl r4, #02h   ; Atualiza indexador de arrayPorta [ arrayPorta[r4] -> &PortEnable ]
    ldh r5, #FFh   ; r5 <= "11111111_10001111"
    ldl r5, #8Fh   ; Habilita acesso a todos os bits da porta de I/O, menos bits 6 a 4
    st r5, r1, r4  ; PortEnable <= "11111111_10001111"

    jmpd #main

;------------------------------------------- PROGRAMA PRINCIPAL ---------------------------------------------

main:

;; BUBBLE SORT DO CARARA

;* Bubble sort

;*      Sort array in ascending order
;*
;*      Used registers:
;*          r1: points the first element of array
;*          r2: temporary register
;*          r3: points the end of array (right after the last element)
;*          r4: indicates elements swaping (r4 = 1)
;*          r5: array index
;*          r6: array index
;*          r7: element array[r5]
;*          r8: element array[r8]
;*
;*********************************************************************

BubbleSort:

    ; Initialization code
    xor r0, r0, r0          ; r0 <- 0

    ldh r1, #arraySort      ;
    ldl r1, #arraySort      ; r1 <- &array

    ldh r2, #arraySortSize  ;
    ldl r2, #arraySortSize  ; r2 <- &size
    ld r2, r2, r0           ; r2 <- size

    add r3, r2, r1          ; r3 points the end of array (right after the last element)

    ldl r4, #0              ;
    ldh r4, #1              ; r4 <- 1

; Main code
scan:
    addi r4, #0             ; Verifies if there was element swapping
    jmpzd #end              ; If r4 = 0 then no element swapping

    xor r4, r4, r4          ; r4 <- 0 before each pass

    add r5, r1, r0          ; r5 points the first array element

    add r6, r1, r0          ;
    addi r6, #1             ; r6 points the second array element

; Read two consecutive elements and compares them
loop:
    ld r7, r5, r0           ; r7 <- array[r5]
    ld r8, r6, r0           ; r8 <- array[r6]
    sub r2, r8, r7          ; If r8 > r7, negative flag is set
    jmpnd #swap             ; (if array[r5] > array[r6] jump)

; Increments the index registers and verifies if the pass is concluded
continue:
    addi r5, #1             ; r5++
    addi r6, #1             ; r6++

    sub r2, r6, r3          ; Verifies if the end of array was reached (r6 = r3)
    jmpzd #scan             ; If r6 = r3 jump
    jmpd #loop              ; else, the next two elements are compared

; Swaps two array elements (memory)
swap:
    st r7, r6, r0           ; array[r6] <- r7
    st r8, r5, r0           ; array[r5] <- r8
    ldl r4, #1              ; Set the element swapping (r4 <- 1)
    jmpd #continue

end:
    halt                    ; Suspend the execution


;------------------------------------------------SUBROTINAS--------------------------------------------------

; CalculaMagicNumberR8:    DEBUG
; CalculaCryptoKey:        DEBUG
; GeraACK:                    DONE
; LeCaracter:                 DONE

CalculaMagicNumberR8: ; Retorna em r14 o magicNumber do processador


    ; MagicNumberR8 = a^x * mod q	
    ; MagicNumberR8 = 6^x * mod 251

    push r4 ; 251
    push r5 ; x ou Seed
    push r6 ; 6
    push r7 ; Mascara de bit (overflow)
    push r12 ; Temporario
    push r13 ; Temporario

    xor r14, r14, r14 ; Zera o valor de retorno
    addi r14, #01 ; Retorno <= 1

    ldh r4, #00h
    ldl r4, #FBh ; r4 < 251

    ; Carrega a seed
    ldh r5, #contadorMSGS
    ldl r5, #contadorMSGS
    ld r5, r0, r5 ; Carrega o Valor do Contador msg para r5

    ldh r6, #00h
    ldl r6, #06h ; carreaga Seis

    ldh r7, #00h
    ldl r7, #80h ; Mascara [ 0000 0000 1000 0000]

    ; Verifica se a seed é menor que 251
    sub r6, r4, r5   ; Realiza (251 - Seed )
    jmpnd #SeedInvalida
    jmpzd #SeedInvalida  ; caso a seed for Negativa ou Zero

    addi r14, #00h ; R14 deve estar igual a 1
    jmpd #calculoExponencial

SeedInvalida:
    xor r6, r6, r6 ; Zera a Seed
    jmpd #calculoExponencial
	
calculoExponencial: ; DEBUG - r14 sendo atualizado com r6

    jmpzd #retornaMagicNumber

    mul r14, r14
    mfl r14 ;   r14 <= r14^2

    div r14, r4
    mfh r14 ; r14 <= r14^2 mod q
	
    and r13, r7, r5 ; Comparacao da mascara

    jmpzd #shiftAndJump

calculoMod:
    mul r14, r6
    mfl r14 ; r14 <= r14 * 6
    div r14, r4
    mfh r14 ; r14 <= r14 * 6 mod 251

shiftAndJump:
    sr0  r7, r7 ; Shift da mascara
    jmpd #calculoExponencial


retornaMagicNumber:
    push r13
    push r12
    push r6
    push r5
    push r4
    rts


CalculaCryptoKey:     ; Retorna em r14 chave criptografica, recebe em r2 magic number do periferico
	
	; Se da pelo calculo de Key = magicNumber mod q
	
	push r3 ; 251
	
	ldh r3, #00h
	ldl r3, #FBh  ; r3 <= 251
	
	div r2, r3 
	mfh r14 ; r14 <= r2( Magic Number ) mod r3 ( q ( 251 ) )
	
	jmpd #retornaCalculaCryptoKey
	
retornaCalculaCryptoKey:

	pop r3
	rts
	
	

GeraACK:              ; Envia ack

    push r1
    push r5
    push r6

    xor r0, r0, r0
    xor r1, r1, r1
    xor r5, r5, r5
    xor r6, r6, r6

;   r1 <= &portData
    ldh r1, #arrayPorta ; Carrega &Porta
    ldl r1, #arrayPorta ; Carrega &Porta
    ld r1, r0, r1       ; Carrega &portData

;   r5 <= dataDD = '1', ACK = '1'
    ldh r5, #00h
    ldh r5, #12h

;   r6 <= dataDD = '1', ACK = '0'
    ldh r5, #00h
    ldh r5, #10h

;   portData <= dataDD = '1', ACK = '1'
    st r5, r1, r0

;   portData <= dataDD = '1', ACK = '0''
    st r6, r1, r0

    pop r6
    pop r5
    pop r1

    rts

LeCaracter:           ; Le caracter atual da porta, salva nos arrays, incrementa ponteiro p/ arrays

    push r1
    push r4
    push r5
    push r6

    xor r0, r0, r0
    xor r1, r1, r1
    xor r4, r4, r4
    xor r5, r5, r5
    xor r6, r6, r6

;   r1 <= &portData
    ldh r1, #arrayPorta ; Carrega &Porta
    ldl r1, #arrayPorta ; Carrega &Porta
    ld r1, r0, r1       ; Carrega &portData

;   r5 <= PortData
    ld r5, r0, r1

;   Shifta até LSB do dado estar no bit 0
    sr0 r5, r5 ; LSB @ 7
    sr0 r5, r5 ; LSB @ 6
    sr0 r5, r5 ; LSB @ 5
    sr0 r5, r5 ; LSB @ 4
    sr0 r5, r5 ; LSB @ 3
    sr0 r5, r5 ; LSB @ 2
    sr0 r5, r5 ; LSB @ 1
    sr0 r5, r5 ; LSB @ 0

;   Salva caracter no vetor de dados criptografados
    ldh r1, #arrayEncrypted
    ldl r1, #arrayEncrypted

    ldh r4, #arrayCryptoPointer
    ldl r4, #arrayCryptoPointer

    st r5, r1, r4 ; arrayEncrypted[r4] = Caracter criptografado

;   Carrega chave de criptografia
    ldh r6, #cryptoKey
    ldl r6, #cryptoKey
    ld r6, r0, r6

;   Descriptografa dado
    xor r5, r6, r5

;   Zera bit não relevantes
    ldh r6, #0
    ldh r6, #FFh
    and r5, r5, r6

;   Salva caracter no vetor de dados descriptografados
    ldh r1, #arrayDecrypted
    ldl r1, #arrayDecrypted

    st r5, r1, r4 ; arrayDecrypted[r4] = Caracter descriptografado

;   Incrementa ponteiro dos vetores
    ldh r1, #arrayCryptoPointer
    ldl r1, #arrayCryptoPointer
    ld r5, r0, r1

    addi r5, #1

    st r5, r0, r1

    pop r6
    pop r5
    pop r4
    pop r1

    rts
;-----------------------------------------TRATAMENTO DE INTERRUPÇÃO------------------------------------------

InterruptionServiceRoutine:

; 1. Salvamento de contexto
; 2. Verificação da origem da interrupção (polling) e salto para o driver correspondente (jsr)
; 3. Recuperação de contexto
; 4. Retorno (rti)

;////////////////////////////////////////////////////////////////////////////////////////////////////////////

; port_io[15] = data[7] (in/out)
; port_io[14] = data[6] (in/out)
; port_io[13] = data[5] (in/out)
; port_io[12] = data[4] (in/out)
; port_io[11] = data[3] (in/out)
; port_io[10] = data[2] (in/out)
; port_io[9]  = data[1] (in/out)
; port_io[8]  = data[0] (in/out)

; port_io[7] = Direção dos bits de dados (dataDD) (15 a 8) , 1 = entrada, 0 = saida (out)

; port_io[6] = Não utilizado (x)
; port_io[5] = Não utilizado (x)
; port_io[4] = Não utilizado (x)

; port_io[3] = data_av (in)
; port_io[2] = keyExchange (in)
; port_io[1] = ack (out)
; port_io[0] = eom (in)

; Interrupção pode ser gerada por bit 15 e bit 14

;   Salva contexto
    push r0
    push r1
    push r2
    push r3
    push r4
    push r5
    push r6
    push r7
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
    pushf

    xor r0, r0, r0
    xor r4, r4, r4
    xor r5, r5, r5
    xor r6, r6, r6

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; LEITURA DO DADO DA PORTA, NAO MUDAR ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;   r1 <= &PortData
    ldh r1, #arrayPorta
    ldl r1, #arrayPorta
    ld r1, r0, r1

;   r5 <= PortData
    ld r5, r0, r1

 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; LEITURA DO DADO DA PORTA, NAO MUDAR ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;   Carrega mascara de comparação para bit 2
    ldh r1, #00h
    ldl r1, #04h

;   Se operação com mascara resultar em 0, interrupção for gerada por bit 2
    and r6, r1, r5
    sub r6, r6, r1
    jmpzd #callDriverBit2

  returnCallDriverBit2:


;   ADICIONAR AQUI TRATAMENTO PARA NOVOS GERADORES DE INTERRUPÇÃO




;   Recupera contexto
    popf
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop r7
    pop r6
    pop r5
    pop r4
    pop r3
    pop r2
    pop r1
    pop r0

    rti

;--------------------------------------------------DRIVERS---------------------------------------------------

;;;;;;;; CHAMADAS P/ DRIVERS

callDriverBit2:
;   bit 2 = keyExchange
    jsrd #driverKeyExchange
    jmpd #returnCallDriverBit2

;;;;;;;;; DRIVERS

driverKeyExchange:

; 1. CryptoMessage ativa keyExchange e coloca no barramento data_out seu magicNumber
; 2. R8 lê o magicNumber e calcula o seu magicNumber
; 3. R8 coloca o seu magicNumber no barramento data_in do CryptoMessage e gera um pulso em ack. Feito isso, ambos calculam a chave criptografica.
; 4. CryptoMessage coloca um caracter da mensagem criptografado no barramento data_out e ativa data_av
; 5. R8 lê o caracter e gera um pulso em ack

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; ESTADO 1 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push r1
    push r5
    push r6

    xor r0, r0, r0
    xor r1, r1, r1
    xor r5, r5, r5
    xor r6, r6, r6

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; ESTADO 2 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;   r1 <= &PortData
    ldh r1, #arrayPorta
    ldl r1, #arrayPorta
    ld r1, r0, r1

;   r5 <= PortData
    ld r5, r0, r1

;   Shifta até LSB do dado estar no bit 0
    sr0 r5, r5 ; LSB @ 7
    sr0 r5, r5 ; LSB @ 6
    sr0 r5, r5 ; LSB @ 5
    sr0 r5, r5 ; LSB @ 4
    sr0 r5, r5 ; LSB @ 3
    sr0 r5, r5 ; LSB @ 2
    sr0 r5, r5 ; LSB @ 1
    sr0 r5, r5 ; LSB @ 0

;   Carrega endereço da variavel magicNumberCryptoMessage
    ldh r1, #magicNumberCryptoMessage
    ldl r1, #magicNumberCryptoMessage

;   Salva magicNumber do periférico na variavel magicNumberCryptoMessage
    st r5, r0, r1

;   Calcula magicNumber do processador (dado disponivel em r14)
    jsrd #CalculaMagicNumberR8

;   Salva magicNumber do processador
    ldh r1, #magicNumberR8
    ldl r1, #magicNumberR8 ; r1 <= &magicNumberR8
    add r5, r0, r14        ; r5 <= magicNumberR8
    st r5, r0, r1          ; Salva magicNumberR8 em memoria

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; ESTADO 3 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;   Seta em portConfig a direção dos dados como saída
    ldh r1, #arrayPorta
    ldl r1, #arrayPorta
    addi r1, #1
    ld r1, r0, r1        ; r1 <= &portConfig

    ldh r5, #00h
    ldl r5, #0Dh         ; dataDD <= '0' (out), outros bits de configuração são mantidos (r5 <= "0xxx_1101")

    st r5, r0, r1        ; portConfig <= ("00000000_0xxx1101")

;   Prepara dado para escrita
    ldh r1, #magicNumberR8
    ldl r1, #magicNumberR8
    ld r5, r0, r1

;   Shifta magicNumberR8 até sua posição
    sl0 r5, r5 ; MSB @ 8
    sl0 r5, r5 ; MSB @ 9
    sl0 r5, r5 ; MSB @ 10
    sl0 r5, r5 ; MSB @ 11
    sl0 r5, r5 ; MSB @ 12
    sl0 r5, r5 ; MSB @ 13
    sl0 r5, r5 ; MSB @ 14
    sl0 r5, r5 ; MSB @ 15

;   Seta ack para '1', dataDD para '0' (saida)
    ldl r5, #02h ; r5 <= "(magicNumberR8)_0xxx_xx1x"

;   Carrega endereço de PortData
    ldh r1, #arrayPorta
    ldl r1, #arrayPorta
    ld r1, r0, r1        ; r1 <= &portData

;   Transmite p/ porta magicNumberR8, sinaliza dataDD = OUT, ack = '1'
    st r5, r0, r1 ; r5 <= "(magicNumberR8)_0xxx_xx1x"

;   Transmite ACK = '0'
    st r0, r0, r1

;   Seta bits de dados novamente como entrada
    ldh r1, #arrayPorta
    ldl r1, #arrayPorta
    addi r1, #1
    ld r1, r0, r1        ; r1 <= &portConfig

;   Seta bits de dados novamente como entrada
    ldh r5, #FFh
    ldl r5, #0Dh
    st r5, r0, r1        ; r5 <= "11111111_00001101"

;   Seta dataDD como entrada (dataDD = '1', ack = '0')
    ldh r1, #arrayPorta
    ldl r1, #arrayPorta
    ld r1, r0, r1        ; r1 <= &portData

    ldh r5, #FFh
    ldl r5, #10h
    st r5, r0, r1        ; r5 <= "xxxx_xxxx_1xxx_xx0x"

;   Seta argumento para calculo da chave criptografica (r2 <= magicNumberCryptoMessage)
    ldh r1, #magicNumberCryptoMessage
    ldl r1, #magicNumberCryptoMessage
    ld r2, r0, r1

;   Calcula chave criptografica
    jsrd #CalculaCryptoKey

;   Salva chave criptografica
    ldh r1, #cryptoKey
    ldl r1, #cryptoKey
    st r14, r0, r1       ; Salva chave criptografica em memoria

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; ESTADO 4 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

PollingLoop: ; Espera próximo sinal de data_av = '1'

;   r1 <= &PortData
    ldh r1, #arrayPorta
    ldl r1, #arrayPorta
    ld r1, r0, r1

;   r5 <= PortData
    ld r5, r0, r1

;   Carrega mascara de comparação para bit 3 (data_av)
    ldh r6, #00h
    ldl r6, #08h         ; r6 <= "00000000_00001000"

;   Se operação com mascara resultar em 0, coloca caracter no array criptografado e descriptografado
    and r6, r1, r5
    sub r6, r6, r1
    jmpzd #LeCaracter

;   Carrega mascara de comparação para bit 0 (eom)
    ldh r6, #00h
    ldl r6, #01h         ; r6 <= "00000000_00000001"

;   Se operação com mascara resultar em 0, retorna da subrotina de driver p/ ISR, else, espera novo caracter
    and r6, r1, r5
    sub r6, r6, r1
    jmpzd #returnPollingLoop

;   Gera ACK
    jsrd #GeraACK

    jmpd #PollingLoop

  returnPollingLoop:

;   Gera ACK
    jsrd #GeraACK

;   Incrementa contador de mensagens
    ldh r1, #contadorMSGS
    ldl r1, #contadorMSGS

;   r5 <= contadorMSGS
    ld r5, r0, r1

;   Compara contador com 251, se for igual, volta para 0, se nao, incrementa
    ldh r1, #00h
    ldl r1, #251

    and r6, r1, r5
    sub r6, r6, r1
    jmpzd #contadorMSGSld0

    addi r5, #1

    st r5, r0, r1

  returncontadorMSGSld0:

    pop r6
    pop r5
    pop r1

    rts

  contadorMSGSld0:
    xor r5, r5, r5
    jmpd #returncontadorMSGSld0

.endcode

.data

; array de registradores da Porta Bidirecional
; arrayPorta [ PortData(0x8000) | PortConfig(0x8001) | PortEnable(0x8002) | irqtEnable(0x8003) ]
arrayPorta:               db #8000h, #8001h, #8002h, #8003h

; Variaveis p/ criptografia
magicNumberR8:            db #0000h
magicNumberCryptoMessage: db #0000h
cryptoKey:                db #0000h
contadorMSGS:             db #0000h ; Novo seed para geração de magic number

; Array de 100 elementos para dados criptografados
arrayEncrypted: db #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h

; Array de 100 elementos para dados decriptografados
arrayDecrypted: db #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h

; Ponteiro para arrays de criptografia
arrayCryptoPointer: db #0000h

; Array para aplicação principal (Bubble Sort) de 50 elementos
arraySort: db #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h, #0000h

; Tamanho do array p/ bubble sort (50 elementos)
arraySortSize: db #50

.enddata
