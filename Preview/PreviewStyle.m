// SPDX-License-Identifier: GPL-3.0-only
#import "PreviewStyle.h"
#import <QuartzCore/QuartzCore.h>

static void PreviewDrawWithAppearance(NSView* view, void (^drawing)(void))
{
    [view.effectiveAppearance performAsCurrentDrawingAppearance:drawing];
}

NSColor* PreviewCanvasColor(void)
{
    return NSColor.windowBackgroundColor;
}

NSColor* PreviewSurfaceColor(void)
{
    return NSColor.controlBackgroundColor;
}

static void PreviewPinContent(NSView* content, NSView* container, CGFloat padding)
{
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:padding],
        [content.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-padding],
        [content.topAnchor constraintEqualToAnchor:container.topAnchor constant:padding],
        [content.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-padding]
    ]];
}

@interface PreviewSurfaceView : NSView
@end

@implementation PreviewSurfaceView

-(BOOL)isOpaque
{
    return NO;
}

-(void)drawRect:(NSRect)dirtyRect
{
    PreviewDrawWithAppearance(self, ^{
        NSRect bounds = NSInsetRect(self.bounds, 0.5, 0.5);
        NSBezierPath* shape = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:10 yRadius:10];
        [NSGraphicsContext saveGraphicsState];
        [shape addClip];
        [PreviewSurfaceColor() setFill];
        NSRectFill(self.bounds);
        [NSGraphicsContext restoreGraphicsState];

        [NSColor.separatorColor setStroke];
        shape.lineWidth = NSWorkspace.sharedWorkspace.accessibilityDisplayShouldIncreaseContrast ? 1.0 : 0.5;
        [shape stroke];
    });
}

-(void)viewDidChangeEffectiveAppearance
{
    [super viewDidChangeEffectiveAppearance];
    self.needsDisplay = YES;
}

@end

NSView* PreviewSurface(NSView* content, CGFloat padding)
{
    PreviewSurfaceView* surface = [[PreviewSurfaceView alloc] init];
    surface.translatesAutoresizingMaskIntoConstraints = NO;
    PreviewPinContent(content, surface, padding);
    return surface;
}

NSView* PreviewGlass(NSView* content, CGFloat padding, CGFloat cornerRadius)
{
    if(NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceTransparency)
        return PreviewSurface(content, padding);

    NSView* contentHost = [[NSView alloc] init];
    contentHost.translatesAutoresizingMaskIntoConstraints = NO;
    PreviewPinContent(content, contentHost, padding);

    NSView* result = nil;
    if(@available(macOS 26.0, *))
    {
        NSGlassEffectView* glass = [[NSGlassEffectView alloc] init];
        glass.style = NSGlassEffectViewStyleRegular;
        glass.cornerRadius = cornerRadius;
        glass.contentView = contentHost;
        result = glass;
    }
    else
    {
        NSVisualEffectView* material = [[NSVisualEffectView alloc] init];
        material.material = NSVisualEffectMaterialPopover;
        material.blendingMode = NSVisualEffectBlendingModeWithinWindow;
        material.state = NSVisualEffectStateFollowsWindowActiveState;
        material.wantsLayer = YES;
        material.layer.cornerRadius = cornerRadius;
        material.layer.masksToBounds = YES;
        [material addSubview:contentHost];
        [NSLayoutConstraint activateConstraints:@[
            [contentHost.leadingAnchor constraintEqualToAnchor:material.leadingAnchor],
            [contentHost.trailingAnchor constraintEqualToAnchor:material.trailingAnchor],
            [contentHost.topAnchor constraintEqualToAnchor:material.topAnchor],
            [contentHost.bottomAnchor constraintEqualToAnchor:material.bottomAnchor]
        ]];
        result = material;
    }
    result.translatesAutoresizingMaskIntoConstraints = NO;
    return result;
}

NSView* PreviewSymbol(NSString* symbol, CGFloat size, NSColor* tint)
{
    CGFloat tileSize = MAX(36.0, size);
    CGFloat symbolSize = MIN(24.0, MAX(14.0, tileSize * 0.5));
    NSImageView* image = [[NSImageView alloc] init];
    image.image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil];
    image.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:symbolSize weight:NSFontWeightMedium];
    image.contentTintColor = tint;
    image.imageScaling = NSImageScaleProportionallyDown;
    image.translatesAutoresizingMaskIntoConstraints = NO;
    image.accessibilityElement = NO;
    [NSLayoutConstraint activateConstraints:@[
        [image.widthAnchor constraintEqualToConstant:tileSize],
        [image.heightAnchor constraintEqualToConstant:tileSize]
    ]];
    return image;
}

@interface PreviewStatusDotView : NSView
@property(nonatomic, strong) NSColor* tint;
@end

@implementation PreviewStatusDotView

-(void)drawRect:(NSRect)dirtyRect
{
    PreviewDrawWithAppearance(self, ^{
        [self.tint setFill];
        [[NSBezierPath bezierPathWithOvalInRect:self.bounds] fill];
    });
}

-(void)viewDidChangeEffectiveAppearance
{
    [super viewDidChangeEffectiveAppearance];
    self.needsDisplay = YES;
}

@end

NSView* PreviewBadge(NSString* text, NSColor* tint)
{
    PreviewStatusDotView* dot = [[PreviewStatusDotView alloc] init];
    dot.translatesAutoresizingMaskIntoConstraints = NO;
    dot.tint = tint;
    dot.accessibilityElement = NO;
    [NSLayoutConstraint activateConstraints:@[
        [dot.widthAnchor constraintEqualToConstant:5.0],
        [dot.heightAnchor constraintEqualToConstant:5.0]
    ]];

    NSTextField* label = [NSTextField labelWithString:text];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
    label.textColor = NSColor.secondaryLabelColor;
    label.accessibilityLabel = text;

    NSStackView* badge = [NSStackView stackViewWithViews:@[dot, label]];
    badge.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    badge.alignment = NSLayoutAttributeCenterY;
    badge.spacing = 6.0;
    badge.translatesAutoresizingMaskIntoConstraints = NO;
    badge.accessibilityElement = NO;
    [badge setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    [badge setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    return badge;
}

@interface PreviewDividerView : NSView
@end

@implementation PreviewDividerView

-(void)drawRect:(NSRect)dirtyRect
{
    PreviewDrawWithAppearance(self, ^{
        [NSColor.separatorColor setFill];
        NSRectFill(self.bounds);
    });
}

-(void)viewDidChangeEffectiveAppearance
{
    [super viewDidChangeEffectiveAppearance];
    self.needsDisplay = YES;
}

@end


NSView* PreviewDivider(void)
{
    PreviewDividerView* divider = [[PreviewDividerView alloc] init];
    divider.translatesAutoresizingMaskIntoConstraints = NO;
    divider.accessibilityElement = NO;
    [divider.heightAnchor constraintEqualToConstant:1.0].active = YES;
    [divider setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    [divider setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    return divider;
}

@interface PreviewNavigationButtonCell : NSButtonCell
@end

@implementation PreviewNavigationButtonCell
-(void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView*)controlView
{
    [super drawInteriorWithFrame:NSInsetRect(cellFrame, 12, 0) inView:controlView];
}
@end

@interface PreviewNavigationButtonControl : NSButton
@end

@implementation PreviewNavigationButtonControl

+(Class)cellClass { return PreviewNavigationButtonCell.class; }

-(void)setState:(NSControlStateValue)state
{
    [super setState:state];
    self.contentTintColor = state == NSControlStateValueOn ? NSColor.labelColor : NSColor.secondaryLabelColor;
    self.needsDisplay = YES;
}

-(void)setEnabled:(BOOL)enabled
{
    [super setEnabled:enabled];
    self.needsDisplay = YES;
}

-(void)drawRect:(NSRect)dirtyRect
{
    PreviewDrawWithAppearance(self, ^{
        if(self.state == NSControlStateValueOn)
        {
            NSBezierPath* selection = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds, 1.0, 1.0)
                xRadius:9 yRadius:9];
            [[NSColor.selectedContentBackgroundColor colorWithAlphaComponent:0.20] setFill];
            [selection fill];
        }

        [super drawRect:dirtyRect];

        if(self.window.firstResponder == self)
        {
            [NSGraphicsContext saveGraphicsState];
            NSSetFocusRingStyle(NSFocusRingOnly);
            NSBezierPath* focus = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds, 2.0, 2.0)
                xRadius:8 yRadius:8];
            [focus fill];
            [NSGraphicsContext restoreGraphicsState];
        }
    });
}

-(void)viewDidChangeEffectiveAppearance
{
    [super viewDidChangeEffectiveAppearance];
    self.contentTintColor = self.state == NSControlStateValueOn ? NSColor.labelColor : NSColor.secondaryLabelColor;
    self.needsDisplay = YES;
}

@end

NSButton* PreviewNavigationButton(NSString* title, NSString* symbol, id target, SEL action)
{
    PreviewNavigationButtonControl* button = [PreviewNavigationButtonControl buttonWithTitle:title target:target action:action];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.buttonType = NSButtonTypePushOnPushOff;
    button.bordered = NO;
    button.bezelStyle = NSBezelStyleRegularSquare;
    button.focusRingType = NSFocusRingTypeExterior;
    button.alignment = NSTextAlignmentLeft;
    button.font = [NSFont systemFontOfSize:13.5 weight:NSFontWeightMedium];
    NSImage* image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil];
    button.image = [image imageWithSymbolConfiguration:
        [NSImageSymbolConfiguration configurationWithPointSize:15 weight:NSFontWeightMedium]];
    button.imagePosition = NSImageLeading;
    button.imageHugsTitle = YES;
    button.contentTintColor = NSColor.secondaryLabelColor;
    button.accessibilityLabel = title;
    [button.heightAnchor constraintEqualToConstant:40.0].active = YES;
    return button;
}
