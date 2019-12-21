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

'PUB externalCommand(com) | data, box
  ' External command
'  longmove(@data,currentClusterOfs+currentOffset,1)
'  data := htonl(data)        
'  currentOffset:=currentOffset+4
'  box := (com >> 28) & 7
'  box := box *3*4 + @mbox
'  longmove(box+8,@currentClusterOfs,1)
'  longmove(box+4,@data,1)
'  longmove(box,@com,1)
'  repeat
'    longmove(@com,box,1)
'  while(com & $80_00_00_00) <> 0
'  longmove(@data,box+4,1)
'  com := 0
'  longmove(box,com,1)
'  return data

'PUB changeCluster(clust)
'  if(clust==$FFFF)
'    ' Current cluster
'    return      
  ' Send load-cluster command for 1st cluster
'  mbox[1]:= clust
'  mbox[0]:= $80_00_00_00
  ' Wait for OK
'  repeat
'  while (mbox[0] & $80_00_00_00) <> 0    
'  currentClusterOfs := mbox[1]
'  currentClusterNum := clust
'  mbox[0] := 0
'  return
    
'PUB htonl(val) | a,b,c,d
' a := (val>>24)&$FF
' b := (val>>16)&$FF
' c := (val>>8)&$FF
' d := (val)&$FF 
' return (d<<24) | (c<<16) | (b<<8) | a


' ----------------------------------------------------

DAT

' The Interpreter COG

Interpreter

        org

' Boxes should be cleared and all COGs running

        mov   dm_command,par    ' Disk manager at box 0
        mov   dm_data,par       ' Disk manager's ...
        add   dm_data,#4        ' ... data box

        call  #ChangeCluster    ' Load cluster 0
        mov   offset,clusterPtr ' Start at top of cluster

CCLLoop 
        rdlong   tmp,offset wc  ' Get the next command
        add      offset,#4      ' Next word
 if_c

' Loop

' -----------------------------------------------------
' tmp = target command (box number within)
' tmp2 = target data
' clusterPtr = memory pointer
' tmp2 <= return data
' tmp  <= return value
COGCommand
        mov     tmp3,tmp         ' Command contains ...
        shr     tmp3,#28         ' ... the box number
        and     tmp3,#7          ' Get the box
        shl     tmp3,#4          ' *16 (TOPHER ... 4 longs per box now)        
        add     tmp3,dm_command  ' Now we are pointing to right box
        add     tmp3,#8          ' Point to offset member
        wrlong  clusterPtr,tmp3  ' Write the offset
        sub     tmp3,#4          ' Point to data
        wrlong  tmp2,tmp3        ' Write the data value
        sub     tmp3,#4          ' Point to command
        wrlong  tmp,tmp3         ' Write command

WaitOnEX
        rdlong  tmp,tmp3         ' Wait for cog ...
 if_c   jmp     #WaitOnEx        ' ... to clear command
        add     tmp3,#4          ' Point to data
        rdlong  tmp2,tmp3        ' Get the data value
        sub     tmp3,#4          ' Point to command
        wrlong  const_0,tmp3     ' Free the box

COGCommand_ret
        ret

' -----------------------------------------------------
' tmp = target cluster (FFFF for do-nothing)
' clusterNum <= tmp
' clusterPtr <= memory pointer
' tmp <= return value from DM
ChangeCluster
        cmp     tmp,const_FFFF wz    ' Ignore if this ...
 if_z   jmp     #ChangeCluster_ret   ' ... is current-cluster
        
        wrlong  clusterNum,dm_data   ' Send the cluster to DM
        wrlong  const_80,dm_cmd      ' Send the cache-cluster command to DM

WaitOnDM
        mov     clusterNum,tmp       ' Rememver the new cluster number
        rdlong  tmp,dm_cmd wc        ' Wait for DM ...
 if_c   jmp     #WaitOnDM            ' ... to clear command
        rdlong  clusterPtr,dm_data   ' Get the offset to the cluster
        wrlong  const_0,dm_cmd       ' Give up the mailbox        

ChangeCluster_ret
        ret

' -----------------------------------------------------

const_0     long  0            ' Constant 0
const_FFFF  long  $FFFF        ' Constant for current-sector
const_80    long  $80_00_00_00 ' Constant for DM cache-cluster command

dm_cmd      long  0            ' Base mailbox command (dm command)
dm_data     long  0            ' Base mailbox data (dm data)
tmp         long  0            ' Temporary
tmp2        long  0            ' Temporary
tmp3        long  0            ' Temporary
clusterPtr  long  0            ' Current cluster data
clusterNum  long  0            ' Current cluster number
offset      long  0            ' Offset within current cluster
stackPtr    long  #stackArea   ' Stack pointer
stackArea   res   4*2*10       ' Room for 10 levels of calls
