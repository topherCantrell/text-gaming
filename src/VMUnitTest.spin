'' Test TAG components
 
CON
        _clkmode        = xtal1 + pll16x
        _xinfreq        = 5_000_000

        SD_DO  = 0
        SD_CLK = 1
        SD_DI  = 2
        SD_CS  = 3

OBJ
        
        vm           : "VariableManager"
        term         : "tv_term"             
                        
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

    term.start(12,@mbox_diskManager)
   

    ' Bo MF AA BB

    ' V10 = nu + $1000
    ' B8 04 10 00     00 00 10 00

    ' V10 = V10 + $1234
    ' B8 0C 10 10     00 00 12 34

    ' V11 = nu + $10
    ' B8 04 11 00     00 00 00 10
    
    mbox_variableManager := 0
    vm.start(@mbox_diskManager)

    sendVarCommand($B8_04_10_00,$10_01)

    'sendVarCommand($B8_0C_10_10,$12_34)
    'sendVarCommand($B8_04_11_00,$10)
        
    repeat
     '

PUB sendVarCommand(command,data)
    mboxData_variableManager := data
    mbox_variableManager := command
    repeat
    while (mbox_variableManager & $80_00_00_00) <> 0
    return    
                                            