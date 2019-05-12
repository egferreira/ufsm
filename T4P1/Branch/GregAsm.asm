.org #0000h             ; Code start

.code
; ----------------------- INICIALIZAÇÕES DAS PORTAS E ENDEREÇOS -------------------
boot:
	ldh r0, #03h
	ldl r0, #52h ;
	ldsp r0 ; SP <= 01AEh
	xor r0, r0, r0 ; r0 <= 0
	xor r7, r7, r7 ; retorno para as funções

	; PortA addresses
	ldh r1, #80h
	ldl r1, #00h ; PortDataA_ADDR
	ldh r2, #80h
	ldl r2, #01h ; PortConfigA_ADDR
	ldh r3, #80h
	ldl r3, #02h ; PortEnableA_ADDR

	; PortB addresses
	ldh r4, #90h
	ldl r4, #00h ; PortDataB_ADDR
	ldh r5, #90h
	ldl r5, #01h ; PortConfigB_ADDR
	ldh r6, #90h
	ldl r6, #02h ; PortEnableB_ADDR
	ldh r7, #90h
	ldl r7, #03h ; IRQ_ENABLE_ADDR

	ldh r15, #address_PortData_A
	ldl r15, #address_PortData_A
	st r1, r15, r0 ; address_PortData_A

	ldh r15, #address_PortData_B
	ldl r15, #address_PortData_B
	st r4, r15, r0 ; address_PortData_B

	ldh r15, #address_PortConfig_A
	ldl r15, #address_PortConfig_A
	st r2, r15, r0 ; address_PortData_A

	ldh r15, #address_PortConfig_B
	ldl r15, #address_PortConfig_B
	st r5, r15, r0 ; address_PortData_B

	ldh r15, #44h
	ldl r15, #FFh ; PortConfig <= 0100 0100 1111 1111
	st r15, r2, r0 ; PortConfigA <= 0111 0100 1111 1111

	ldh r15, #74h
	ldl r15, #FFh ; PortConfig <= 0111 0100 1111 1111
	st r15, r5, r0 ; PortConfigB <= 0111 0100 1111 1111

	st r0, r1, r0 ; PortData_A <= 0000h
	st r0, r4, r0 ; PortData_B <= 0000h

	ldh r15, #30h ; 00110000
	ldl r15, #00h ;
	st r15, r7, r0 ; irqEnable_PortB

	; enable PortA and PortB
	ldh r15, #CCh
	ldl r15, #FFh
	st r15, r3, r0 ; PortEnable_A <= 1100 1100 11111111
	ldh r15, #FCh
	st r15, r6, r0 ; PortEnable_B <= 1111 1100 11111111

	; RANDOM NUMBER INICIALIZATION
	ldh r15, #random_number
	ldl r15, #random_number
	xor r3, r3, r3 ; r3 <= 0 ; random number
	st r3, r15, r0 ; random_number

	; INTERRUPT MASK INICIALIZATION
	ldh r15, #A0h
	ldl r15, #02h

	ldh r14, #00h
	ldl r14, #30h

	st r14, r15, r0 ; MASK_INTERRUPT <= 0011 0000

	; ISR INICIALIZATION
	ldh r15, #00h
	ldl r15, #3Ch
	ldisra r15

	jmpd #BubbleSort

InterruptionServiceRoutine:
	; salvamento de contexto
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

	; identificação da origem da interrupcao
	xor r0, r0, r0
	ldh r1, #A0h
	ldl r1, #00h ; endereco PIC IRQ_ID_ADDR
	ld r1, r1, r0 ; interrupcao codificada
	ldh r3, #interrupt_vector
	ldl r3, #interrupt_vector
	ld r2, r3, r1 ; r2 <= endereco do handler
	jsr r2

	xor r0, r0, r0
	ldh r1, #A0h
	ldl r1, #00h ; endereco PIC IRQ_ID_ADDR
	ld r1, r1, r0 ; interrupcao codificada
	ldh r2, #A0h
	ldl r2, #01h ; r2 <= INT_ACK_ADDR
	st r1, r2, r0 ; INT_ACK_ADDR <= r1 (instrucao codificada)

	; recuperacao de contexto
recupera_contexto:
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

; ---------------------------------------- INICIO CRYPTO1 ---------------------------------------------
Crypto1_handler:
	; carregar endereços dos regs
	jsrd #bitmask_init
	ldh r1, #address_PortData_A
	ldl r1, #address_PortData_A
	ld r1, r1, r0 ; r1 <= address_PortData_A

	ldh r2, #address_PortConfig_A
	ldl r2, #address_PortConfig_A
	ld r2, r2, r0 ; r2 <= address_PortConfig_A

	ldh r3, #random_number
	ldl r3, #random_number
	ld r3, r3, r0 ; r3 <= random_number
	jsrd #testa_crypto
	jsrd #calcula_chave ; chave em r7 ou em #chave

	xor r6, r6, r6 ; r6 <= contador de caracteres
le_caractere_crypto1:
	ldl r4, #buffer_caract
	ldh r4, #buffer_caract
	st r0, r4, r0 ; zera o buffer_caract
	jsrd #le_caractere_crypto ; le o caractere 1
	jsrd #verifica_fim_mensagem
	jmpzd #move_data_up_crypto1
	jmpd #guarda_caractere_crypto1

move_data_up_crypto1:
	jsrd #move_data_up_crypto

	jsrd #le_caractere_crypto ; le o caractere2

guarda_caractere_crypto1:
	ldh r5, #msg_c1 ;
	ldl r5, #msg_c1 ; r5 <= ponteiro para a variavel
	ldh r4, #buffer_caract
	ldl r4, #buffer_caract
	ld r8, r4, r0 ; r8 <= buffer_caract
	st r8, r5, r6 ; grava na memória
	addi r6, #1 ; r6++
	jsrd #verifica_fim_mensagem
	jmpzd #le_caractere_crypto1
fim_mensagem_crypto_1:
	rts

; ------------------------------------- FIM CRYPTO1 -------------------------------------------------


; ------------------------------------- INICIO CRYPTO2 ----------------------------------------------
Crypto2_handler:
	; carregar endereços dos regs
	jsrd #bitmask_init
	ldh r1, #address_PortData_B
	ldl r1, #address_PortData_B
	ld r1, r1, r0 ; r1 <= address_PortData_B

	ldh r2, #address_PortConfig_B
	ldl r2, #address_PortConfig_B
	ld r2, r2, r0 ; r2 <= address_PortConfig_B

	ldh r3, #random_number
	ldl r3, #random_number
	ld r3, r3, r0 ; r3 <= random_number
	jsrd #testa_crypto
	jsrd #calcula_chave ; chave em r7 ou em #chave

	xor r6, r6, r6 ; r6 <= contador de caracteres

le_caractere_crypto2:
	ldl r4, #buffer_caract
	ldh r4, #buffer_caract
	st r0, r4, r0 ; zera o buffer_caract
	jsrd #le_caractere_crypto ; le o caractere 1
	jsrd #verifica_fim_mensagem
	jmpzd #move_data_up_crypto2
	jmpd #guarda_caractere_crypto2

move_data_up_crypto2:
	jsrd #move_data_up_crypto

	jsrd #le_caractere_crypto ; le o caractere2

guarda_caractere_crypto2:
	ldh r5, #msg_c2 ;
	ldl r5, #msg_c2 ; r5 <= ponteiro para a variavel
	ldh r4, #buffer_caract
	ldl r4, #buffer_caract
	ld r8, r4, r0 ; r8 <= buffer_caract
	st r8, r5, r6 ; grava na memória
	addi r6, #1 ; r6++
	jsrd #verifica_fim_mensagem
	jmpzd #le_caractere_crypto2
fim_mensagem_crypto_2:
	rts
; ---------------------------------- FUNÇÕES GERAIS DA APLICAÇÃO ----------------------------------

; finds a^b mod q 
; receives r6 as "a"
; receives r3 as "b"
; receives r5 as "q"
; returns the answer in "r7" register
exp_mod:
	push r1
	ldh r4, #00h
	ldl r4, #80h ; bitmask para testes

	ldh r7, #00h
	ldl r7, #01h ; resposta <= 1
	addi r4, #00h
loop:
	jmpzd #fim_find_key
	mul r7, r7
	mfl r7 ; r7 <= r7^2
	div r7, r5
	mfh r7 ; r7 <= r7^2 mod q
	and r1, r4, r3
	jmpzd #continue_loop
multiplica:
	mul r7, r6
	mfl r7 ; r7 <= r7 * a
	div r7, r5
	mfh r7 ; r7 <= r7 * a mod q
continue_loop:
	SR0 r4, r4
	jmpd #loop
fim_find_key:
	;resposta em r7
	pop r1
	rts

; r8 is the in and out
; move the lower bits to the higher part
move_high:
	push r6
	ldl r6, #08h
	ldh r6, #00h
	addi r6, #0
shift: ; shift left de 8 bits
	jmpzd #continue_move
	sl0 r8, r8
	subi r6, #1
	jmpd #shift
continue_move:
	pop r6
	rts

; verifica o numero aleatorio e garante que ele é menor que 251
; r3 in/out
verifica_num_alet:
		push r5
		ldh r5, #00h
		ldl r5, #FBh
		sub r5, r3, r5
		jmpzd #reinicia_numero
		pop r5
		rts
reinicia_numero:
		ldh r3, #00h
		ldl r3, #00h
		pop r5
		rts

bitmask_init:
	ldh r10, #00h
	ldl r10, #FFh ; r10 <= bitmask para data_in(crypto) -- LOW BYTE MASK
	ldh r11, #FFh
	ldl r11, #00h ; r11 <= HIGH BYTE MASK
	ldh r12, #80h
	ldl r12, #00h ; r12 <= bitmask para ack
	ldh r13, #08h
	ldl r13, #00h ; r13 <= bitmask para in/out
	ldh r14, #40h
	ldl r14, #00h ; r14 <= bitmask para data_av
	ldh r15, #04h
	ldl r15, #00h ; r15 <= bitmask para eom 0000 0100 0000 0000
	rts

; magicNumber retornado em r7 e guardado em magicNumberFromProcessor
calcula_magic_number:
	; prepara para a chamada de exp_mod (parametros)
	ldh r3, #random_number
	ldl r3, #random_number
	ld r3, r3, r0 ; r3 <= random_number
	ldh r5, #00h
	ldl r5, #FBh ; q <= 251
	ldh r6, #00h
	ldl r6, #06h ; a <= 6
	jsrd #verifica_num_alet
	addi r3, #1 ; incrementa o numero aleatorio
	ldh r4, #random_number
	ldl r4, #random_number
	st r3, r4, r0 ; guarda o novo valor de random_number
	jsrd #exp_mod ; resposta retornada em r7 => magicNumberFromProcessor
	ldh r4, #magicNumberFromProcessor
	ldl r4, #magicNumberFromProcessor
	st r7, r4, r0 ; magicNumberFromProcessor <= r7
	; magicNumber do processador em r7
	ld r4, r1, r0
	or r4, r4, r13 ; seta o bit para o tristate
	st r4, r1, r0

	ld r4, r2, r0 ; r4 <= PortConfig
	and r4, r4, r11 ; r4 <= Porta vira saida
	st r4, r2, r0 ; PortA(7:0) => saida

	or r5, r7, r13 ; seta o magicNumber e o bit do tristate
	or r5, r5, r12 ; seta ack
	st r5, r1, r0 ; PortData <= MagicNumber + ack + tristate_signal
	xor r5, r5, r12 ; desativa o ack
	st r5, r1, r0 ; desativa o ack

	ld r4, r2, r0 ; r4 <= PortConfig
	or r4, r10, r4 ;
	st r4, r2, r0 ; Port(7:0) => entrada
	xor r4, r4, r4 ;
	st r4, r1, r0 ; desativa o tristate
	rts

; pega o magicNumber do crypto e calcula o magicNumber do processador
testa_crypto:
	ld r8, r1, r0 ; r8 <= PortData
	and r8, r8, r10 ; BITS do magic number do Crypto
	ldh r4, #magicNumberFromCrypto
	ldl r4, #magicNumberFromCrypto
	st r8, r4, r0 ; magicNumberFromCrypto <= magicNumberFromCrypto
	; calcula_magic_number
	jsrd #calcula_magic_number
	rts

calcula_chave:
	ldh r3, #random_number
	ldl r3, #random_number
	ld r3, r3, r0 ; r3 <= random_number
	ldh r4, #magicNumberFromCrypto
	ldl r4, #magicNumberFromCrypto
	ld r6, r4, r0 ; r6 <= MagicNumber do crypto A
	ldh r5, #00h
	ldl r5, #FBh ; r5 <= q (251)
	jsrd #exp_mod ; chave em r7
	ldh r4, #chave
	ldl r4, #chave
	st r7, r4, r0
	rts

le_caractere_crypto:
	ld r4, r1, r0  ; r4 <= PortData_A
	and r5, r14, r4
	JMPZD #le_caractere_crypto ; pooling enquanto o caractere nao esta pronto
	ldh r5, #buffer_leitura
	ldl r5, #buffer_leitura
	st r4, r5, r0 ; buffer_leitura <= r4
	or r5, r4, r12 ;
	st r5, r1, r0 ; pulso em ack
	xor r5, r5, r12 ;
	st r5, r1, r0 ; limpa o ack
	and r8, r4, r10 ; limpa a parte alta de PortDataA
	xor r8, r7, r8 ; descriptografa a mensagem
	ldh r5, #buffer_caract
	ldl r5, #buffer_caract
	ld r4, r5, r0 ; r4 <= buffer_caract
	or r8, r4, r8 ; r8 <= r4 or r8
	st r8, r5, r0 ; buffer <= mensagem descriptografada
	rts

move_data_up_crypto:
	ldh r5, #buffer_caract
	ldl r5, #buffer_caract
	ld r8, r5, r0 ; r8 <= buffer_caract
	jsrd #move_high ; r8 <= caractere (parte alta)
	st r8, r5, r0 ; buffer_caract <= r8 << 8
	rts

verifica_fim_mensagem:
	ldh r5, #buffer_leitura
	ldl r5, #buffer_leitura
	ld r4, r5, r0 ; r4 <= buffer_leitura
	and r4, r15, r4 ; verifica fim da mensagem
	rts

; ----------------------------- BUBBLESORT ---------------------------------------------------------
BubbleSort:

    ; Initialization code
    xor r0, r0, r0          ; r0 <- 0

    ldh r1, #array          ;
    ldl r1, #array          ; r1 <- &array

    ldh r2, #size           ;
    ldl r2, #size           ; r2 <- &size
    ld r2, r2, r0           ; r2 <- size

    add r3, r2, r1          ; r3 points the end of array (right after the last element)

    ldl r4, #0              ;
    ldh r4, #1              ; r4 <- 1


; Main code
scan:
    addi r4, #0             ; Verifies if there was element swaping
    jmpzd #end              ; If r4 = 0 then no element swaping

    xor r4, r4, r4          ; r4 <- 0 before each pass

    add r5, r1, r0          ; r5 points the first arrar element

    add r6, r1, r0          ;
    addi r6, #1             ; r6 points the second array element

; Read two consecutive elements and compares them
loop_bubble:
    ld r7, r5, r0           ; r7 <- array[r5]
    ld r8, r6, r0           ; r8 <- array[r6]
    sub r2, r8, r7          ; If r8 > r7, negative flag is set
    jmpnd #swap             ; (if array[r5] > array[r6] jump)

; Increments the index registers and verifies is the pass is concluded
continue:
    addi r5, #1             ; r5++
    addi r6, #1             ; r6++

    sub r2, r6, r3          ; Verifies if the end of array was reached (r6 = r3)
    jmpzd #scan             ; If r6 = r3 jump
    jmpd #loop_bubble              ; else, the next two elements are compared


; Swaps two array elements (memory)
swap:
    st r7, r6, r0           ; array[r6] <- r7
    st r8, r5, r0           ; array[r5] <- r8
    ldl r4, #1              ; Set the element swaping (r4 <- 1)
    jmpd #continue

end:
    halt                    ; Suspend the execution
.endcode

; Data area (variables)
.data
	address_PortData_A: db #00h
	address_PortData_B: db #00h
	address_PortConfig_A: db #00h
	address_PortConfig_B: db #00h
	buffer_caract: db #00h
	buffer_leitura: db #00h
	random_number: db #00h
	chave: db #00h
	magicNumberFromProcessor: db #00h
	magicNumberFromCrypto: db #00h
	msg_c1: db #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h
    msg_c2: db #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h, #00h

    array:     db #50h, #49h, #48h, #47h, #46h, #45h, #44h, #43h, #42h, #41h, #40h, #39h, #38h, #37h, #36h, #35h, #34h, #33h, #32h, #31h, #30h, #29h, #28h, #27h, #26h, #25h, #24h, #23h, #22h, #21h, #20h, #19h, #18h, #17h, #16h, #15h, #14h, #13h, #12h, #11h, #10h, #9h, #8h, #7h, #6h, #5h, #4h, #3h, #2h, #1h
    size:      db #32h    ; 'array' size

	interrupt_vector: db #0, #0, #0, #0, #Crypto1_handler, #Crypto2_handler, #0, #0

.enddata
