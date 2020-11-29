;*----------------------------------------------------------------------------
;* Name:    Lab4_T.s 
;* Purpose: To implement a reflex-meter using a STM32F401RE 
;* Author: 	Reinier Torres 
;* Revision: 0.1
;* Changelog: Nov-24-2020 by Reinier Torres
;*----------------------------------------------------------------------------*/
;************************** DO NOT CHANGE THIS CODE **************************
; Set up the MCU for work and enables peripherals for STM32F401RE and match
; startup_stm32f401xe.s file 
		THUMB	; Thumb instruction set 
		AREA 	My_code, CODE, READONLY
		EXPORT 	__MAIN
		EXPORT	EXTI15_10_IRQHandler	
__MAIN

;***************************  Constant declarations ***************************
;----- Peripherals Declarations
RCC_AHB1ENR		EQU 0x40023830	; Address of enable register for AHB1
RCC_APB2ENR		EQU	0x40023844	; Address of enable register for APB2
GPIOA_MODER 	EQU 0x40020000	; Base address of GPIOA
GPIOB_MODER		EQU	0x40020400	; Base address of GPIOB	
GPIOC_MODER		EQU	0x40020800	; Base address of GPIOC	

;Offset for GPIOs are the same accross the whole family (neat)
GPIO_OTYPER 	EQU 0x04	; Output TYpE Register
GPIO_OSPEEDR	EQU 0X08	; Output SPEED Register
GPIO_PUPDR		EQU 0x0C	; Pull UP/Down (control) Register
GPIO_IDR 		EQU 0x10	; Input Data Register	
GPIO_ODR 		EQU 0x14	; Output Data Register
	
;---- Interrupt Declarations
;System configuration controller base address
SYSCFG			EQU	0x40013800 ; Base address System Configuration peripheral
;System configuration controller registers offsets	
SYSCFG_EXTICR4	EQU	0X14 ; External interrupt control register No.4. EXTI13 is located here
	

;----- External interrupt controller base address
EXTI		EQU	0x40013C00 
;Offsets
EXTI_IMR	EQU	0X00 ;Interrupt mask register
EXTI_FTSR	EQU	0X0C ;Falling trigger selection register
EXTI_PR		EQU	0X14 ;Pending register
	
;----- NVIC registers	
NVIC		EQU 0xE000E000
NVIC_ISER1	EQU	0x104	
NVIC_IPR10	EQU 0x40A	
NVIC_IABR1	EQU	0x300
	
;----- Other constants
RAND_SEED	EQU 0x2F1
DELAY_CNT	EQU 8000

;********************* Static variable declarations ***************************
RAND_DATA	EQU 0x20000000 ;Reserve address for random number
	LDR R0,	=RAND_SEED ; load the seed number 
	LDR	R1,	=RAND_DATA ; load the address of the static variable
	STR	R0,[R1]		   ; store the random number in memory
	
BTN_FLAG	EQU 0x20000004 ;Reserve address for button flag
	MOV R0,	#0 ; Flag: '1': Button Pressed; '0': Button serviced or never pressed 
	LDR	R1,	=BTN_FLAG  ; load the address of the static variable
	STR	R0,[R1]		   ; Store the button flag in memory	

BCD_TEST	EQU 0x1234	
;***************************** PERIPHERAL SETUP *******************************
	; We will use a technique called Read/Modify/Write Back. This is commonly
	; used when programming embedded application. Note that just writing our
	; wanted configuration may ruin the configuration for other pins/peripherals.
	; Reading what is in the peripheral register before modifying it allows us to
	; set our configuration whilst keeping previous configurations that shouldn't
	; be changed.
	; We encorage you to follow this practice, it will help you avoid crashes.
	LDR	R1,  =RCC_AHB1ENR ;Set the pointer to RCC_AHB1ENR register
	LDR	R0,  [R1]  ; Read: RCC_AHB1ENR from mapped memory 
	ORR	R0,  #0x05 ; Modify: Enable the clock for GPIOA and GPIOC
	STR	R0,  [R1]  ; Write Back: Write back to RCC_AHB1ENR
	; GPIOA,C are now enable but more stuff must be configured
	; Deep dive: Comment out the Write Back operation and see what happens to
	; the MCU. HINT: You will end up in the hard fault handler, look the RCC_AHB1ENR
	; register in the datasheet and try to understand why the system fails

;---- GPIOA configuration
; We do not use the read/modify/write back in some cases because the whole register can
; be overwritten wothout affecting the proper operation of the system
	LDR	R1,=GPIOA_MODER ;Load pointer for GPIOA mode. This is the base register
	MOV	R0, #0x55555555  ; Set ALL pins of GPIOA as output 
	STR	R0, [R1]	; Write mode
	
	MOV	R0, #0  ; Set GPIOA_PIN5 as a push-pull output 
	STR	R0, [R1, #GPIO_OTYPER]	; Write back the output type	
		
;---- GPIOC configuration
; We use the three bits from GPIOC to control the RGB-LED
	LDR		R1,=GPIOC_MODER ;Load pointer for GPIOB mode. This is the base register
	LDR		R0,[R1] ; Load Output Data Register
	MOV32	R2,#0x15 ; Set PC0..PC2 of GPIOC as outputs all other as inputs
	ORR		R0,R0,R2
	
	STR	R0, [R1]	; Write mode
	
	MOV	R0, #0x0  ; Set GPIOC_PIN[2..0] as a push-pull outputs
	STR	R0, [R1, #GPIO_OTYPER]	; Write back the output type	
	MOV	R0,	#0
	STR	R0, [R1, #GPIO_OSPEEDR]	; Low speed operation
	MOV	R0,	#0x00000000
	STR	R0, [R1, #GPIO_PUPDR]	; No internal pull-ups
	
		
;---- Testing GPIOs. To see this happening you must debug the lines that 
;     follow step by step
;--GPIOA: seven-segement display
	LDR	R1,=GPIOA_MODER
	MOV	R0, #BCD_TEST  ; Write 1234 to display
	STR	R0, [R1, #GPIO_ODR]	; Write the data to output data register

;--GPIOC: RGB-LED
	LDR	R1,=GPIOC_MODER
	MOV	R0, #0x0  ; Turn on three LEDs (LED will shine white) 
	STR	R0, [R1, #GPIO_ODR]	; Write back the data to output data register

	MOV	R0, #0x6  ; RGB RED/ON
	STR	R0, [R1, #GPIO_ODR]	; Write back the data to output data register
	NOP
	MOV	R0, #0x5  ; RGB GREEN/ON
	STR	R0, [R1, #GPIO_ODR]	; Write back the data to output data register
	NOP
	MOV	R0, #0x3  ; RGB BLUE/ON
	STR	R0, [R1, #GPIO_ODR]	; Write back the data to output data register
	NOP	
	MOV	R0, #0x0  ; RGB ALL OFF
	STR	R0, [R1, #GPIO_ODR]	; Write back the data to output data register
	NOP	
	
;************************ INTERRUPT CONFIGURATION  ************************
; Read this code carefully and try to understand what is being done. For Lab4
; you will mostly copy and paste segments of code from this section and place
; them in your implementation from Lab3. Some code snippets are not to be
; reused. For example, the ERQ-IRQ chain neds to be executed once and the NVIC
; mask cannot be masked with the ERQ unmasked. Some snippets need to be adapted,
; for example, you may need to change code to clear or set a bit to perform the
; complementary operation.
; WARNING: In most cases you need to use the Read/Modify/Write back method, if
; you fail to do it properly you can ruin the configuration for other ERQ-IRQ
; chains and the system will likely crash. Be careful when modifying code to
; set clear bits.
; WARNING: Always ensure you are reading/writing the correct address.

;----- Nested Vector Interrupt Controller (NVIC). The NVIC is part of the ARM core
	;---Set interrupt priority according to SMT34F4xx documentation
	LDR		R1,=NVIC ;Load address for NVIC_IPR10: priority register
	MOV		R0,#47
	STRB	R0,[R1, #NVIC_IPR10]
	
	;---IRQ mask is on the NVIC controller. 
	LDR		R1,=NVIC ; Load address for NVIC_ISERC: Interrupt enable register
	LDR		R0,[R1, #NVIC_ISER1]
	ORR		R0, R0, #0X100 ;Enable Interrupt 40 leave other configurations intact
	STR		R0,[R1, #NVIC_ISER1]

	;---System Controller Configuration (SYSCFG)
	; Enable clock for SYSCFG on Peripheral Bus No. 2
	LDR	R1,  =RCC_APB2ENR ;Set the pointer to RCC_APB2ENR register
	LDR	R0,  [R1]  ; Read: RCC_APB2ENR from mapped memory 
	ORR	R0,  #0x4000 ; Modify: Enable the clock for GPIOA and GPIOC
	STR	R0,  [R1]  ; Write Back: Write back to RCC_APB2ENR

	LDR		R1,=SYSCFG ;Load pointer for SYSCFG controller. This is the base register.
	LDR		R0,[R1, #SYSCFG_EXTICR4] ; Load SYSCFG_EXTICR4 Register
	AND		R0,#0xFFFF0FFF ;Clear bits for EXTI13 mltiplexer but leave everything else unchanged
	ORR		R0,R0,#0x0000020 ;Set bits to select PC13 as event source
	STR		R0,[R1, #SYSCFG_EXTICR4] ; Write back SYSCFG_EXTICR4 Register
	; System controller configuration is complete
	
	;ERQ edge detection
	LDR		R1,=EXTI ;Load pointer for EXTI controller. This is the base register.
	LDR		R0,[R1, #EXTI_FTSR] ; Load EXTI_FTSR Register
	ORR		R0,R0,#0x0002000 ;Set bit will trigger IRQ with falling edge of event source
	STR		R0,[R1, #EXTI_FTSR] ; Write back EXTI_FTSR Register
			
	;ERQ mask is on the EXTI controller 
	LDR		R1,=EXTI ; Load EXTI_EMR Register
	LDR		R0,[R1, #EXTI_IMR] ; Load EXTI_IMR Register
	AND		R0,R0,#0xFFFFDFFF ;Set bit to unmask ERQ, clear to mask ERQ
	STR		R0,[R1, #EXTI_IMR] ; Write back EXTI_IMR Register

;----------------------------- END OF SETUP CODE ------------------------------


;************************* USER CODE STARTS HERE ******************************
	LDR		R1,=EXTI ; Load EXTI_EMR Register
	LDR		R0,[R1, #EXTI_IMR] ; Load EXTI_IMR Register
	AND		R0,R0,#0xFFFFDFFF ;Clear bit to mask event IRQ
	STR		R0,[R1, #EXTI_IMR] ; Write back EXTI_IMR Register
	
main_loop
	
	NOP ; You code from Lab3 goes here. Don't forget your subroutines in the
		; subroutines section. The ERQ is masked, so your code should work
		; as when submitted for Lab3. Once the code is up and working you
		; can start making modifications to remove perioci polling and use
		; interrupts.

	B	main_loop ;Also end of main program
	
;------------------------------------------------------------------------------	
	
	
;************************* Pseudo Random Num Gen ******************************
; Input:  NA 
; Output: R8 Contains the random number.
; Description: Rand generates a pseudo random number by using the Linear 
;              Feedback Shift Register (LFSR) method, for details on the theory
;			   of LFSR and its applications you can start at: 
;			   https://en.wikipedia.org/wiki/Linear-feedback_shift_register
;			   The seed is initialized at the start of the program and saved in
;			   memory for use within the subroutine. The subroutine does not take
;			   any argument because it saves it using static memory allocation.
;			   That is we are using something like:
;			   static int RandNumber = 0x03FA; //equivalent C code
;			   To achieve the static allocation we first need to reserve a space 
;			   in RAM memory and then load it with the seed value. Later Rand
;			   will only need to read the value at the start of the call an store
;			   the value for future use in RAM
;
; WARNING: I've changed the code from previous versions of this lab that reserve
;		   R11 for exclusive use of Rand. You know from Lab2 that reserving 
;		   registers for exclusive use of subroutines is REALLY BAD practice.
;		   We now use R8 as per convention.
; WARNING: DO NOT MODIFY this subroutine to circumvent the rule about register
;		   reservations you will get a failed grade for Lab3.
Rand	
	STMFD		R13!,{R0-R3, R14}
; Hint: Let's try some C/Assembly mixing, look at the C statement below
; static int RandNumber = 0x03FA; 
; Something as simple as the previous line in C, requires the compiler to 
;  produce code in two different places:
; 1) In the init section of the program the compiler will reserve memory to place
;    the int and will also assign the initial value. Check init section...
; 2) Every time the value is read from memory there has to be code to load the
;	 address into a register and then load the value. Within the subroutine
;    we can cheat a little bit and reserve a register to hold the address but
;    we must load the address in the subroutine code or we will be in violation
;    of the non exclusive reservation rule.
	LDR	R0,	=RAND_DATA ;Load random number address
	LDR	R8,	[R0] ;Load random number
	;Random generation is a traightforward sequence of logic operations				
	AND			R1, R8, #0x2000
	AND			R2, R8, #0x0400
	LSR			R1, #2
	EOR			R3, R1, R2 ;first tab
	
	AND			R1, R8, #0x0400
	LSR			R3, #2
	EOR			R3, R3, R1 ;second tab

	AND			R1, R8, #0x0040
	
	LSR			R3, #4
	EOR			R3, R3, R1	;third tab
	
	
	LSR			R3, #6 ;shift XORED bit to b0
	LSL			R8, #1 ;shit current one to the lefr
	
	ORR			R8, R8, R3 ;assemble new randdom number
	MOV			R1, #0x7FFF ;clear up mask for unwanted bits
	AND			R8, R1	;clear up
				
	STR	R8,[R0] ;save random number in RAM			
	LDMFD		R13!,{R0-R3, R15}	

;------------------------------------------------------------------------------	
	
;******************************** Binary to BCD *******************************
; Input: R0 binary number to convert to BCD. The number is assumed to be positive
;		 and smaller than 0x270F = 9999dec.
; Output: R8 the packed Binary Coded Decimal (BCD) code for the input number. If
;		  the number is greater than 9999 the subroutine will return 0xEEEE
; Hint: For details on the BCD number system you can start at: 
;	    https://en.wikipedia.org/wiki/Binary-coded_decimal
; Note: This is one of those subroutines that seems very long but is indeed very
;       fast compared to most of its C counterparts. You can find C implemenations
;		that take a couple of lines of code. However, it requires the use of division
;		and the modulus (%) operand. If the MCU does not have support for 
;		multiplication and division, then the ASM counterpart based on subtraction
;		ALWAYS wins the race. BCD conversion is one of those things that can drag
;       performance down without triggering any alarm.
BinToBCD
	STMFD		R13!,{R0-R3, R14}
	MOV		R8,#0 ; Initialize return value
if_BCD_logic_1 				; Equivalent C is if(R0 > 9999) {R8=0xEEEE; return;}
	MOV		R1,#9999		; We check the logic statement by subtracting R0 from
	SUBS	R1,R1,R0		; 9999, if the result is negative then R0 > 9999 and
	BPL		if_BCD_end_1 	; the BCD code is ERROR. The branch that terminates 
if_BCD_then_1				; the if statement occurs when the result is positive
	MOV		R8,#0xEEEE		; or zero, meaning R0 \in [0,9999]
	B		BCD_return ;return
if_BCD_end_1

; Binary number in range [0,9999] convert to BCD
; ----- Thousands column
; The equivalent C code for the loop is:
; for(i=R0; i>0; i-R1) {R3++}
	MOV		R3,#0
	MOV 	R1,#1000 ; We use decimal notation. Let the assembler do its job!
for_thousands
	SUBS 	R2,R0,R1
	BMI		for_thousands_end ;terminate the loop R0 < 0
	MOV		R0,R2             ; Update R0 iff subtraction zero or positive
	ADD		R3,#1             ; R3++
	B		for_thousands
for_thousands_end
; The unpacked BCD is now in R3, we need to pack by shifting and ORing
; in C this is equivalent to: R8 = R8 | (R3 << 12);
	LSL		R3,#12
	ORR		R8,R8,R3

; ----- Hundreds column
	MOV		R3,#0
	MOV 	R1,#100 ; We use decimal notation. Let the assembler do its job!
for_hundreds
	SUBS 	R2,R0,R1
	BMI		for_hundreds_end ;terminate the loop R0 < 0
	MOV		R0,R2            ; Update R0 iff subtraction zero or positive
	ADD		R3,#1            ; R3++
	B		for_hundreds
for_hundreds_end
; The unpacked BCD is now in R3, we need to pack by shifting and ORing
; in C this is equivalent to: R8 = R8 | (R3 << 8);
	LSL		R3,#8
	ORR		R8,R8,R3	

; ----- Tens column
	MOV		R3,#0
	MOV 	R1,#10 ; We use decimal notation. Let the assembler do its job!
for_tens
	SUBS 	R2,R0,R1
	BMI		for_tens_end ;terminate the loop R0 < 0
	MOV		R0,R2        ; Update R0 iff subtraction zero or positive
	ADD		R3,#1        ; R3++
	B		for_tens
for_tens_end
; The unpacked BCD is now in R3, we need to pack by shifting and ORing
; in C this is equivalent to: R8 = R8 | (R3 << 4);
	LSL		R3,#4
	ORR		R8,R8,R3	
	
; ---- Ones column	
;Whatever remains in R0 is the ones column	
	ORR		R8,R8,R0 

BCD_return

	LDMFD		R13!,{R0-R3, R15}	
	
;------------------------------------------------------------------------------	

;********************************* BUTTON ISR *********************************
; NO INPUTS NO OUTPUTS 
; ISRs are not called, therefore there is no reference to the caller making ISRs
; special.
; ISRs are special in the sense that they cannot take inputs (unless triggerd
; by software) and they cannot return values. All shared data with the main 
; program needs to be done through RAM. That is the reason we have declared a
; static variable called BTN_FLAG which you should set here and clear once the
; main program processes the button. For an example on how to read and write
; back to a static variable check RAND_DATA in the Rand subroutine.
; Hint: You must use the clear flag snippet below in your main program. You do
;       not want spurious button requests being processed.
; Hint: You do not need to store R0..R3 as part of the stack handling for ARM ISR
;       implementations. The ARM core does handles these registers as part of the
;       ISR handling. You would have to push/pop any other register beyond R3.
; WARNING: The button bounces when clicked and therefore it will produce several
;          pulses that will eventually trigger the ISR multiple times. The low
;          pass filter reduces bouncing but does not removes it completely. 
;          Fortunately we can get away by masking the ERQ after the first time
;          the ISR is executed. You can then unmask the ERQ when entering Stage2.

EXTI15_10_IRQHandler PROC
	STMFD		R13!,{R14}
					
	NOP ; Your code goes here			
				
	; Clear the interrupt flag as the last steo in IRS handling
	LDR	R1,=EXTI ; Load EXTI_EMR Register
	MOV	R0,#0x0002000 ;Set bit to clear interrupt
	STR	R0,[R1, #EXTI_PR] ; Write back EXTI_EMR Register

	LDMFD	R13!,{R15}
	ENDP
;------------------------------------------------------------------------------	

	END

	