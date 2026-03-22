// STARMAP book — Typst rendering
// Faithful reproduction of the 1978 book by Berry & Thorstensen

#import "template.typ": *

#show: starmap-book

// ── Title page ──────────────────────────────────────────────
#page(header: none, footer: none)[
  #v(1fr)
  #align(center)[
    #text(size: 18pt, weight: "bold")[STARMAP]
  ]
  #v(2fr)
  #align(center)[
    #text(size: 11pt)[Paul C. Berry] \
    #text(size: 11pt)[John R. Thorstensen]
  ]
  #v(1fr)
  #align(left)[
    #text(size: 8pt)[
      APL PRESS \
      Pleasantville \
      New York
    ]
  ]
]

// ── Copyright page ──────────────────────────────────────────
#page(header: none, footer: none)[
  #v(1fr)
  #text(size: 7pt)[
    Copyright APL Press 1978

    First published 1973 by IBM Corp. \
    as Technical Report No. 02.665.

    ISBN 0-917326-07-5
  ]
]

// ── Body ────────────────────────────────────────────────────
#counter(page).update(1)

= Introduction

#indent[In many fields of science or commerce, it is possible to define a set of functions (i.e. computer programs) in such a way that each corresponds to a term or concept used in that discipline. Such a set of functions in effect constitutes a "user language" for that particular area of application. If that language has a simple and consistent syntax, and if its various functions refer to the data on which they work in a consistent way, it is possible to achieve a programming package that is easy to understand, to revise, or to adapt to new applications. At the same time, such a package constitutes an _executable model_ of some of the concepts of that discipline.]

#indent[Constructing a particular definition by referring to a set of simpler or more general sub-definitions is the principal technique of what has come to be called _modular programming_; the program used for a particular job consists of a brief invocation of the concepts or components from which it is made. They in turn are defined by invoking modules at the next level of detail. Reading programs that have been written in that way, the student sees at the outer level a brief summary of the organization of the work; pursuing the definitions further, he or she may obtain explanation to whatever level of detail is desired.]

#indent[The aim of this paper is to illustrate this style of programming in APL by presenting in detail the definitions used in a particular project. We selected for this purpose the set of programs contained in an APL workspace called STARMAP, which was in use as part of a display on astronomy at the IBM Exhibit Center in New York during 1973 and 1974. That set of programs served to print at a terminal a map showing the positions of the brighter stars, the planets, and the comet Kohoutek, as they would appear above any point on Earth at any time on any date--at least for some number of years on either side of the present.]

#indent[To generate a map, the user started work by invoking a function called #apl[DISPLAY]. Thereupon he or she was asked to specify the date for which a map was wanted, the local time, and the latitude and longitude. The program then computed the positions of the stars and planets, and drew the map, either at the typewriter terminal (using a special type element for fine plotting) or on a cathode-ray display tube. A sample of the conversation in which a user enters the specifications of a map is shown in Figure 1; the resulting chart (photographically reduced from the original size of about 35 cm. square) is shown in Figure 2.]

#figure(
  image("../markdown/figure-01.png", width: 90%),
  caption: [Dialog during user's request for a star map],
  supplement: [Fig.],
)

#indent[Following this dialog, the keyboard is unlocked, awaiting a carriage return from the user to indicate that the fine plotting element has been inserted and the paper is ready to receive the printed map.]

#indent[On the opposite page appears the map generated in response to the request shown in Figure 1. The map has been photographically reduced; the actual print-out is about 35 cm. high. The fine plotting type element (number 114) carries fifteen dots and fifteen crosses, one for each position of a 3-by-5 matrix, giving a resolution of about .85 mm (1/30 inch) between adjacent points vertically or horizontally. Four additional star maps are shown beginning on page 28.]

#figure(
  image("../markdown/figure-02.png", width: 90%),
  caption: [Sample chart produced by the STARMAP workspace],
  supplement: [Fig.],
)

#indent[To generate such a map requires solving the formulas for planetary motion in order to know where in the solar system the planets should be located at the date requested, and then to translate those coordinates to show their apparent positions as seen from the Earth. The coordinates thus obtained, together with those of the fixed stars, could then be rotated for the desired time and location on the surface of the Earth.]

#indent[The motions of the planets may be described by formulas that were first developed by Kepler early in the seventeenth century. Kepler's function states the time needed for a planet to traverse a given angle through its orbit. To find the position at a given time requires the inverse of that function; a general iterative method, applicable to evaluating that inverse, was worked out by Newton later in the same century. The rest of the task is an exercise in analytic geometry, to translate and rotate the coordinates appropriately. Formulas for doing so were familiar in the seventeenth and eighteenth centuries, but were simplified by the matrix algebra developed in the nineteenth century. Thus the programming task involved here consists mainly of representing in terms executable by the computer a set of classical formulas.]

#indent[The interest in these programs lies not in the method itself, which has been well known for many years, but in the style in which classical and familiar formulas may be stated in APL. Our aim was to provide APL definitions for a vocabulary of terms which would not only make clear the process by which the work is done, but would permit the student of astronomy to apply them to new problems or applications. Where possible, we used names that correspond to those in general use in astronomy. Occasionally we had to coin names for functions which are not usually explicitly identified, but even here our terms should be recognizable to astronomers. To make our APL definitions correspond more directly to familiar formulas, we also made free use of defined functions such as #apl[SIN], #apl[COS], #apl[PI], #apl[RADIAN], etc. despite the fact that their effects could be readily obtained from APL primitives.]

#indent[Clearly, programs to convert the coordinates into a printed map or video display were also necessary to this project, but these are standard packages in widespread use, and we have not chosen to discuss them here.]

= Organization and key parameters

#indent[The function #apl[DISPLAY] initiates the entire task. It calls functions corresponding to the various stages of work. A tabular outline of the functions used is shown in Table 1. At the top left of the table the name #apl[DISPLAY] appears, indicating that this is the primary function. Indented five spaces below it appear the names of each of the functions called by #apl[DISPLAY]. Indented below them appear the names of functions they call, and so on. (For simplicity, some 98 references to functions such as #apl[SIN], #apl[COS], #apl[RADIAN], etc. have been omitted from the table.) The rest of this paper provides an explication of the work being done at each of these stages, in top-down order.]

#indent[In the text that follows, the symbol ∇ (del) is used to indicate the _header_ of a function, containing the name of the function, names for its arguments and results, and names for temporary variables used as intermediate steps in its definition, if any. As may be seen below, #apl[DISPLAY] calls #apl[ENTRY] (which requests input for the parameters governing a particular map), then pauses to permit the user to align the paper and insert the fine plotting element (indicated by the input symbol ⎕), and then calls #apl[WORK], which does the necessary calculations and prints the map:]

#apl-block[```
DISPLAY
ENTRY
⎕
WORK
```]

#indent[The function #apl[ENTRY] establishes the values of the input parameters by calling the functions #apl[GETDATE], #apl[GETTIME], #apl[GETLAT], and #apl[GETLONG], and adjusts the date and time stated by the user to correct for the indicated longitude:]

#apl-block[```
ENTRY
STATEDDAYNO←GETDATE
STATEDTIME←GETTIME
LAT←GETLAT
LONG←GETLONG
TIME←LONG TIMEADJUST STATEDTIME
DATE←STATEDDAYNO+(TIME÷24)-LONG÷360
```]

#indent[When execution of #apl[ENTRY] is complete, values have been established for the following variables:]

#param[TIME][Time is a single number indicating the number of hours since midnight in the exact local time for the indicated longitude. (However, the user enters the time in conventional form as it would appear on a clock in the nearest time zone.)]

#param[DATE][Although entered in a conventional form, the date is represented internally as the Julian day number; a function #apl[JNU] converts the date to that form. (The Julian day number of 1 January 1974 was 2442049.) The fractional part of the day number indicates how far through the day by universal time the indicated time is. Thus before the major calculations take place, all information on time is contained in the single number #apl[DATE].]

#param[LAT][Number of degrees north of the Equator.]

#param[LONG][Number of degrees east of the prime meridian.]

#indent[The time and date as entered by the user are preserved as #apl[STATEDTIME] and #apl[STATEDDATE], and the Julian day number of the stated date as #apl[STATEDDAYNO]; in some circumstances the adjusted value of #apl[DATE] (in universal time) may fall within a day 1 more or less than the stated date.]

= Stages of calculation

#indent[The task of calculation and printing may be divided into seven stages, each defined by a single function:]

#apl-block[```
WORK
CAPTION
CALCULATEPLANETS
REPORTPLANETS
CALCULATESTARS
PLOTSTARS
REPORTSTARS
PRINTED
```]

#indent[The sequence of segments is designed to overlap output to the terminal (produced by #apl[CAPTION] or #apl[REPORTPLANETS]) with the segments that require substantial calculation.]

#indent[The function #apl[CAPTION] recapitulates the stated input parameters, and adds the day of the week (directly obtainable from 7|STATEDDAYNO). The function #apl[REPORTPLANETS] prints a table showing for each planet (and the moon, sun, and comet) its right ascension and declination. For those that are visible, the altitude and azimuth are included, together with the coordinates on the map grid. The phase of the moon is reported.]

#indent[The function #apl[PLOTSTARS] calls #apl[FPLOT], which is adapted from the fine-plotting function in IBM program 5798-AGL, "Graphs and Histograms in APL." The stars and planets visible above the horizon are plotted, together with a circular frame of dots at 3-degree intervals around the horizon, and cross marks at intervals of 15 degrees of elevation. The standard plotting program was modified to insert a label showing the name of each planet, and to print a special symbol for the sun and moon.]

#indent[The function #apl[REPORTSTARS] prints a table showing the names of bright stars appearing in the plot, together with the altitude, azimuth and map-grid coordinates of each. The function #apl[PRINTED] permits the finished map to be labelled with the name of the person for whom it was prepared, and reports the date and time at which it was printed. The input and output functions are not described further in this article.]

#indent[The functions #apl[CALCULATEPLANETS] and #apl[CALCULATESTARS] use the global arguments #apl[DATE], #apl[TIME], #apl[LAT], and #apl[LONG], as well as the following reference tables:]

#param[#apl[STARS]][A table containing the right ascension and declination of about 300 bright stars.]

#param[#apl[planets]][A table of the elements for the elliptical orbits of the nine planets.]

#param[#apl[MOON]][A similar table for the elements of the moon's elliptical orbit about the Earth.]

#param[#apl[KOHOUTEK]][A table of the elements for the parabolic orbit of the comet.]

#param[#apl[BRIGHT]][A logical vector indicating which members of #apl[STARS] represent stars of magnitude 1.5 or brighter.]

#param[#apl[BP]][A logical vector indicating which planets are usually of magnitude 1.5 or brighter.]

#indent[The positions of the stars are taken from the Yale Catalog of Bright Stars, and the elements of the planetary orbits from the American Ephemeris and Nautical Almanac for 1973. The orbital functions which follow were written after consulting the text by Marion (1965) Classical Dynamics of Particles and Systems.]

= Coordinate systems used in describing the positions of the planets

#indent[Calculating the appearance of the heavens can be divided into two principal tasks: finding the locations of the planets in the solar system, and then calculating how they appear to an observer. A large part of the work thus involves rotation of coordinate axes, or translation from one system of coordinates to another. It will help to understand the programs that determine the positions of the planets if the various coordinate systems are first described.]

#indent[_Two-dimensional coordinates in the plane of each planet._ Each of the objects in orbit around the sun is first considered to be moving along an ellipse (or, in the case of the comet, along a parabola) lying in a plane. Each planet can thus be located by two coordinates. During the initial solution of the orbits, these are polar coordinates; they are then converted to Cartesian coordinates, describing the planet's position by its distance from the solar focus along the major and minor axes of the ellipse. Two-dimensional coordinates appear only within the functions #apl[PLANETPOS], #apl[MOONPOS], and #apl[COMETPOS].]

#indent[_Heliocentric Cartesian coordinates._ The two-dimensional Cartesian coordinates that specify each planet's position within the plane of its own orbit are converted to a common three-dimensional coordinate system whose center is in the sun. The first coordinate points from the sun in a direction opposite to the Earth at the moment of the vernal equinox. The second points perpendicularly out of the plane of the ecliptic, on the same side as the north pole. The third points in the plane of the ecliptic, perpendicularly to the other two, so that the three form a right-handed coordinate system. It intersects the celestial sphere at a right ascension of 18 hours (i.e. 270 degrees) and a declination (due to the tilt of the Earth's axis) of -23.45 degrees.]

#indent[Positions stated in the heliocentric system are given the name #apl[H] in the functions #apl[PLANETPOS], #apl[MOONPOS], #apl[COMETPOS], and in #apl[EARTHVIEW] (which translates from heliocentric to geocentric coordinates).]

#indent[The function #apl[ORBROTATE] converts the two-dimensional Cartesian coordinates of the planets within their own planes to three-dimensional heliocentric coordinates, taking into account the orientation and tilt of the plane of each orbit, by reference to the elements #apl[PERIANGLE] (angle of perihelion), #apl[INCLINATION], and #apl[ASCENDING] (the angle of the ascending node); see pp. 14-15.]

#indent[_Geocentric ecliptic coordinates._ The axes of this system are parallel to those of the heliocentric system, but have their origin in the center of the Earth rather than in the sun; values in this system are obtained simply by subtracting the heliocentric coordinates of the Earth from those of the object in question. Coordinates stated in this system are given the name #apl[GC]. They appear as intermediate steps in the function #apl[EARTHVIEW].]

#indent[_Geocentric equatorial coordinates._ This is a Cartesian form of the standard astronomical system of right ascension and declination. The first axis points (as before) to the vernal equinox. The second points to the north celestial pole. The third points at a location on the equator at the right ascension of the winter solstice.]

#indent[Positions in this coordinate system are obtained from those stated in the geocentric ecliptic system by a rotation of 23.45 degrees around the first axis. Variables stated in these coordinates are given the name #apl[GQ].]

#indent[_Egocentric coordinates._ The final transformation is to adjust for the position on Earth of the observer for whom the map is calculated. The first axis points due south. The second points to the zenith (above the observer). The third points due west. Positions in this system are obtained from positions in the geocentric equatorial system by a sequence of rotations in the course of the function #apl[SKYPOS], whose arguments are the positions of the planets in geocentric equatorial coordinates (#apl[GQ]) and the latitude, date, and time of the viewing point on Earth. The result is in units of altitude and azimuth, and such variables are given the name #apl[AA].]

= Calculating the positions of the planetary bodies

#indent[The function #apl[CALCULATEPLANETS] finds #apl[PLANETS], a table of the positions of the sun, moon, and planets at the desired date. When first calculated by the function #apl[PLANETPOS], these positions are stated in 3-dimensional heliocentric Cartesian coordinates. But the function #apl[EARTHVIEW] converts them to geocentric polar coordinates (right ascension in hours, declination in degrees, and distance in astronomical units), locating the planets with respect to the center of the Earth.]

#indent[In order to plot the sky above a particular place, the function #apl[SKYPOS] (see p. 29) is used to calculate #apl[AA], a table of altitude and azimuth with respect to given time and location on the Earth's surface. The function #apl[VISIBLE] is used to select from #apl[P] those members that are above the horizon, and saves them in the table #apl[AAE]. Finally, the #apl[PROJECTION] of these coordinates onto a flat surface is calculated, and translated to the Cartesian form expected by the plotting function; the function #apl[IF] is simply a compression of the left argument by the APL symbol /.]

#apl-block[```
CALCULATEPLANETS; AA; MOON; SUN; KOHOUTEK
PLANETCOORD←AAE←PLANETS←VP←10
PLANETS←DATE EARTHVIEW DATE PLANETPOS (3×19)/planets
SUN←DATE EARTHVIEW 0 0 0
K←100≥|DATE-JNU 12 28 1973
KOHOUTEK←DATE EARTHVIEW (DATE IF K) COMETPOS KOHOUTEK
MOON←MOONPOS DATE
PHASE←MOON[1;1] MOONPHASE SUN[1;1]
PLANETS←MOON,[1] SUN,[1] PLANETS,[1] KOHOUTEK
MOON←MOON[;3] PARALLAXADJUST (LAT,DATE,TIME) SKYPOS MOON
AA←MOON,[1] (LAT,DATE,TIME) SKYPOS 1 0+PLANETS
PLANETCOORD←MAPCARTESIAN PROJECTION AAE←AA IF VP←VISIBLE AA
```]

#indent[Execution of #apl[CALCULATEPLANETS] causes new values to be assigned to four global variables. (These are initially set to 10 in the first statement, mainly to draw attention to a list of the global variables which will be reset as a consequence of executing this function.) The four are:]

#param[#apl[PLANETS]][The right ascension and declination of the moon, sun, planets, and Kohoutek.]

#param[#apl[VP]][A logical vector indicating which planets are visible from the place, date, and time requested.]

#param[#apl[AAE]][The altitude and azimuth of the visible planets.]

#param[#apl[PLANETCOORD]][The Cartesian coordinates used to plot the projection of the visible planets.]

= Orbital parameters

#indent[The functions that locate the positions of the planets in their orbits make reference to a set of parameters usually called the _elements_ of the orbit. The reference set of orbital elements for the planets is stored in the matrix #apl[planets]. Each row contains the set of elements for a particular planet. For example:]

#apl-block[```
Z←EARTH
Z←planets[,3;]
```]

#indent[Each column corresponds to a particular element of the various orbits. Each of the functions that makes use of the orbital elements (#apl[PLANETPOS], #apl[MOONPOS], or #apl[COMETPOS]) take as one of its arguments a matrix containing the rows of the table #apl[planets] that are appropriate: i.e. those corresponding to the particular planets being considered. This sub-table is given the name #apl[ORB]. Functions are provided corresponding to each orbital element (for example, #apl[PERIOD], #apl[ECCENTRICITY], #apl[INCLINATION], etc.). Those functions select the appropriate column of the table #apl[ORB]. In that way, terms such as #apl[PERIOD], #apl[ECCENTRICITY] or #apl[INCLINATION] refer to those elements for the planets currently under consideration, whatever those may be. This is achieved by making #apl[ORB], the table from which the values are selected, global with respect to these selection functions, but local to the functions such as #apl[PLANETPOS] which use the elements, since #apl[ORB] there appears as the explicit argument.]

#indent[The geometrical meanings of the terms inclination, ascending node, and angle of perihelion are illustrated in Figure 5.]

// Two-column selector functions layout
#grid(
  columns: (1fr, 1fr),
  column-gutter: 1em,
  apl-block[```
Z←SEMIMAJOR
Z←ORB[;1]
```],
  apl-block[```
Z←ASCENDING
Z←ORB[;5]
```],
  apl-block[```
Z←PERIOD
Z←ORB[;2]
```],
  apl-block[```
Z←PERIANGLE
Z←ORB[;6]
```],
  apl-block[```
Z←ECCENTRICITY
Z←ORB[;3]
```],
  apl-block[```
Z←ANOMALY
Z←ORB[;7]
```],
  apl-block[```
Z←INCLINATION
Z←ORB[;4]
```],
  apl-block[```
Z←ANOMALYDATE
Z←ORB[;10]
```],
)

#indent[The date of perihelion is computed from the elements already tabled:]

#apl-block[```
Z←PERIDATE
Z←ANOMALYDATE - PERIOD×ANOMALY÷360
```]

#figure(
  image("../markdown/figure-03.png", width: 80%),
  caption: [Elements of an elliptical orbit],
  supplement: [Fig.],
)

#indent[The rectangular plane represents the plane of the ecliptic. The focus of the planet's elliptical orbit is the sun. #apl[INCLINATION] is the angle between the plane of the ellipse and the plane of the ecliptic.]

#indent[The #apl[ASCENDING] node is the point at which the planet's orbit passes through the plane of the ecliptic from south to north.]

#indent[The angle Ω is measured in the plane of the ecliptic, from a line from the sun through the vernal equinox, to a line from the sun to the ascending node.]

#indent[The angle ω is measured in the plane of the planet's orbit, from a line from the sun to the ascending node, to the major axis on the side of perihelion.]

#indent[The parameter #apl[PERIANGLE] used in this article is defined as Ω+ω.]

#indent[In finding where a planet is located at a particular date, one must know what portion of its total period has elapsed since its last perihelion. This is provided by the function #apl[PERIODER]:]

#apl-block[```
Z←PERIODER DATE
Z←1|(ANOMALY÷360) + (DATE-ANOMALYDATE) ÷ PERIOD×TROPYR
```]

= Epochal adjustment of planetary elements

#indent[The orientations of the major axes of the elliptical orbits of the planets are not fixed, but themselves rotate steadily; the effect is appreciable over long intervals. Allowance for this secular shift requires an adjustment to the elements #apl[ASCENDING] (the angular coordinate of the ascending node) and #apl[PERIANGLE] (the angular coordinate of perihelion). An approximate adjustment is made by the function #apl[EPOCHADJUST]. It revises the values in columns 5 and 6 of #apl[ORB] (i.e. the ascending node and the angle of perihelion) by the size of the secular shift per unit time, multiplied by the interval since the epoch date. The secular effect is here considered to be linear with time:]

#apl-block[```
Z←INTERVAL EPOCHADJUST ORB
ORB[; 5 6]←ORB[; 5 6] + SECULAR × INTERVAL
Z←ORB
```]

#grid(
  columns: (1fr, 1fr),
  column-gutter: 1em,
  apl-block[```
Z←SECULAR
Z←ORB[;8 9]
```],
  apl-block[```
Z←EPOCHDATE
Z←ORB[;10 11]
```],
)

= Procedure for locating the planets

#indent[The function #apl[PLANETPOS] finds the positions of any or all the planets as a function of the date and their orbital elements.]

#apl-block[```
H←DATE PLANETPOS ORB; E; THETA
ORB←(DATE-EPOCHDATE) EPOCHADJUST ORB
E←ECCENTRICITY
THETA←E TRUEANOMALY E KEPLINVERSE 2×PI×PERIODER DATE
H←ORBROTATE CARTESIAN THETA,[1.5] RADIUS THETA
```]

#indent[The third statement of #apl[PLANETPOS] finds #apl[THETA], the angle between each planet's position at perihelion and its position on the indicated date. The function #apl[RADIUS] finds the distance that angle intersects the ellipse:]

#apl-block[```
Z←RADIUS THETA; E
E←ECCENTRICITY
Z←SEMIMAJOR×(1-E×2)÷1+E×COS THETA
```]

#indent[In the last statement of #apl[PLANETPOS], the polar coordinates #apl[THETA] calculated in the preceding step are converted to Cartesian heliocentric coordinates #apl[H].]

= The inverse of Kepler's function

#indent[The formula for an ellipse permits us to state the distance from the solar focus to a point on the ellipse (that is, the radius at that point) as a function of the angle #apl[THETA] between the major axis and a line through the focus to that point. However, finding the true anomaly #apl[THETA] directly as a function of time is difficult. An easier method is due to Kepler. He discovered that a closely related angle #apl[PSI] could be constructed (see Figure 4) for which the solution is simpler. A quantity proportional to the time is computed by #apl[KEPLERFN] as a function of #apl[PSI] and the eccentricity #apl[E]:]

#apl-block[```
TIME←E KEPLERFN PSI
K←⊖(⊂1+ρPSI),ρE)ρE
TIME←PSI - E×SIN PSI
```]

#indent[Notice that as #apl[E] goes to zero (meaning that the ellipse approaches a circle) #apl[KEPLERFN PSI] approaches #apl[PSI].]

#indent[To find #apl[PSI] as a function of time, #apl[KEPLERFN] must be inverted. Because #apl[KEPLERFN] involves both #apl[PSI] and #apl[SIN PSI], it is transcendental, and approximations must be used to evaluate its inverse. We used an iterative method. In this procedure, each estimate of #apl[PSI] is adjusted by correcting the previous approximation by an amount inversely proportional to the derivative. That general procedure is known as Newton's method; it was while working on solutions to Kepler's equations that Newton developed the method:]

#apl-block[```
PSI←E KEPLINVERSE TIME; ERROR; TOL
TOL←1E¯10
TIME←PSI←((ρE),ρTIME)ρTIME
TEST: →END IF ∧/,TOL>|ERROR←TIME-E KEPLERFN PSI
PSI←PSI+ERROR÷E KEPDERIV PSI
→TEST
END: PSI←+/PSI×(2ρE)ρ(1+ρE)÷1
```]

#indent[The restructuring appearing in the second statement and the last statement (and also in #apl[KEPDERIV], below) is introduced to permit parallel solution for multiple values of #apl[E] and #apl[TIME], so that all planets can be treated at once.]

#indent[The derivative of Kepler's functions is given as follows:]

#apl-block[```
Z←E KEPDERIV PSI
E←⊖(⊂1+ρPSI),ρE)ρE
Z←1-E×COS PSI
```]

#indent[Now that #apl[PSI] has been found, the more useful true anomaly can be found by analytic geometry:]

#apl-block[```
THETA←E TRUEANOMALY PSI
THETA←(2×PI)|2×ARCTAN (SQRT(1+E)÷1-E) × TAN PSI÷2
```]

#indent[The function #apl[RADIUS] can now used to find the planet's distance from the sun in astronomical units.]

#figure(
  image("../markdown/figure-04.png", width: 70%),
  caption: [Angles θ and ψ in the calculation of true anomaly],
  supplement: [Fig.],
)

#indent[The angle #apl[THETA] is measured between the major axis and a line drawn from the focus to the planet's position on the ellipse.]

#indent[The angle #apl[PSI] is measured from the major axis to a line drawn from the center of a circle circumscribed about the ellipse, to the point where a line drawn perpendicular to the axis and passing through the planet intersects the Earth.]

= Plotting the heliocentric coordinates of the planets

#indent[The aim in preparing this set of functions was to draw maps showing the sky as it appears above a particular place on Earth. To achieve that, the heliocentric coordinates just calculated must be further translated and rotated to allow for the position of the Earth in the solar system and of the observer on the Earth. However, before introducing the functions that carry out that part of the task, we illustrate a use of the heliocentric coordinates. A function #apl[PLANETSPOS] constructs (iteratively) a table showing for a selected set of dates the positions of selected planets (and also of the comet Kohoutek) for each of an array of dates:]

#apl-block[```
H←DATES PLANETSPOS P; I; D; PL
DATES←,DATES
PL←planets[P;]
H←(0,(1+ρP),3)ρI←0
TEST: →0 IF (ρDATES)<I←I+1
D←DATES[I]
H←H,[1] (D PLANETPOS PL),[1] D COMETPOS KOHOUTEK
→TEST
```]

#indent[The result is a 3-dimensional array, dates by planets by coordinates. Plotting the first coordinate against the third, we obtain a diagram showing the positions of the planets projected in the plane of the ecliptic (Figure 5).]

#figure(
  image("../markdown/figure-05.png", width: 80%),
  caption: [Sample output of program to plot heliocentric coordinates],
  supplement: [Fig.],
)

#indent[The plot shows the orbits of the four inner planets and the comet Kohoutek at 2-day intervals from 20 October 1973 through 30 March 1974.]

= Positions of the Earth and Moon

#indent[In order to find the geocentric coordinates of the other bodies, the heliocentric coordinates of the Earth are required. However, this does not require a special function, since they are directly obtainable from the expression]

#apl-block[```
DATE PLANETPOS EARTH
```]

#indent[in which #apl[EARTH] is the function which selects the orbital elements of the Earth.]

#indent[Since the moon is in an elliptical orbit about the Earth, the position of the moon with respect to the earth can be found by the same procedure used to locate the planets with respect to the sun. In calculating the position of the moon, the positions of the ascending node and the angle of perihelion are subject to linear epochal adjustments that are larger than those for the planets, but they are computed in exactly the same way:]

#apl-block[```
GQ←MOONPOS DATE; GC
GC←DATE PLANETPOS MOON
GQ←3 RADECDIST GC+.×INCLROTATE RADIAN AXITILT×23.4428
```]

#indent[In the case of the moon, the unit of distance is the semimajor axis of the orbit of the moon rather than of the Earth.]

#indent[The rotation functions will be discussed below (see pp. 26-27); the function #apl[RADECDIST] calculates polar coordinates in units of right ascension, declination, and distance; the left argument 3 indicates that in this case all three are to be retained.]

#indent[Since #apl[MOONPOS] finds the moon's position with respect to the Earth, the result is stated with respect to the Earth, and there is no need for subsequent translation from heliocentric to geocentric coordinates. (In the definition of #apl[CALCULATEPLANETS], p. 13, the expressions for #apl[PLANETS], #apl[SUN] and #apl[KOHOUTEK] require the application of the function #apl[EARTHVIEW], whereas the expression for #apl[MOON] does not.) However, the moon is sufficiently close to the Earth that in calculating its apparent position allowance must be made for the parallax introduced by the fact that the observer's position on the surface of the Earth may depart significantly from a line between the center of the Earth and the center of the moon. Such a correction to the moon's altitude is used in #apl[CALCULATEPLANETS]:]

#apl-block[```
Z←DIST PARALLAXADJUST AA; ALT
ALT←AA[;1]
Z←AA
Z[;1]←ALT - (COS RADIAN ALT)×MOONRATIO÷DIST
```]

#indent[in which #apl[MOONRATIO] is the ratio of the semimajor axis of the moon's orbit to the radius of the Earth, expressed in radians; the value is about 0.95.]

#indent[The phase of the moon depends upon the difference between the right ascensions of the sun and moon:]

#apl-block[```
Z←MOON MOONPHASE SUN
Z←1|(MOON-SUN)÷24
```]

#indent[The moon is full when their right ascensions differ by 12 hours, and new when they are equal. When both the right ascension and the declination of the moon are equal to those of the sun, there is an eclipse of the sun; when their right ascensions differ by 12 hours and their declinations are equal but of opposite sign, there is an eclipse of the moon.]

= Position of the comet

#indent[The position of Kohoutek is calculated only for dates within 100 days of its perihelion, 28 December 1973. The logical variable #apl[K] (set in #apl[CALCULATEPLANETS]) has the value 1 when Kohoutek is within range, 0 otherwise. The expression _K/DATE_ thus makes the date empty when the position of the comet is not needed.]

#apl-block[```
H←DATE COMETPOS ORB; X
H← 0 3ρ0
→0 IF 0=ρ,DATE
X←COMETSOLVE (PI×SQRT 2×PERIDIST)×(DATE-ANOMALYDATE)÷TROPYR
H←ORBROTATE (PARABOLA X), ¯X
```]

#indent[The method used to locate the comet is similar to that used for the planets. However, for several reasons the polar coordinates used in the initial two-dimensional solution for the planets are here replaced with Cartesian coordinates. The approximations for planets (whose orbits are nearly circular) do not converge easily when applied to the comet, whose orbit is almost exactly parabolic. The usual polar expression in the function #apl[RADIUS] is singular when #apl[E] is 1 (parabola) and #apl[THETA] is #apl[PI]. Moreover, the Cartesian expression for a parabola is simple to integrate; hence Kepler's equal-areas equal-times law is easily applied.]

#indent[The time required to reach a point on the parabolic path of the comet as a function of the distance from the axis of the parabola is given by the function #apl[AREA]:]

#apl-block[```
Z←AREA X
Z←(PERIDIST×X÷2) + (X×3)÷4×PERIDIST
```]

#indent[in which the orbital element #apl[PERIDIST] is the distance from the sun at perihelion, in astronomical units:]

#apl-block[```
Z←PERIDIST
Z←ORB[;1]
```]

#indent[The function #apl[COMETSOLVE] provides an iterative definition for the inverse of #apl[AREA], giving the perpendicular distance from the axis of the parabola as a function of the time interval from perihelion:]

#apl-block[```
X←COMETSOLVE TIME; ERROR
X←2×TIME÷PERIDIST
TEST: →0 IF 1E¯8>|ERROR←TIME-AREA X
X←X+ERROR÷AREADERIV X
→TEST
```]

#indent[Here again the inverse is found by Newton's method; convergence is speeded by the use of the derivative of the area function with respect to the abscissa:]

#apl-block[```
Z←AREADERIV X
Z←(PERIDIST÷2) + (X×2)÷8×PERIDIST
```]

#indent[The second coordinate of the comet's position (within the plane of its orbit) is measured in the direction of the axis of the parabola. It is obtained from the first coordinate by the function #apl[PARABOLA]:]

#apl-block[```
Z←PARABOLA X
Z←PERIDIST - (X×2)÷4×PERIDIST
```]

= Rotation of the stars

#indent[The positions of the stars are represented by a table of their right ascensions and declinations, as of 1 January 2000, contained in the matrix #apl[STARS]. There is no provision for the proper motions of the stars, nor for the effects of parallax between different positions on the Earth's orbit, since both these effects are small compared to the precision of the rest of the calculation or to the resolution of the plotting program. The calculation thus reduces to the correction for the observer's position at a given latitude, date, and time, and the long-run variation introduced by precession.]

#apl-block[```
CALCULATESTARS; STARS
VE←BRIGHT←STARCOORD←AAE←10
STARS←(LAT,DATE,TIME) SKYPOS DATE PRECESS STARS
BRIGHT←BRIGHT IF VE←VISIBLE STARS
AAE←STARS IF BRIGHT∧VE
STARCOORD←MAPCARTESIAN PROJECTION STARS IF VE
```]

#indent[The global results of this function (initially set to 10 in the first statement) are as follows:]

#param[#apl[STARCOORD]][Cartesian coordinates on the map for the stars visible from the indicated time, date, and location.]

#param[#apl[BRIGHT]][A logical vector indicating which of the visible stars are of magnitude 1.5 or brighter.]

#param[#apl[VE]][A logical vector indicating which stars are visible.]

#param[#apl[AAE]][A matrix containing the altitude and azimuth of the visible bright stars.]

= Correction for precession

#indent[The effect of precession is to alter the direction in which the Earth's axis is tilted. A line drawn from the north pole to the zenith (which today points approximately to the star Polaris) in the course of 25800 years describes a complete circle, with radius 23.45 degrees. What changes with precession is the direction in which the Earth's north pole departs from a point perpendicular to the plane of the Earth's orbit. However, since the direction of the equinox enters into the definition of one of the axes of both the heliocentric and the geocentric ecliptic coordinates, the effect appears as a systematic rotation of the entire star table. The function #apl[PRECESS] makes this adjustment by first removing the Earth's axial tilt, then rotating about the second axis through an angle that would amount to a complete rotation in 25800 years, and then restoring the axial tilt.]

#apl-block[```
Z←INTERVAL PRECESS X; PRECESSION; ROT; TILT; DETILT; RETILT
X←CARTRIPLET X
RETILT←INCLROTATE TILT←RADIAN AXITILT
DETILT←INCLROTATE -TILT
PRECESSION←LONGROTATE INTERVAL × 2×PI÷25800×YRLENGTH
ROT←RETILT+.×PRECESSION+.×DETILT
Z←2 RADECDIST X+.×⊖ROT
```]

#indent[The variable #apl[TROPYR] is the length of the tropical year in days; #apl[EQUINOX] is the Julian date of a vernal equinox (in this case, for 1973).]

#indent[The function #apl[LATROTATE] prepares a matrix of sines and cosines, exploiting the relation between rotation of latitude and rotation of inclination:]

#apl-block[```
Z←LATROTATE LAT
Z←⊖⊖INCLROTATE LAT
```]

= Conversion of units

#indent[The positions of objects in the sky are described in spherical polar coordinates, usually as right ascension, declination, and distance. The first two are stated as angles in hours or degrees, and the last in astronomical units. The function #apl[RADECDIST] converts from Cartesian to polar coordinates in which right ascension is stated in hours and declination in degrees. Since the distance of celestial objects is not apparent from the Earth, only the right ascension and declination are required for some calculations; by using a left argument of 2, only the first two coordinates are retained, and distance is dropped where it is no longer appropriate:]

#apl-block[```
Z←COL RADECDIST GQ; DIST
Z←ARCCOS GQ[;1]÷(GQ[; 1 3]+.*2)×0.5
Z←(12÷PI)×Z+(GQ[;3]>0)×2×PI-Z
DIST←(GQ+.*2)×0.5
Z←Z,[1.5] (180÷PI)×ARCSIN GQ[;2]÷DIST
→0 IF COL<3
Z←Z,DIST
```]

#indent[The norm is defined as the square root of the sum of the squares:]

#apl-block[```
Z←NORM X
Z←(X+.*2)×0.5
```]

#indent[Conversion to Cartesian from polar coordinates is provided by the function #apl[CARTESIAN]:]

#apl-block[```
Z←CARTESIAN POLAR; RHO; THETA
THETA←POLAR[;1]
RHO←POLAR[;2]
Z←(RHO×COS THETA),[1.5] -RHO×SIN THETA
```]

#indent[Conversion to non-normalized three-dimensional Cartesian coordinates from spherical polar coordinates is provided by the function #apl[CARTRIPLET]:]

#apl-block[```
Z←CARTRIPLET RADEC; Z1; Z2; Z3
Z1←COS PI×RADEC[;1]÷12
Z2←TAN RADIAN RADEC[;2]
Z3←-SIN PI×RADEC[;1]÷12
Z←Z1, Z2,[1.5] Z3
```]

= Sample star maps

#indent[On the following pages maps generated by these programs are reproduced, showing the views from Philadelphia on 14 January 1974 (when Kohoutek was visible), and from the Arctic circle at midnight on 21 June 1974. On two further charts, showing the views from the north and south poles at the vernal equinox, lines linking stars in the same constellation have been drawn in by hand.]

#figure(
  image("../markdown/figure-07.png", width: 90%),
  caption: [Star map at Philadelphia on January 14, 1974],
  supplement: [Fig.],
)

#figure(
  image("../markdown/figure-08.png", width: 90%),
  caption: [Star map at Fort Yukon on June 31, 1974],
  supplement: [Fig.],
)

#figure(
  image("../markdown/figure-09.png", width: 90%),
  caption: [Star map at North Pole on March 19, 1974],
  supplement: [Fig.],
)

#figure(
  image("../markdown/figure-10.png", width: 90%),
  caption: [Star map at South Pole on March 19, 1974],
  supplement: [Fig.],
)

= Projection of the visible sky

#indent[Once the altitude and azimuth of moon, sun, planets, and comet have been calculated, it remains only to select those that are visible, and calculate a suitable projection for the map. Objects are considered to be visible if they are on or above the horizon, i.e. if they have non-negative altitude:]

#apl-block[```
Z←VISIBLE X; ALT
ALT←X[;1]
Z←ALT≥0
```]

#indent[To preserve the apparent shapes of constellations when projected onto a flat surface, the altitudes near the zenith are condensed and those near the horizon expanded by the function #apl[PROJECTION] which makes the distance from the center of the map proportional to the tangent of one half the coaltitude:]

#apl-block[```
Z←PROJECTION X
Z←(TAN 0.5×COALTITUDE X[;1]),[1.5] RADIAN X[;2]
```]

#indent[in which coaltitude is defined thus:]

#apl-block[```
Z←COALTITUDE X
Z←RADIAN 90-X
```]

#indent[Since the plotting routine expects its data to be stated in Cartesian coordinates, the projected polar coordinates are converted back to that form. The function #apl[MAPCARTESIAN] makes allowance for the fact that altitude and azimuth are conventionally grouped in the opposite order from right ascension and declination:]

#apl-block[```
Z←MAPCARTESIAN X
Z←⊖CARTESIAN⊖X
```]

= Functions for rotation and translation of coordinates

#indent[The function #apl[ORBROTATE] converts the two-dimensional Cartesian coordinates of the planets within their own planes to three-dimensional heliocentric coordinates, taking into account the orientation and tilt of the plane of each orbit:]

#apl-block[```
H←ORBROTATE X; INCL; I; OMEGA; O; OMEG4; Q
X←((ρX),1)ρX← 1 0 1 \X
OMEGA←RADIAN PERIANGLE-ASCENDING
OMEG4←RADIAN ASCENDING
INCL←RADIAN INCLINATION
I←INCLROTATE INCL
O←LONGROTATE OMEGA
Q←LONGROTATE OMEG4
H←(Q TIMES I TIMES O) TIMES X
H←((1+ρH),×/1+ρH)ρH
```]

#indent[The rotations are achieved by a series of matrix products. The functions #apl[INCLROTATE] and #apl[LONGROTATE] generate the appropriate matrices of sines and cosines, stacking them in a three-dimensional array since several sets of coordinates are to be rotated at once. The function #apl[TIMES] (not shown) calculates the ordinary matrix product of the corresponding pairs of matrices in a three-dimensional stack.]

#indent[The functions #apl[INCLROTATE] and #apl[LONGROTATE] generate stacks of matrices containing the appropriate sines and cosines of the angles through which rotation is to occur (see Figure 6):]

#apl-block[```
Z←INCLROTATE INCL; RHO
RHO←ρINCL
Z←((ρ,INCL), 3 3)ρ9↑1
Z[;2;2]←Z[;3;3]←COS INCL
Z[;2;3]←-Z[;3;2]←SIN INCL
→(0<ρRHO)/0
Z← 3 3 ρZ
```]

#apl-block[```
Z←LONGROTATE OMEGA; RHO
Z←((ρ,OMEGA), 3 3)ρ 0 0 0 0 1 0 0 0 0
Z[;1;1]←Z[;3;3]←COS OMEGA
Z[;3;1]←-Z[;1;3]←SIN OMEGA
→(0<ρRHO)/0
Z← 3 3 ρZ
```]

#indent[These functions are used in translating the heliocentric coordinates of the planets to geocentric equatorial coordinates (i.e. the view from the center of the Earth):]

#apl-block[```
GQ←DATE EARTHVIEW H; GC
GC←H-(ρH)ρDATE PLANETPOS EARTH
GQ←3 RADECDIST GC+.×INCLROTATE -RADIAN AXITILT
```]

#indent[in which #apl[AXITILT] is the angle between the axis of the Earth and the plane of the ecliptic.]

#figure(
  image("../markdown/figure-06.png", width: 70%),
  caption: [Stacking of rotation matrices],
  supplement: [Fig.],
)

#indent[Each plane represents the rotation matrix for one of the planets.]

#indent[The next transformation adjusts for the location on the Earth of the observer for whom the map is calculated. The coordinates with respect to the observer are described in a system in which the three coordinates point respectively south, overhead, and west. These are calculated by #apl[SKYPOS] as a function of the geocentric equatorial coordinates #apl[GQ], and the observer's latitude and true local time:]

#apl-block[```
AA←EARTH SKYPOS GQ; SUN; ROT; LAT; DATE; TIME; ALT; AZ; NEG; S
LAT←EARTH[1]
DATE←EARTH[2]
TIME←EARTH[3]
SUN←(24÷YRLENGTH)×YRLENGTH|DATE-EQUINOX
ROT←PI×(SUN+TIME-12)÷12
LAT←RADIAN 90-LAT
GQ←GQ+⊖(⊖ρGQ)ρNORM GQ←CARTRIPLET GQ
GQ←GQ+.×⊖(LATROTATE LAT)+.×LONGROTATE-ROT
ALT←DEGREES ARCSIN GQ[;2]
NEG←-S×GQ[;3]
AZ←(360×S≥0)+NEG×DEGREES ARCCOS GQ[; 1 3]÷NORM GQ[; 1 3]
AA←ALT,[1.5] AZ
```]

#line(length: 100%)

= References

Marion, Jerry B., _Classical Dynamics of Particles and Systems_, New York: Academic Press, 1965.

_American Ephemeris and Nautical Almanac_, Explanatory Supplement, U.S. Naval Observatory, 1961.

Hoffleit, Dorrit, _Catalog of Bright Stars_, New Haven: Yale University, 1964.

#line(length: 100%)

= Appendix

== Tables

#indent[The tables in this appendix were prepared by Mr. Per Gjerlov of IBM Denmark, using data from the Yale Catalogue of Bright Stars.]

#indent[On the first page, values are given for the orbital elements of the nine planets, of the moon, and of the comet Kohoutek. These are the values used to produce the sample charts shown in this report.]

#indent[Following that, there appear the coordinates of 332 stars. The stars included are roughly the first 300 in visual magnitude, plus a handful of others chosen because they help complete the outline of certain constellations. The table shows the popular name (where there is one), the Bayer designation, and the number in the Yale catalogue. The coordinates are shown as right ascension in hours, minutes, and seconds, and declination, in degrees and minutes, epoch 1 January 2000. The last two columns show the visual magnitude, and the annual parallax in seconds. Where there is a bright double star, only one star is listed.]

#indent[The stars in Pleiades are here named PLE, although they are commonly referred to the constellation Taurus. To improve visual display, they are shown with positions slightly different from the correct ones.]

== Mean orbital elements for the planets (columns 1-7 of `planets`)

#data-table[```
           SEMIMAJOR     PERIOD   ECCENT'Y   INCLINAT'N   ASCENDING   PERIANGLE     ANOMALY
MERCURY        0.387    0.24085    0.20563     7.004330    48.07347    77.11704    289.6550
VENUS          0.723    0.61521    0.00678     3.394420    76.48402   131.26501    150.2801
EARTH          1        1.00004    0.01672     0            0         102.56835     34.4957
MARS           1.524    1.88089    0.09338     1.849810    49.38973   335.65866    271.1460
JUPITER        5.202   11.86223    0.04794     1.305540   100.21550    14.10850    283.9167
SATURN         9.578   29.45772    0.05759     2.486680   113.49100    94.40310    348.2963
URANUS        19.178   84.01529    0.04808     0.771410    74.00020   168.86530     25.4394
NEPTUNE       29.965  164.78829    0.01119     1.772070   131.54740    59.57130    224.9265
PLUTO         39.543  248.43020    0.24934    17.137130   109.88680   223.14830    335.6904
```]

== Mean orbital elements for the planets (columns 8-11 of `planets`)

#data-table[```
              SECULAR ASCENDING   SECULAR PERIANGLE   DATE (ASC)   DATE (PERI)
MERCURY       0.000 032 444 198   0.000 042 559 243    2443600.5     2443600.5
VENUS         0.000 024 641 163   0.000 038 505 620    2443600.5     2443600.5
EARTH         0.000 000 000 000   0.000 047 000 737    2443600.5     2443600.5
MARS          0.000 021 188 358   0.000 050 392 700    2443600.5     2443600.5
JUPITER       0.000 027 683 282   0.000 044 110 724    2443600.5     2443600.5
SATURN        0.000 023 880 633   0.000 053 617 346    2443600.5     2443600.5
URANUS        0.000 013 689 535   0.000 044 110 724    2443600.5     2443600.5
NEPTUNE       0.000 030 040 924   0.000 018 252 713    2443600.5     2443600.5
PLUTO         0.000 038 026 486   0.000 038 026 486    2443600.5     2443600.5
```]

== Orbital elements for the moon (with respect to Earth)

#data-table[```
    SEMIMAJOR    PERIOD ECCENTRICITY INCLINATION  ASCENDING   PERIANGLE
MOON    1       0.07544      0.05490     5.14342  260.38369   331.80423

       SECULAR ASCENDING   SECULAR PERIANGLE    DATE (ASC)   DATE (PERI)
MOON  ¯0.005 295 392 200   0.011 140 408 030   2414997.831   2414997.831
```]

== Orbital elements for the comet Kohoutek

#data-table[```
          PERIDIST   INCLINATION  ASCENDING  PERIANGLE       PERIDATE
KOHOUTEK     0.142       14.2969    257.7153  295.5891    2442046.463
```]

== Bright Stars

#set text(font: "Courier", size: 4.5pt)
#set par(justify: false, first-line-indent: 0em)
#block(breakable: true)[
  #raw(read("star-table.txt"), block: true)
]
#set text(font: "Courier", size: 7.5pt)
