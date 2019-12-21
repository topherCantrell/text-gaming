'' Test TAG components
 
CON
        _clkmode        = xtal1 + pll16x
        _xinfreq        = 5_000_000

        SD_DO  = 0
        SD_CLK = 1
        SD_DI  = 2
        SD_CS  = 3

OBJ
        
        'disk         : "DiskManager"
        term         : "tv_terminal"
        'kb           : "keyboard"
        line : "LineInputManager"     
                        
VAR     
        
        long   mbox_diskManager
        long   mboxData_diskManager
        long   mboxClusterOffset_diskManager

        long   mbox_printManager
        long   mboxData_printManager
        long   mboxClusterOffset_printManager

        long   mbox_lineInput
        long   mboxData_lineInput
        long   mboxClusterOffset_lineInput

        long   mbox_variableManager
        long   mboxData_variableManager
        long   mboxClusterOffset_vm
        
PUB start | type, i, temp

    term.start(12)

    term.str(@buffer)

    line.initTokens(@tokens)

    i := line.tokenize(10,0,@buffer)

    term.hex(i,4)   

    repeat
     '
DAT

tokens
  byte "ONE",0,$B
  byte "TWO",0,$C
  byte "THREE",0,$D
  byte "FOUR",0,$E
  byte 0

buffer
  byte "ONE TWO THREE FOUR FIVE",0

    