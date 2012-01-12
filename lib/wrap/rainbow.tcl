#
# Copyright (C) 2011, 2012 by Roger E Critchlow Jr, Santa Fe, NM, USA.
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
# 

###
### this program is buggy, I haven't fixed all its problems
###

# /*   rainbow(double h, double s, double v, double *r, double *g, double *b)
#  This routine computes colors suitable for use in color level plots.
#  Typically s=v=1 and h varies from 0 (red) to 1 (blue) in
#  equally spaced steps.  (h=.5 gives green; 1<h<1.5 gives magenta.)
#  To convert for frame buffer, use   R = floor(255.999*pow(*r,1/gamma))  etc.
#  To get tables calibrated for other devices or to report complaints,
#  contact ehg@research.att.com.
# */
# 
# /*
#  * The author of this software is Eric Grosse.  Copyright (c) 1986,1991 by AT&T.
#  * Permission to use, copy, modify, and distribute this software for any
#  * purpose without fee is hereby granted, provided that this entire notice
#  * is included in all copies of any software which is or includes a copy
#  * or modification of this software and in all copies of the supporting
#  * documentation for such software.
#  * THIS SOFTWARE IS BEING PROVIDED "AS IS", WITHOUT ANY EXPRESS OR IMPLIED
#  * WARRANTY.  IN PARTICULAR, NEITHER THE AUTHORS NOR AT&T MAKE ANY
#  * REPRESENTATION OR WARRANTY OF ANY KIND CONCERNING THE MERCHANTABILITY
#  * OF THIS SOFTWARE OR ITS FITNESS FOR ANY PARTICULAR PURPOSE.
#  */
# 
# 
# #include <stdio.h>
# #include <math.h>
# double	huettab[] = {
#  0.0000, 0.0062, 0.0130, 0.0202, 0.0280, 0.0365, 0.0457, 0.0559, 0.0671, 0.0796,
#  0.0936, 0.1095, 0.1275, 0.1482, 0.1806, 0.2113, 0.2393, 0.2652, 0.2892, 0.3119,
#  0.3333, 0.3556, 0.3815, 0.4129, 0.4526, 0.5060, 0.5296, 0.5501, 0.5679, 0.5834,
#  0.5970, 0.6088, 0.6191, 0.6281, 0.6361, 0.6430, 0.6490, 0.6544, 0.6590, 0.6631,
#  0.6667, 0.6713, 0.6763, 0.6815, 0.6873, 0.6937, 0.7009, 0.7092, 0.7190, 0.7308,
#  0.7452, 0.7631, 0.7856, 0.8142, 0.8621, 0.9029, 0.9344, 0.9580, 0.9755, 0.9889,
#  1.0000
# };
# /* computed from the FMC-1 color difference formula */
# /* Barco monitor, max(r,g,b)=1, n=61 magenta,  2 Jan 1986 */
# 
# rainbow(h, s, v, r, g, b)
# double	h, s, v, *r, *g, *b;
# {
# 	int	i;
# 	double	modf(), trash;
# 	h = 60 * modf(h / 1.5, &trash);
# 	i = floor(h);
# 	h = huettab[i] + (huettab[i+1] - huettab[i]) * (h - i);
# 	dhsv2rgb(h, s, v, r, g, b);
# }
# 
# 
# dhsv2rgb(h, s, v, r, g, b)    /*...hexcone model...*/
# double	h, s, v, *r, *g, *b;    /* all variables in range [0,1[ */
# /* here, h=.667 gives blue, h=0 or 1 gives red. */
# {  /* see Alvy Ray Smith, Color Gamut Transform Pairs, SIGGRAPH '78 */
# 	int	i;
# 	double	f, m, n, k;
# 	double	modf(), trash;
# 	h = 6 * modf(h, &trash);
# 	i = floor(h);
# 	f = h - i;
# 	m = (1 - s);
# 	n = (1 - s * f);
# 	k = (1 - (s * (1 - f)));
# 	switch (i) {
# 	case 0: 
# 		*r = 1; 
# 		*g = k; 
# 		*b = m; 
# 		break;
# 	case 1: 
# 		*r = n; 
# 		*g = 1; 
# 		*b = m; 
# 		break;
# 	case 2: 
# 		*r = m; 
# 		*g = 1; 
# 		*b = k; 
# 		break;
# 	case 3: 
# 		*r = m; 
# 		*g = n; 
# 		*b = 1; 
# 		break;
# 	case 4: 
# 		*r = k; 
# 		*g = m; 
# 		*b = 1; 
# 		break;
# 	case 5: 
# 		*r = 1; 
# 		*g = m; 
# 		*b = n; 
# 		break;
# 	default: 
# 		fprintf(stderr, "bad i: %f %d", h, i); 
# 		exit(1);
# 	}
# 	f = *r;
# 	if ( f < *g ) 
# 		f = *g;
# 	if ( f < *b ) 
# 		f = *b;
# 	f = v / f;
# 	*r *= f;
# 	*g *= f;
# 	*b *= f;
# }
# /*
#  *  Creates texture array with saturation levels in the y (t) direction
#  *  and hue and lightness changes in x (s) direction.
#  *  Black band on both hue ends, for plotting data out of range.
#  *			[0,black_border-1] and [texture_size-black_border,
#  *                      texture_size-1] are black.  Otherwise, use cindex =
#  *			black_border + h*(texture_size-2*black_border-1).
#  *			Returns a malloc'ed array of texture_size*texture_size
#  *			longs with successive texture_size blocks having
#  *			different saturation values; each long has r,g,b,0
#  *			stored as unsigned chars.
#  *
#  * The authors of this software are Eric Grosse and W. M. Coughran, Jr.
#  * Copyright (c) 1991 by AT&T.
#  * Permission to use, copy, modify, and distribute this software for any
#  * purpose without fee is hereby granted, provided that this entire notice
#  * is included in all copies of any software which is or includes a copy
#  * or modification of this software and in all copies of the supporting
#  * documentation for such software.
#  * THIS SOFTWARE IS BEING PROVIDED "AS IS", WITHOUT ANY EXPRESS OR IMPLIED
#  * WARRANTY.  IN PARTICULAR, NEITHER THE AUTHORS NOR AT&T MAKE ANY
#  * REPRESENTATION OR WARRANTY OF ANY KIND CONCERNING THE MERCHANTABILITY
#  * OF THIS SOFTWARE OR ITS FITNESS FOR ANY PARTICULAR PURPOSE.
#  *
#  * We thank Cleve Moler for describing the "hot iron" scale to us.
#  */
# #include <stdlib.h>
# #include <stdio.h>
# #include <math.h>
# #include <string.h>
# 
# /* color maps */
# #define RAINBOW	1
# #define GRAY	2
# #define TERRAIN	3
# #define IRON	4
# #define ASTRO	5
# #define ZEBRA	6
# 
# long *
# texture_gen(int saturation_lvls,int texture_size,int black_border)
# {
# 	unsigned char	r, g, b, *obuf;
# 	char	*mapstr, *s;
# 	int	invert = 0, map, ncolors = 7, tx, x, y, ihue;
# 	long	*texture;
# 	double	hue, oldhue, sat, oldsat, red, green, blue, h;
# 
# 	if (s = getenv("NCOLORS")) 
# 		ncolors = atoi(s);
# 	if (!( mapstr = getenv("MAP")))
# 		mapstr = "rainbow";
# 	else
# 		ToLower(mapstr);   /* #define ToLower(s) ;  if you don't care */
# 
# 	if(!strncmp("inverse ",mapstr,8)){
# 		invert = 1;
# 		mapstr += 8;
# 	}
# 	if(!strcmp("rainbow",mapstr))
# 		map = RAINBOW;
# 	else if(!strcmp("gray",mapstr)||!strcmp("grey",mapstr))
# 		map = GRAY;
# 	else if(!strcmp("terrain",mapstr)||!strcmp("topo",mapstr))
# 		map = TERRAIN;
# 	else if(!strcmp("iron",mapstr)||!strcmp("heated",mapstr)||
# 			!strncmp("hot",mapstr,3))
# 		map = IRON;
# 	else if(!strcmp("astro",mapstr))
# 		map = ASTRO; /* the astronomers made me do it */
# 	else if(!strncmp("alt",mapstr,3)||!strcmp("zebra",mapstr))
# 		map = ZEBRA;
# 	else
# 		exit(2);
# 
# 	texture = (long *)malloc(texture_size*saturation_lvls*sizeof(long));
# 
# 	oldhue = -1;
# 	oldsat = -1;
# 	for (y = 0; y < saturation_lvls; y++) {
# 		obuf = (unsigned char *)(texture+y*texture_size);
# 		sat = y / (saturation_lvls-1.);
# 		if(sat>0.99) sat = 0.99;
# 		if( oldsat!=sat ){
# 			for (x = 0, tx = 0; x < texture_size; x++, tx += 4) {
# 				hue = (x-black_border) / (texture_size-2*black_border-1.);
# 				ihue = floor(ncolors*hue);
# 				hue = ((double)ihue)/(ncolors-1);
# 				if(hue>1.) hue = 1.;
# 				if(invert) hue = 1.-hue;
# 				if( x<black_border || x>=texture_size-black_border ){
# 					r = 0;
# 					g = 0;
# 					b = 0;
# 				}else if( oldhue!=hue ){
# 					switch(map){
# 					  case RAINBOW:
# 						rainbow(1.-hue, sat, 1., &red, &green, &blue);
# 						break;
# 					  case GRAY:
# 						red = hue;
# 						green = hue;
# 						blue = hue;
# 						break;
# 					  case TERRAIN:
# 						h = 3*hue;
# 						if(h<.25){
# 							red = 0;
# 							green = 0;
# 							blue = 0.25+2*h;
# 						}else if(h<2){
# 							red = 0;
# 							green = 0.25+(2-h);
# 							blue = 0;
# 						}else if(h<2.7){
# 							red = .75;
# 							green = .15;
# 							blue = .0;
# 						}else{
# 							red = .9;
# 							green = .9;
# 							blue = .9;
# 						}
# 						break;
# 					  case IRON:
# 						red = 3*(hue+.03);
# 						green = 3*(hue-.333333);
# 						blue = 3*(hue-.666667);
# 						break;
# 					  case ASTRO:
# 						red = hue;
# 						green = hue;
# 						blue = (hue+.2)/1.2;
# 						break;
# 					  case ZEBRA:
# 						red = (ihue+invert) % 2;
# 						green = red;
# 						blue = red;
# 					}
# 					if(red>1.) red = 1.;
# 					if(green>1.) green = 1.;
# 					if(blue>1.) blue = 1.;
# 					if(red<0.) red = 0.;
# 					if(green<0.) green = 0.;
# 					if(blue<0.) blue = 0.;
# 					r = 255*red;
# 					g = 255*green;
# 					b = 255*blue;
# 					oldhue = hue;
# 					if(sat==1.)
# 						printf("# %.2g %.2g %.2g\n",
# 							r/255.,g/255.,b/255.);
# 				}
# 				obuf[tx+0] = r;
# 				obuf[tx+1] = g;
# 				obuf[tx+2] = b;
# 				obuf[tx+3] = 0;
# 			}
# 		}
# 		oldsat = sat;
# 	}
# 	return texture;
# }

package provide rainbow 1.0.0

namespace eval ::rainbow {
    set huettab {
	0.0000 0.0062 0.0130 0.0202 0.0280 0.0365 0.0457 0.0559 0.0671 0.0796
	0.0936 0.1095 0.1275 0.1482 0.1806 0.2113 0.2393 0.2652 0.2892 0.3119
	0.3333 0.3556 0.3815 0.4129 0.4526 0.5060 0.5296 0.5501 0.5679 0.5834
	0.5970 0.6088 0.6191 0.6281 0.6361 0.6430 0.6490 0.6544 0.6590 0.6631
	0.6667 0.6713 0.6763 0.6815 0.6873 0.6937 0.7009 0.7092 0.7190 0.7308
	0.7452 0.7631 0.7856 0.8142 0.8621 0.9029 0.9344 0.9580 0.9755 0.9889
	1.0000
    }
}

proc rainbow::dhsv2rgb {h s v} {
    set h [expr {6*fmod($h, 1.0)}]
    set i [expr {int(floor($h))}]
    set f [expr {$h - $i}]
    set m [expr {1 - $s}]
    set n [expr {1 - $s * $f}]
    set k [expr {1 - ($s * (1 - $f))}]
    switch $i {
	0 { lassign [list 1 $k $m] r g b } 
	1 { lassign [list $n 1 $m] r g b } 
	2 { lassign [list $m 1 $k] r g b } 
	3 { lassign [list $m $n 1] r g b }
	4 { lassign [list $k $m 1] r g b }
	5 { lassign [list 1 $m $n] r g b } 
 	default { error "bad i $h $i" }
    }
    set f [expr {$v/max($r,max($g,$b))}]
    return [list [expr {$f*$r}] [expr {$f*$g}] [expr {$f*$b}]]
}

proc rainbow::rainbow {h s v} {
    set h [expr {6*fmod($h/1.5, 1.0)}]
    set i [expr {int(floor($h))}]
    set h_i [lindex $::rainbow::huettab $i]
    set h_j [lindex $::rainbow::huettab [incr i]]
    set h [expr {$h_i + ($h_j - $h_i) * ($h - $i)}]
    return [dhsv2rgb $h $s $v]
}

#define RAINBOW	1
#define GRAY	2
#define TERRAIN	3
#define IRON	4
#define ASTRO	5
#define ZEBRA	6
proc rainbow::texture_gen {saturation_lvls texture_size ncolors map} {
    set texture {}
    set oldhue  -1
    set oldsat -1;
    for {set y 0} {$y < $saturation_lvls} {incr y} {
	set obuf {}
	set sat [expr {min(0.99, $y / ($saturation_lvls-1.0))}]
	if {$oldsat != $sat} {
	    for {set x 0} {$x < $texture_size} {incr x} {
		set hue [expr {$x / ($texture_size-1.)}]
		set ihue [expr {floor($ncolors*$hue)}]
		set hue  [expr {double($ihue)/($ncolors-1)}]
		if {$hue>1.} { set hue 1. }
		if {$oldhue != $hue} {
		    switch $map {
			rainbow { lassign [rainbow [expr {1.-$hue}] $sat 1.] red green blue }
			gray { lassign [list $hue $hue $hue] red green blue }
			terrain {
			    set h [expr {3*$hue}]
			    if {$h < .25} {
				lassign [list 0 0 [expr {0.25+2*$h}]] red green blue
			    } elseif {$h < 2} {
				lassign [list 0 [expr {0.25+(2-$h)}] 0] red green blue
			    } elseif {$h < 2.7} {
				lassign {0.75 0.15 0.00} red green blue
			    } else {
				lassign {0.9 0.9 0.9} red green blue
			    }
			}
			iron { lassign [list [expr {3*($hue+0.03)}] [expr {3*($hue-.333333)}] [expr {3*($hue-.666667)}]] red green blue }
			astro { lassign [list $hue $hue [expr {($hue+0.2)/1.2}]] red green blue }
			zebra {
			    set x [expr {$ihue%2}]
			    lassign [list $x $x $x] red green blue
			}
		    }
		    set r [expr {int(255*min(1,max($red,0)))}]
		    set g [expr {int(255*min(1,max($green,0)))}]
		    set b [expr {int(255*min(1,max($blue,0)))}]
		    set oldhue $hue
		    # if(sat==1.) printf("# %.2g %.2g %.2g\n", r/255.,g/255.,b/255.);
		}
		lappend obuf [list $r $g $b 0]
	    }
	}
	lappend texture $obuf
	set oldsat $sat
    }
    return $texture
}
