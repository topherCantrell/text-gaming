'' Test TAG components
 
CON
        _clkmode        = xtal1 + pll16x
        _xinfreq        = 5_000_000

        SD_DO  = 0
        SD_CLK = 1
        SD_DI  = 2
        SD_CS  = 3

OBJ
        
        disk         : "DiskManager"
        term         : "tv_terminal"
        kb           : "keyboard"        
                        
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

        byte   cluster[1024]
        
PUB start | type, i, temp

    term.start(12)
    kb.start(26, 27)

    mbox_diskManager := 0
    disk.start(@mbox_diskManager)

    ' Send load-cluster command
    mboxData_diskManager := 0
    mbox_diskManager := $80_00_00_00
    ' Wait for OK
    repeat
    while (mbox_diskManager & $80_00_00_00) <> 0    
    temp := mboxData_diskManager

    'temp := disk.init
    'temp := disk.cacheCluster(0)
    'disk.readSector(100,@cluster)
'    temp := @cluster
    'term.hex(temp,4)

    repeat i from 0 to 511
      term.hex(byte[temp][i],2)
      term.out(32)

    repeat
     '
    

    
                                                                  