globals
[ time ]

breed [people person]
breed [borders border]
breed [tables table]
breed [chairs chair]
breed [doors door]
breed [vendors vendor]
breed [queues queue]

patches-own
[ meaning ]

people-own
[ status
  count-down
  sitting?
  infection?
  buying?
  leave?
]

borders-own []

chairs-own
[ availability ]

queues-own
[ vendors-id
  availability
  id ]

vendors-own
[ queue-list ]

;----------------------------------------------- SETUP -----------------------------------------------;
to setup
  ca
  setup-borders
  setup-vendors
  setup-table
  setup-people
  reset-ticks
end

to setup-borders
  ask patches [set meaning "aisle"]
  ;setup borders (yellow line)
  ask patches with [pxcor = min-pxcor or pxcor = max-pxcor]
  [ set meaning "border"
    sprout-borders 1
    [ set shape "border"
      set color yellow
      ifelse xcor = min-pxcor [set heading 0][set heading 180]]]
  ask patches with [pycor = min-pycor or pycor = max-pycor]
  [ set meaning "border"
    sprout-borders 1
    [ set shape "border"
      set color yellow
      set heading 90]]

  ;setup door
  ask patches with [pxcor = round (max-pxcor / 2)]
  [ ask borders in-radius (door-size / 2) with [ycor = min-pycor]
    [ ask patch-here
      [ set meaning "door"
        sprout-doors 1
        [ set shape "chair-trans"
          set heading 0]]
      die]]
end

to setup-vendors
  let needed-space-x (vendors-size * (vendors-num - (2 * round(vendors-num / 3)))) + (2 * (vendors-num - (2 * round(vendors-num / 3)))) + 4
  let needed-space-y (vendors-size * round(vendors-num / 3)) + (2 * (round(vendors-num / 3) - 1)) + 5
  ifelse needed-space-x <= (max-pxcor - 2) and needed-space-y <= (max-pycor - 2)
    [ breed-vendors ]
    [ user-message (word "Free space not enough, please reduce vendors settings") ]
  ask vendors
  [ ask patch-here [set meaning "vendors"]]
end

to breed-vendors
  let center_x max-pxcor
  let center_y max-pycor - 5
  let num_ round(vendors-num / 3) - 1
  let aisle_between 2
  let list_ []
  let not_vendor []

  ;for vertical vendors
  let n 0 ;for looping
  while [ n <= num_ ]
  [ set list_ lput (center_y - (n * vendors-size) - (n * aisle_between)) list_
    set n n + 1]
  foreach list_
  [ y -> breed-vendors-vertical max-pxcor y]
  foreach list_
  [ y -> breed-vendors-vertical min-pxcor y]
  foreach list_ [y -> set not_vendor lput (y - (round(vendors-size / 2) - 1)) not_vendor]
  ask vendors with [not member? ycor not_vendor][set shape "vendor-table" stamp die]

  ;for horizontal vendors
  set num_ vendors-num - (2 * round(vendors-num / 3))
  ifelse num_ mod 2 = 0

  ;if even
  [ set center_x (round(max-pxcor / 2) + (round (vendors-size / 2)))
    set list_ []
    set list_ lput center_x list_
    set n 1 ;for looping
    while [ n <= (num_ / 2) - 1]
    [ set list_ lput (center_x + (n * vendors-size) + (n * aisle_between)) list_
      set n n + 1]
    set n 1
    while [ n <= (num_ / 2) ]
    [ set list_ lput (center_x - (n * vendors-size) - (n * aisle_between)) list_
      set n n + 1]]

  ;if odd
  [ set center_x round(max-pxcor / 2)
    set list_ []
    set list_ lput center_x list_
    set n 1 ;for looping
    while [ n <= (num_ / 2) ]
    [ set list_ lput (center_x + (n * vendors-size) + (n * aisle_between)) list_
      set list_ lput (center_x - (n * vendors-size) - (n * aisle_between)) list_
      set n n + 1]]
  foreach list_
  [ x -> breed-vendors-horizontal x max-pycor]
  set not_vendor []
  foreach list_ [x -> set not_vendor lput (x - (round(vendors-size / 2) - 1)) not_vendor]
  ask vendors with [not member? xcor not_vendor and heading = 90][set shape "vendor-table" stamp die]

  setup-queue
  add-queue-to-vendors
end

to breed-vendors-vertical [ x_ y_]
  ask patches with [pxcor = x_ and pycor = y_ ]
  [ ask patches in-radius ((vendors-size - 1) / 2) with [pxcor = x_]
    [ sprout-vendors 1
      [ set shape "vendor"
        set heading min [heading] of borders-here
        set color yellow]]]
end

to breed-vendors-horizontal [ x_ y_]
  ask patches with [pxcor = x_ and pycor = y_ ]
  [ ask patches in-radius ((vendors-size - 1) / 2) with [pycor = y_]
    [ sprout-vendors 1
      [ set shape "vendor"
        set heading min [heading] of borders-here
        set color yellow]]]
end

to setup-queue
  let heading_ 0
  let angle_ 0
  ask vendors with [pxcor = min-pxcor or pxcor = max-pxcor]
  [ breed-queue (heading - 90) 90 1 who]
  ask vendors with [pycor = max-pycor]
  [ breed-queue (heading - 90) 90 1 who]

  ask queues
  [ let list_ range(vendors-size)
    set list_ remove 0 list_
    set angle_ heading - 180
    ( ifelse
      xcor = min-pxcor + 1 [ set heading_ heading - 90]
      xcor = max-pxcor - 1 [ set heading_ heading + 90]
      ycor = max-pycor - 1 [ set angle_ heading + 90 set heading_ heading - 90])

    foreach list_
    [ x -> breed-queue heading_ angle_ x vendors-id]]

  ask queues
  [ (ifelse
    xcor = min-pxcor + 1 and heading != 270 [ set angle_ heading + 90 ]
    xcor = max-pxcor - 1 and heading != 90 [ set angle_ heading - 90 ]
    ycor = max-pycor - 1 and heading != 0 [ set angle_  heading]
    [set angle_ "no"])
    if angle_ != "no" [breed-queue (heading - 180 ) angle_ 1 vendors-id]]
end

to breed-queue [heading_ angle_ dist_ vendors_id]
  ask patch-right-and-ahead angle_ dist_
    [ sprout-queues 1
      [ set shape "queue"
        set vendors-id vendors_id
        set availability 0
        set heading heading_
        set color gray]]
end

to add-queue-to-vendors
  ;add queue list to vendors
  ask vendors
  [ let who_ who
    let last_ []
    let all_ sublist sort [who] of queues with [vendors-id = who_] 0 vendors-size
    let last_who sublist sort [who] of queues with [vendors-id = who_] vendors-size length [who] of queues with [vendors-id = who_]

    ifelse heading != 90 ;the top vendors
    ;sort based on y
    [ let last_y sort-by > [ycor] of queues with [member? who last_who]
      foreach last_y [y -> ask queues with [ycor = y and member? who last_who] [set last_ lput who last_]]]
    ;sort based on x
    [ let last_x sort-by > [xcor] of queues with [member? who last_who]
      foreach last_x [x -> ask queues with [xcor = x and member? who last_who] [set last_ lput who last_]]]

    set all_ lput last_ all_
    set all_ reduce sentence all_
    set queue-list all_
    foreach all_ [ x -> ask queues with [who = x][set id position x all_]]
  ]
end

to setup-table
  let needed-space-x (table-columns * table-size) + (table-aisle * (table-columns - 1))
  let needed-space-y (table-rows * 4) + (table-aisle * (table-rows - 1))
  ifelse needed-space-x <= (max-pxcor - 2) and needed-space-y <= (max-pycor - 2)
    [ breed-table ]
    [ user-message (word "Free space not enough, please reduce table settings") ]
end

to breed-table
  let x-start-point 0
  let y-start-point 0
  ifelse table-columns mod 2 = 1
  [ set x-start-point round(max-pxcor / 2) ] ;if odd, start the table layout from center
  [ set x-start-point (round(max-pxcor / 2) + (table-size / 2)) ] ;if even

  ifelse table-rows mod 2 = 1
  [ set y-start-point round(max-pycor / 2) ] ;if odd, start the table layout from center
  [ set y-start-point (round(max-pycor / 2) + 4) ] ;if even -> 5 represent table width + chairs on each side + space between table

  ;first center table
  make-table x-start-point y-start-point
  set y-start-point y-start-point + 1
  make-table x-start-point y-start-point
  set y-start-point y-start-point - 1

  ;horizontal table (based on columns)
  let list-col []
  ifelse table-columns mod 2 = 0
  ;if even
  [ let n 1 ;for looping
    while [ n <= ((table-columns / 2) - 1) ]
    [ set list-col lput (x-start-point + (n * table-size) + (n * table-aisle)) list-col
      set n n + 1]
    set n 1
    while [ n <= (table-columns / 2) ]
    [ set list-col lput (x-start-point - (n * table-size) - (n * table-aisle)) list-col
      set n n + 1]]
  ;if odd
  [ let n 1 ;for looping
    while [ n <= (table-columns / 2) ]
    [ set list-col lput (x-start-point + (n * table-size) + (n * table-aisle)) list-col
      set list-col lput (x-start-point - (n * table-size) - (n * table-aisle)) list-col
      set n n + 1]]

  ;vertical table (based on rows)
  let list-row []
  ifelse table-rows mod 2 = 0
  ;if even
  [ let n 1 ;for looping
    while [ n <= ((table-rows / 2) - 1) ]
    [ set list-row lput (y-start-point + (n * 4) + (n * table-aisle)) list-row
      set n n + 1]
    set n 1
    while [ n <= (table-rows / 2) ]
    [ set list-row lput (y-start-point - (n * 4) - (n * table-aisle)) list-row
      set n n + 1]]
  ;if odd
  [ let n 1 ;for looping
    while [ n <= (table-rows / 2) ]
    [ set list-row lput (y-start-point + (n * 4) + (n * table-aisle)) list-row
      set list-row lput (y-start-point - (n * 4) - (n * table-aisle)) list-row
      set n n + 1]]

  ;for middle part
  foreach list-row
    [ y -> make-table x-start-point y
      set y y + 1
      make-table x-start-point y]

  ;the rest
  foreach list-col
  [ x -> make-table x y-start-point
    set y-start-point y-start-point + 1
    make-table x y-start-point
    set y-start-point y-start-point - 1
    foreach list-row
    [ y -> make-table x y
      set y y + 1
      make-table x y]]

  make-chair
end

to make-table [x-start-point y-start-point]
  ask patches with [pxcor = x-start-point and pycor = y-start-point]
  [ set meaning "table"
    sprout-tables 1
    [ set heading 90
      ask patches in-cone (table-size / 2) 0
      [ set meaning "table"
        sprout-tables 1
        [ set shape "table"
          set heading 0
          set color blue]]
      set heading 270
      ask patches in-cone ((table-size / 2) - 1) 0
      [ set meaning "table"
        if not any? tables-here
        [ sprout-tables 1
          [ set shape "table"
            set heading 0
            set color blue]]]]]
  ask tables with [shape != "table"][die]
end

to make-chair
  ask tables
  [ let who_ who
    ask patches in-cone 1 0
    [ if not any? tables-here
      [ set meaning "chair"
        sprout-chairs 1
        [ face table who_
          set availability "available"
          set shape "chair-trans"]]
        sprout 1
        [ face table who_
          set shape "chair"
          set color blue
          stamp die]]
    set heading 180
    ask patches in-cone 1 0
    [ if not any? tables-here
      [ set meaning "chair"
        sprout-chairs 1
        [ face table who_
          set availability "available"
          set shape "chair-trans"]]
        sprout 1
        [ face table who_
          set shape "chair"
          set color blue
          stamp die]]
  ]

  ask patches with [ meaning = "aisle" and not any? turtles-here]
  [ sprout 1 ]
  ask turtles with [breed = turtles]
    [ (ifelse
      count chairs in-radius 2 = 4 and not any? tables in-radius 2 [set meaning "intersection" die]
      count chairs in-radius 2 >= 2 and count tables in-radius 2 >= 2 [ set meaning "table-aisle" die]
      count chairs in-radius 2 = 2 and not any? tables in-radius 2 [set meaning "intersection" die]
      any? chairs in-radius 1 or any? tables in-radius 1 [set meaning "table-aisle" die])]
  ask turtles with [breed = turtles]
    [ ifelse count chairs in-radius 2 = 1 and count patches in-radius 1 with [meaning = "table-aisle"] >= 2 [set meaning "intersection" die]
      [die]]

end

to setup-people
  ask n-of initial-people patches with [meaning = "aisle" ]
  [ breed-people ]
  ask people
  [ if any? queues with [availability = 0]
    [ set status "buying" select-vendors]]
end

to breed-people
  sprout-people 1
  [ set shape "person"
    set color white
    set status "moving"
    if random-float 1 <= initial-infection [set infection? 1 set color red]
    set heading 0
  ]
end

;------------------------------------------------ ASSIGN VENDORS ------------------------------------------------;
to select-vendors
  let selected_ 0
  ask one-of vendors with
  [ any-available-queue? queue-list = true]
  [ let vendors_ who
    let queue_ min [id] of queues with [vendors-id = vendors_ and availability = 0]
    ask queues with [vendors-id = vendors_ and id = queue_]
    [ set selected_ who
      set availability 1]]
  set buying? selected_
end

to-report any-available-queue? [list_]
  if min [availability] of queues with [member? who list_] = 0 [report true]
  report false
end

;------------------------------------------------ GO ------------------------------------------------;
to go
  ask people
  [(ifelse
    status = "buying" [ buy ]
    status = "ordering" [ order ]
    status = "moving" [ move ]
    status = "sitting" [ sit ]
    status = "eat" [ eat ]
    status = "leaving" [ leave ])
    virus-spread-move ]
  count-time
  arriving-people
  tick
end

;------------------------------------------------ MOVE ------------------------------------------------;
to buy
  ifelse round xcor != [xcor] of turtle buying? and round ycor != [ycor] of turtle buying?
  [ step turtle buying?]
  [ move-to turtle buying?
    set heading [heading] of turtle buying?
    ifelse [id] of turtle buying? = 0
    ;if in front of vendors
    [ set status "ordering" set count-down (serving-time * 60) ]
    ;if not yet
    [ let who_ who let id_ ([id] of turtle buying? - 1) let vendors_ [vendors-id] of turtle buying?
      ask queues with [ id = id_ and vendors-id = vendors_]
      [ if availability = 0
        [ let queue_ who
          ask turtle who_
          [ ask turtle buying? [set availability 0]
            set buying? queue_]
          set availability 1]]
      move-to turtle buying?
      set heading [heading] of turtle buying?
    ]
  ]
end

to order
  set count-down count-down - 1
  if count-down = 0
  [ ifelse random 1 <= sitting-chance
    [set status "sitting"]
    [set status "leaving"]
    set sitting? one-of chairs with [availability = "available"]
    ask sitting? [set availability "not available"]
    ask queues-here [set availability 0]]
  ask people with [status = "buying"][buy]
end

to move
  if any? queues with [availability = 0]
  [ set status "buying" select-vendors]
  step one-of borders
end

to sit
  ifelse one-of turtles in-radius 1 != sitting?
  [ step sitting? ]
  [ move-to sitting?
    set count-down (sitting-time * 60)
    set status "eat"  ]
end

to eat
  set count-down count-down - 1
  if count-down = 0
  [ set status "leaving"
    set leave? one-of doors
    ask chairs-here [set availability "available"]]
end

to leave
  ifelse not any? doors-here
  [ step leave? ]
  [ die ]
end

to step [destination]
  let angle 45
  let x_ 0
  if [meaning] of patch-here != "table-aisle" and [meaning] of patch-here != "intersection"
  [ set heading 0
    ( ifelse
      ycor < [ycor] of destination [ set angle (1 * angle) ]
      ycor = [ycor] of destination [ set angle (2 * angle) ]
      ycor > [ycor] of destination [ set angle (3 * angle) ])
    ( ifelse
      xcor < [xcor] of destination [ set heading heading + angle set x_ "<" ]
      xcor = [xcor] of destination and ycor > [ycor] of destination [ set heading heading + (2 * angle)]
      xcor > [xcor] of destination [ set heading heading - angle set x_ ">" ])]

  if [meaning] of patch-here = "intersection"
  [ ifelse ycor < [ycor] of destination
    [ set heading 0 ]
    [ set heading 180 ]

    if ycor = ([ycor] of destination + 1) or ycor = ([ycor] of destination - 1)
    [ ifelse xcor < [xcor] of destination
      [ set heading 90 ]
      [ set heading 270 ]]
  ]

  let new-patch patch-ahead 1
  let turtle-ahead one-of turtles-on new-patch

  while [ turtle-ahead != nobody and [breed] of turtle-ahead != people and [breed] of turtle-ahead != queues and [breed] of turtle-ahead != doors]
    [(ifelse
      x_ = "<" and [meaning] of patch-here != "table-aisle" [set heading heading - 45]
      x_ = ">" and [meaning] of patch-here != "table-aisle" [set heading heading + 45]
      x_ = 0 and [meaning] of patch-here != "table-aisle" [set heading heading + 90]

      [set heading heading + 45])
      set new-patch patch-ahead 1
      set turtle-ahead one-of turtles-on new-patch]
  move-to new-patch
end

;------------------------------------------------ VIRUS SPREAD & RECOVERY ------------------------------------------------;
to virus-spread-move
  if people-here != nobody and [infection?] of people-here = [1] and random-float 1 <= infection-chance
    [ set infection? 1
      set color red ]
end

;------------------------------------------------ PEOPLE ARRIVE & LEAVE ------------------------------------------------;
to arriving-people
  if (time mod (1 / arrival-rate)) = 0 and count people < maximum-people
  [ ask one-of patches with [meaning = "door"]
    [ breed-people ]]
end

to count-time
  set time time + 1
end
@#$#@#$#@
GRAPHICS-WINDOW
329
40
805
517
-1
-1
13.0
1
10
1
1
1
0
1
1
1
0
35
0
35
0
0
1
min
30.0

SLIDER
15
43
171
76
initial-people
initial-people
0
100
50.0
1
1
NIL
HORIZONTAL

SLIDER
16
84
171
117
arrival-rate
arrival-rate
0
1
1.0
0.05
1
person/sec
HORIZONTAL

INPUTBOX
187
45
290
105
maximum-people
150.0
1
0
Number

BUTTON
229
169
292
202
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
843
48
961
81
door-size
door-size
2
20
8.0
2
1
NIL
HORIZONTAL

BUTTON
229
210
292
243
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
975
126
1046
171
total-table
table-rows * table-columns
17
1
11

SLIDER
844
111
959
144
table-rows
table-rows
1
5
5.0
1
1
NIL
HORIZONTAL

TEXTBOX
845
92
995
110
Tables & Chairs Setting
11
0.0
1

SLIDER
844
143
959
176
table-columns
table-columns
1
4
4.0
1
1
NIL
HORIZONTAL

MONITOR
974
183
1044
228
total-chairs
count chairs
17
1
11

SLIDER
844
175
959
208
table-aisle
table-aisle
0
5
1.0
1
1
patch
HORIZONTAL

SLIDER
844
208
959
241
table-size
table-size
2
6
6.0
2
1
NIL
HORIZONTAL

SLIDER
15
223
167
256
sitting-chance
sitting-chance
0
1
0.7
0.05
1
NIL
HORIZONTAL

SLIDER
15
305
167
338
initial-infection
initial-infection
0
1
0.1
0.05
1
NIL
HORIZONTAL

SLIDER
15
190
167
223
sitting-time
sitting-time
0
20
10.0
1
1
min
HORIZONTAL

SLIDER
15
343
168
376
infection-chance
infection-chance
0
1
0.3
0.01
1
NIL
HORIZONTAL

SLIDER
845
267
958
300
vendors-num
vendors-num
3
10
9.0
1
1
NIL
HORIZONTAL

SLIDER
845
300
958
333
vendors-size
vendors-size
1
7
7.0
2
1
NIL
HORIZONTAL

TEXTBOX
848
252
998
270
Vendors Setting
11
0.0
1

SLIDER
845
333
958
366
serving-time
serving-time
0
10
1.0
1
1
min
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

border
true
0
Rectangle -7500403 true true 120 0 180 300

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

chair
true
0
Circle -7500403 true true 0 0 300
Rectangle -16777216 true false -15 -15 300 150
Circle -16777216 true false 45 45 210
Circle -7500403 true true 60 45 180
Circle -7500403 true true 255 120 60
Circle -7500403 true true -15 120 60

chair-trans
true
0

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

kiva
true
0
Circle -16777216 true false 15 15 90
Circle -16777216 true false 195 15 90
Rectangle -955883 true false 45 195 255 285
Circle -955883 true false 15 195 90
Circle -955883 true false 195 195 90
Rectangle -16777216 true false 45 15 255 105
Rectangle -955883 true false 15 45 285 240
Polygon -7500403 true true 270 165 210 195 210 105 270 135
Polygon -7500403 true true 135 30 105 90 195 90 165 30
Polygon -7500403 true true 135 270 105 210 195 210 165 270
Polygon -7500403 true true 30 135 90 105 90 195 30 165
Polygon -7500403 true true 105 90 90 105 90 195 105 210 195 210 210 195 210 105 195 90
Circle -16777216 true false 105 105 90

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

people-heading
true
0
Polygon -7500403 true true 150 0 90 75 135 60 135 120 165 120 165 60 210 75
Circle -7500403 true true 60 105 180

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

queue
true
0
Polygon -7500403 true true 15 180 150 60 285 180 150 105

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

table
true
0
Rectangle -7500403 true true 0 0 390 315

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

vendor
true
0
Rectangle -7500403 true true 120 0 180 300
Rectangle -7500403 true true 0 -15 90 330
Polygon -7500403 true true 195 150 270 60 240 150 270 240 195 150 195 150

vendor-table
true
0
Rectangle -7500403 true true 120 0 180 300
Rectangle -7500403 true true 0 -15 90 330

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.0-RC2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
