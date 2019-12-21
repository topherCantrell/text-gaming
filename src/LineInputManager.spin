'' Line Input Manager

'' -- Input Line
'' 1010:0000 00 RR MM (First register to fill and max tokens)
'' SSSS:BBBB (Size and offset to input buffer)
'' Cluster base address
''   Returns 1=OK or 0xFF=error

'' -- Init Tokens
'' 1010:0001 00 00 00
'' Offset to token data
'' Cluster base address
''   Returns 1=OK or 0xFF=error               


VAR

  long  cog
  long  box
  byte  printIt[2]

  long  stack[82]

  byte tokens[800]

OBJ

  kb  : "keyboard"

PUB start(a,b,mailbox)

  kb.start(a,b)
    
  cognew(server(mailbox), @stack)

PUB server(mailbox) | i, firstReg, size, maxTokens, buffer, data, offset

  box := mailbox
  
  repeat
    longmove(@i,mailbox+6*4,1)
    if (i & $80_00_00_00) <> 0
      longmove(@data,mailbox+7*4,1)
      longmove(@offset,mailbox+8*4,1)
      if( i& $0F_00_00_00) == 0
        ' Input line
        firstReg := (i>>8)&$FFFF
        maxTokens := i&$FF
        buffer := (data & $FFFF) + offset
        size := (data>>16) & $FFFF
        readLine(buffer,size)
        'sendCommand(3,$B8_04_06_00,byte[buffer+0],0)
        'sendCommand(3,$B8_04_07_00,byte[buffer+1],0)
        'sendCommand(3,$B8_04_08_00,byte[buffer+2],0)
        'sendCommand(3,$B8_04_09_00,byte[buffer+3],0)
        'sendCommand(3,$B8_04_0A_00,byte[buffer+4],0)
        size:=tokenize(maxTokens,firstReg+1,buffer)
        sendCommand(3,$B8_04_00_00 | (firstReg<<8), size,0)
        'sendCommand(3,$B8_04_05_00, 61234,0)
      elseif (i& $0F_00_00_00) == $01_00_00_00
        ' Init tokens
        initTokens(data+offset)    
      i := 1
      longmove(mailbox+6*4,@i,1)

PUB initTokens(buffer)
  bytemove(@tokens,buffer,800)

PUB readLine(buffer, size) | i, ptr , tmp
    
  ptr := 0
  repeat
    i := kb.getKey
    if(i==13)
      i:=10
    printIt[0] := i
    printIt[1] := 0
    sendCommand(1,$90_00_00_00,@printIt,0)        
    if (i == 10)
      byte[buffer+ptr] := 0
      return
    if (i>31 AND i<128)
      byte[buffer+ptr] := i
      ptr := ptr + 1
      if(ptr==size)
        return

PUB sendCommand(cogNum,com,data,ofs)
  ' Wait for the box to free up
  repeat while not lockset(cogNum)
  ' Write offset, data, and command (command trigger last)
  longmove(box+cogNum*4*3+8,@ofs,1)
  longmove(box+cogNum*4*3+4,@data,1)
  longmove(box+cogNum*4*3,@com,1)
  ' Wait for the COG to respond
  repeat
    longmove(@com,box+cogNum*4*3,1)
  while( (com&$80_00_00_00) <> 0)
  ' Get return data
  longmove(@data,box+cogNum*4*3+4,1)
  ' Free the box for other cogs
  lockclr(cogNum)
  return data 
  
PUB tokenize(maxTokens, firstReg, buffer) | j,p,q,count

  p := 0
  count := 0

  ' Done before we started
  if(buffer[p]==0 OR buffer[p]==32)
   return 0

  repeat
    ' Find the end of the next input token
    q:=p 
    repeat
      q:=q+1
    while(byte[buffer+q]<>32 AND byte[buffer+q]<>0)

    j:=tokenLookup(buffer+p,q-p)

    ' Store token j
    ' Vn+count = j
    sendCommand(3,$B8_04_00_00|((firstReg+count)<<8),j,0)

    ' Bump the count
    count:= count + 1
    if(count==maxTokens OR byte[buffer+q]==0)
      return count
      
    ' Tokenize next word
    p := q+1

PUB tokenLookup(buffer,size) | x , y
 x := 0

 repeat
   ' Return -1 if there are no more tokens
   if(tokens[x]==0)
     return $FF_FF

   ' Check the input word against the current token
   y := -1
   repeat
     y:=y+1
   while((y<size) AND (byte[buffer+y]==tokens[x+y]))

   'sendCommand(3,$B8_04_08_00,size,0)
         
   ' If we got to the end of the buffer and the token, we matched
   if(y==size AND tokens[x+y]==0)     
     return tokens[x+y+1]

   ' Skip to the next token and try again
   x := x+y-1
   repeat
    x:= x+1
   while (tokens[x]<>0)
   x:= x+2

   