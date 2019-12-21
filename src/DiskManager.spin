'' Disk Manager - Reads SD card

'' -- Load Cluster N
'' 1000:0000 00 00 00 00
'' SectorNumber
'' ClusterPointer
''  Returns pointer to base load or $FFFF if error

'' -- Make Cluster stickie
'' 1000:0001 00 00 00 00
'' 00
'' ClusterPointer
''  Returns 1=OK, 0xFF if error

VAR

  long  cog
  long  firstDataSector

  byte   cluster[CACHE_SIZE*2048]     ' As big as possible
  long   clusterContent[4]
  byte   sticky[4]

  long  stack[40]  
  
CON
  SD_DO  = 0
  SD_CLK = 1
  SD_DI  = 2
  SD_CS  = 3

  CACHE_SIZE = 4

PUB start(mailbox)
  
  cognew(server(mailbox), @stack)

PUB server(mailbox) | com

  init  
    
  repeat
    longmove(@com,mailbox,1)
    if(com & $80_00_00_00) <> 0
      if(com & $01_00_00_00) <> 0
        ' ToggleStickie
        longmove(@com,mailbox+4,1)
        toggleSticky(com)
        com := $1
        longmove(mailbox,@com,1)
      else
        ' LoadCluster
        longmove(@com,mailbox+4,1)
        com := cacheCluster(com)
        longmove(mailbox+4,@com,1)
        com := $2
        longmove(mailbox,@com,1)
    
        
PUB init | type, i, temp, fatsize, rootent

  repeat i from 0 to (CACHE_SIZE-1)
    clusterContent[i] := $FFFF
    sticky[i] := 0
    
  ' Direction and initial values of I/O pins
  
  outa[SD_CLK]  := 0
  outa[SD_DI]   := 0
  outa[SD_CS]   := 1

  dira[SD_CS]   := 1
  dira[SD_CLK]  := 1
  dira[SD_DI]   := 1
  dira[SD_DO]   := 0

  ' Send some clocks to boot the disk 
  repeat i from 0 to 50
    sendAndGetByte($FF)

  ' Assert chip-select
  outa[SD_CS] :=0

  ' Send GO-IDLE command until it responds with 1 (idle bit) 
  repeat i from 0 to 50
    temp := sendCommand(0,0)    
    if(temp == 1)
      i:=50

  if temp<>1
    return temp+$100
  
  ' Send INIT command util it responds with 0
  ' (might take time to power back up and clear te idle bit)
  repeat i from 0 to 50
    temp := sendCommand(1,0)    
    if(temp == 0)
      i:=50
  if temp<> 0
    return temp+$100
            
  ' Finish init with the 55, 41 combo
  temp := sendCommand(55,0)    
  temp := sendCommand(41,0)    

  ' Read the Partition Table and find the starting sector of the first drive  
  readSector(0, @cluster)
  temp := byte[@cluster+$1C6]
  ' Read the boot sector and find the first file's starting sector
  readSector(temp,@cluster)
  firstDataSector := byte[@cluster+15]<<8 + byte[@cluster+14]
  fatsize := byte[@cluster+23]<<8 + byte[@cluster+22]
  rootent := byte[@cluster+18]<<8 + byte[@cluster+17]
  rootent := rootent >> 4
  if (fatsize == 0)
    ' For FAT32 we skip the first cluster (root directory)
    fatsize := byte[@cluster+37]<<8 + byte[@cluster+36]
    rootent := byte[@cluster+13]
  firstDataSector := firstDataSector + byte[@cluster+16] * fatsize
  firstDataSector := firstDataSector + rootent+temp

  return temp

PUB toggleSticky(offset)
  offset := offset - @cluster
  offset := offset/2048
  if (sticky[offset] == 0)
    sticky[offset] := 1
  else
    sticky[offset] :=0
  return

PUB cacheCluster(clusterNum) | i, t

  ' See if the request is already cached
  repeat i from 0 to (CACHE_SIZE-1)
    if (clusterContent[i] == clusterNum)
      return @cluster[2048*i]

  ' Look for a free cache entry and load
  repeat i from 0 to (CACHE_SIZE-1)
    if (clusterContent[i] == $FFFF)
      repeat t from 0 to 3
        readSector(firstDataSector+clusterNum*4+t, @cluster+2048*i+512*t)
      clusterContent[i] := clusterNum
      return @cluster[2048*i]

  ' Look for a non-sticky entry and load over
  ' (Yes, this needs some algorithm to pick LRU)
  repeat i from 0 to (CACHE_SIZE-1)
    if (sticky[i] == 0)
      repeat t from 0 to 3
        readSector(firstDataSector+clusterNum*4+t, @cluster+2048*i+512*t)
      clusterContent[i] := clusterNum
      return @cluster[2048*i]

  return $FFFF

PUB readSector(sectorNum, secBuf)  | i, temp

  ' Send the command
  temp:= sendCommand(17,512* sectorNum)

  ' Return error code if failed
  if temp <> 0
    return temp

  ' Wait for the SD card to fetch the data
  repeat i from 0 to 5000
    temp := sendAndGetByte($FF)
    if temp == $FE
      i := 5000

  ' Return error if not responding    
  if temp <> $FE
    return $1FF 

  ' Read the data bytes
  repeat i from 0 to 511
    byte[secBuf][i] := sendAndGetByte($FF)    

  sendAndGetByte($FF) ' Ignore ...
  sendAndGetByte($FF) ' ... CRC value

  sendAndGetByte($FF) ' 8 more clocks for the card to finish
  
  return 0                 

PUB sendCommand(command,address) | response, i

' 6-byte protocol. First byte is command | $40 (upper bit off, next on)
' Next 4 are address
' Last byte is checksum | $80 (upper bit on)
' Only the first command needs checksum, which happens to be value $95
'   and we'll always send that since nobody else cares.

    command := command | $40
    sendAndGetByte(command)
    sendAndGetByte( (address>>24) & $FF )
    sendAndGetByte( (address>>16) & $FF )
    sendAndGetByte( (address>>8) & $FF )
    sendAndGetByte( address & $FF)
    sendAndGetByte( $95 ) ' Again ... IGNORED except on 1st command

    ' We'll give the card 100 cycles to respond. Then
    ' we'll just return the $FF error
    repeat i from 0 to 99
      response := sendAndGetByte($FF)      
      if response <> $FF
        sendAndGetByte($FF)
        return response

    return response


PUB sendAndGetByte(toSend) | read, count
 
' This one function serves both reading and writing ... not
' usually at the same time. To read simply send the dummy $FF.

' Bits come and go MSB first

  read := 0

  repeat count from 0 to 7
    read := read << 1             
    if (toSend & $80) > 0
      outa[SD_DI] := 1
    else
      outa[SD_DI] := 0        
    if (ina[SD_DO] == 1)
      read := read | 1
    toSend := toSend << 1         
    outa := outa | 2
    '[SD_CLK] := 1
    outa := outa & !2    
    'outa[SD_CLK] := 0    

  return read