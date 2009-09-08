/* xscreensaver, Copyright (c) 1992, 1997 Jamie Zawinski <jwz@jwz.org>
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

#ifndef __COLORS_H__
#define __COLORS_H__

#import <AppKit/AppKit.h>
#import <ScreenSaver/ScreenSaver.h>

typedef struct {
    float hue;
    float saturation;
    float brightness;
} HSVcolor;


/* Generates a sequence of colors evenly spaced between the given pair
   of HSV coordinates.

   If closed_p is true, the colors will go from the first point to the
   second then back to the first.
 */
__private_extern__ void make_color_ramp (HSVcolor startColor,
                             HSVcolor endColor,
                             HSVcolor *colors, int *ncolors,
                             BOOL closed_p);

/* Generates a sequence of colors evenly spaced around the triangle
   indicated by the thee HSV coordinates.
 */
__private_extern__  void make_color_loop (HSVcolor startColor,
                             HSVcolor middleColor,
                             HSVcolor endColor,
                             HSVcolor *colors, int *ncolorsP);


/* Allocates a hopefully-interesting colormap, which will be a closed loop
   without any sudden transitions.
 */
__private_extern__  void make_smooth_colormap (HSVcolor *colors, int *ncolorsP);

/* Allocates a uniform colormap which touches each hue of the spectrum,
   evenly spaced.  The saturation and intensity are chosen randomly, but
   will be high enough to be visible.
 */
__private_extern__  void make_uniform_colormap (HSVcolor *colors, int *ncolorsP);

/* Allocates a random colormap (the colors are unrelated to one another.)
   If `bright_p' is false, the colors will be completely random; if it is
   true, all of the colors will be bright enough to see on a black background.
 */
__private_extern__  void make_random_colormap (HSVcolor *colors, int *ncolorsP,
                                  BOOL bright_p);


#endif /* __COLORS_H__ */
