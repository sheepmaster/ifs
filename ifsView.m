//
//  ifsView.m
//  ifs
//
//  Created by pecos on Tue Oct 02 2001.
//  Copyright (c) 2001 __CompanyName__. All rights reserved.
//

// ***************** BEGIN original header *****************
/*-
* Copyright (c) 1997 by Massimino Pascal <Pascal.Massimon@ens.fr>
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose and without fee is hereby granted,
 * provided that the above copyright notice appear in all copies and that
 * both that copyright notice and this permission notice appear in
 * supporting documentation.
 *
 * This file is provided AS IS with no warranties of any kind.  The author
 * shall have no liability with respect to the infringement of copyrights,
 * trade secrets or any patents by this file or any part thereof.  In no
 * event will the author be liable for any lost revenue or profits or
 * other special, indirect and consequential damages.
 *
 * If this mode is weird and you have an old MetroX server, it is buggy.
 * There is a free SuSE-enhanced MetroX X server that is fine.
 *
 * When shown ifs, Diana Rose (4 years old) said, "It looks like dancing."
 *
 * Revision History:
 * 01-Nov-2000: Allocation checks
 * 10-May-1997: jwz@jwz.org: turned into a standalone program.
 *              Made it render into an offscreen bitmap and then copy
 *              that onto the screen, to reduce flicker.
 */
// ***************** END original header *****************


#import "ifsView.h"

#define kVersion	@"1.1.1"
#define kCurrentVersionsFile @"http://spazioinwind.libero.it/tpecorella/uselesssoft/saversVersions.plist"

// #define LOG_DEBUG

#define LRAND()			((long) (random() & 0x7fffffff))
#define NRAND(n)		((int) (LRAND() % (n)))
#define MAXRAND			(2147483648.0) /* unsigned 1<<31 as a float */

static DBL Gauss_Rand(DBL c, DBL A, DBL S);
static DBL Half_Gauss_Rand(DBL c, DBL A, DBL S);
static void Random_Simis(FRACTAL * F, SIMI * Cur, int i, RGBcolor* colors, int ncolors, int colorType);
static inline void Transform(SIMI * Simi, F_PT xo, F_PT yo, F_PT * x, F_PT * y);
static void Trace(FRACTAL * F, F_PT xo, F_PT yo);

static FRACTAL *Cur_F;
static XPoint *Buf[MAX_SIMI];
static int  PointNo[5];

#define COLORSPAN	50.0
static unsigned int ColorIndex = 0;
static unsigned int ColorSpan;

@implementation ifsView

- (id)initWithFrame:(NSRect)frameRect isPreview:(BOOL) preview
{
    NSString* version;
    int i;
    
    ScreenSaverDefaults *defaults = [ScreenSaverDefaults defaultsForModuleWithName:@"ifs"];

    if (self) {
        NSOpenGLPixelFormatAttribute attribs[] =
    {	NSOpenGLPFAAccelerated,
        //		NSOpenGLPFADepthSize, 16,
        NSOpenGLPFAColorSize, 16,
        NSOpenGLPFAMinimumPolicy,
        NSOpenGLPFAMaximumPolicy,
        //		NSOpenGLPFAClosestPolicy,
        0
    };

        NSOpenGLPixelFormat *format = [[[NSOpenGLPixelFormat alloc] initWithAttributes:attribs] autorelease];

        _view = [[[NSOpenGLView alloc] initWithFrame:NSZeroRect pixelFormat:format] autorelease];

        [self addSubview:_view];
        _viewAllocated = TRUE;
        _initedGL = NO;
    }

#ifdef LOG_DEBUG
    NSLog( @"initWithFrame" );
#endif

    if (![super initWithFrame:frameRect isPreview:preview]) return nil;
	
    // Do your subclass initialization here
    version   = [defaults stringForKey:@"version"];
    ncolorsSaved = [defaults integerForKey:@"ncolors"];
    alpha     = [defaults floatForKey:@"alpha"];
    colorMode	 = [defaults integerForKey:@"colorMode"];
    simiColor = [defaults integerForKey:@"simiColor"];
    pointSize = [defaults floatForKey:@"pointSize"];
    pointSmoothing = [defaults boolForKey:@"pointSmoothing"];
    blur = [defaults integerForKey:@"blur"];
    mainMonitorOnly = [defaults boolForKey:@"mainMonitorOnly"];
    
    if( ![version isEqualToString:kVersion] || (version == NULL) ) {
        // first time ever !! 
        [defaults setObject: kVersion forKey: @"version"];
        [defaults setInteger: 200 forKey:@"ncolors"];
        [defaults setFloat: 0.25 forKey:@"alpha"];
        [defaults setInteger:0 forKey:@"colorMode"];
        [defaults setBool: 1 forKey: @"simiColor"];
        [defaults setFloat: 1.0 forKey:@"pointSize"];
        [defaults setBool: YES forKey: @"pointSmoothing"];
        [defaults setInteger:0 forKey:@"blur"];
        [defaults setBool: NO forKey: @"mainMonitorOnly"];
        
        [defaults synchronize];
        
        ncolorsSaved = 200;
        alpha = 0.25;
        colorMode = 0;
        simiColor = 1;
        pointSize = 1.0;
        pointSmoothing = YES;
        blur = 0;
        mainMonitorOnly = NO;
    }
    
    if( ncolorsSaved >= NCOLORSMAX )
        ncolorsSaved = NCOLORSMAX;
    if( ncolorsSaved < 1 )
        ncolorsSaved = 1;

    if( pointSize < 1 )
        pointSize = 1;

    if( colorMode < 0 || colorMode > 2 )
        colorMode = 0;
    
    width = [self bounds].size.width;
    height = [self bounds].size.height;

    for( i=0; i<MAX_SIMI; i++ )
        Fractal.Buffer[i] = 0;

    mustInitialize = YES;
    [self initColors];
    [self init_ifs];

    return self;
}

- (void)animateOneFrame
{
    // Do your animation stuff here.
    // If you want to use drawRect: just add setNeedsDisplay:YES to this method
    
    if( thisScreenIsOn == FALSE ) {
        [self stopAnimation];
        return;
    }

    [[_view openGLContext] makeCurrentContext];

    if (!_initedGL) {
        [self InitGL];
        _initedGL = YES;
    }

    if(blur){  // partially
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glColor4f(0.0f, 0.0f, 0.0f, 0.5f - sqrt(sqrt(blur)) * 0.150208);
        // glPushMatrix();
        // glLoadIdentity();
        glBegin(GL_TRIANGLE_STRIP);
        glVertex2f(0.0, 0.0);
        glVertex2f(width, 0.0);
        glVertex2f(0.0, height);
        glVertex2f(width, height);
        glEnd();
        // glPopMatrix();
    }
    else  // completely
        glClear(GL_COLOR_BUFFER_BIT);
    
    if( mustInitialize ) {
        [self initColors];
        [self init_ifs];
        return;
    }

    [self draw_ifs];
    glFlush();
}

- (void)startAnimation
{
    // Do your animation initialization here
    int mainScreen;
    int thisScreen;
    NSOpenGLContext *context;
    
#ifdef LOG_DEBUG
    NSLog( @"startAnimation" );
#endif

    context = [_view openGLContext];
    [context makeCurrentContext];
    glClearColor(0.0, 0.0, 0.0, 0.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glFlush();

    thisScreenIsOn = TRUE;
    if( mainMonitorOnly ) {
        thisScreen = [[[[[self window] screen] deviceDescription] objectForKey:@"NSScreenNumber"] intValue];
        mainScreen = [[[[NSScreen mainScreen] deviceDescription] objectForKey:@"NSScreenNumber"] intValue];
        // NSLog( @"test this %d - main %d", thisScreen, mainScreen );
        if( thisScreen != mainScreen ) {
            thisScreenIsOn = FALSE;
        }
    }
    
    if( thisScreenIsOn ) {
        [self init_ifs];
    }
    
    [super startAnimation];
}

- (void)stopAnimation
{
    // Do your animation termination here
    
    [super stopAnimation];
}

- (BOOL) hasConfigureSheet
{
    // Return YES if your screensaver has a ConfigureSheet
    return YES;
}

- (NSWindow*)configureSheet
{
    NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];
    
#ifdef LOG_DEBUG
    NSLog( @"configureSheet" );
#endif
    if( ! configureSheet ) [NSBundle loadNibNamed:@"ifs" owner:self];
    
    [IBversionNumberField setStringValue:kVersion];
    [IBUpdatesInfo setStringValue:@""];

    [IBncolorsTxt setStringValue: [NSString stringWithFormat:
        [thisBundle localizedStringForKey:@"Number of colors (%d)" value:@"" table:@""], ncolorsSaved]];
    [IBncolors setIntValue:ncolorsSaved];
    [IBncolorsBut setIntValue:ncolorsSaved];
    [IBalfaTxt setStringValue: [NSString stringWithFormat:
        [thisBundle localizedStringForKey:@"Transparency (%.2f)" value:@"" table:@""], alpha]];
    [IBalfa setFloatValue:alpha*100];

    [IBcolorModeTxt setStringValue: [thisBundle localizedStringForKey:@"Color mode:" value:@"" table:@""]];
    [IBcolorMode removeAllItems];
    [IBcolorMode addItemWithTitle:
        [thisBundle localizedStringForKey:@"Uniform" value:@"" table:@""]];
    [IBcolorMode addItemWithTitle:
        [thisBundle localizedStringForKey:@"Smoothed" value:@"" table:@""]];
    [IBcolorMode addItemWithTitle:
        [thisBundle localizedStringForKey:@"Ramp" value:@"" table:@""]];
    [IBcolorMode selectItemAtIndex:colorMode];

    [IBSimiColorTxt setStringValue: [thisBundle localizedStringForKey:@"Figures color:" value:@"" table:@""]];
    [IBSimiColor removeAllItems];
    [IBSimiColor addItemWithTitle:
        [thisBundle localizedStringForKey:@"Single" value:@"" table:@""]];
    [IBSimiColor addItemWithTitle:
        [thisBundle localizedStringForKey:@"Gradient" value:@"" table:@""]];
    [IBSimiColor addItemWithTitle:
        [thisBundle localizedStringForKey:@"Random" value:@"" table:@""]];
    [IBSimiColor selectItemAtIndex:simiColor];

    [IBpointSizeTxt setStringValue: [NSString stringWithFormat:
        [thisBundle localizedStringForKey:@"Point size (%.1f)" value:@"" table:@""], pointSize]];
    [IBpointSize setFloatValue:pointSize];
    [IBpointSmoothing setState:(pointSmoothing ? NSOnState : NSOffState)];
    [IBpointSmoothing setTitle:[thisBundle localizedStringForKey:@"Point Smoothing" value:@"" table:@""]];

    [IBblur setIntValue:blur];
    [IBblurTxt setStringValue:[NSString stringWithFormat:
        [thisBundle localizedStringForKey:@"Blur (%d)" value:@"" table:@""], blur]];
    
    [IBmainMonitorOnly setState:(mainMonitorOnly ? NSOnState : NSOffState)];
    [IBmainMonitorOnly setTitle:[thisBundle localizedStringForKey:@"Main monitor only" value:@"" table:@""]];

    [IBCheckVersion setTitle:[thisBundle localizedStringForKey:@"Check updates" value:@"" table:@""]];
    [IBCancel setTitle:[thisBundle localizedStringForKey:@"Cancel" value:@"" table:@""]];
    [IBSave setTitle:[thisBundle localizedStringForKey:@"Save" value:@"" table:@""]];
    
    return configureSheet;
}

- (IBAction) closeSheet_save:(id) sender {
    int thisScreen;
    int mainScreen;
    int oldColNum;
    int oldColMode;
    int oldSimiColor;
    int i;
    
    ScreenSaverDefaults *defaults = [ScreenSaverDefaults defaultsForModuleWithName:@"ifs"];
    
#ifdef LOG_DEBUG
    NSLog( @"closeSheet_save" );
#endif

    oldColNum = ncolorsSaved;
    oldColMode = colorMode;
    oldSimiColor = simiColor;

    ncolorsSaved = [IBncolors intValue];
    alpha = [IBalfa floatValue]/100.0;
    colorMode    = [IBcolorMode indexOfSelectedItem];
    simiColor    = [IBSimiColor indexOfSelectedItem];

    pointSize = [IBpointSize floatValue];
    pointSmoothing = ( [IBpointSmoothing state] == NSOnState ) ? true : false;

    blur = [IBblur intValue];

    mainMonitorOnly = ( [IBmainMonitorOnly state] == NSOnState ) ? true : false;

    [defaults setInteger:ncolorsSaved forKey:@"ncolors"];
    [defaults setFloat:alpha forKey:@"alpha"];
    [defaults setInteger:colorMode forKey:@"colorMode"];
    [defaults setInteger: simiColor forKey: @"simiColor"];
    [defaults setFloat: pointSize forKey:@"pointSize"];
    [defaults setBool: pointSmoothing forKey: @"pointSmoothing"];
    [defaults setInteger: blur forKey: @"blur"];
    [defaults setBool: mainMonitorOnly forKey: @"mainMonitorOnly"];
    
    [defaults synchronize];

#ifdef LOG_DEBUG
    NSLog(@"Canged params" );
#endif
    
    if( mainMonitorOnly ) {
        thisScreen = [[[[[self window] screen] deviceDescription] objectForKey:@"NSScreenNumber"] intValue];
        mainScreen = [[[[NSScreen mainScreen] deviceDescription] objectForKey:@"NSScreenNumber"] intValue];
        // NSLog( @"test this %d - main %d", thisScreen, mainScreen );
        if( thisScreen != mainScreen ) {
            thisScreenIsOn = FALSE;
        }
    }
    if( (thisScreenIsOn == FALSE) && (mainMonitorOnly == FALSE) ) {
        thisScreenIsOn = TRUE;
        [self startAnimation];
    }

    if( oldColNum != ncolorsSaved || oldColMode != colorMode )
        [self initColors];

    if( oldColNum != ncolorsSaved || oldSimiColor != simiColor ) {
        SIMI * Cur;
        ColorIndex = 0;
        for (Cur = Fractal.Components, i = Fractal.Nb_Simi-1; i>=0; i--, Cur++) {
            if( simiColor == 0 ) {		// single color
                Cur->colorindex = 0;
            }
            else if( simiColor == 1 ) {		// gradient
                Cur->colorindex = ColorIndex;
                ColorIndex += ColorSpan;
            }
            else {				// random
                Cur->colorindex = NRAND(ncolors);
            }
        }
    }
    
    if( pointSmoothing )
        glEnable(GL_POINT_SMOOTH);
    else
        glDisable(GL_POINT_SMOOTH);
    glPointSize( pointSize );
    
    [NSApp endSheet:configureSheet];
}

- (IBAction) closeSheet_cancel:(id) sender {

#ifdef LOG_DEBUG
    NSLog( @"closeSheet_cancel" );
#endif
    
    [NSApp endSheet:configureSheet];
}

- (IBAction)updateConfigureSheet:(id) sender
{
    float 	floatValue;
    int 	intValue;
    NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];

#ifdef LOG_DEBUG
    NSLog( @"updateConfigureSheet" );
#endif

    if( sender == IBalfa ) {
        floatValue = [IBalfa floatValue]/100;
        [IBalfaTxt setStringValue: [NSString stringWithFormat:
            [thisBundle localizedStringForKey:@"Transparency (%.2f)" value:@"" table:@""], floatValue]];
    }
    else if( sender == IBncolors ) {
        intValue = [IBncolors intValue];
        [IBncolorsBut setIntValue:intValue];
        [IBncolorsTxt setStringValue: [NSString stringWithFormat:
            [thisBundle localizedStringForKey:@"Number of colors (%d)" value:@"" table:@""], intValue]];
    }
    else if( sender == IBncolorsBut ) {
        intValue = [IBncolorsBut intValue];
        [IBncolors setIntValue:intValue];
        [IBncolorsTxt setStringValue: [NSString stringWithFormat:
            [thisBundle localizedStringForKey:@"Number of colors (%d)" value:@"" table:@""], intValue]];
    }
    else if( sender == IBpointSize ) {
        floatValue = [IBpointSize floatValue];
        [IBpointSizeTxt setStringValue: [NSString stringWithFormat:
            [thisBundle localizedStringForKey:@"Point size (%.1f)" value:@"" table:@""], floatValue]];
    }
    else if( sender == IBblur ) {
        intValue = [IBblur intValue];
        [IBblurTxt setStringValue:[NSString stringWithFormat:
            [thisBundle localizedStringForKey:@"Blur (%d)" value:@"" table:@""], intValue]];
    }
}

- (void) dealloc {

#ifdef LOG_DEBUG
    NSLog( @"dealloc" );
#endif
    [super dealloc];
}


- (void) init_ifs
{
    int i;
    
#ifdef LOG_DEBUG
    NSLog( @"init_ifs" );
#endif

    [self free_ifs_buffers];

    i = (NRAND(4)) + 2;	/* Number of centers */
    switch (i) {
        case 3:
            Fractal.Depth = MAX_DEPTH_3;
            Fractal.r_mean = .6;
            Fractal.dr_mean = .4;
            Fractal.dr2_mean = .3;
            break;

        case 4:
            Fractal.Depth = MAX_DEPTH_4;
            Fractal.r_mean = .5;
            Fractal.dr_mean = .4;
            Fractal.dr2_mean = .3;
            break;

        case 5:
            Fractal.Depth = MAX_DEPTH_5;
            Fractal.r_mean = .5;
            Fractal.dr_mean = .4;
            Fractal.dr2_mean = .3;
            break;

        default:
        case 2:
            Fractal.Depth = MAX_DEPTH_2;
            Fractal.r_mean = .7;
            Fractal.dr_mean = .3;
            Fractal.dr2_mean = .4;
            break;
    }

    Fractal.Nb_Simi = i;
    Fractal.Max_Pt = Fractal.Nb_Simi - 1;
    for (i = 0; i <= Fractal.Depth + 1; ++i)
        Fractal.Max_Pt *= Fractal.Nb_Simi;

    for (i=0; i<MAX_SIMI; i++) {
        if ((Fractal.Buffer[i] = (XPoint *) calloc(Fractal.Max_Pt,
                                              sizeof (XPoint))) == NULL) {
            [self free_ifs_buffers];
            return;
        }
    }

    Fractal.Speed = 6;
    Fractal.Width = width;
    Fractal.Height = height;
    Fractal.Count = 0;
    Fractal.Lx = (Fractal.Width - 1) / 2;
    Fractal.Ly = (Fractal.Height - 1) / 2;

    Random_Simis(&Fractal, Fractal.Components, 5 * MAX_SIMI, colors, ncolors, simiColor);

    mustInitialize = NO;
}

- (void) draw_ifs
{
    int         i;
    DBL         u, uu, v, vv, u0, u1, u2, u3;
    SIMI       *S, *S1, *S2, *S3, *S4;
    FRACTAL    *F;

    F = &Fractal;
    if (F->Buffer[0] == NULL)
        return;

    u = (DBL) (F->Count) * (DBL) (F->Speed) / 1000.0;
    uu = u * u;
    v = 1.0 - u;
    vv = v * v;
    u0 = vv * v;
    u1 = 3.0 * vv * u;
    u2 = 3.0 * v * uu;
    u3 = u * uu;

    S = F->Components;
    S1 = S + F->Nb_Simi;
    S2 = S1 + F->Nb_Simi;
    S3 = S2 + F->Nb_Simi;
    S4 = S3 + F->Nb_Simi;

    for (i = F->Nb_Simi; i; --i, S++, S1++, S2++, S3++, S4++) {
        S->c_x = u0 * S1->c_x + u1 * S2->c_x + u2 * S3->c_x + u3 * S4->c_x;
        S->c_y = u0 * S1->c_y + u1 * S2->c_y + u2 * S3->c_y + u3 * S4->c_y;
        S->r   = u0 * S1->r   + u1 * S2->r   + u2 * S3->r   + u3 * S4->r;
        S->r2  = u0 * S1->r2  + u1 * S2->r2  + u2 * S3->r2  + u3 * S4->r2;
        S->A   = u0 * S1->A   + u1 * S2->A   + u2 * S3->A   + u3 * S4->A;
        S->A2  = u0 * S1->A2  + u1 * S2->A2  + u2 * S3->A2  + u3 * S4->A2;
    }

    [self Draw_Fractal];

    if (F->Count >= 1000 / F->Speed) {
        S = F->Components;
        S1 = S  + F->Nb_Simi;
        S2 = S1 + F->Nb_Simi;
        S3 = S2 + F->Nb_Simi;
        S4 = S3 + F->Nb_Simi;

        for (i = F->Nb_Simi; i; --i, S++, S1++, S2++, S3++, S4++) {
            S2->c_x = 2.0 * S4->c_x - S3->c_x;
            S2->c_y = 2.0 * S4->c_y - S3->c_y;
            S2->r   = 2.0 * S4->r   - S3->r;
            S2->r2  = 2.0 * S4->r2  - S3->r2;
            S2->A   = 2.0 * S4->A   - S3->A;
            S2->A2  = 2.0 * S4->A2  - S3->A2;

            *S1 = *S4;
        }
        Random_Simis(F, F->Components + 3 * F->Nb_Simi, F->Nb_Simi, colors, ncolors, simiColor);

        Random_Simis(F, F->Components + 4 * F->Nb_Simi, F->Nb_Simi, colors, ncolors, simiColor);

        F->Count = 0;
    } else
        F->Count++;
}


- (void) Draw_Fractal
{
    FRACTAL    *F = &Fractal;
    int         i, j;
    F_PT        x, y, xo, yo;
    SIMI       *Cur, *Simi;

    for (Cur = F->Components, i = F->Nb_Simi; i; --i, Cur++) {
        Cur->Cx = DBL_To_F_PT(Cur->c_x);
        Cur->Cy = DBL_To_F_PT(Cur->c_y);

        Cur->Ct = DBL_To_F_PT(cos(Cur->A));
        Cur->St = DBL_To_F_PT(sin(Cur->A));
        Cur->Ct2 = DBL_To_F_PT(cos(Cur->A2));
        Cur->St2 = DBL_To_F_PT(sin(Cur->A2));

        Cur->R = DBL_To_F_PT(Cur->r);
        Cur->R2 = DBL_To_F_PT(Cur->r2);
    }


    Cur_F = F;
    for (i=0; i<MAX_SIMI; i++ ) {
        Buf[i] = F->Buffer[i];
        PointNo[i] = 0;
    }
    
    for (Cur = F->Components, i = F->Nb_Simi; i; --i, Cur++) {
        xo = Cur->Cx;
        yo = Cur->Cy;
        for (Simi = F->Components, j = F->Nb_Simi; j; --j, Simi++) {
            if (Simi == Cur)
                continue;
            Transform(Simi, xo, yo, &x, &y);
            Trace(F, x, y);
        }
    }

    for (i=0; i<F->Nb_Simi; i++)
        if( PointNo[i] >= F->Max_Pt )
            NSLog( @"ERROR: index %d, points %d (max %d)", i, PointNo[i], F->Max_Pt );
        
    colorindex ++;
    if( colorindex >= ncolors )
        colorindex = 0;

    for (Cur = F->Components, i = F->Nb_Simi-1; i>=0; i--, Cur++) {
        int colornum = (Cur->colorindex + colorindex) % ncolors;
        glColor4f( colors[colornum].red,
                   colors[colornum].green,
                   colors[colornum].blue, alpha );
        
        glBegin(GL_POINTS);			// Begin Drawing The Textured Quad
        for( j=0; j<PointNo[i]; j++) {
            glVertex2i( F->Buffer[i][j].x, F->Buffer[i][j].y );
        }
        glEnd();				// Done Drawing The Textured Quad
    }
}

- (IBAction) checkUpdates:(id)sender
{
    NSString *testVersionString;
    NSDictionary *theVersionDict;
    NSString *theVersion;
    NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];
	
    testVersionString = [NSString stringWithContentsOfURL:[NSURL URLWithString:kCurrentVersionsFile]];
    
    if( testVersionString == nil ) {
        // no connection with the server
        [IBUpdatesInfo setStringValue:
            [thisBundle localizedStringForKey:@"Couldn't connect to version database, sorry" value:@"" table:@""]];
    }
    else {
        theVersionDict = [testVersionString propertyList];
        theVersion = [theVersionDict objectForKey:@"ifs"];
    
        if ( ![theVersion isEqualToString:kVersion] ) {
            //hopefully our version numbers will never be going down... 
            //also takes care of going from MyGreatApp? 7.5 to SuperMyGreatApp? Pro 1.0
            [IBUpdatesInfo setStringValue:
                [thisBundle localizedStringForKey:@"New version available !!" value:@"" table:@""]];
        }
        else {
            [IBUpdatesInfo setStringValue:
                [thisBundle localizedStringForKey:@"You're up-to-date" value:@"" table:@""]];
        }
    }
}

- (void) free_ifs_buffers
{
    int i;

    for (i=0; i<MAX_SIMI; i++) {
        if (Fractal.Buffer[i] != NULL) {
            (void) free((void *) Fractal.Buffer[i]);
            Fractal.Buffer[i] = (XPoint *) NULL;
        }
    }
}

// InitGL ---------------------------------------------------------------------

- (GLvoid) InitGL
{

    // glDisable(GL_DEPTH_TEST);

    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);	// This Will Clear The Background Color To Black
                                          // glClearDepth(1.0);				// Enables Clearing Of The Depth Buffer
                                          //    glShadeModel(GL_FLAT);
    glMatrixMode(GL_PROJECTION);			// Select The Projection Matrix
    glLoadIdentity();				// Reset The Projection Matrix

    // glViewport( 0, 0, (GLdouble) windowWidth, (GLdouble) windowHeight );
    // gluPerspective(45.0f,(GLfloat)windowWidth/(GLfloat)windowHeight,0.1f,100.0f);
    glOrtho( 0, (GLdouble) width, 0, (GLdouble) height, 0, 1 );
    // glMatrixMode(GL_MODELVIEW) ;
    glShadeModel(GL_SMOOTH);
    glHint(GL_POINT_SMOOTH_HINT, GL_NICEST);
    if( pointSmoothing )
        glEnable(GL_POINT_SMOOTH);
    else
        glDisable(GL_POINT_SMOOTH);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glPointSize( pointSize );
}

- (void) setFrameSize:(NSSize) newSize
{
    [super setFrameSize:newSize];
    if( _viewAllocated )
        [_view setFrameSize:newSize];
    _initedGL = NO;
}


- (void) initColors
{
    HSVcolor tempColors[ncolorsSaved];
    int n;
    
    ncolors = ncolorsSaved;

    switch( colorMode ) {
        case 0: // make_uniform_colormap
            make_uniform_colormap( tempColors, &ncolors );
            colorindex = SSRandomIntBetween( 0, ncolors-1 );
            break;
        case 1: // make_smooth_colormap
            make_smooth_colormap( tempColors, &ncolors );
            colorindex = SSRandomIntBetween( 0, ncolors-1 );
            break;
        case 2: // make_color_ramp
            tempColors[0].hue = SSRandomFloatBetween( 0.0, 1.0 );
            tempColors[0].saturation = SSRandomFloatBetween( 0.0, 1.0);
            tempColors[0].brightness = SSRandomFloatBetween( 0.0, 0.8) + 0.2;

            tempColors[1].hue = SSRandomFloatBetween( 0.0, 1.0 );
            tempColors[1].saturation = SSRandomFloatBetween( 0.0, 1.0);
            tempColors[1].brightness = SSRandomFloatBetween( 0.0, 0.8) + 0.2;
            
            make_color_ramp( tempColors[0], tempColors[1], tempColors, &ncolors, true );
            colorindex = SSRandomIntBetween( 0, ncolors-1 );
            break;
    }

    for (n = 0; n < ncolors; n++) {
        NSColor* theColor = [NSColor colorWithCalibratedHue:tempColors[n].hue
                                                 saturation:tempColors[n].saturation
                                                 brightness:tempColors[n].brightness
                                                      alpha:1.0];
        colors[n].red   = [theColor redComponent];
        colors[n].green = [theColor greenComponent];
        colors[n].blue  = [theColor blueComponent];
    }

    ColorSpan = (int)ceil(ncolors/COLORSPAN);
}

@end

/* boxmuller.c           Implements the Polar form of the Box-Muller
Transformation

 (c) Copyright 1994, Everett F. Carter Jr.
 Permission is granted by the author to use
 this software for any application provided this
 copyright notice is preserved.

 */

/* normal random variate generator */
/* mean m, standard deviation s */

// #define ranf LRAND() / MAXRAND
/*
static float box_muller(float m, float s)
{
    float x1, x2, w, y1;
    static float y2;
    static int use_last = 0;
    if (use_last) {		        // use value from previous call
        y1 = y2;
        use_last = 0;
    }
    else {
        do {
            x1 = 2.0 * ranf - 1.0;
            x2 = 2.0 * ranf - 1.0;
            w = x1 * x1 + x2 * x2;
        } while ( w >= 1.0 );
        w = sqrt( (-2.0 * log( w ) ) / w );
        y1 = x1 * w;
        y2 = x2 * w;
        use_last = 1;
    }
    return( m + y1 * s );
}
*/

static DBL Gauss_Rand(DBL c, DBL A, DBL S)
{
    DBL         y;

    y = (DBL) LRAND() / MAXRAND;
    y = A * (1.0 - exp(-y * y * S)) / (1.0 - exp(-S));
    if (NRAND(2))
        return (c + y);
    return (c - y);
}

static DBL Half_Gauss_Rand(DBL c, DBL A, DBL S)
{
    DBL         y;

    y = (DBL) LRAND() / MAXRAND;
    y = A * (1.0 - exp(-y * y * S)) / (1.0 - exp(-S));
    return (c + y);
}

static void Random_Simis(FRACTAL * F, SIMI * Cur, int i, RGBcolor* colors, int ncolors, int colorType)
{
    while (i--) {
        Cur->c_x = Gauss_Rand(0.0, .8, 4.0);
        Cur->c_y = Gauss_Rand(0.0, .8, 4.0);
        Cur->r = Gauss_Rand(F->r_mean, F->dr_mean, 3.0);
        Cur->r2 = Half_Gauss_Rand(0.0, F->dr2_mean, 2.0);
        Cur->A = Gauss_Rand(0.0, 360.0, 4.0) * (M_PI / 180.0);
        Cur->A2 = Gauss_Rand(0.0, 360.0, 4.0) * (M_PI / 180.0);
        if( colorType == 0 ) {		// single color
            Cur->colorindex = 0;
        }
        else if( colorType == 1 ) {	// gradient
            Cur->colorindex = ColorIndex;
            ColorIndex += ColorSpan;
        }
        else {				// random
            Cur->colorindex = NRAND(ncolors);
        }
        Cur++;
    }
}

static inline void Transform(SIMI * Simi, F_PT xo, F_PT yo, F_PT * x, F_PT * y)
{
    F_PT        xx, yy;

    xo = xo - Simi->Cx;
    xo = (xo * Simi->R) / UNIT;
    yo = yo - Simi->Cy;
    yo = (yo * Simi->R) / UNIT;

    xx = xo - Simi->Cx;
    xx = (xx * Simi->R2) / UNIT;
    yy = -yo - Simi->Cy;
    yy = (yy * Simi->R2) / UNIT;

    *x = ((xo * Simi->Ct - yo * Simi->St + xx * Simi->Ct2 - yy * Simi->St2) / UNIT) + Simi->Cx;
    *y = ((xo * Simi->St + yo * Simi->Ct + xx * Simi->St2 + yy * Simi->Ct2) / UNIT) + Simi->Cy;
}



static void Trace(FRACTAL* F, F_PT xo, F_PT yo)
{
    F_PT        x, y;
    int		i;
    SIMI       *Cur;
    double xd, yd;

    Cur = Cur_F->Components;

    for (i = Cur_F->Nb_Simi-1; i>=0; i--, Cur++) {
        Transform(Cur, xo, yo, &x, &y);
        xd = ceil(x * F->Lx / (UNIT * 2));
        yd = ceil(y * F->Ly / (UNIT * 2));
        Buf[i]->x = F->Lx + (int)(xd);
        Buf[i]->y = F->Ly - (int)(yd);
        Buf[i]++;
        PointNo[i]++;

        if (F->Depth && (abs(x - xo) >= 16) && (abs(y - yo) >= 16)) {
            // if (F->Depth && ((x - xo) >> 4) && ((y - yo) >> 4)) {
            F->Depth--;
            Trace(F, x, y);
            F->Depth++;
        }
    }
}

