globals [ticks]

;; diggers are used only for setup
breeds [diggers humans zombies]
humans-own [panic-time]
zombies-own [chasing-time]

to go
  set-current-plot "Zombies vs. time"
  plot count zombies

  ask zombies [
    set color ifelse-value green-zombies? [green] [gray] 
    
    ifelse chasing-time > 0 [
      set chasing-time chasing-time - 1
    ] [
      if random 4 = 0 [set heading random 360]
    ]
    
    if (who - ticks) mod 5 = 0 [
      let beings-seen turtles in-cone 10 45 with [self != myself] 
      if any? beings-seen [
        let target random-one-of beings-seen
        face target
        set chasing-time 20
      ]
    ]
    
    step 0.2
    
    ask humans-here [
      set breed zombies
      set color ifelse-value green-zombies? [green] [gray]      
    ]
  ]
  
  ask humans [
    step 1
    if panic-time > 0 [
       set panic-time panic-time - 1
       if panic-time = 0 [set color magenta]
       step 1
    ] 

    if (who - ticks) mod 5 = 0 [
      let beings-seen turtles in-cone 10 45 with [self != myself and (breed = zombies or (breed = humans and panic-time > 0))] 
      if any? beings-seen [
        lt 157.5 + random-float 45
        set color magenta + 3
        set panic-time 10
      ]
    ]
  ]
  
  set ticks ticks + 1
end

;; In jigs of width 2 or 3, things like to get stuck. 

;; Step without running into things.  dist, the distance to step, should not
;; exceed 1, else the turtle might jump through a wall.  
to step [dist]
  if pcolor-of patch-ahead dist != black [
    ;; Turn so that we're facing parallel to the wall, ie. find the black neighbouring
    ;; patch closest to where we would have gone (at distance 1), and turn to face it.
    let x dx + xcor
    let y dy + ycor
    face min-one-of neighbors4 with [pcolor = black] [distancexy x y]
  ]
  fd dist
end

;; doesn't quite always uninfect, if num-zombies was increased
to uninfect
  ;; Reduce the number of zombies to num-zombies.  
  ask zombies with [who >= num-zombies] [
    set breed humans
    set color magenta
  ]
  ask humans with [who < num-zombies] [
    set breed zombies
    set color ifelse-value green-zombies? [green] [gray]      
  ]
end

to setup
  setup-town
  setup-beings
end

to setup-beings
  ct
  ;; this stuff is in this function just so it always happens
  set-current-plot "Zombies vs. time"
  clear-plot

  set ticks 0 
  
  ;; Zombies get the earliest who numbers; we use this elsewhere.
  ;; Make sure the beings are on non-built squares.  
  create-custom-zombies num-zombies [
    set color ifelse-value green-zombies? [green] [gray]
    setxy random-float screen-size-x random-float screen-size-y        
    set heading random-float 360
    while [pcolor != black] [fd 1]
  ]

  create-custom-humans num-humans [
    set color magenta
    setxy random-float screen-size-x random-float screen-size-y        
    set heading random-float 360
    while [pcolor != black] [fd 1]
  ]
end

to setup-town
  cp
  ask patches [set pcolor gray - 3]

  ;; Make the alleyways.  Instead of the rectangle-placing approach, which proves slow, 
  ;; let a special kind of turtle dig them.  
  ;; The number of diggers here and later will need changing if the screen size is changed.
  ct
  create-diggers 112 

  ;; Set the diggers up in pairs facing away from each other, so we don't get dead end passages
  ask diggers with [who mod 2 = 0] [
    setxy random-float screen-size-x random-float screen-size-y        
    set heading 90 * random 4
  ]
  ask diggers with [who mod 2 = 1] [
    setxy xcor-of turtle (who - 1) ycor-of turtle (who - 1)
    set heading 180 + heading-of turtle (who - 1)
    fd 1
  ]

  ask diggers [
    while [pcolor != black] [
      set pcolor black
      fd 1
      if random-float 1 < (1 / 30) [lt 90 + 180 * random 2]
    ]
  ]
  
  ;; Make the squares, by getting a few diggers to dig them out.  
  ct
  create-custom-diggers 56 [
    setxy random-float screen-size-x random-float screen-size-y
    let xsize 2 + random 60
    let ysize 2 + random 60
    foreach n-values xsize [?] [
      let x ?
      foreach n-values ysize [?] [set pcolor-of patch-at x ? black]
    ]
  ]
  
  ct
  
  ;; Fake non-wrapping by setting edge patches to building.
  if not wrap? [
    ask patches with [pxcor = screen-edge-x] [set pcolor gray - 3]
    ask patches with [pycor = screen-edge-y] [set pcolor gray - 3]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
500
10
1056
587
136
136
2.0
1
10
1
1
1
0
1
1
1

CC-WINDOW
5
609
1073
704
Command Center
0

SLIDER
18
102
190
135
num-humans
num-humans
0
6144
665
1
1
NIL

SLIDER
18
136
190
169
num-zombies
num-zombies
0
64
1
1
1
NIL

BUTTON
18
22
84
55
NIL
setup\n
NIL
1
T
OBSERVER
T
NIL

SWITCH
18
170
175
203
green-zombies?
green-zombies?
0
1
-1000

BUTTON
212
22
275
55
NIL
go
T
1
T
OBSERVER
T
NIL

BUTTON
18
219
100
252
NIL
uninfect
NIL
1
T
OBSERVER
T
NIL

BUTTON
87
22
201
55
NIL
setup-beings
NIL
1
T
OBSERVER
T
NIL

SWITCH
18
68
121
101
wrap?
wrap?
0
1
-1000

MONITOR
156
277
221
326
zombies
count zombies
3
1

MONITOR
18
277
81
326
humans
count humans
3
1

PLOT
18
329
218
479
Zombies vs. time
Time
Zombies
0.0
512.0
0.0
32.0
true
false

MONITOR
84
277
153
326
panicked
count humans with [panic-time > 0]
3
1

@#$#@#$#@
WHAT IS IT?
-----------
This is a moderately faithful rewrite of Kevan Davis' Zombie Infection Simulation in NetLogo.  

Go play with the original model if you haven't yet; a lot of this documentation is a comparison with the original. 

HOW IT WORKS
------------
Zombies are green (or gray), move very slowly and change direction randomly and frequently unless they can see something moving in front of them, in which case they start walking towards it. After a while they get bored and wander randomly again.

If a zombie finds a human on the same patch, it infects them; the human immediately joins the ranks of the undead.

Humans are pink (well, magenta) and run five times as fast as zombies, changing direction when they run into a wall.  If they see a zombie in front of them, they turn around and panic.

Panicked humans are bright pink and run twice as fast as other humans. If a human sees another panicked human, it starts panicking as well. A panicked human who has seen nothing to panic about for a while will calm down again.

HOW TO USE IT
-------------
Press SETUP to create and populate a new city.
Press SETUP-BEINGS to place the beings while retaining the current city.  
Press UNINFECT to reduce the number of zombies to NUM-ZOMBIES (this may change some humans to zombies if you have increased NUM-ZOMBIES while running the model).
GO, as usual, runs the model.  

Parameters:
NUM-HUMANS: number of humans (only takes effect after SETUP or SETUP-BEINGS)
NUM-ZOMBIES: number of zombies (only takes effect after SETUP or SETUP-BEINGS or UNINFECT)
GREEN-ZOMBIES?: are zombies green?  If not, they'll be gray.
WRAP?: does the city wrap around the edges? (only takes effect after SETUP)

SIGNIFICANT DIFFERENCES FROM THE ORIGINAL
-----------------------------------------
The model of space is the standard NetLogo model, in which space and direction are both continuous.  Thus, for instance, it's more reasonable for humans to keep
running in straight lines when nothing is in their way; they don't miss entrances to small passages or cluster as much as they would in the discrete grid-based model.

Beings' fields of vision are cones with 45 degree width instead of just the lines directly ahead.  These fields of vision go through walls (I guess the beings can hear, or smell, or something).

The city wraps around by default; again, this is more natural in NetLogo than it might be in proce55ing.

Arbitrarily many beings may occupy one patch.  

The city is carved out differently: although it has the same general feel, more types of passages can occur, for instance zig-zags:
| *****************
|                 *
|                 *
|                 *
|                 *****************

Beings only look ahead of themselves every fifth time step.  This was done to speed the model up, and appears to have no significant effects on the simulation.  

THINGS TO NOTICE
----------------
Infection takes place much more slowly, in terms of simulation timesteps, than in the original model.  

In zombie-dominated areas of the city, the zombies tend to form into lines (in the original model, we instead observe blobs).  

THINGS TO TRY
-------------
Find the critical population density for panic to be self-sustaining.  

Play with NetLogo perspective features like watch and follow.

Resize the city, using the Edit button on the city display.  This will probably require adjusting the numbers in the setup-town procedure to get the same overall proportion of open space.

EXTENDING THE MODEL
-------------------
A number of variants of the Zombie Infection Simulator have already been created (see Kevan's page for links).  This model could be extended in any of the same ways:
- Allow humans to fight back; alternatively, create a military breed of humans dedicated to fighting zombies.
- Drop nukes on the city.
- Let zombies break down walls.
etc.

These extensions are more like bug-fixes:
- Ensure that there are no completely isolated spaces without entrances or exits when the city is created.  
- Beings like to get stuck in zig-zags in tunnels that are only two or three patches wide.  Prevent this from happening.  
- Make the walls actually opaque.  (This will probably be a mess, since there is no support for this among the NetLogo agentset reporters like in-cone.)

And, of course, it would be nice to make it run faster.  

NETLOGO FEATURES
----------------
The tunnels in the city are carved by a dedicated breed of turtle (an initial attempt to generate them with patch agentsets proved horribly slow).

I especially like the way beings reorient themselves after hitting a wall -- they can even follow tunnels with no special case movement rules.  

Beings never move by more than distance 1 at a time, to prevent them from jumping through walls.  

Even though NetLogo supports a full suite of nowrap primitives, I lazily implemented the unwrapped city by simply placing walls around the edges.  This means that beings can still see in a wrapped fashion past these walls even when WRAP? is off.  



CREDITS AND REFERENCES
----------------------
Kevan Davis' original Zombie Infection Simulation, version 2.3:
http://kevan.org/proce55ing/zombies/

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

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 3.0.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
