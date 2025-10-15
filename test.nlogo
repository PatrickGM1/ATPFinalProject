; -------------------------
; Zombies vs Humans (NL 6.4) + Efficient Grouping + Spacing + Leader Dedupe
; -------------------------

; breeds
breed [ builders builder ]
breed [ humans human ]
breed [ zombies zombie ]

globals [
  stop-reason

  ;; --- combat tunables ---
  infection-delay
  p-z-infect
  p-z-damage
  p-h-hit
  human-base-hp
  zombie-base-hp
  human-base-damage

  ;; --- counters ---
  human-deaths-combat
  zombie-deaths

  ;; --- grouping controls ---
  group-min-dist           ;; spacing inside groups
  group-scan-period        ;; how often (in ticks) to run grouping logic

  ;; --- grouping stats (for monitors & plot) ---
  initial-loners
  initial-groupers
  alive-loners
  alive-groupers

]

; per-breed state
humans-own  [
  panic-time
  infection-timer
  hp
  h-damage

  ;; --- grouping state ---
  grouping?          ;; random 50/50 on spawn
  group-id           ;; leader's who (or -1 if ungrouped)
  leader?            ;; am I the leader?
  leader-turtle      ;; reference to leader turtle (or nobody)
]
zombies-own [
  chasing-time
  z-speed
  z-damage
  z-health
  hp
]

; -------------------------
; main loop
; -------------------------
to go
  set-current-plot "Zombies vs. time"
  set-current-plot-pen "default"
  plotxy ticks count zombies

  ; --- zombies ---
  ask zombies [
    set color green
    ifelse chasing-time > 0 [ set chasing-time chasing-time - 1 ]
    [ if random 4 = 0 [ set heading random 360 ] ]

    if (who - ticks) mod 5 = 0 [
      let beings-seen turtles in-cone 10 45 with [ self != myself ]
      if any? beings-seen [
        let target one-of beings-seen
        face target
        set chasing-time 20
      ]
    ]
    step z-speed

    let target one-of humans-here
    if target != nobody [
      zombie-attack target
      if target != nobody and [breed] of target = humans [
        ask target [ human-attack myself ]
      ]
    ]
  ]

  ; --- humans ---
  ask humans [
    ;; infection progression first
    if infection-timer > 0 [
      set infection-timer infection-timer - 1
      if infection-timer = 0 [
        ;; leaving any group on turn
        set leader? false
        set group-id -1
        set leader-turtle nobody

        set breed zombies
        set chasing-time 0
        set z-speed  0.20
        set z-damage 2.0
        set z-health 1.0
        set color green
        set hp zombie-base-hp * z-health
      ]
    ]

    if breed = humans [
      ;; GROUP BEHAVIOR: spacing + following
      let grouped (group-id != -1 and grouping?)
      if grouped and panic-time = 0 [
        let mates other humans with [ group-id = [group-id] of myself ]
        let nearest nobody
        if any? mates [ set nearest min-one-of mates [ distance myself ] ]
        ifelse nearest != nobody and distance nearest < group-min-dist [
          ;; too close → step away softly
          facexy [xcor] of nearest [ycor] of nearest
          rt 180
        ] [ if (not leader?) and leader-turtle != nobody and [breed] of leader-turtle = humans [
            face leader-turtle
          ]
        ]
      ]

      step 0.22  ;; normal human speed

      if panic-time > 0 [
        set panic-time panic-time - 1
        if panic-time = 0 [
          ifelse infection-timer > 0 [ set color red + 2 ] [ set color magenta ]
        ]
        step 0.28
      ]

      ;; flee if zombie in front
      if (who - ticks) mod 5 = 0 [
        let beings-seen turtles in-cone 10 45
          with [ self != myself and breed = zombies ]
        if any? beings-seen [
          lt 157.5 + random-float 45
          set color magenta + 3
          set panic-time 10
        ]
      ]

      if leader? [ set color cyan ]  ;; keep leaders marked
    ]
  ]

  ;; run grouping/upkeep less often to avoid lag
  if ticks mod group-scan-period = 0 [ manage-grouping ]
  ;; collapse overlapping leaders so only one survives (lowest who)
  dedupe-leaders
  ;; periodic upkeep (cap sizes, elect canonical leader per group-id)
  if ticks mod (group-scan-period * 2) = 0 [ maintain-groups ]

  update-grouping-stats
  ; stopping conditions
  if count humans = 0 [
    set stop-reason (word "All humans infected at tick " ticks)
    stop
  ]
  if force-stop = true [
    if ticks >= simulation-time [
      set stop-reason (word "Simulation ended by reaching " ticks " ticks")
      stop
    ]
  ]

  tick
  ;; remove delay to reduce perceived lag
  ;; wait 0
end



; -------------------------
; motion helper (avoid walls)
; -------------------------
to step [dist]
  if [pcolor] of patch-ahead dist != black [
    let x dx + xcor
    let y dy + ycor
    face min-one-of neighbors4 with [ pcolor = black ] [ distancexy x y ]
  ]
  fd dist
end

; -------------------------
; COMBAT HELPERS
; -------------------------
to zombie-attack [h]
  let roll random-float 1
  let dmg z-damage

  if roll < p-z-infect [
    ask h [
      if infection-timer = 0 [
        set infection-timer infection-delay
        set color red + 2
      ]
      set hp hp - dmg
      if hp <= 0 [ die-human-combat ]
    ]
  ]
  if roll >= p-z-infect and roll < (p-z-infect + p-z-damage) [
    ask h [
      set hp hp - dmg
      if hp <= 0 [ die-human-combat ]
    ]
  ]
end

to human-attack [z]
  let roll random-float 1
  if roll < p-h-hit [
    let dmg h-damage
    ask z [
      set hp hp - dmg
      if hp <= 0 [ die-zombie ]
    ]
  ]
end

to die-human-combat
  set human-deaths-combat human-deaths-combat + 1
  die
end

to die-zombie
  set zombie-deaths zombie-deaths + 1
  die
end


; -------------------------
; GROUPING (efficient, radius-based)
; Forms/expands groups among humans within radius 1 of each other.
; -------------------------
to manage-grouping
  ;; stagger work across ticks to smooth CPU
  ask humans with [ grouping? and ((who + ticks) mod group-scan-period = 0) ] [
    let local humans in-radius 1 with [ grouping? ]
    if any? local [
      let cluster (turtle-set self local)
      if count cluster >= 2 [
        ;; choose a leader: prefer an existing one, else lowest who
        let L one-of (cluster with [ leader? ])
        if L = nobody [ set L min-one-of cluster [ who ] ]

        ;; assert leader info
        ask L [
          set leader? true
          set group-id who
          set leader-turtle self
          set color cyan
        ]

        let gid [who] of L
        let current count humans with [ breed = humans and group-id = gid ]
        let space max (list 0 (max-group-size - current))

        ;; recruit from this cluster up to capacity (safe n-of)
        let pool (cluster with [ self != L and group-id != gid ])
        if any? pool and space > 0 [
          let n min (list space count pool)
          ask n-of n pool [
            set group-id gid
            set leader-turtle L
            set leader? false
          ]
        ]
      ]
    ]
  ]
end


; -------------------------
; LEADER DEDUPE
; Keep exactly one leader when leaders are close.
; Lowest who within merge-radius remains leader; others (and their followers) join the winner.
; -------------------------
to dedupe-leaders
  let merge-radius 1.5
  ask humans with [ leader? ] [
    let the-winner self
    let rivals other humans in-radius merge-radius with
               [ leader? and who > [who] of the-winner ]
    if any? rivals [
      ask rivals [
        let rid who
        ;; demote rival
        set leader? false
        set group-id [who] of the-winner
        set leader-turtle the-winner
        ifelse infection-timer > 0 [ set color red + 2 ] [ set color magenta ]
        ;; move rival's followers to the winner too
        ask humans with [ group-id = rid ] [
          set group-id [who] of the-winner
          set leader? false
          set leader-turtle the-winner
          ifelse infection-timer > 0 [ set color red + 2 ] [ set color magenta ]
        ]
      ]
    ]
  ]
end


; -------------------------
; GROUP UPKEEP (less frequent)
; - ungroup followers whose leader vanished
; - elect lowest who as leader per group
; - enforce max size
; -------------------------
to maintain-groups
  ;; a real leader must have group-id = who
  ask humans with [ leader? and group-id != who ] [
    set leader? false
    ifelse infection-timer > 0 [ set color red + 2 ] [ set color magenta ]
  ]

  ;; clear followers with missing/invalid leader
  ask humans with [ leader-turtle != nobody ] [
    if [breed] of leader-turtle != humans [
      set leader-turtle nobody
      set group-id -1
      set leader? false
      ifelse infection-timer > 0 [ set color red + 2 ] [ set color magenta ]
    ]
  ]

  let gids remove-duplicates [ group-id ] of humans with [ group-id != -1 ]
  foreach gids [ gid ->
    let members humans with [ group-id = gid ]
    if count members <= 1 [
      ask members [
        set group-id -1
        set leader? false
        set leader-turtle nobody
        ifelse infection-timer > 0 [ set color red + 2 ] [ set color magenta ]
      ]
    ]
    if count members > 1 [
      let newleader min-one-of members [ who ]
      ask newleader [
        set leader? true
        set leader-turtle self
        set group-id who
        set color cyan
      ]
      ask members with [ self != newleader ] [
        set leader? false
        set leader-turtle newleader
        set group-id [who] of newleader
      ]
      ;; cap size (protect leader)
      let overflow max (list 0 (count members - max-group-size))
      if overflow > 0 [
        let to-unassign n-of overflow (members with [ not leader? ])
        ask to-unassign [
          set group-id -1
          set leader? false
          set leader-turtle nobody
          ifelse infection-timer > 0 [ set color red + 2 ] [ set color magenta ]
        ]
      ]
    ]
  ]
end


; -------------------------
; “uninfect” (reset mix to slider value)
; -------------------------
to uninfect
  ; zombies → humans (higher who back to human)
  ask zombies with [ who >= num-zombies ] [
    set breed humans
    set panic-time 0
    set color magenta
    set infection-timer 0
    set hp human-base-hp
    set h-damage human-base-damage

    ;; grouping init (50/50)
    set grouping? (random 2 = 0)
    set group-id -1
    set leader? false
    set leader-turtle nobody
  ]

  ; humans → zombies (lowest who)
  ask humans with [ who < num-zombies ] [
    set leader? false
    set group-id -1
    set leader-turtle nobody

    set breed zombies
    set chasing-time 0
    set z-speed  0.20
    set z-damage 2.0
    set z-health 1.0
    set color green
    set infection-timer 0
    set hp zombie-base-hp * z-health
  ]
end


; -------------------------
; setup wrappers
; -------------------------
to setup
  set stop-reason ""

  ;; ---- combat defaults ----
  set infection-delay     200
  set p-z-infect          0.30
  set p-z-damage          0.50
  set p-h-hit             0.55
  set human-base-hp       20
  set zombie-base-hp      10
  set human-base-damage    5.0

  set human-deaths-combat 0
  set zombie-deaths       0

  ;; --- grouping defaults (override with sliders if you want) ---
  set max-group-size 5
  set group-min-dist 1.2
  set group-scan-period 5

  setup-town
  setup-beings
end

to setup-beings
  clear-turtles

  set-current-plot "Zombies vs. time"
  clear-plot
  set-plot-x-range 0 1000
  set-plot-y-range 0 (num-humans + num-zombies)
  reset-ticks

  ; zombies get earliest who numbers (relied on by uninfect)
  create-zombies num-zombies [
    set size 4
    set chasing-time 0
    set z-speed  0.20
    set z-damage 2.0
    set z-health 1.0
    set color green
    set hp zombie-base-hp * z-health
    setxy random-xcor random-ycor
    set heading random-float 360
    while [ [pcolor] of patch-here != black ] [ fd 1 ]
  ]

  create-humans num-humans [
    set size 4
    set panic-time 0
    set infection-timer 0
    set color magenta
    set hp human-base-hp
    set h-damage human-base-damage

    ;; grouping init (50/50)
    set grouping? (random 2 = 0)
    set group-id -1
    set leader? false
    set leader-turtle nobody

    setxy random-xcor random-ycor
    set heading random-float 360
    while [ [pcolor] of patch-here != black ] [ fd 1 ]
  ]

  ;; --- grouping stats at spawn ---
  set initial-groupers count humans with [ grouping? ]
  set initial-loners   count humans with [ not grouping? ]
  set alive-groupers initial-groupers
  set alive-loners   initial-loners

  ;; --- plotting: add two pens on existing plot ---
  set-current-plot "Zombies vs. time"
  ;; we already do clear-plot above; now add pens for groupers/loners
  create-temporary-plot-pen "groupers"
  create-temporary-plot-pen "loners"

end

to update-grouping-stats
  set alive-groupers count humans with [ grouping? ]
  set alive-loners   count humans with [ not grouping? ]

  ;; plot on the existing plot using dedicated pens
  set-current-plot "Zombies vs. time"
  set-current-plot-pen "groupers"
  plotxy ticks alive-groupers
  set-current-plot-pen "loners"
  plotxy ticks alive-loners

  ;; (optional) switch back to default pen the zombies line uses
  set-current-plot-pen "default"
end


; -------------------------
; city carving
; -------------------------
to setup-town
  clear-patches
  ask patches [ set pcolor gray - 3 ]  ; buildings

  clear-turtles
  create-builders 112

  ask builders with [ who mod 2 = 0 ] [
    setxy random-xcor random-ycor
    set heading 90 * random 4
  ]
  ask builders with [ who mod 2 = 1 ] [
    setxy [xcor] of turtle (who - 1) [ycor] of turtle (who - 1)
    set heading (180 + [heading] of turtle (who - 1))
    fd 1
  ]

  ask builders [
    while [ [pcolor] of patch-here != black ] [
      set pcolor black
      fd 1
      if random-float 1 < (1 / 30) [
        lt (90 + 180 * random 2)
      ]
    ]
  ]

  clear-turtles
  create-builders 56 [
    setxy random-xcor random-ycor
    let xsize 2 + random 60
    let ysize 2 + random 60
    (foreach n-values xsize [ i -> i ] [ x ->
      foreach n-values ysize [ j -> j ] [ y ->
        ask patch-at x y [ set pcolor black ]
      ]
    ])
  ]

  clear-turtles

  if not wrap? [
    ask patches with [ pxcor = max-pxcor or pxcor = min-pxcor ] [ set pcolor gray - 3 ]
    ask patches with [ pycor = max-pycor or pycor = min-pycor ] [ set pcolor gray - 3 ]
  ]

  reset-ticks
end

to reset-world
  ca
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
821
622
-1
-1
3.0
1
15
1
1
1
0
1
1
1
-100
100
-100
100
0
0
1
ticks
30.0

BUTTON
27
16
90
49
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

SLIDER
22
207
194
240
num-humans
num-humans
0
1000
418.0
1
1
NIL
HORIZONTAL

SLIDER
21
257
193
290
num-zombies
num-zombies
0
100
52.0
1
1
NIL
HORIZONTAL

SWITCH
24
379
127
412
wrap?
wrap?
1
1
-1000

BUTTON
25
63
92
96
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

BUTTON
25
111
139
144
NIL
setup-beings
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
24
431
107
464
NIL
uninfect
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
832
86
932
131
NIL
count humans
17
1
11

MONITOR
965
84
1066
129
NIL
count zombies
17
1
11

MONITOR
832
20
1065
65
NIL
count humans with [ panic-time > 0 ]
17
1
11

PLOT
1089
20
1694
496
Zombies vs. time
Time
Zombies
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 2 -14439633 true "" "plot count turtles"

BUTTON
25
158
128
191
NIL
setup-town
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
23
480
128
513
NIL
reset-world
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
211
628
422
673
Why stopped
stop-reason
17
1
11

SWITCH
441
634
554
667
force-stop
force-stop
1
1
-1000

SLIDER
587
634
759
667
simulation-time
simulation-time
100
10000
100.0
1
1
NIL
HORIZONTAL

MONITOR
832
149
970
194
NIL
human-deaths-combat
17
1
11

MONITOR
982
149
1076
194
NIL
zombie-deaths
17
1
11

SLIDER
22
317
195
350
max-group-size
max-group-size
2
20
5.0
1
1
NIL
HORIZONTAL

MONITOR
834
214
924
260
NIL
initial-loners
17
1
11

MONITOR
952
215
1061
261
NIL
initial-groupers
17
1
11

MONITOR
834
280
918
326
NIL
alive-loners
17
1
11

MONITOR
952
277
1055
323
NIL
alive-groupers
17
1
11

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
NetLogo 6.4.0
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
