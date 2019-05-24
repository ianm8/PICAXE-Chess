#picaxe 28x2
setfreq em64
;setfreq m16

; move generation
; search best move
; validate user moves
; test for check
; test for checkmate
; test for stalemate

#define TOP_LEVEL 3
#define BOARD 0
#define TABLE_BOARD_INIT 0
#define TABLE_OFFSET 120
#define TABLE_DISPLACEMENTS 127
#define TABLE_SCORES 151
#define TRUE 1
#define FALSE 0
#define MIN_SCORE -64
#define MAX_SCORE 64

symbol opiece = b0
symbol piece = b1
symbol origin = b2
symbol target = b3
symbol offset = b4
symbol displacement = b5
symbol directions = b6
symbol capture = b7
symbol score = b8
symbol best_score = b9
symbol side = b10
symbol level = b11
symbol validmove = b12
symbol s2 = b13
symbol bs2 = b14

symbol i = b16
symbol sign = b17
symbol temp = b18
symbol p = b19
symbol row = b20
symbol col = b21
symbol check_king_attack = b22
symbol best_origin = b23
symbol best_target = b24
symbol saved_origin = b25
symbol saved_target = b26
symbol saved_opiece = b27
symbol saved_capture = b28
symbol n = b29
symbol rand = w15 ; b30, b31

; initial setup (0)
table (7, 7, 7, 7, 7, 7, 7, 7, 7, 7) ; 0
table (7, 7, 7, 7, 7, 7, 7, 7, 7, 7) ; 10
table (7, 2, 5, 3, 4, 6, 3, 5, 2, 7) ; 20
table (7, 1, 1, 1, 1, 1, 1, 1, 1, 7) ; 30
table (7, 0, 0, 0, 0, 0, 0, 0, 0, 7) ; 40
table (7, 0, 0, 0, 0, 0, 0, 0, 0, 7) ; 50
table (7, 0, 0, 0, 0, 0, 0, 0, 0, 7) ; 60
table (7, 0, 0, 0, 0, 0, 0, 0, 0, 7) ; 70
table (7, 9, 9, 9, 9, 9, 9, 9, 9, 7) ; 80
table (7,10,13,11,12,14,11,13,10, 7) ; 90
table (7, 7, 7, 7, 7, 7, 7, 7, 7, 7) ; 100
table (7, 7, 7, 7, 7, 7, 7, 7, 7, 7) ; 110

; offsets (120)
table (16) ; white pawn
table (20) ; black pawn
table (8)  ; rook
table (12) ; bishop
table (8)  ; queen
table (0)  ; knight
table (8)  ; king

; displacements (127)
table (0xeb,0xed,0xf4,0xf8) ; knight (-21,-19,-12,-8)
table (0x08,0x0c,0x13,0x15) ; knight (8,12,19,21)
table (0xf6,0x0a,0xff,0x01) ; rank and file, rook, queen, king (-10,10,-1,1)
table (0x09,0x0b,0xf7,0xf5) ; diagonal, bishop, queen, king (9,11,-9,-11)
table (0xf5,0xf7,0xf6,0xec) ; white pawn, capture left, capture right, forward one, forward two (-11,-9,-10,-20)
table (0x09,0x0b,0x0a,0x14) ; black pawn, capture left, capture right, forward one, forward two (9,11,10,20)

; piece scores (151)
table (0,1,5,3,9,3,45)

#rem
for i=0 to 10 : do
   if i=2 or i=3 then : exit : endif
   sertxd(#i)
   sertxd(0x0d)
exit : loop : next i
end
#endrem

start:
   gosub init
   do
      ; double loop so we can use exit to continue!
      do
         gosub show_board
         gosub read_coord
         get origin,opiece
         p = opiece&0x08
         if p=0 then
            gosub notvalid
            exit
         endif
         get target,p
         p = p&0x08
         if p!=0 then
            gosub notvalid
            exit
         endif
         ; check valid user move
         check_king_attack = FALSE
         saved_origin = origin
         saved_target = target
         level = 0
         side = 0x08 ; user move
         gosub _play
         if best_score!=MAX_SCORE then
            ; move not found
            gosub notvalid
            exit
         endif
         ; do the move and check for check
         origin = saved_origin
         target = saved_target
         gosub do_move
         ; save move in case need to undo
         saved_opiece = opiece
         saved_capture = capture
         ; check if user is in check
         check_king_attack = TRUE
         ; computer moves to validate if user in check
         side = 0
         gosub _play
         if best_score=MAX_SCORE then
            sertxd("In check!\r\n")
            origin = saved_origin
            target = saved_target
            opiece = saved_opiece
            capture = saved_capture
            gosub undo_move
            exit
         endif
         ; user move is valid
         gosub show_board
         ; computer move
         check_king_attack = TRUE
         level = TOP_LEVEL
         side = 0 ; black to play
         n = 1 ; number of moves with same score
         gosub _play
         sertxd("Move score: ",#best_score,"\r\n")
         get best_origin,opiece
         origin = best_origin
         target = best_target
         gosub do_move
      loop
   loop
end

notvalid:
   sertxd("Not a valid move.\r\n")
return

read_coord:
   serrxd temp
   if temp="x" then : reset : endif
   origin = temp-1&0x07+1
   serrxd temp
   temp = temp-1&0x07
   origin = 9-temp*10+origin
   serrxd temp
   target = temp-1&0x07+1
   serrxd temp
   temp = temp-1&0x07
   target = 9-temp*10+target
return

init:
   pushram clear
   pushram clear
   pushram clear
   pushram clear
   pushram clear
   for i=0 to 119
      readtable i,temp
      put i,temp
   next
return
   
headers:
   sertxd ("  A B C D E F G H\r\n")
return

show_board:
   i = 21
   gosub headers
   for row=0 to 7
      temp = 0x38-row
      sertxd(temp)
      for col=0 to 7
         get i,p
         lookup p,(".prbqnk  PRBQNK"),p
         sertxd(" ")
         sertxd(p)
         inc i
      next
      sertxd(" ")
      sertxd(temp)
      sertxd(0x0d)
      sertxd(0x0a)
      inc i
      inc i
   next
   gosub headers
   sertxd(0x0d)
   sertxd(0x0a)
return

do_move:
   p = opiece
   if p=1 or p=9 then
      if target<29 or target>90 then
         ; promote pawn to queen
         p = p^0x05
      endif
   endif
   get target,capture
   put target,p
   put origin,0
return

undo_move:
   put origin,opiece
   put target,capture
return

   
_play:
   validmove = FALSE
   best_score = MIN_SCORE
   ; scan the board
   for origin=21 to 98
      ; progress
      if level=TOP_LEVEL then
         sertxd(".")
      endif
      get origin,opiece
      if opiece=0 then next_origin
      piece = opiece^side
      if piece>6 then next_origin
      if piece=1 and side!=0 then 
         piece=0
      endif
      offset = TABLE_OFFSET+piece
      readtable offset,offset
      directions = piece+4&0x0c
      do
         target = origin
         displacement = TABLE_DISPLACEMENTS+offset
         readtable displacement,displacement
         do
            target = target+displacement
            get target,capture
            if capture=7 then exit
            if capture=0 then
               ; pawn moves 1 or 2?
               if offset>=16 then
                  if directions>2 then exit
                  readtable origin,temp
                  temp = temp&0x07
                  if temp!=1 then
                     dec directions
                  endif
               endif
            else
               ; see if pawn can capture
               if offset>=16 then
                  if directions<3 then
                     directions = 1
                     exit
                  endif
               endif
               ; check for capture and break if own piece
               temp = capture^side
               if temp<7 then exit
               if check_king_attack=TRUE then
                  if temp=14 then
                     best_score = MAX_SCORE
                     return
                  endif
               endif
            endif
            if level=0 then
               if check_king_attack=FALSE then
                  ; do user move validation
                  if saved_origin=origin and saved_target=target then
                     best_score = MAX_SCORE
                     return
                  endif
               endif
            else
               gosub do_move
               pushram
               level = 0
               side = side^0x08
               gosub _play
               temp = best_score
               popram
               if temp=MAX_SCORE then
                  gosub undo_move
               else
                  validmove = TRUE
                  temp = capture&0x07+TABLE_SCORES
                  readtable temp,score
                  if target>52 and target<57 then
                     inc score
                  elseif target>62 and target<67 then
                     inc score
                  endif
                  if level>1 then
                     pushram
                     side = side^0x08
                     dec level
                     s2 = score
                     bs2 = best_score
                     gosub _play
                     temp = best_score
                     popram
                     score = score-temp
                  endif
                  gosub undo_move
                  temp = score-best_score
                  sign = ~score&best_score
                  if temp!=0 and temp<0x80 or sign>=0x80 then
                     best_score = score
                     if level=TOP_LEVEL then
                        best_origin = origin
                        best_target = target
                        ; //// output best so far
                     else
                        sign = s2-best_score
                        temp = bs2-sign
                        sign = ~bs2&sign
                        if temp!=0 and temp<0x80 or sign>=0x80 then
                           return
                        endif
                     endif
                  elseif temp=0 and level=TOP_LEVEL then
                     ; select a random move
                     inc n
                     random rand
                     temp = rand%n
                     if temp=0 then
                        best_origin = origin
                        best_target = target
                        ; //// output best so far
                     endif
                  endif
               endif
            endif
            if piece>4 or piece<2 then exit
            if capture!=0 then exit
         loop
         inc offset
         dec directions
      loop while directions>0
   next_origin:
   next origin
   if level!=0 and validmove=FALSE then
      ; no valid moves found, check for checkmate
      pushram
      level = 0
      side = side^0x08
      gosub _play
      temp = best_score
      popram
      if temp=MAX_SCORE then
         best_score = TOP_LEVEL-level-MAX_SCORE
      else
         best_score = 0;
      endif
   endif
return
