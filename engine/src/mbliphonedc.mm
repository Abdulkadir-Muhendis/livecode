/* Copyright (C) 2003-2013 Runtime Revolution Ltd.

This file is part of LiveCode.

LiveCode is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

LiveCode is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with LiveCode.  If not see <http://www.gnu.org/licenses/>.  */

#include "prefix.h"

#include "globdefs.h"
#include "filedefs.h"
#include "objdefs.h"
#include "parsedef.h"

#include "execpt.h"
#include "printer.h"
#include "globals.h"
#include "dispatch.h"
#include "stack.h"
#include "card.h"
#include "field.h" 
#include "unicode.h"
#include "notify.h"
#include "statemnt.h"
#include "funcs.h"
#include "eventqueue.h"
#include "image.h"
#include "osspec.h"
#include "fiber.h"
#include "redraw.h"
#include "param.h"
#include "mbldc.h"

#include <objc/runtime.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <AudioToolbox/AudioToolbox.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import <MediaPlayer/MPMoviePlayerViewController.h>

#include "mbliphonecontext.h"
#include "mbliphoneapp.h"
#include "mbliphoneview.h"

////////////////////////////////////////////////////////////////////////////////

extern Bool X_init(int argc, char *argv[], char *envp[]);
extern void X_main_loop(void);
extern bool X_main_loop_iteration(void);
extern int X_close(void);
extern void send_startup_message(bool p_do_relaunch = true);
extern void setup_simulator_hooks(void);

@class com_runrev_livecode_MCIPhoneBreakWaitHelper;

////////////////////////////////////////////////////////////////////////////////

Boolean tripleclick = False;
uint4 g_current_background_colour = 0;

////////////////////////////////////////////////////////////////////////////////

// These are used by the MCScreenDC 'beep' methods.
static SystemSoundID s_system_sound = 0;
static MCStringRef s_system_sound_name = nil;

// These control the mapping of LiveCode pixel values to iOS pixels.
static int32_t s_iphone_res_scale = 1;
static int32_t s_iphone_control_res_scale = 1;

// The main fiber on which all other code is executed.
static MCFiberRef s_main_fiber = nil;
// The fiber on which script and code calling script is executed.
static MCFiberRef s_script_fiber = nil;

// If this is true, then a request to break the current wait has already been
// made.
static bool s_break_wait_pending = false;
// The helper object used to break the main wait loop.
static com_runrev_livecode_MCIPhoneBreakWaitHelper *s_break_wait_helper = nil;
// The current depth of wait.
static uindex_t s_wait_depth = 0;

// The current height of the keyboard.
static float s_current_keyboard_height = 0.0f;

////////////////////////////////////////////////////////////////////////////////

static bool MCIPhoneWait(double sleep);

static float iphone_font_measure_text(void *p_font, const char *p_text, uint32_t p_text_length, bool p_is_unicode);

MCRectangle MCRectangleFromLogicalCGRect(const CGRect p_cg_rect)
{
	return MCU_make_rect(
				(int2)(p_cg_rect . origin . x * s_iphone_res_scale),
				(int2)(p_cg_rect . origin . y * s_iphone_res_scale),
				(uint2)(p_cg_rect . size . width * s_iphone_res_scale),
				(uint2)(p_cg_rect . size . height * s_iphone_res_scale));
}

CGRect MCRectangleToLogicalCGRect(const MCRectangle p_rect)
{
	return CGRectMake(
				p_rect . x / (CGFloat)s_iphone_res_scale,
				p_rect . y / (CGFloat)s_iphone_res_scale,
				p_rect . width / (CGFloat)s_iphone_res_scale,
				p_rect . height / (CGFloat)s_iphone_res_scale);
}

// MW-2012-08-06: [[ Fibers ]] Primitive calls for executing selectors on
//   different fibers.

struct sel_ctxt_t
{
	id object;
	SEL selector;
	id argument;
};

static void sel_callback(void *p_context)
{
	sel_ctxt_t *ctxt;
	ctxt = (sel_ctxt_t *)p_context;
	[ctxt -> object performSelector: ctxt -> selector];
}

static void sel_callback_arg(void *p_context)
{
	sel_ctxt_t *ctxt;
	ctxt = (sel_ctxt_t *)p_context;
	[ctxt -> object performSelector: ctxt -> selector withObject: ctxt -> argument];
}

static void MCFiberCallSelector(MCFiberRef p_fiber, id object, SEL selector)
{
	sel_ctxt_t ctxt;
	ctxt . object = object;
	ctxt . selector = selector;
	MCFiberCall(p_fiber, sel_callback, &ctxt);
}

static void MCFiberCallSelectorWithObject(MCFiberRef p_fiber, id object, SEL selector, id arg)
{
	sel_ctxt_t ctxt;
	ctxt . object = object;
	ctxt . selector = selector;
	ctxt . argument = arg;
	MCFiberCall(p_fiber, sel_callback_arg, &ctxt);
}

void MCIPhoneCallOnMainFiber(void (*handler)(void *), void *context)
{
	MCFiberCall(s_main_fiber, handler, context);
}

////////////////////////////////////////////////////////////////////////////////

Boolean MCScreenDC::open(void)
{
	common_open();
	
	return True;
}

Boolean MCScreenDC::close(Boolean p_force)
{
	return True;
}

bool MCScreenDC::hasfeature(MCPlatformFeature p_feature)
{
	return false;
}

MCNameRef MCScreenDC::getdisplayname(void)
{
	return MCN_iphone;
}

MCNameRef MCScreenDC::getvendorname(void)
{
	return MCN_iphone;
}

uint2 MCScreenDC::getwidth()
{
	return 320 * s_iphone_res_scale;
}

uint2 MCScreenDC::getheight()
{
	return 480 * s_iphone_res_scale;
}

uint2 MCScreenDC::getwidthmm()
{
	return 32;
}

uint2 MCScreenDC::getheightmm()
{
	return 48;
}

uint2 MCScreenDC::getmaxpoints()
{
	return 4096;
}

uint2 MCScreenDC::getvclass()
{
	return TrueColor;
}

uint2 MCScreenDC::getdepth()
{
	return 32;
}

uint2 MCScreenDC::getrealdepth(void)
{
	return 32;
}

uint2 MCScreenDC::getpad()
{
	return 32;
}

Window MCScreenDC::getroot()
{
	return NULL;
}

uint4 MCScreenDC::getdisplays(MCDisplay const *& p_displays, bool p_effective)
{
	static MCDisplay s_display;

	s_display . index = 0;
	s_display . viewport = MCRectangleFromLogicalCGRect(MCIPhoneGetScreenBounds());
	s_display . workarea = MCRectangleFromLogicalCGRect(MCIPhoneGetViewBounds());
	if (p_effective)
		s_display . workarea . height -= s_current_keyboard_height;
	
	p_displays = &s_display;
	
	return 1;
}

Boolean MCScreenDC::getwindowgeometry(Window p_window, MCRectangle& r_rect)
{
	r_rect = MCRectangleFromLogicalCGRect(MCIPhoneGetViewBounds());
	return True;
}

////////////////////////////////////////////////////////////////////////////////

MCContext *MCScreenDC::createcontext(Drawable p_drawable, MCBitmap *p_mask)
{
	MCMobileBitmap *t_bitmap;
	t_bitmap = (MCMobileBitmap *)p_drawable -> handle . pixmap;
	return new MCIPhoneContext(t_bitmap, p_mask, true, true);
}

MCContext *MCScreenDC::createcontext(Drawable p_drawable, bool p_alpha, bool p_transient)
{
	MCMobileBitmap *t_bitmap;
	t_bitmap = (MCMobileBitmap *)p_drawable -> handle . pixmap;
	return new MCIPhoneContext(t_bitmap, nil, true, p_alpha);
}

MCContext *MCScreenDC::creatememorycontext(uint2 p_width, uint2 p_height, bool p_alpha, bool p_transient)
{
	return new MCIPhoneContext(MCMobileBitmapCreate(p_width, p_height, false), nil, false, p_alpha);
}

void MCScreenDC::freecontext(MCContext *p_context)
{
	delete p_context;
}

int4 MCScreenDC::textwidth(MCFontStruct *f, const char *p_string, uint2 p_length, bool p_unicode_override)
{
	return ceil(iphone_font_measure_text(f -> fid, p_string, p_length, p_unicode_override || f -> unicode));
}

////////////////////////////////////////////////////////////////////////////////

void MCScreenDC::beep(void)
{
	// MW-2012-08-06: [[ Fibers ]] Execute the system code on the main fiber.
	MCIPhoneRunBlockOnMainFiber(^(void) {
		AudioServicesPlayAlertSound(s_system_sound_name != nil ? s_system_sound : kSystemSoundID_Vibrate);
	});
}

struct MCScreenDCDoSetBeepSoundEnv
{
	const char *sound;
	bool result;
};

// MW-2012-08-06: [[ Fibers ]] Main fiber callback for system calls.
static void MCScreenDCDoSetBeepSound(void *p_env)
{
	MCScreenDCDoSetBeepSoundEnv *env;
	env = (MCScreenDCDoSetBeepSoundEnv *)p_env;
	
	if (env -> sound == nil || *(env -> sound) == 0)
	{
		if (s_system_sound_name != nil)
		{
			AudioServicesDisposeSystemSoundID(s_system_sound);
			MCValueRelease(s_system_sound_name);
		}
		s_system_sound = 0;
		s_system_sound_name = nil;
		env -> result = true;
		return;
	}
	
	SystemSoundID t_new_sound;
	
	MCAutoStringRef t_sound_path;
	MCAutoStringRef t_env_sound;
	/* UNCHECKED */ MCStringCreateWithCString(env -> sound, &t_env_sound);
	MCS_resolvepath(*t_env_sound, &t_sound_path);
	
	NSURL *t_url;
	t_url = [NSURL fileURLWithPath: [NSString stringWithMCStringRef: *t_sound_path]];
	
	OSStatus t_status;
	t_status = AudioServicesCreateSystemSoundID((CFURLRef)t_url, &t_new_sound);
	if (t_status == noErr)
	{
		if (s_system_sound_name != nil)
		{
			AudioServicesDisposeSystemSoundID(s_system_sound);
			MCValueRelease(s_system_sound_name);
		}
		s_system_sound = t_new_sound;
		s_system_sound_name = MCValueRetain(*t_sound_path);
	}
	else
		MCValueRelease(*t_sound_path);
	
	env -> result = t_status == noErr;
}

bool MCScreenDC::setbeepsound(MCStringRef p_beep_sound)
{
	MCScreenDCDoSetBeepSoundEnv t_env;
	t_env . sound = MCStringGetCString(p_beep_sound);

	// MW-2012-08-06: [[ Fibers ]] Execute the system code on the main fiber.
	/* REMOTE */ MCFiberCall(s_main_fiber, MCScreenDCDoSetBeepSound, &t_env);

	return t_env . result;
}

bool MCScreenDC::getbeepsound(MCStringRef& r_beep_sound)
{
	if (s_system_sound_name != nil)
		r_beep_sound = MCValueRetain(s_system_sound_name);
	else
		r_beep_sound = MCValueRetain(kMCEmptyString);
	return true;
}

void MCScreenDC::getbeep(uint4 property, int4& r_value)
{
}

void MCScreenDC::setbeep(uint4 property, int4 beep)
{
}

////////////////////////////////////////////////////////////////////////////////

struct MCScreenDCDoSnapshotEnv
{
	MCRectangle r;
	uint4 window;
	const char *displayname;
	MCBitmap *result;
};

// MW-2012-08-06: [[ Fibers ]] Main fiber callback for system calls.
static void MCScreenDCDoSnapshot(void *p_env)
{
	MCScreenDCDoSnapshotEnv *env;
	env = (MCScreenDCDoSnapshotEnv *)p_env;
	
	MCRectangle r;
	uint4 window;
	const char *displayname;
	r = env -> r;
	window = env -> window;
	displayname = env -> displayname;
	
	/////
	
	bool t_success = true;
	
	MCBitmap *t_bitmap = NULL;
	
	// Use the screenRect to clip the input rect
	MCRectangle t_screen_rect;
	const MCDisplay *t_displays;
	MCscreen -> getdisplays(t_displays, false);
	t_screen_rect = t_displays[0] . viewport;
	r = MCU_clip_rect(r, t_screen_rect . x, t_screen_rect . y, t_screen_rect . width, t_screen_rect . height);
	
	MCBitmap *t_newimage;
	t_newimage = nil;
	if (r.width != 0 && r.height != 0)
	{
		CGContextRef t_img_context = nil;
		CGColorSpaceRef t_colorspace = nil;
		uint8_t *t_pixel_buffer = nil;
		
		if (t_success)
		{
			t_colorspace = CGColorSpaceCreateDeviceRGB();
			t_success = t_colorspace != nil;
		}
		
		if (t_success)
		{
			t_bitmap = MCscreen->createimage(32, r.width, r.height, True, 0, False, False);
			t_success = t_bitmap != nil;
		}
		
		if (t_success)
		{
			t_img_context = CGBitmapContextCreate(t_bitmap -> data, t_bitmap->width, t_bitmap->height, 8, t_bitmap->bytes_per_line, t_colorspace, kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst);
			t_success = t_img_context != nil;
		}
		
		if (t_success)
		{
			int32_t t_scale = s_iphone_res_scale;
			CGContextScaleCTM(t_img_context, 1.0, -1.0);
			CGContextTranslateCTM(t_img_context, 0, -r . height);
			CGContextTranslateCTM(t_img_context, -r.x, -r.y);
			
			bool t_is_rotated;
			CGSize t_offset;
			CGFloat t_angle;
			switch(MCIPhoneGetOrientation())
			{
				case UIInterfaceOrientationPortrait:
					t_angle = 0.0;
					t_offset = CGSizeMake(t_screen_rect . width / 2, t_screen_rect . height / 2);
					t_is_rotated = false;
					break;
				case UIInterfaceOrientationPortraitUpsideDown:
					t_angle = M_PI;
					t_offset = CGSizeMake(t_screen_rect . width / 2, t_screen_rect . height / 2);
					t_is_rotated = false;
					break;
				case UIInterfaceOrientationLandscapeLeft:
					// MW-2011-10-17: [[ Bug 9816 ]] Angle caused upside-down image so inverted.
					t_angle = M_PI / 2.0;
					t_offset = CGSizeMake(t_screen_rect . height / 2, t_screen_rect . width / 2);
					t_is_rotated = true;
					break;
				case UIInterfaceOrientationLandscapeRight:
					// MW-2011-10-17: [[ Bug 9816 ]] Angle caused upside-down image so inverted.
					t_angle = -M_PI / 2.0;
					t_offset = CGSizeMake(t_screen_rect . height / 2, t_screen_rect . width / 2);
					t_is_rotated = true;
					break;
			}
			
			CGContextTranslateCTM(t_img_context, t_screen_rect . width / 2, t_screen_rect . height / 2);
			CGContextRotateCTM(t_img_context, t_angle);
			CGContextTranslateCTM(t_img_context, -t_offset . width, -t_offset . height);
			
			CGContextScaleCTM(t_img_context, t_scale, t_scale);
			
#ifndef USE_UNDOCUMENTED_METHODS
			NSArray *t_windows;
			t_windows = [[[UIApplication sharedApplication] windows] retain];
#else
			NSMutableArray *t_windows;
			t_windows = [[[UIApplication sharedApplication] windows] mutableCopy];
			if (![[UIApplication sharedApplication] isStatusBarHidden])
			{
				CGFloat t_statusbar_size;
				CGRect t_statusbar_frame;
				t_statusbar_frame = [[UIApplication sharedApplication] statusBarFrame];
				if (t_is_rotated)
					t_statusbar_size = t_statusbar_frame . size . width;
				else
					t_statusbar_size = t_statusbar_frame . size . height;
				
				MCRectangle t_statusbar_rect;
				MCU_set_rect(t_statusbar_rect, 0, 0, t_screen_rect . width, t_statusbar_size * t_scale);
				if (!MCU_empty_rect(MCU_intersect_rect(t_statusbar_rect, r)))
				{
					id t_statusbar_window;
					if (object_getInstanceVariable([UIApplication sharedApplication], "_statusBarWindow", (void **)&t_statusbar_window) != nil)
						[t_windows addObject: t_statusbar_window];
				}
			}
#endif
			
			for (UIWindow *window in t_windows) 
			{
				if ([window screen] == [UIScreen mainScreen])
				{
					// -renderInContext: renders in the coordinate space of the layer,
					// so we must first apply the layer's geometry to the graphics context
					CGContextSaveGState(t_img_context);
					// Center the context around the window's anchor point
					CGContextTranslateCTM(t_img_context, [window center].x, [window center].y);
					// Apply the window's transform about the anchor point
					CGContextConcatCTM(t_img_context, [window transform]);
					// Offset by the portion of the bounds left of and above the anchor point
					CGContextTranslateCTM(t_img_context,
										  -[window bounds].size.width * [[window layer] anchorPoint].x,
										  -[window bounds].size.height * [[window layer] anchorPoint].y);
					
					// Render the layer hierarchy to the current context
					[[window layer] renderInContext:t_img_context];
					
					// Restore the context
					CGContextRestoreGState(t_img_context);
				}
			}
			
			[t_windows release];
		}
		
		if (t_img_context)
			CGContextRelease(t_img_context);
		
		if (t_success)
			t_newimage = t_bitmap;
		else
		{
			if (t_bitmap != NULL)
			{
				MCscreen->destroyimage(t_bitmap);
				t_bitmap = NULL;
			}
		}
	}
		
	env -> result = t_bitmap;
}

MCBitmap *MCScreenDC::snapshot(MCRectangle &r, uint4 window, MCStringRef displayname)
{
	MCScreenDCDoSnapshotEnv env;
	env . r = r;
	env . window = window;
	env . displayname = MCStringGetCString(displayname);

	// MW-2012-08-06: [[ Fibers ]] Execute the system code on the main fiber.
	/* REMOTE */ MCFiberCall(s_main_fiber, MCScreenDCDoSnapshot, &env);

	return env . result;
}

////////////////////////////////////////////////////////////////////////////////

Boolean MCScreenDC::wait(real8 duration, Boolean dispatch, Boolean anyevent)
{
	real8 curtime = MCS_time();
	
	if (duration < 0.0)
		duration = 0.0;
	
	real8 exittime = curtime + duration;
	
	Boolean abort = False;
	Boolean reset = False;
	Boolean done = False;
	
	MCwaitdepth++;
	
	do
	{
		real8 eventtime = exittime;
		if (handlepending(curtime, eventtime, dispatch))
		{
			if (anyevent)
				done = True;
			
			if (MCquit)
			{
				abort = True;
				break;
			}
		}
		
		if (dispatch && MCEventQueueDispatch())
		{
			if (anyevent)
				done = True;
			
			if (MCquit)
			{
				abort = True;
				break;
			}
		}
		
		// MW-2012-09-19: [[ Bug 10218 ]] Make sure we update the screen in case
		//   any engine event handling methods need us to.
		MCRedrawUpdateScreen();

		// Get the time now
		curtime = MCS_time();
		
		// And work out how long to sleep for.
		real8 t_sleep;
		t_sleep = 0.0;
		if (curtime >= exittime)
			done = True;
		else if (!done && eventtime > curtime)
			t_sleep = MCMin(eventtime - curtime, exittime - curtime);
		
		// Switch to the main fiber and wait for at most t_sleep seconds. This
		// returns 'true' if the wait was broken rather than timed out.
		if (MCIPhoneWait(t_sleep) && anyevent)
			done = True;
		
		// If 'quit' has been set then we must have got a finalization request
		if (MCquit)
		{
			abort = True;
			break;
		}
	}
	while(!done);
	
	MCwaitdepth--;
	
	// MW-2012-09-19: [[ Bug 10218 ]] Make sure we update the screen in case
	//   any engine event handling methods need us to.
	MCRedrawUpdateScreen();

	return abort;
}

// MW-2011-08-16: [[ Wait ]] Break the OS event loop, causing a switch back to
//   the engine fiber, with control resuming within 'wait()'.
void MCScreenDC::pingwait(void)
{
	MCIPhoneBreakWait();
}

void MCScreenDC::openIME()
{
}

void MCScreenDC::activateIME(Boolean activate)
{
	// MW-2012-08-06: [[ Fibers ]] Execute the system code on the main fiber.
	MCIPhoneRunBlockOnMainFiber(^(void) {
	if (activate)
			MCIPhoneActivateKeyboard();
	else
			MCIPhoneDeactivateKeyboard();
	});
}

void MCScreenDC::closeIME()
{
	// MW-2012-08-06: [[ Fibers ]] Execute the system code on the main fiber.
	MCIPhoneRunBlockOnMainFiber(^(void) {
		MCIPhoneDeactivateKeyboard();
	});
}

void MCScreenDC::do_take_focus(void)
{
	// MW-2012-08-06: [[ Fibers ]] Execute the system code on the main fiber.
	MCFiberCallSelector(s_main_fiber, MCIPhoneGetView(), @selector(becomeFirstResponder));
}

void MCScreenDC::do_fit_window(bool p_immediate_resize, bool p_post_message)
{
	if (m_current_window == nil)
		return;
	
	MCRectangle t_view_bounds;
	t_view_bounds = MCRectangleFromLogicalCGRect(MCIPhoneGetViewBounds());
	
	m_window_left = t_view_bounds . x;
	m_window_top = t_view_bounds . y;
	
	if (p_post_message)
	{
		if (p_immediate_resize)
			((MCStack *)m_current_window) -> configure(True);
		else
			MCEventQueuePostWindowReshape((MCStack *)m_current_window);
	}
}

// MW-2012-03-05: [[ ViewStack]] Change the currently displayed stack to a new one.
void MCScreenDC::do_show_stack_in_window(MCStack *p_stack)
{
	[MCIPhoneGetRootView() setCurrentStack: p_stack];
}

Window MCScreenDC::get_current_window(void)
{
	return m_current_window;
}

////////////////////////////////////////////////////////////////////////////////

struct do_iphone_font_create_env
{
	const char *name;
	uint32_t size;
	bool bold;
	bool italic;
	void *result;
};

// MW-2012-08-06: [[ Fibers ]] Main fiber callback for system calls.
static void do_iphone_font_create(void *p_env)
{
	do_iphone_font_create_env *env;
	env = (do_iphone_font_create_env *)p_env;
	
	const char *p_name;
	uint32_t p_size;
	bool p_bold;
	bool p_italic;
	p_name = env -> name;
	p_size = env -> size;
	p_bold = env -> bold;
	p_italic = env -> italic;
	
	char t_font_name[256];
	UIFont *t_font;
	t_font = nil;
	
    // MW-2012-03-22: [[ Bug ]] First see if we can find the font with the given name. We
    //   use this to get the correct 'family' name so styled names work correctly.
    UIFont *t_base_font;
    t_base_font = [ UIFont fontWithName: [ NSString stringWithCString: p_name encoding: NSMacOSRomanStringEncoding ] size: p_size ];
    
    char t_base_name[256];
    if (t_base_font != nil)
        sprintf(t_base_name, "%s", [[t_base_font fontName] cStringUsingEncoding: NSMacOSRomanStringEncoding]);
    else
        strcpy(t_base_name, p_name);
    
	if (p_bold && p_italic)
	{
		sprintf(t_font_name, "%s-BoldItalic", t_base_name);
		t_font = [ UIFont fontWithName: [ NSString stringWithCString: t_font_name encoding: NSMacOSRomanStringEncoding ] size: p_size ];
		if (t_font == nil)
		{
			sprintf(t_font_name, "%s-BoldOblique", t_base_name);
			t_font = [ UIFont fontWithName: [ NSString stringWithCString: t_font_name encoding: NSMacOSRomanStringEncoding ] size: p_size ];
		}
	}
	
	if (t_font == nil && p_bold)
	{
		sprintf(t_font_name, "%s-Bold", t_base_name);
		t_font = [ UIFont fontWithName: [ NSString stringWithCString: t_font_name encoding: NSMacOSRomanStringEncoding ] size: p_size ];
	}
	
	if (t_font == nil && p_italic)
	{
		sprintf(t_font_name, "%s-Italic", t_base_name);
		t_font = [ UIFont fontWithName: [ NSString stringWithCString: t_font_name encoding: NSMacOSRomanStringEncoding ] size: p_size ];
		if (t_font == nil)
		{
			sprintf(t_font_name, "%s-Oblique", t_base_name);
			t_font = [ UIFont fontWithName: [ NSString stringWithCString: t_font_name encoding: NSMacOSRomanStringEncoding ] size: p_size ];
		}
	}
	
    // MW-2012-03-22: If the font is nil here either there was no styling, or no styled
    //   variants were found so use the base font.
	if (t_font == nil)
		t_font = t_base_font;

	if (t_font == nil)
		t_font = [ UIFont systemFontOfSize: p_size ];
	
	[ t_font retain ];
	
	env -> result = t_font;
}

void *iphone_font_create(MCStringRef p_name, uint32_t p_size, bool p_bold, bool p_italic)
{
	do_iphone_font_create_env env;
	env . name = MCStringGetCString(p_name);
	env . size = p_size;
	env . bold = p_bold;
	env . italic = p_italic;
	// MW-2012-08-06: [[ Fibers ]] Execute the system code on the main fiber.
	/* REMOTE */ MCFiberCall(s_main_fiber, do_iphone_font_create, &env);
	return env . result;
}

void iphone_font_get_metrics(void *p_font, float& r_ascent, float& r_descent)
{
	r_ascent = [ (UIFont *)p_font ascender ];
	r_descent = fabsf([ (UIFont *)p_font descender ]);
}

void iphone_font_destroy(void *p_font)
{
	// MW-2012-08-06: [[ Fibers ]] Execute the system code on the main fiber.
	/* REMOTE */ MCFiberCallSelector(s_main_fiber, (UIFont *)p_font, @selector(release));
}

//////////

typedef void for_each_word_callback_t(void *context, const void *text, uindex_t text_length, bool is_unicode);

static void for_each_word(const void *p_text, uint32_t p_text_length, bool p_is_unicode, for_each_word_callback_t p_callback, void *p_context)
{
	void *t_text_ptr;
	if (p_is_unicode && ((uintptr_t)p_text & 1) != 0)
	{
		t_text_ptr = malloc(p_text_length);
		memcpy(t_text_ptr, p_text, p_text_length);
	}
	else
		t_text_ptr = (void *)p_text;
		
	if (!p_is_unicode)
	{
		char *t_native_text_ptr;
		t_native_text_ptr = (char *)t_text_ptr;
		
		uindex_t t_word_start;
		t_word_start = 0;
		while(t_word_start < p_text_length)
		{
			uindex_t t_word_end;
			t_word_end = t_word_start;
			while(t_native_text_ptr[t_word_end] != ' ' && t_word_end < p_text_length)
				t_word_end++;
			while(t_native_text_ptr[t_word_end] == ' ' && t_word_end < p_text_length)
				t_word_end++;
			
			p_callback(p_context, t_native_text_ptr + t_word_start, t_word_end - t_word_start, p_is_unicode);
			
			t_word_start = t_word_end;
		}
	}
	else
	{
		unichar_t *t_unicode_text_ptr;
		t_unicode_text_ptr = (unichar_t *)t_text_ptr;
	
		uindex_t t_word_start;
		t_word_start = 0;
		while(t_word_start < p_text_length / 2)
		{
			uindex_t t_word_end;
			t_word_end = t_word_start;
			while(t_unicode_text_ptr[t_word_end] != ' ' && t_word_end < p_text_length / 2)
				t_word_end++;
			while(t_unicode_text_ptr[t_word_end] == ' ' && t_word_end < p_text_length / 2)
				t_word_end++;
			
			p_callback(p_context, t_unicode_text_ptr + t_word_start, (t_word_end - t_word_start) * 2, p_is_unicode);
			
			t_word_start = t_word_end;
		}
	}
		
	if (t_text_ptr != p_text)
		free(t_text_ptr);
}

struct iphone_font_measure_text_context_t
{
	void *font;
	float width;
};

static void iphone_font_do_measure_text(void *p_context, const void *p_text, uint32_t p_text_length, bool p_is_unicode)
{
	iphone_font_measure_text_context_t *t_context;
	t_context = (iphone_font_measure_text_context_t *)p_context;
	
	NSString *t_string;
	t_string = [[NSString alloc] initWithBytes: (uint8_t *)p_text length: p_text_length encoding: (p_is_unicode ? NSUTF16LittleEndianStringEncoding : NSMacOSRomanStringEncoding)];

	UIFont *t_font;
	t_font = (UIFont *)t_context -> font;
	
	t_context -> width += ceil([ t_string sizeWithFont: t_font ] . width);
	
	[t_string release];
}

float iphone_font_measure_text(void *p_font, const char *p_text, uint32_t p_text_length, bool p_is_unicode)
{
	uindex_t t_word_start;
	t_word_start = 0;

	iphone_font_measure_text_context_t t_context;
	t_context . font = p_font;
	t_context . width = 0.0f;
	for_each_word(p_text, p_text_length, p_is_unicode, iphone_font_do_measure_text, &t_context);

	return t_context . width;
}

struct iphone_font_draw_text_context_t
{
	void *font;
	float x;
	float y;
};

static void iphone_font_do_draw_text(void *p_context, const void *p_text, uint32_t p_text_length, bool p_is_unicode)
{
	iphone_font_draw_text_context_t *t_context;
	t_context = (iphone_font_draw_text_context_t *)p_context;

	NSString *t_string;
	t_string = [[NSString alloc] initWithBytes: (uint8_t *)p_text length: p_text_length encoding: (p_is_unicode ? NSUTF16LittleEndianStringEncoding : NSMacOSRomanStringEncoding)];
	
	UIFont *t_font;
	t_font = (UIFont *)t_context -> font;
	
	CGSize t_size;
	t_size = [ t_string drawAtPoint: CGPointMake(t_context -> x, t_context -> y - ceilf([ t_font ascender ])) withFont: t_font ];
	
	t_context -> x += ceil(t_size . width);
	
	[t_string release];
}

void iphone_font_draw_text(void *p_font, CGContextRef p_context, CGFloat x, CGFloat y, const char *p_text, uint32_t p_text_length, bool p_is_unicode)
{
	UIGraphicsPushContext(p_context);
	
	iphone_font_draw_text_context_t t_context;
	t_context . font = p_font;
	t_context . x = x;
	t_context . y = y;
	for_each_word(p_text, p_text_length, p_is_unicode, iphone_font_do_draw_text, &t_context);
	
	UIGraphicsPopContext();
}

////////////////////////////////////////////////////////////////////////////////

bool iphone_run_on_main_thread(void *p_callback, void *p_callback_state, int p_options);

typedef void (*MCExternalThreadOptionalCallback)(void *state);
typedef void (*MCExternalThreadRequiredCallback)(void *state, int flags);
enum
{
	// Post the callback and wait until the callback is invoked
	kMCExternalRunOnMainThreadSend = 0 << 0,
	// Post the callback and return immediately
	kMCExternalRunOnMainThreadPost = 1 << 0,
	// The callback does not have to be executed
	kMCExternalRunOnMainThreadOptional = 0 << 1,
	// The callback has to be executed (changes signature)
	kMCExternalRunOnMainThreadRequired = 1 << 1,
	// The callback should be invoked in a script-safe environment
	kMCExternalRunOnMainThreadSafe = 0 << 2,
	// The callback should can be invoked in a non-script-safe environment
	kMCExternalRunOnMainThreadUnsafe = 1 << 2,
	// The callback should be invoked as soon as possible
	kMCExternalRunOnMainThreadImmediate = 0 << 3,
	// The callback should be invoked synchronized to the event queue
	kMCExternalRunOnMainThreadDeferred = 1 << 3,
	// Call the callback on the UI thread.
	kMCExternalRunOnMainThreadJumpToUI = 1 << 4,
	// Call the callback on the Engine thread.
	kMCExternalRunOnMainThreadJumpToEngine = 2 << 4,
};

@interface com_runrev_livecode_MCRunOnMainThreadHelper : NSObject
{
	void *m_callback;
	void *m_callback_state;
	int m_options;
}

- (id)initWithCallback:(void*)callback state:(void *)callbackState options:(int)options;
- (void)run;

@end

@implementation com_runrev_livecode_MCRunOnMainThreadHelper

- (id)initWithCallback:(void*)p_callback state:(void *)p_callback_state options:(int)p_options
{
	self = [super init];
	if (self == nil)
		return nil;
	
	m_callback = p_callback;
	m_callback_state = p_callback_state;
	m_options = p_options;
	
	return self;
}

- (void)perform
{
	if ((m_options & kMCExternalRunOnMainThreadRequired) != 0)
		((MCExternalThreadRequiredCallback)m_callback)(m_callback_state, 0);
	else
		((MCExternalThreadOptionalCallback)m_callback)(m_callback_state);
}

- (void)run
{
	iphone_run_on_main_thread(m_callback, m_callback_state, m_options);
	[self release];
}

@end

class MCRunOnMainThreadEvent: public MCCustomEvent
{
public:
	MCRunOnMainThreadEvent(void *p_callback, void *p_callback_context, int p_options)
	{
		m_callback = p_callback;
		m_callback_context = p_callback_context;
		m_options = p_options;
		m_dispatched = false;
	}
	
	void Destroy(void)
	{
		if (!m_dispatched && (m_options & kMCExternalRunOnMainThreadRequired) != 0)
			((MCExternalThreadRequiredCallback)m_callback)(m_callback_context, 1);
		delete this;
	}
	
	void Dispatch(void)
	{
		m_dispatched = true;
		
		if ((m_options & kMCExternalRunOnMainThreadRequired) != 0)
			((MCExternalThreadRequiredCallback)m_callback)(m_callback_context, 0);
		else
			((MCExternalThreadOptionalCallback)m_callback)(m_callback_context);
	}
	
private:
	void *m_callback;
	void *m_callback_context;
	int m_options;
	bool m_dispatched;
};

// MW-2012-08-06: [[ Fibers ]] Updated implementation to understand 'jumps'
bool iphone_run_on_main_thread(void *p_callback, void *p_callback_state, int p_options)
{
	// Handle the jump to one or other fiber.
	if ((p_options & kMCExternalRunOnMainThreadJumpToUI) != 0)
	{
		if ((p_options & ~kMCExternalRunOnMainThreadJumpToUI) != 0)
			return false;
			
		MCFiberCall(s_main_fiber, (MCFiberCallback)p_callback, p_callback_state);
		
		return true;
	}
	else if ((p_options & kMCExternalRunOnMainThreadJumpToEngine) != 0)
	{
		if ((p_options & ~kMCExternalRunOnMainThreadJumpToEngine) != 0)
			return false;
			
		MCFiberCall(s_script_fiber, (MCFiberCallback)p_callback, p_callback_state);
		
		return true;
	}

	// If we aren't on one of the fibers, then post a selector to the main fiber's
	// thread.
	MCFiberRef t_current_fiber;
	t_current_fiber = MCFiberGetCurrent();
	if (t_current_fiber != s_script_fiber && t_current_fiber != s_main_fiber)
	{
		com_runrev_livecode_MCRunOnMainThreadHelper *t_helper;
		t_helper = [[com_runrev_livecode_MCRunOnMainThreadHelper alloc] initWithCallback: p_callback state: p_callback_state options: p_options];
		
		SEL t_selector;
		if ((p_options & (kMCExternalRunOnMainThreadDeferred | kMCExternalRunOnMainThreadUnsafe)) == (kMCExternalRunOnMainThreadUnsafe | kMCExternalRunOnMainThreadImmediate))
			t_selector = @selector(perform);
		else
			t_selector = @selector(run);
		
		[t_helper performSelectorOnMainThread: t_selector withObject: nil waitUntilDone: (p_options & kMCExternalRunOnMainThreadPost) == 0];
		
		return true;
	}
	
	// Unsafe and immediate -> queue and perform
	if ((p_options & (kMCExternalRunOnMainThreadDeferred | kMCExternalRunOnMainThreadUnsafe)) == (kMCExternalRunOnMainThreadUnsafe | kMCExternalRunOnMainThreadImmediate))
	{
		if ((p_options & kMCExternalRunOnMainThreadPost) == 0)
		{
			if ((p_options & kMCExternalRunOnMainThreadRequired) != 0)
				((MCExternalThreadRequiredCallback)p_callback)(p_callback_state, 0);
			else
				((MCExternalThreadOptionalCallback)p_callback)(p_callback_state);
			return true;
		}
		
		com_runrev_livecode_MCRunOnMainThreadHelper *t_helper;
		t_helper = [[com_runrev_livecode_MCRunOnMainThreadHelper alloc] initWithCallback: p_callback state: p_callback_state options: p_options];
		[t_helper performSelector: @selector(perform) withObject: nil afterDelay: 0];
		return true;
	}
	
	// Safe and immediate -> post to front of event queue
	// Unsafe/Safe and deferred -> post to back of event queue
	MCRunOnMainThreadEvent *t_event;
	t_event = new MCRunOnMainThreadEvent(p_callback, p_callback_state, p_options);
	if ((p_options & kMCExternalRunOnMainThreadDeferred) != 0)
		MCEventQueuePostCustom(t_event);
	else
		MCEventQueuePostCustomAtFront(t_event);
		
	return true;
}

////////////////////////////////////////////////////////////////////////////////

MCUIDC *MCCreateScreenDC(void)
{
	return new MCScreenDC;
}

////////////////////////////////////////////////////////////////////////////////

// MW-2013-03-20: [[ Bug 10748 ]] Make sure we only switch display class when
//   absolutely necessary - the request to switch is deferred until the next
//   update request.

static bool s_ensure_opengl = false;
static bool s_is_opengl_display = false;

void MCIPhoneSwitchToOpenGL(void)
{
	s_ensure_opengl = true;
}

void MCIPhoneSwitchToUIKit(void)
{
	s_ensure_opengl = false;
}

void MCIPhoneSyncDisplayClass(void)
{
	if (s_ensure_opengl && !s_is_opengl_display)
	{
		s_is_opengl_display = true;
		MCIPhoneRunBlockOnMainFiber(^(void) {
			MCIPhoneSwitchViewToOpenGL();
			MCIPhoneConfigureContentScale(s_iphone_res_scale);
		});
	}
	else if (!s_ensure_opengl && s_is_opengl_display)
	{
		s_is_opengl_display = false;
		// MW-2012-08-06: [[ Fibers ]] Execute the system code on the main fiber.
		MCIPhoneRunBlockOnMainFiber(^(void) {
			MCIPhoneSwitchViewToUIKit();
		});
	}
}

////////////////////////////////////////////////////////////////////////////////

float MCIPhoneGetDeviceScale(void)
{
	return [[UIScreen mainScreen] scale];
}

float MCIPhoneGetResolutionScale(void)
{
	return (float)s_iphone_res_scale;
}

float MCIPhoneGetNativeControlScale(void)
{
	return s_iphone_control_res_scale;
}

// Only called from mobile extra calls so on main thread.
void MCIPhoneUseDeviceResolution(bool p_use, bool p_controls_too)
{
	if (p_use)
	{
		s_iphone_res_scale = (int32_t)[[UIScreen mainScreen] scale];
		if (p_controls_too)
			s_iphone_control_res_scale = s_iphone_res_scale;
	}
	else
	{
		s_iphone_res_scale = 1;
		s_iphone_control_res_scale = 1;
	}
	
	MCIPhoneConfigureContentScale(s_iphone_res_scale);
	
	// This doesn't do an immediate resize, so is fine for the main thread. (no
	// script called).
	static_cast<MCScreenDC *>(MCscreen) -> do_fit_window(false, true);
	
	// MW-2012-03-21: [[ Bug ]] Make sure the screen is dirtied as chances are
	//   scaling has changed.
	MCRedrawDirtyScreen();
}

////////////////////////////////////////////////////////////////////////////////

// MW-2012-08-06: [[ Fibers ]] Primitives for executing code on the main fiber.

void MCIPhoneCallSelectorOnMainFiber(id p_object, SEL p_selector)
{
	MCFiberCallSelector(s_main_fiber, p_object, p_selector);
}

void MCIPhoneCallSelectorOnMainFiberWithObject(id p_object, SEL p_selector, id p_argument)
{
	MCFiberCallSelectorWithObject(s_main_fiber, p_object, p_selector, p_argument);
}

void MCIPhoneRunOnMainFiber(void (*p_callback)(void *), void *p_context)
{
	MCFiberCall(s_main_fiber, p_callback, p_context);
}

static void invoke_block(void *p_context)
{
	void (^t_block)(void) = (void (^)(void))p_context;
	t_block();
}

void MCIPhoneRunBlockOnMainFiber(void (^block)(void))
{
	MCFiberCall(s_main_fiber, invoke_block, block);
}

////////////////////////////////////////////////////////////////////////////////

// MW-2012-08-06: [[ Fibers ]] Updated entry point for didBecomeActive.
static void MCIPhoneDoDidBecomeActive(void *)
{ 
	extern char **environ;
	char **env;
	env = environ;
	
	// MW-2011-08-11: [[ Bug 9671 ]] Make sure we initialize MCstackbottom.
	int i;
	MCstackbottom = (char *)&i;
	
	NSAutoreleasePool *t_pool;
	t_pool = [[NSAutoreleasePool alloc] init];
	
	char *args[1];
	args[0] = (char *)[[[[NSProcessInfo processInfo] arguments] objectAtIndex: 0] cString];
	
	// Setup the value of the major OS version global.
	NSString *t_sys_version;
	t_sys_version = [[UIDevice currentDevice] systemVersion];
	MCmajorosversion = ([t_sys_version characterAtIndex: 0] - '0') * 100;
	MCmajorosversion += ([t_sys_version characterAtIndex: 2] - '0') * 10;
	if ([t_sys_version length] == 5)
		MCmajorosversion += [t_sys_version characterAtIndex: 4] - '0';
	
	// Initialize the engine.
	Bool t_init_success;
	t_init_success = X_init(1, args, env);
	
	[t_pool release];
	
	if (!t_init_success)
	{
		
		if (MCValueGetTypeCode(MCresult -> getvalueref()) == kMCValueTypeCodeString)
		{
			MCStringRef t_value;
			t_value = (MCStringRef) MCValueRetain(MCresult -> getvalueref());
			NSLog(@"Startup error: %s\n", MCStringGetCString(t_value));
			abort();
			return;
		}
	}

	// MW-2012-08-31: [[ Bug 10340 ]] Now we've finished initializing, get the app to
	//   start preparing.
	[MCIPhoneGetApplication() performSelectorOnMainThread:@selector(startPreparing) withObject:nil waitUntilDone:NO];
}

// MW-2012-08-06: [[ Fibers ]] Updated entry point that triggers before the main
//   runloop is entered.
static void MCIPhoneDoDidStartPreparing(void *)
{
	NSAutoreleasePool *t_pool;
	t_pool = [[NSAutoreleasePool alloc] init];
	send_startup_message(false);
	if (!MCquit)
		MCdispatcher ->  gethome() -> open();
	[t_pool release];
	
	// MW-2012-08-31: [[ Bug 10340 ]] Now we've finished preparing, get the app to
	//   start executing.
	[MCIPhoneGetApplication() performSelectorOnMainThread:@selector(startExecuting) withObject:nil waitUntilDone:NO];
}

// MW-2012-08-06: [[ Fibers ]] Updated entry point for execution of the main
//   run loop.
static void MCIPhoneDoDidStartExecuting(void *)
{
	// Now run the event loop
	for(;;)
	{
		NSAutoreleasePool *t_pool;
		t_pool = [[NSAutoreleasePool alloc] init];
		
		bool t_continue;
		t_continue = X_main_loop_iteration();
		
		[t_pool release];
		
		if (!t_continue)
			break;
	}
	
	// MW-2013-01-13: [[ Bug 10633 ]] Make sure the app exits on quit.
	// MW-2013-04-01: [[ Bug 10799 ]] Make sure we only exit if the quit was explicit.
	if (MCquitisexplicit)
		exit(0);
}

// MW-2012-08-06: [[ Fibers ]] Updated entry point for willTerminate.
static void MCIPhoneDoWillTerminate(void *)
{
	NSAutoreleasePool *t_pool;
	t_pool = [[NSAutoreleasePool alloc] init];
	
	// Ensure shutdown is called.
	if (MCdefaultstackptr != nil)
		MCdefaultstackptr->getcard()->message(MCM_shut_down, (MCParameter*)NULL, True, True);
	
	// Shutdown the engine
	X_close();
	
	[t_pool release];
	
}

// MW-2012-08-06: [[ Fibers ]] Updated entry point for when main view resizes.
static void MCIPhoneDoViewBoundsChanged(void *)
{
	if (MCscreen == nil)
		return;
	
	static_cast<MCScreenDC *>(MCscreen) -> do_fit_window(true, true);	
}

////////////////////////////////////////////////////////////////////////////////

// MW-2012-08-06: [[ Fibers ]] Main (system) fiber side handler for didBecomeActive.
void MCIPhoneHandleDidBecomeActive(void)
{
	// Convert the current thread to the main fiber (system owned).
	MCFiberConvert(s_main_fiber);

	// Create our auxillary script fiber.
	MCFiberCreate(256 * 1024, s_script_fiber);
	
	// Transfer control to the engine fiber.
	MCFiberCall(s_script_fiber, MCIPhoneDoDidBecomeActive, nil);
}

// MW-2012-08-06: [[ Fibers ]] Main (system) fiber side handler for didStartPreparing.
void MCIPhoneHandleDidStartPreparing(void)
{
	// Transfer control to the engine fiber.
	MCFiberCall(s_script_fiber, MCIPhoneDoDidStartPreparing, nil);
}

// MW-2012-08-06: [[ Fibers ]] Main (system) fiber side handler for didStartExecuting.
void MCIPhoneHandleDidStartExecuting(void)
{
	// Transfer control to the engine fiber.
	MCFiberCall(s_script_fiber, MCIPhoneDoDidStartExecuting, nil);
}

// MW-2012-08-06: [[ Fibers ]] Main (system) fiber side handler for willTerminate.
void MCIPhoneHandleWillTerminate(void)
{
	// Ensure we cause a complete exit.
	MCquit = True;
	MCexitall = True;
	
	// Switch to the script thread to allow the wait to exit.
	MCFiberMakeCurrent(s_script_fiber);
	
	// Now invoke will terminate.
	MCFiberCall(s_script_fiber, MCIPhoneDoWillTerminate, nil);
	
	// The app terminates after this routine exits. So make sure we
	// do the final clean up of the fibers.
	MCFiberDestroy(s_script_fiber);
	s_script_fiber = nil;
	MCFiberDestroy(s_main_fiber);
	s_main_fiber = nil;
}

// MW-2012-10-04: Main handler for when the app should suspend.
void MCIPhoneHandleSuspend(void)
{
}

// MW-2012-10-04: Main handler for when the app should resume.
void MCIPhoneHandleResume(void)
{
}

// MW-2012-08-06: [[ Fibers ]] Main (system) fiber side handler for didReceiveMemoryWarning.
void MCIPhoneHandleDidReceiveMemoryWarning(void)
{
	static_cast<MCScreenDC *>(MCscreen) -> compact_memory();
	MCCachedImageRep::FlushCache();
}

// MW-2012-08-06: [[ Fibers ]] Main (system) fiber side handler for viewBoundsChanged.
void MCIPhoneHandleViewBoundsChanged(void)
{
	MCFiberCall(s_script_fiber, MCIPhoneDoViewBoundsChanged, nil);
}

//////////

struct MCOrientationChangedEvent: public MCCustomEvent
{
	void Destroy(void)
	{
		delete this;
	}
	
	void Dispatch(void)
	{
		MCdefaultstackptr -> getcurcard() -> message(MCM_orientation_changed);
		// MW-2012-08-06: [[ Fibers ]] Invoke the subsequent action on the main fiber.
		/* REMOTE */ MCFiberCallSelector(s_main_fiber, MCIPhoneGetApplication(), @selector(commitOrientation));
	}
};

void MCIPhoneHandleOrientationChanged(void)
{
	MCEventQueuePostCustom(new MCOrientationChangedEvent);
}

//////////

static NSInteger compare_touch_timestamps(id a, id b, void *context)
{
	double ta, tb;
	ta = [a timestamp];
	tb = [b timestamp];
	return ta < tb ? NSOrderedAscending : (ta > tb ? NSOrderedDescending : NSOrderedSame);
}

void MCIPhoneHandleTouches(UIView *p_view, NSSet *p_touches, UITouchPhase p_phase)
{
	NSArray *t_sorted_touches;
	t_sorted_touches = [[p_touches allObjects] sortedArrayUsingFunction: compare_touch_timestamps context: nil];
	
	MCEventTouchPhase t_phase;
	if (p_phase == UITouchPhaseBegan)
		t_phase = kMCEventTouchPhaseBegan;
	else if (p_phase == UITouchPhaseEnded)
		t_phase = kMCEventTouchPhaseEnded;
	else if (p_phase == UITouchPhaseMoved)
		t_phase = kMCEventTouchPhaseMoved;
	else if (p_phase == UITouchPhaseCancelled)
		t_phase = kMCEventTouchPhaseCancelled;
	else
		return;
	
	for(UITouch *t_touch in t_sorted_touches)
	{
		CGPoint t_location;
		t_location = [ t_touch locationInView: p_view ];
		static_cast<MCScreenDC *>(MCscreen) -> handle_touch(t_phase, t_touch, [t_touch timestamp] * 1000, t_location . x * s_iphone_res_scale, t_location . y * s_iphone_res_scale);
	}
}

//////////

class MCTextEditFinishedEvent: public MCCustomEvent
{
public:
	void Destroy(void)
	{
		delete this;
	}
	
	void Dispatch(void)
	{
		static_cast<MCScreenDC *>(MCscreen) -> unfocus_current_window();
	}
};

void MCIPhoneHandleBeginTextInput(void)
{
}

void MCIPhoneHandleEndTextInput(void)
{
	MCEventQueuePostCustom(new MCTextEditFinishedEvent);
}

void MCIPhoneHandleProcessTextInput(uint32_t p_char_code, uint32_t p_key_code)
{
	if (MCactivefield == nil)
		return;

	static_cast<MCScreenDC *>(MCscreen) -> handle_key_press(0, p_char_code, p_key_code);
}

/////////

void MCIPhoneHandleMotionBegan(UIEventSubtype motion, NSTimeInterval timestamp)
{
	if (motion == UIEventSubtypeMotionShake)
		static_cast<MCScreenDC *>(MCscreen) -> handle_motion(kMCEventMotionShakeBegan, timestamp * 1000);
}

void MCIPhoneHandleMotionCancelled(UIEventSubtype motion, NSTimeInterval timestamp)
{
	if (motion == UIEventSubtypeMotionShake)
		static_cast<MCScreenDC *>(MCscreen) -> handle_motion(kMCEventMotionShakeCancelled, timestamp * 1000);
}

void MCIPhoneHandleMotionEnded(UIEventSubtype motion, NSTimeInterval timestamp)
{
	if (motion == UIEventSubtypeMotionShake)
		static_cast<MCScreenDC *>(MCscreen) -> handle_motion(kMCEventMotionShakeEnded, timestamp * 1000);
}

/////////

struct MCKeyboardActivatedEvent: public MCCustomEvent
{
	MCKeyboardActivatedEvent(float p_height)
	{
		m_height = p_height;
	}

	void Destroy(void)
	{
		delete this;
	}
	
	void Dispatch(void)
	{
		s_current_keyboard_height = m_height;
		MCdefaultstackptr -> getcurcard() -> message(MCM_keyboard_activated);
	}
	
private:
	float m_height;
};

struct MCKeyboardDeactivatedEvent: public MCCustomEvent
{
	void Destroy(void)
	{
		delete this;
	}
	
	void Dispatch(void)
	{
		s_current_keyboard_height = 0.0;
		MCdefaultstackptr -> getcurcard() -> message(MCM_keyboard_deactivated);
	}
};

void MCIPhoneHandleKeyboardWillActivate(float p_height)
{
	MCEventQueuePostCustom(new MCKeyboardActivatedEvent(p_height));
}

void MCIPhoneHandleKeyboardWillDeactivate(void)
{
	MCEventQueuePostCustom(new MCKeyboardDeactivatedEvent);
}

////////////////////////////////////////////////////////////////////////////////

void MCIPhoneHandlePerformRedraw(void)
{
	MCRedrawEnableScreenUpdates();
	MCRedrawUpdateScreen();
	MCRedrawDisableScreenUpdates();
}

////////////////////////////////////////////////////////////////////////////////

@interface com_runrev_livecode_MCIPhoneBreakWaitHelper : NSObject

- (void)breakWait;

@end

@implementation com_runrev_livecode_MCIPhoneBreakWaitHelper

- (void)breakWait
{
	// When the wait is broken, just jump to the script fiber.
	MCFiberMakeCurrent(s_script_fiber);
}

@end

static void MCIPhoneDoBreakWait(void *)
{
	[NSObject cancelPreviousPerformRequestsWithTarget: s_break_wait_helper];
	
	s_break_wait_pending = true;
	
	if (s_wait_depth > 0)
	{
		NSArray *t_modes;
		t_modes = [[NSArray alloc] initWithObject: NSRunLoopCommonModes];
		[s_break_wait_helper performSelector: @selector(breakWait) withObject: nil afterDelay: 0 inModes: t_modes];
		[t_modes release];
}
}

void MCIPhoneBreakWait(void)
{
	if (s_break_wait_pending)
		return;
	
	if (s_break_wait_helper == nil)
		s_break_wait_helper = [[com_runrev_livecode_MCIPhoneBreakWaitHelper alloc] init];
	
	MCFiberCall(s_main_fiber, MCIPhoneDoBreakWait, nil);
}

static void MCIPhoneDoScheduleWait(void *p_ctxt)
{
	double t_sleep;
	t_sleep = *(double *)p_ctxt;
	[s_break_wait_helper performSelector: @selector(breakWait) withObject: nil afterDelay: t_sleep inModes: [NSArray arrayWithObject: NSRunLoopCommonModes]];
}
	
static void MCIPhoneDoCancelWait(void *p_ctxt)
	{
	[NSObject cancelPreviousPerformRequestsWithTarget: s_break_wait_helper selector: @selector(breakWait) object: nil];
	}

static bool MCIPhoneWait(double p_sleep)
	{
	if (s_break_wait_pending)
		{
		MCFiberCall(s_main_fiber, MCIPhoneDoCancelWait, nil);
		s_break_wait_pending = false;
		return true;
		}
    
	if (s_break_wait_helper == nil)
		s_break_wait_helper = [[com_runrev_livecode_MCIPhoneBreakWaitHelper alloc] init];
	
	// Schedule the wait on the main fiber.
	MCFiberCall(s_main_fiber, MCIPhoneDoScheduleWait, &p_sleep);
	
	// Mark ourselves as waiting.
	s_wait_depth += 1;
	
	// Now switch back to the main fiber.
	MCFiberMakeCurrent(s_main_fiber);

	// Unmark ourselves as waiting.
	s_wait_depth -= 1;

	bool t_broken;
	t_broken = s_break_wait_pending;
	s_break_wait_pending = false;

	return t_broken;
	}
	
////////////////////////////////////////////////////////////////////////////////
