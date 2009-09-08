/* xscreensaver, Copyright (c) 1997 Jamie Zawinski <jwz@jwz.org>
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation.  No representations are made about the suitability of this
 * software for any purpose.  It is provided "as is" without express or 
 * implied warranty.
 *
 * ported to mac OS X by T. Pecorella, 2001
 */

/* This file contains some utility routines for randomly picking the colors
   to hack the screen with.
 */

#include "colors.h"

// #define LOG_DEBUG

__private_extern__ void
make_color_ramp (HSVcolor startColor,
                 HSVcolor endColor,
		 HSVcolor *colors, int *ncolorsP,
		 BOOL closed_p)
{
    int i;
    double dh, ds, dv;		/* deltas */
    float h1, s1, v1;
    float h2, s2, v2;
    int ncolors;
    
    ncolors = *ncolorsP;
    
    h1 = startColor.hue;
    s1 = startColor.saturation;
    v1 = startColor.brightness;
    
    h2 = endColor.hue;
    s2 = endColor.saturation;
    v2 = endColor.brightness;
    
    if (closed_p)
        ncolors = (ncolors / 2) + 1;
    
    /* Note: unlike other routines in this module, this function assumes that
        if h1 and h2 are more than 180 degrees apart, then the desired direction
        is always from h1 to h2 (rather than the shorter path.)  make_uniform
        depends on this.
    */
    
    dh = (h2 - h1) / ncolors;
    ds = (s2 - s1) / ncolors;
    dv = (v2 - v1) / ncolors;
    
    for (i = 0; i < ncolors; i++) {
        colors[i].hue = h1 + (i*dh);
        colors[i].saturation = s1 + (i*ds);
        colors[i].brightness = v1 + (i*dv);
    }
    
    if (closed_p)
        for (i = ncolors; i < *ncolorsP; i++)
            colors[i] = colors[*ncolorsP-i];
    
    return;
}


#define MAXPOINTS 50	/* yeah, so I'm lazy */


static void
make_color_path (int npoints, HSVcolor *colorPoints,
		 HSVcolor *colors, int *ncolorsP)
{
    int i, j, k;
    int total_ncolors = *ncolorsP;

    int ncolors[MAXPOINTS];  /* number of pixels per edge */
    double dh[MAXPOINTS];    /* distance between pixels, per edge (0 - 1.0) */
    double ds[MAXPOINTS];    /* distance between pixels, per edge (0 - 1.0) */
    double dv[MAXPOINTS];    /* distance between pixels, per edge (0 - 1.0) */

    if (npoints == 0) {
        return;
    }
    else if (npoints == 2) {	/* using make_color_ramp() will be faster */
        make_color_ramp (colorPoints[0], colorPoints[1],
                        colors, ncolorsP,
                        true);  /* closed_p */
        return;
    }
    else if (npoints >= MAXPOINTS) {
        npoints = MAXPOINTS-1;
    }
    
    {
    double DH[MAXPOINTS];	/* Distance between H values in the shortest
				   direction around the circle, that is, the
				   distance between 10 and 350 is 20.
				   (Range is 0 - 360.0.)
				*/
    double edge[MAXPOINTS];	/* lengths of edges in unit HSV space. */
    double ratio[MAXPOINTS];	/* proportions of the edges (total 1.0) */
    double circum = 0;
    double one_point_oh = 0;	/* (debug) */
    
    for (i = 0; i < npoints; i++) {
	int j = (i+1) % npoints;
	double d = ((double) (colorPoints[i].hue - colorPoints[j].hue));
	if (d < 0) d = -d;
	if (d > 0.5) d = 1 - d;
	DH[i] = d;
    }

    for (i = 0; i < npoints; i++) {
	int j = (i+1) % npoints;
	edge[i] = sqrt((DH[i] * DH[j]) +
		       ((colorPoints[j].saturation - colorPoints[i].saturation) * (colorPoints[j].saturation - colorPoints[i].saturation)) +
		       ((colorPoints[j].brightness - colorPoints[i].brightness) * (colorPoints[j].brightness - colorPoints[i].brightness)));
	circum += edge[i];
    }

    if (circum < 0.0001) {
        NSLog ( @"Circum = %f", circum );
    }

    for (i = 0; i < npoints; i++) {
	ratio[i] = edge[i] / circum;
	one_point_oh += ratio[i];
    }
    
    if (one_point_oh < 0.99999 || one_point_oh > 1.00001)
      NSLog ( @"one_point_oh = %f", one_point_oh );

    /* space the colors evenly along the circumference -- that means that the
       number of pixels on a edge is proportional to the length of that edge
       (relative to the lengths of the other edges.)
     */
    for (i = 0; i < npoints; i++)
      ncolors[i] = total_ncolors * ratio[i];

    for (i = 0; i < npoints; i++) {
	int j = (i+1) % npoints;

	if (ncolors[i] > 0) {
	    dh[i] = DH[i] / ncolors[i];
	    ds[i] = (colorPoints[j].saturation - colorPoints[i].saturation) / ncolors[i];
	    dv[i] = (colorPoints[j].brightness - colorPoints[i].brightness) / ncolors[i];
        }
    }
    }

    memset (colors, 0, (*ncolorsP) * sizeof(*colors));

    k = 0;
    for (i = 0; i < npoints; i++) {
        float distance;
        int direction;
        distance = colorPoints[(i+1) % npoints].hue - colorPoints[i].hue;
        direction = (distance >= 0 ? -1 : +1);

        if (distance > 0.5)
            distance = 1.0 - distance;
        else if (distance < -0.5)
            distance = -(1.0 - distance);
        else
            direction = -direction;

        for (j = 0; j < ncolors[i]; j++, k++) {
            double hh = (colorPoints[i].hue + (j * dh[i] * direction));
            if (hh < 0) hh += 1.0;
            else if (hh > 1.0) hh -= 1.0;
            
            colors[k].hue = hh;
            colors[k].saturation = colorPoints[i].saturation + (j * ds[i]);
            colors[k].brightness = colorPoints[i].brightness + (j * dv[i]);
	}
    }

    /* Floating-point round-off can make us decide to use fewer colors. */
    if (k < *ncolorsP) {
      *ncolorsP = k;
    }

    return;
}


__private_extern__ void
make_color_loop (HSVcolor startColor,
                 HSVcolor middleColor,
                 HSVcolor endColor,
		 HSVcolor *colors, int *ncolorsP)
{
    HSVcolor colorPoints[3];
    
    colorPoints[0] = startColor;
    colorPoints[1] = middleColor;
    colorPoints[2] = endColor;
    
    make_color_path( 3, colorPoints, colors, ncolorsP);
}


__private_extern__ void
make_smooth_colormap (HSVcolor *colors, int *ncolorsP)
{
    int npoints;
    int ncolors = *ncolorsP;

    int i;
    HSVcolor colorPoints[MAXPOINTS];
    double total_s = 0;
    double total_v = 0;

    if (*ncolorsP <= 0) return;

    {
    int n = SSRandomIntBetween( 0, 19 );
    if      (n <= 5)  npoints = 2;	/* 30% of the time */
    else if (n <= 15) npoints = 3;	/* 50% of the time */
    else if (n <= 18) npoints = 4;	/* 15% of the time */
    else             npoints = 5;	/*  5% of the time */
    }

REPICK_ALL_COLORS:
    for (i = 0; i < npoints; i++) {
REPICK_THIS_COLOR:
        colorPoints[i].hue = SSRandomFloatBetween( 0.0, 1.0 );
        colorPoints[i].saturation = SSRandomFloatBetween( 0.0, 1.0);
        colorPoints[i].brightness = SSRandomFloatBetween( 0.0, 0.8) + 0.2;

      /* Make sure that no two adjascent colors are *too* close together.
	 If they are, try again.
       */
        if (i > 0) {
            int j = (i+1 == npoints) ? 0 : (i-1);
            double hi = ((double) colorPoints[i].hue);
            double hj = ((double) colorPoints[j].hue);
            double dh = hj - hi;
            double distance;
            if (dh < 0) dh = -dh;
            if (dh > 0.5) dh = 1.0 - dh;
            distance = sqrt ((dh * dh) +
                ((colorPoints[j].saturation - colorPoints[i].saturation) * (colorPoints[j].saturation - colorPoints[i].saturation)) +
		((colorPoints[j].brightness - colorPoints[i].brightness) * (colorPoints[j].brightness - colorPoints[i].brightness)));
            if (distance < 0.2)
                goto REPICK_THIS_COLOR;
        }
        total_s += colorPoints[i].saturation;
        total_v += colorPoints[i].brightness;
    }

  /* If the average saturation or intensity are too low, repick the colors,
     so that we don't end up with a black-and-white or too-dark map.
   */
    if (total_s / npoints < 0.2)
        goto REPICK_ALL_COLORS;
    if (total_v / npoints < 0.3)
        goto REPICK_ALL_COLORS;
    
#ifdef LOG_DEBUG
    NSLog( @"%d points:", npoints );
    for( i=0; i<npoints; i++ )
        NSLog( @" %f %f %f", colorPoints[i].hue, colorPoints[i].saturation, colorPoints[i].brightness );
#endif
 
    make_color_path (npoints, colorPoints, colors, &ncolors);

    *ncolorsP = ncolors;
    
    return;
}


__private_extern__ void
make_uniform_colormap (HSVcolor *colors, int *ncolorsP)
{
    int ncolors = *ncolorsP;
    HSVcolor start, end;
    
    float S = SSRandomFloatBetween( 0.6, 1.0 );	/* range 66%-100% */
    float V = SSRandomFloatBetween( 0.6, 1.0 );	/* range 66%-100% */
    
    start.hue = 0;
    start.saturation = S;
    start.brightness = V;
    end.hue = 1.0;
    end.saturation = S;
    end.brightness = V;
    
    if (*ncolorsP <= 0) return;
    
    make_color_ramp(start, end,
                    colors, &ncolors,
                    false);

    *ncolorsP = ncolors;
  
    return;
}


__private_extern__ void
make_random_colormap (HSVcolor *colors, int *ncolorsP,
		      BOOL bright_p)
{
    int ncolors = *ncolorsP;
    int i;

    if (*ncolorsP <= 0) return;

    for (i = 0; i < ncolors; i++) {
        colors[i].hue = SSRandomFloatBetween( 0.0, 1.0 );
        if (bright_p) {
            colors[i].saturation = SSRandomFloatBetween( 0.3, 1.0 );  /* range 30%-100% */
            colors[i].brightness = SSRandomFloatBetween( 0.6, 1.0 );  /* range 66%-100% */
        }
        else {
            colors[i].saturation = SSRandomFloatBetween( 0.0, 1.0 );  /* range 0%-100% */
            colors[i].brightness = SSRandomFloatBetween( 0.0, 1.0 );  /* range 0%-100% */
        }
    }
    
    *ncolorsP = ncolors;
    
    return;
}

