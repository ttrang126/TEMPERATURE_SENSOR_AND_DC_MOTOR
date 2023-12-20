;=================================	
;		LCD Connection
;=================================	
LCD_Port EQU P0
LCD_RS BIT P2.0
LCD_EN BIT P2.1
;=================================	
;		ADC Connection
;=================================	
ADC_Port EQU P1
ADC_RD BIT P3.0
ADC_WR BIT P3.1
ADC_INTR BIT P3.2
ADC_Value EQU R0
;=================================
;     DC Motor Connection
;=================================
PWM_EN BIT P2.2
BTN1 BIT P2.3
BTN2 BIT P2.4
BTN3 BIT P2.5
PWM_Value DATA 100

ORG 0000H
	LJMP Main

ORG 000BH
	LJMP Timer0_ISR
;=================================
;			   Main		
;=================================
ORG 0080H
	
Main:
	LCALL LCD_Init					;Initialize LCD
	MOV	DPTR, #TEMPERATURE			;Print Temperature
	LCALL LCD_String

	SETB EA							;Enable Interupt
	SETB ET0						;Turn on Timer0 overflow interupt
	MOV	TMOD, #02H					;Timer0 Mode 2
	MOV	TL0, #00H				
	MOV	TH0, #00H
	SETB TR0						;Start Timer0

;=================================
;          DC Motor Mode
;=================================
Check_Mode:
;-----------------------
;	  Manual Mode
;-----------------------
	JNB BTN1, Speed_1				 ;Check if Button 1 is pressed (pressed: BTN1 = 0). If pressed, jump to Speed_1
	JNB	BTN2, Speed_2				 ;Check if Button 2 is pressed (pressed: BTN2 = 0). If pressed, jump to Speed_2
	JNB BTN3, Speed_3  				 ;Check if Button 3 is pressed (pressed: BTN3 = 0). If pressed, jump to Speed_3
;-----------------------
;	  Auto Mode
;-----------------------	
	CLR C
	MOV	A, ADC_Value	 
	SUBB A, #30						 ;Compare temperature value to 30oC
	JC Speed_1						 ;If temperature <= 30oC, jump to Speed_1
	JZ Speed_1

	CLR C
	MOV A, ADC_Value
	SUBB A, #50						 ;Compare temperature value to 50oC
	JC Speed_2						 ;If 30 < temperature <= 50oC, jump to Speed_2
	JZ Speed_2

	JMP Speed_3						 ;If temperature > 50oC, jump to Speed_3

	SJMP Check_Mode
;-----------------------
;	 Duty cycle 25%
;-----------------------
Speed_1:								 
	MOV PWM_Value, #25
	LCALL Print_Temperature
	MOV A, #1
	LCALL Set_Cursor_2
	MOV DPTR, #MODE_1 
	LCALL LCD_String
	SJMP Check_Mode	
;-----------------------
;	 Duty cycle 50%
;-----------------------
Speed_2:								  
	MOV PWM_Value, #50
	LCALL Print_Temperature
	MOV A, #1
	LCALL Set_Cursor_2
	MOV DPTR, #MODE_2 
	LCALL LCD_String
	SJMP Check_Mode	
;-----------------------
;	 Duty cycle 75%
;-----------------------
Speed_3:								  
	MOV PWM_Value, #75
	LCALL Print_Temperature
	MOV A, #1
	LCALL Set_Cursor_2
	MOV DPTR, #MODE_3 
	LCALL LCD_String
	SJMP Check_Mode	
;=================================
;		Print Temperature
;=================================
Print_Temperature:
	MOV	A, #11							  ;Set Cursor to position 11 line 1
	LCALL Set_Cursor_1
	LCALL ADC_Convert
	LCALL DELAY_50MS
	LCALL DELAY_50MS
	RET
;=================================
;Timer0 Interupt Service Rountine
;=================================
Timer0_ISR:										 ;Interrupt Timer to control PWM
	PUSH ACC
	MOV 7FH, C
	CLR	TF0
	CLR TR0
	SETB TR0
	MOV A, PWM_Value
	CJNE A, #0, EN_PWM							 ;PWM is different from 0, Enable PWM
	JMP Exit_ISR								 ;PWM is equal to 0, Exit Interrupt
	EN_PWM:
	INC R7										 ;Increasing interrupt counter
	MOV A, R7
	CJNE A, PWM_Value, OFF_Pulse
	CLR PWM_EN								     ;Open DC Motor
	OFF_Pulse:
	CJNE A, #100, Exit_ISR						 ;Duty cylce is not over --> Exit Interrupt
	SETB PWM_EN									 ;Close DC Motor
	MOV R7, #0									 ;Reset Counter
	Exit_ISR:
	MOV C, 7H
	POP ACC
	RETI
;=================================
;			   ADC
;=================================
ADC_Init:
	MOV	ADC_Port, #0FFH					;Set ADC_Port as an input
	SETB ADC_RD
	CLR	ADC_WR							
	SETB ADC_WR							;Start read data
	Here: JB ADC_INTR, Here				;Wait for INTR signal
	CLR	ADC_RD							;Allow read data
	MOV	ADC_Value, ADC_Port				;Store data
	RET
	
ADC_Convert:
	ACALL ADC_Init

	MOV	A, ADC_Value					;Hundreds
	MOV	B, #100
	DIV	AB
	ADD	A, #30H
	ACALL LCD_Data
	ACALL DELAY_100US
	
	MOV	A, B							;Tens
	MOV	B, #10
	DIV	AB
	ADD	A, #30H
	ACALL LCD_Data
	ACALL DELAY_100US

	MOV A, B							;Units
	ADD	A, #30H
	ACALL LCD_Data
	ACALL DELAY_100US
		
	MOV A, #11011111B					;Degree	
	LCALL LCD_Data
	LCALL DELAY_100US
	
	MOV A, #'C'							;'C'
	LCALL LCD_Data
	LCALL DELAY_100US
	RET
;=================================
;	     LCD 8 bit mode
;=================================
LCD_Init:
	MOV	A,#38H					;Send 38H to set 8 bit Interface, 2 line LCD and 5x7 Font set
	ACALL LCD_Command
	ACALL DELAY_100US
	MOV	A,#0CH					;Display ON, Cursor OFF
	ACALL LCD_Command
	ACALL DELAY_100US
	RET

LCD_CLR:						;Clear LCD
	MOV		A,#01H
	ACALL 	LCD_Data
	RET

LCD_Command:
	MOV	LCD_Port,A
	CLR	LCD_RS					;Clear RS, going to send command
	SETB LCD_EN
	ACALL DELAY_100US
	CLR	LCD_EN
	RET	

LCD_Data:
	MOV	LCD_Port,A
	SETB LCD_RS					;Set RS, going to send data
	SETB LCD_EN
	ACALL DELAY_100US
	CLR	LCD_EN
	RET	

Set_Cursor_1: 
	CLR LCD_RS				
	ADD A, #80H				 	;Set Cursor to line 1
	LCALL LCD_Command
	LCALL DELAY_100US 
	SETB LCD_RS
	RET

Set_Cursor_2:
	CLR LCD_RS			
	ADD A, #0C0H			 	;Set Cursor to line 2
	LCALL LCD_Command
	LCALL DELAY_100US 
	SETB LCD_RS
	RET

LCD_String:
	CLR A
	MOVC A, @A+DPTR
	CJNE A, #0, Jump
	SJMP Exit
	Jump:
	LCALL LCD_Data
	LCALL DELAY_100US
	INC DPTR
	SJMP LCD_String
	Exit: 
	RET

;=================================
;		 Print String
;=================================
TEMPERATURE:
	DB "TEMPERATUR:", 0

MODE_1:
	DB "DUTY CYCLE 25%", 0

MODE_2:
	DB "DUTY CYCLE 50%", 0

MODE_3:
	DB "DUTY CYCLE 75%", 0

BLANK:
	DB "                 ", 0
;=================================
;		  	  Delay
;=================================
DELAY_100US:
	   MOV R1, #50
LOOP1: DJNZ R1, LOOP1
	   RET
	
DELAY_50MS:
		MOV R2, #50
LOOP2:  MOV R3, #250
LOOP3:	DJNZ 	R3, LOOP3
		DJNZ 	R2, LOOP2
		RET
END