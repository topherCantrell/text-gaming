'' Interpreter

'' IF       0001:ssss SS CC CC (follow with external command)
'' GOTO     0010:ssss SS CC CC
'' CALL     0011:ssss SS CC CC
'' RETURN   0100:0000 00 00 00

'' external commands have leading bit=1 and formed as follows:
'' 1nnn:---- -- -- -- (nnn = target box)
'' DATA

'' Execution begins at the first word of the first cluster

CON
        _clkmode        = xtal1 + pll16x
        _xinfreq        = 5_000_000

OBJ
        
        disk         : "DiskManager"
        print        : "PrintManager"
        line         : "LineInputManager"
        varMgr       : "VariableManager"
    
VAR

  long  cog

  long   mbox[4*3] ' Mailbox for inter-cog communications
  long   currentClusterOfs
  long   currentClusterNum
  long   currentOffset
  long   stack[28]
  byte   stackPointer

PUB start | com, data, tclus, toffs

    ' Reserve 4 locks (0-3) for the 4 mailboxes
    locknew
    locknew
    locknew
    locknew

    ' Clear out the mailboxes
    repeat com from 0 to 4*3
      mbox[com] := 0

    ' Clear stack pointer
    stackPointer := 0

    ' Start the disk manager
    disk.start(@mbox)

    ' Sart the print-manager
    print.start(12,@mbox)

    ' Start the line-input-manager
    line.start(26,27,@mbox)

    ' Start the variable manager
    varMgr.start(@mbox)
        
    ' Send load-cluster command for 1st cluster
    changeCluster(0)
    currentOffset := 0

    ' The processing loop
    repeat
      longmove(@com,currentClusterOfs+currentOffset,1)
      com := htonl(com)
      currentOffset:=currentOffset+4       
      if (com & $80_00_00_00) <> 0          
        ' External command
        externalCommand(com)        
      else                                                       
        ' Flow control
        data := com>>28
        tclus := com&$FFFF
        toffs := (com>>16)&$FFF        
        if(data == 1)
          ' IF
          longmove(@com,currentClusterOfs+currentOffset,1)
          com := htonl(com)
          currentOffset:=currentOffset+4
          com := externalCommand(com)
          if(com == 0)
            changeCluster(tclus)
            currentOffset := toffs  
        elseif(data==2)
          ' GOTO
          if(tclus<>$FFFF)
            changeCluster(tclus)
          currentOffset := toffs            
        elseif(data==3)
          ' CALL
          stack[stackPointer] := currentClusterNum
          stack[stackPointer+1] := currentOffset
          stackPointer := stackPointer + 2
          changeCluster(tclus)
          currentOffset := toffs          
        elseif(data==4)
          ' RETURN
          stackPointer := stackPointer - 2
          currentClusterNum := stack[stackPointer]
          currentOffset := stack[stackPointer+1]
          changeCluster(currentClusterNum)

PUB externalCommand(com) | data, box, i
  ' External command
  longmove(@data,currentClusterOfs+currentOffset,1)
  data := htonl(data)        
  currentOffset:=currentOffset+4
  i := (com >> 28) & 7  
  box := i *3*4 + @mbox
  repeat until not lockset(i)
  longmove(box+8,@currentClusterOfs,1)
  longmove(box+4,@data,1)
  longmove(box,@com,1)
  repeat
    longmove(@com,box,1)
  while(com & $80_00_00_00) <> 0
  longmove(@data,box+4,1)  
  lockclr(i)
  return data

PUB changeCluster(clust)
  if(clust==$FFFF)
    ' Current cluster
    return      
  ' Send load-cluster command for 1st cluster
  mbox[1]:= clust
  mbox[0]:= $80_00_00_00
  ' Wait for OK
  repeat
  while (mbox[0] & $80_00_00_00) <> 0    
  currentClusterOfs := mbox[1]
  currentClusterNum := clust
  mbox[0] := 0
  return
    
PUB htonl(val) | a,b,c,d
 a := (val>>24)&$FF
 b := (val>>16)&$FF
 c := (val>>8)&$FF
 d := (val)&$FF 
 return (d<<24) | (c<<16) | (b<<8) | a