//window.m
#import <Cocoa/Cocoa.h>

// Global array to store window references
NSMutableArray *windows;

void initializeApplication() {
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    windows = [NSMutableArray array]; // Initialize the windows array
}

NSWindow* createWindow(float width, float height,  const char *cTitle) {
    NSRect frame = NSMakeRect(0, 0, width, height);
    NSUInteger style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable;
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                  styleMask:style
                                                    backing:NSBackingStoreBuffered
                                                      defer:NO];
    NSString *objcTitle = [NSString stringWithUTF8String:cTitle];
    [window setTitle:objcTitle]; // Use the NSString directly
    [window makeKeyAndOrderFront:nil];
    [windows addObject:window]; // Add the window to the array
    return window;
}

@interface ContentView : NSView
@end

@implementation ContentView {
    NSBitmapImageRep* bitmap;
}

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        int width = frame.size.width;
        int height = frame.size.height;

        // Create a bitmap representation with RGBA channels
        bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                         pixelsWide:width
                                                         pixelsHigh:height
                                                      bitsPerSample:8
                                                    samplesPerPixel:4
                                                           hasAlpha:YES
                                                           isPlanar:NO
                                                     colorSpaceName:NSDeviceRGBColorSpace
                                                        bytesPerRow:width * 4
                                                       bitsPerPixel:32];

        // Initialize with white pixels (RGBA = 255,255,255,255)
        memset([bitmap bitmapData], 255, width * height * 4);
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    NSGraphicsContext* context = [NSGraphicsContext currentContext];
    [context saveGraphicsState];

    // Get the current size of the content view
    NSRect bounds = self.bounds;
    CGFloat width = bounds.size.width;
    CGFloat height = bounds.size.height;

    // Draw the bitmap with the same size as the content view
    NSRect imageRect = NSMakeRect(0, 0, width, height);
    [bitmap drawInRect:imageRect];

    [context restoreGraphicsState];
}

// Modify the method to accept RGBA color values
- (void)setPixelAtX:(int)x Y:(int)y red:(int)red green:(int)green blue:(int)blue alpha:(int)alpha {
    int width = self.bounds.size.width;
    int height = self.bounds.size.height;

    if (x < 0 || x >= width || y < 0 || y >= height) {
        NSLog(@"[WARNINGC] Pixel coordinates out of bounds: (%d, %d)", x, y);
        return; // Bounds check
    }

    unsigned char* data = [bitmap bitmapData];
    int flippedY = height - y - 1;  // Flipping y-axis for macOS
    int index = (flippedY * width + x) * 4;

    // Set the pixel's color using the passed RGBA values
    data[index] = red;
    data[index + 1] = green;
    data[index + 2] = blue;
    data[index + 3] = alpha;

    //NSLog(@"[INFO] Pixel drawn at (%d, %d) with color (%d, %d, %d, %d)", x, y, red, green, blue, alpha);

    // Trigger a redraw
    [self setNeedsDisplay:YES];
}

- (void)updateView {
    [self setNeedsDisplay:YES];
}

@end

void setupContentView(NSWindow *window) {
    NSRect frame = [window contentRectForFrameRect:[window frame]];
    ContentView *contentView = [[ContentView alloc] initWithFrame:frame];
    [window setContentView:contentView];
    //NSLog(@"[INFO] ContentView created and set as window's content view");
}

@interface WindowDelegate : NSObject <NSWindowDelegate>
@end

@implementation WindowDelegate
- (void)windowWillClose:(NSNotification *)notification {
    NSWindow *window = notification.object;
    [windows removeObject:window]; // Remove the window from the array
}
@end

void setWindowDelegate(NSWindow *window) {
    WindowDelegate *windowDelegate = [[WindowDelegate alloc] init];
    [window setDelegate:windowDelegate];
}

void setupWindow(NSWindow *window) {
    setupContentView(window);
    setWindowDelegate(window);
}

void activateApplication() {
    [NSApp activateIgnoringOtherApps:YES];
}

ContentView* GetContentView(NSWindow *window) {
    if (!window) {
        NSLog(@"[ERROR] Window is NULL");
        return NULL;
    }

    ContentView* view = (ContentView*)window.contentView;
    if (!view) {
        NSLog(@"[ERROR] ContentView is NULL");
        return NULL;
    }

    return view;
}

void DrawPixelC(NSWindow *window, int x, int y, float r, float g, float b, float a) {
    ContentView* view = GetContentView(window);
    if (view) {
        int red = (int)(r);
        int green = (int)(g);
        int blue = (int)(b);
        int alpha = (int)(a);
        [view setPixelAtX:x Y:y red:red green:green blue:blue alpha:alpha];
        //NSLog(@"[INFO] Pixel drawn at (%d, %d) with color (%d, %d, %d, %d)", x, y, red, green, blue, alpha);
    }
}

void pollEvents() {
    @autoreleasepool {
        NSEvent *event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                            untilDate:[NSDate distantPast]
                                               inMode:NSDefaultRunLoopMode
                                              dequeue:YES];
        if (event) {
            [NSApp sendEvent:event];
        }
        [NSApp updateWindows];
    }
}
