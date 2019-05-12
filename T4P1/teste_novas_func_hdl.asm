.org #0000h


.code



    xor r0, r0, r0

    ldh r1, #00h
    ldl r1, #0ah
    ldh r2, #00h
    ldl r2, #02h


    div r1, r2
    mfh r3
    mfl r4
    div r3, r2
    mfh r5
    mfl r6

    xor r1, r1, r1
    addi r1, #FFh

    mul r1 r1
    mfh r7
    mfl r8

    halt
.endcode
