'' Variable Manager COG

'' -- Variable Operation
'' 1011:oooo MF AA BB
'' Constant
'' Cluster base pointer     
''   Returns 1=OK 0xFF=error (second word is actual value)
  
'' AA is result destination variable (if stored)
'' BB is left side of operation and must be a variable
'' VV is either value or a variable

'' All expressions are of the form "A op B math V"

'' Math:                  Ops:            Flags:
'' 0000 +                 1000 =          ----abcd
'' 0001 -   (FUTURE)      1001 ==         a : 1 if B is used
'' 0010 *   (FUTURE)      1010 !=         b : 1 if C is constant (0=var)
'' 0011 /   (FUTURE)      1011 >          c : 1 if A is indirect
'' 0100 REM               1100 >=         d : 1 if B is indirect
'' 0101 AND               1101 <
'' 0110 OR                1110 <=
'' 0111 NOT               1111 no-op
'' 1000 <<
'' 1001 >>
'' 1010 RND

VAR

  long  cog
 
PUB start(mailbox) : okay

'' Start VariableManager - starts a cog
'' returns false if no cog available

  stop
  okay := cog := cognew(@VariableManager, mailbox) + 1

PUB stop

'' Stop VariableManager - frees a cog

  if cog
    cogstop(cog~ - 1)

DAT

' The VariableManager COG

VariableManager

        org

        mov   op,#128
        mov   temp,#vararray
initij
        movd  initi,temp
        nop
initi
        mov   0,#0
        add   temp,#1
        djnz  op,#initij
        

        mov             mboxCommand,par
        add             mboxCommand,#4*3 * 3
        mov             mboxData,mboxCommand
        add             mboxData,#4
                    
top                   
        rdlong          temp,mboxCommand       ' Get command word
        mov             op,temp wc             ' Check the upper bit                    
  if_nc jmp             #top                   ' Not a command

' Get OP and right

        rdlong          right,mboxData         ' Get the data value                          
        shr             op,#24                 ' OP is ...
        and             op,#$0F                ' ... ....oooo -- -- --

' Get Math
        
        mov             math,temp              ' MATH ...
        shr             math,#20               ' ... is ...
        and             math,#$0F              ' ... -- mmmm.... -- --

' Get flags
        mov             flags,temp
        shr             flags,#16

' Get varA and valueA
        
        mov             varA,temp              ' AA ...
        shr             varA,#8                ' ... is ...
        and             varA,#$FF              ' ... -- -- AA --  

        mov             valueA,varA            ' Get the value from there
        mov             count,flags            ' Indirection ...
        shr             count,#1               ' ... results in ...                  
        and             count,#1               ' ... two passes
        add             count,#1
lookupA                          
        add             valueA,#vararray       ' Location of user variable
        movs            ins0,valueA            ' Lookup ...
        movd            ins3,valueA            ' (might need for assign later)
ins0    mov             valueA,0               ' ... current value
        djnz            count,#lookupA         ' Lookup again if indirect       

' Get valueB

        mov             valueB,temp            ' BB is ...        
        and             valueB,#$FF            ' ... -- -- BB --

        mov             count,flags            ' Indirection ...
        and             count,#1               ' ... two passes
        add             count,#1
lookupB                                            
        add             valueB,#vararray       ' Location of user variable        
        movs            ins4,valueB            ' Lookup ...
        nop                                    ' Purge the execution pipe
ins4    mov             valueB,0               ' ... current value
        djnz            count,#lookupB 

        and             flags,#8 nr, wz        ' See if B is even used 
  if_z  mov             valueB,#0              ' NOT USED ... make it 0  

' Lookup right if variable
          
        and             flags,#4 wz, nr        ' If C is register ...
  if_z  add             right,#vararray        ' ... get contents ...  
  if_z  movs            ins1,right             ' ... of ...
        nop                                    
ins1
  if_z  mov             right,0                ' ... user variable
  
' Now >right< contains the value on the right of the >math< op
' and >valueB< contains the value on the left. We have
' to perform the requested operation.

       cmp             math, #0    wz
 if_z  jmp             #mathPLUS         
       cmp             math, #1    wz
if_z   jmp             #mathMINUS
       cmp             math, #5    wz
if_z   jmp             #mathAND
       cmp             math, #6    wz
if_z   jmp             #mathOR
       cmp             math, #7    wz
if_z   jmp             #mathNOT
       cmp             math, #8    wz
if_z   jmp             #mathSHL
       cmp             math, #9    wz
if_z   jmp             #mathSHR
       cmp             math, #10   wz
if_z   jmp             #mathRND

       mov             valueB,#0       
       wrlong          valueB,mboxData          
       wrlong          ERRORCODE_FF,mboxCommand  ' Return ...  
       jmp             #top                      ' ... unknown command error

' ------------------------- MATH OPERATIONS

mathPLUS         
        add             valueB,right
        jmp             #handleResult
mathMINUS
        sub             valueB,right
        jmp             #handleResult
mathAND
        and             valueB,right
        jmp             #handleResult
mathOR
        or              valueB,right
        jmp             #handleResult
mathNOT         
        xor             valueB,ALL_FF
        jmp             #handleResult
mathSHL
        shl             valueB,right
        jmp             #handleResult
mathSHR
        shr             valueB,right
        jmp             #handleResult
mathRND
        mov             valueB,CNT
        and             valueB,right
        jmp             #handleResult

' -----------------------------------------

' Now the final result is in valB. We have to do the
' storage operation like '=' and '==' and '<'

handleResult
        cmp             op,#8 wz
  if_z  jmp             #resultASSIGN
        cmp             op,#9 wz
  if_z  jmp             #resultEQUALS
        cmp             op,#10 wz
  if_z  jmp             #resultNOTEQUALS
        cmp             op,#11 wz
  if_z  jmp             #resultGREATER
        cmp             op,#12 wz
  if_z  jmp             #resultGREATEREQUAL
        cmp             op,#13 wz
  if_z  jmp             #resultLESS
        cmp             op,#14 wz
  if_z  jmp             #resultLESSEQUAL
  
        jmp             #finish
        
' ------------------------- RESULT OPERATIONS          

resultASSIGN  
ins3    mov             0,valueB    
        jmp             #finish
resultEQUALS
        cmp             valueA,valueB wz,wc
        mov             valueB,#0
  if_z  mov             valueB,#1
        jmp             #finish    
resultNOTEQUALS
        cmp             valueA,valueB wz,wc
        mov             valueB,#0
  if_nz mov             valueB,#1
        jmp             #finish 
resultLESS
        cmp             valueA,valueB wz,wc
        mov             valueB,#0
  if_b  mov             valueB,#1
        jmp             #finish 
resultLESSEQUAL
        cmp             valueA,valueB wz,wc
        mov             valueB,#9
  if_be mov             valueB,#1
        jmp             #finish 
resultGREATER
        cmp             valueA,valueB wz,wc
        mov             valueB,#0
  if_a  mov             valueB,#1
        jmp             #finish 
resultGREATEREQUAL
        cmp             valueA,valueB wz,wc
        mov             valueB,#0
  if_ae mov             valueB,#1
        jmp             #finish 

' -------------------------------------------

finish

        wrlong          valueB,mboxData
        wrlong          ERRORCODE_01,mboxCommand
        jmp             #top

'testStop
'        wrlong          ERRORCODE_01,mboxCommand
'        wrlong          TEST_CODE,mboxData
'ttt     jmp             ttt

'TEST_CODE    long   $AA550000
ALL_FF       long   $FFFFFFFF
ERRORCODE_FF long   $FF
ERRORCODE_01 long   $01

mboxCommand  long   $0
mboxData     long   $0  
count        long   $0
temp         long   $0
flags        long   $0
op           long   $0
math         long   $0
varA         long   $0
valueB       long   $0
right        long   $0
valueA       long   $0

vararray res 128
bottom