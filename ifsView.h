//
//  ifsView.h
//  ifs
//
//  Created by pecos on Tue Oct 02 2001.
//  Copyright (c) 2001 __CompanyName__. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <ScreenSaver/ScreenSaver.h>
#include <time.h>
#import <OpenGL/gl.h>
#import <OpenGL/glu.h>
#import "colors.h"
#define NCOLORSMAX 2048


typedef struct {
    float red;
    float green;
    float blue;
} RGBcolor;


typedef struct xpoint_s
{
    int x;
    int y;
} XPoint;

/*****************************************************/

typedef float DBL;
typedef int F_PT;

// typedef float F_PT;

/*****************************************************/

// #define FIX 12
// #define UNIT   ( 1<<FIX )
#define UNIT   4096.
#define MAX_SIMI  6

/* settings for a PC 120Mhz... */
#define MAX_DEPTH_2  10
#define MAX_DEPTH_3  6
#define MAX_DEPTH_4  4
#define MAX_DEPTH_5  3

#define DBL_To_F_PT(x)  (F_PT)( (DBL)(UNIT)*(x) )

typedef struct Similitude_Struct SIMI;
typedef struct Fractal_Struct FRACTAL;

struct Similitude_Struct {

    DBL         c_x, c_y;
    DBL         r, r2, A, A2;
    F_PT        Ct, St, Ct2, St2;
    F_PT        Cx, Cy;
    F_PT        R, R2;
    int		colorindex;
};

struct Fractal_Struct {

    int         Nb_Simi;
    SIMI        Components[5 * MAX_SIMI];
    int         Depth;
    int         Count, Speed;
    int         Width, Height, Lx, Ly;
    DBL         r_mean, dr_mean, dr2_mean;
    int         Max_Pt;
    XPoint     	*Buffer[MAX_SIMI];
};

@interface ifsView : ScreenSaverView {
    
    BOOL mainMonitorOnly;
    
    NSOpenGLView *_view;
    BOOL _viewAllocated;
    BOOL _initedGL;
    
    BOOL mustInitialize;
    BOOL thisScreenIsOn;
    
    int width, height;
    
    FRACTAL	Fractal;
    float	alpha;
    RGBcolor colors[NCOLORSMAX];
    int ncolors, ncolorsSaved;
    int simiColor;
    int colorindex;
    int colorMode;
    
    float pointSize;
    BOOL pointSmoothing;

    int blur;
    
    IBOutlet id configureSheet;
    IBOutlet id IBversionNumberField;

    IBOutlet id IBncolorsTxt;
    IBOutlet id IBncolors;
    IBOutlet id IBncolorsBut;
    IBOutlet id IBalfaTxt;
    IBOutlet id IBalfa;
    IBOutlet id IBcolorMode;
    IBOutlet id IBcolorModeTxt;
    IBOutlet id IBSimiColor;
    IBOutlet id IBSimiColorTxt;
    
    IBOutlet id IBpointSize;
    IBOutlet id IBpointSizeTxt;
    IBOutlet id IBpointSmoothing;

    IBOutlet id IBblur;
    IBOutlet id IBblurTxt;

    IBOutlet id IBUpdatesInfo;
    
    IBOutlet id IBmainMonitorOnly;

    IBOutlet id IBCheckVersion;
    IBOutlet id IBCancel;
    IBOutlet id IBSave;
    
}

- (IBAction) closeSheet_save:(id) sender;
- (IBAction) closeSheet_cancel:(id) sender;
- (IBAction) updateConfigureSheet:(id) sender;
- (IBAction) checkUpdates:(id)sender;

- (void) init_ifs;
- (void) draw_ifs;
- (void) Draw_Fractal;

- (void) free_ifs_buffers;
- (GLvoid) InitGL;
- (void) initColors;

@end

