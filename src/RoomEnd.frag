; Process the generals
  CALL Common1:Handle
  
  if(respAction == 1) {
    CALL PrintRoomDescription    
  }

InputAgain:

  ; After-every-step
  CALL AfterEveryStep  

  GOTO Main

; -----------------------------------------------------------------------------

MoveIntoRoom:

  CALL AfterEveryStep
  
  ; Figure out if there is light in this room naturally
  ; or from the lit lamp.

  temp = ambientLight
  IF(lampOn==1) {
    IF(loc_lamp == IN_PACK) {
      temp = 1
    } else {
      IF(loc_lamp == currentRoom) {
        temp = 1
      }
    }
  }

  ; Print description or fall into pit

  if(temp==1) {
    CALL PrintDesc
  } else {    
    temp = temp + lastAmbientLight
	IF(temp==0) {
      temp = temp RND 255
	  if(temp>0x67) {
	    GOTO Common2:FallIntoPit
	  }      
    }
    PRINT msgDark
  }

  ; Have the mummy check the pack

  if(loc_chest == 0) {
    if(numberOfTreasuresInPack>1) {	  
      CALL Mummy:StealTreasure
    }
  }  
  
;MoveIntoRoom:
;  If ambient-light or lit-lamp is in (room or pack) show description
;  If we are moving from a dark room to a dark room
;    If random(256) >=0x67 fall in pit
;  Current-room-number to last-room-number
;  Print room description and object description (or "it is dark")
;
;  If chest has not been placed in maze
;    If number of treasures in pack >=2
;      Move all treasures in pack to treasure room
;      Place chest in maze
;      Print mummy-steals-treasure

  RETURN

; -----------------------------------------------------------------------------

PrintRoomDescription:
  ;PRINTVAR numberOfObjectsInPack

  temp = ambientLight
  IF(lampOn==1) {
    IF(loc_lamp == IN_PACK) {
      temp = 1
    } else {
      IF(loc_lamp == currentRoom) {
        temp = 1
      }
    }
  }

  ; Print description 

  if(temp==1) {
    PRINT desc
	CALL Objects:PrintDescriptions
  } else {        
    PRINT msgDark
  }

  RETURN

; -----------------------------------------------------------------------------

AfterEveryStep:

  numberOfTurns = numberOfTurns + 1

  if(lampOn==1) {
    lampTime = lampTime + 1
	if(lampTime>0x12C) {
	  if(batteriesDead == 0) {
	    ; Change batteries if they are in pack
	    PRINT msgChangeBatteries
	    lampTime = 0
	    batteriesDead = 1
	  }
	}
	if(lampTime==0x122) {
	  ; Warn the player
	  PRINT msgDim
	}
	if(lampTime==0x136) {
	  ; Lamp goes out
	  PRINT msgLampOut
	  lampOn = 0
	  ; PRINT msgDark
	}

  }

; After-every-step:
;  Bump lamp time if it is lit 
;  Greater than 0x12C we look for batteries and change if we have
;  Warn the player about lamp if ==0x122 turns
;  At 0x136 the lamp goes out (reprint room description)
;  Bump the turn count

  RETURN

; ---------------------------------------------------------------------

inputBuffer:
# "                                                  ",0

msgColorInput:
# 2,0

msgColorDesc:
# 1,0

msgPrompt:
# ":",0

;  01234567890123456789012345678901234567890
msgDim:
# "YOUR LAMP IS GETTING DIM. YOU'D BEST",10
# "START WRAPPING THIS UP, UNLESS YOU CAN",10 
# "FIND SOME FRESH BATTERIES. I SEEM TO",10 
# "RECALL THERE IS A VENDING MACHINE IN THE",10 
# "MAZE. BRING SOME COINS WITH YOU."10,0

msgChangeBatteries:
# "YOUR LAMP IS GETTING DIM. I'M TAKING THE",10
# "LIBERTY OF REPLACING THE BATTERIES.",10,0

msgLampOut:
# "YOUR LAMP HAS RUN OUT OF POWER.",10,0

msgDark:
# "IT IS NOW PITCH DARK. IF YOU PROCEED, YOU",10
# "WILL LIKELY FALL INTO A PIT.",10,0

