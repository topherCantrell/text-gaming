CON
     _clkmode        = xtal1 + pll16x
     _xinfreq        = 5_000_000        
OBJ
     term : "tv_terminal"
     kb   : "keyboard"        
VAR
     long counterA
     long counterB

PUB start

  cognew(@r1, @counterA) ' Start a new COG
  cognew(@r2, @counterB) ' Start a new COG  
  term.start(12)   ' Start the TV and graphics COGs
  kb.start(26,27)  ' Start the Keyboard driver
  repeat
    kb.getKey              ' Wait for a key
    term.hex(counterA,8)   ' Print counterA
    term.out(",")          ' Spacer
    term.hex(counterB,8)   ' Print counterB
    term.out(13)           ' New-line            

DAT
    org 0
r1  add      c1,#1  ' Add 1 to counter
    wrlong   c1,par ' Write register 3 to main RAM
    jmp      #r1    ' Loop back
c1  long     0      ' Init counter to 0
    
    org 0
r2  add      c2,#2  ' Add 2 to counter
    wrlong   c2,par ' Write register 3 to main RAM
    jmp      #r2    ' Loop back
c2  long     0      ' Init counter to 0
      