// SPDX-License-Identifier: GPL-3.0-only
#import "PreviewStyle.h"
#import <QuartzCore/QuartzCore.h>

static void PreviewDrawWithAppearance(NSView* view, void (^drawing)(void))
{
    [view.effectiveAppearance performAsCurrentDrawingAppearance:drawing];
}

static BOOL PreviewIncreaseContrast(void)
{
    return NSWorkspace.sharedWorkspace.accessibilityDisplayShouldIncreaseContrast;
}

static CGFloat PreviewHairline(NSView* view)
{
    CGFloat scale = view.window.backingScaleFactor ?: NSScreen.mainScreen.backingScaleFactor ?: 2.0;
    return PreviewIncreaseContrast() ? 1.0 : 1.0 / scale;
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
        [content.leftAnchor constraintEqualToAnchor:container.leftAnchor constant:padding],
        [content.rightAnchor constraintEqualToAnchor:container.rightAnchor constant:-padding],
        [content.topAnchor constraintEqualToAnchor:container.topAnchor constant:padding],
        [content.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-padding]
    ]];
}

#pragma mark - Surfaces

@interface PreviewSurfaceView : NSView
@property(nonatomic) CGFloat radius;
@property(nonatomic) BOOL recessed;
@end

@implementation PreviewSurfaceView

-(BOOL)isOpaque
{
    return NO;
}

-(void)drawRect:(NSRect)dirtyRect
{
    PreviewDrawWithAppearance(self, ^{
        CGFloat line = PreviewHairline(self);
        NSRect bounds = NSInsetRect(self.bounds, line / 2.0, line / 2.0);
        NSBezierPath* shape = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:self.radius yRadius:self.radius];
        if(self.recessed)
        {
            [[NSColor.labelColor colorWithAlphaComponent:0.045] setFill];
            [shape fill];
            if(PreviewIncreaseContrast())
            {
                [NSColor.separatorColor setStroke];
                shape.lineWidth = line;
                [shape stroke];
            }
            return;
        }
        [PreviewSurfaceColor() setFill];
        [shape fill];
        [NSColor.separatorColor setStroke];
        shape.lineWidth = line;
        [shape stroke];
    });
}

-(void)viewDidChangeEffectiveAppearance
{
    [super viewDidChangeEffectiveAppearance];
    self.needsDisplay = YES;
}

-(void)viewDidChangeBackingProperties
{
    [super viewDidChangeBackingProperties];
    self.needsDisplay = YES;
}

@end

NSView* PreviewSurfaceWithRadius(NSView* content, CGFloat padding, CGFloat cornerRadius)
{
    PreviewSurfaceView* surface = [[PreviewSurfaceView alloc] init];
    surface.translatesAutoresizingMaskIntoConstraints = NO;
    surface.radius = cornerRadius;
    PreviewPinContent(content, surface, padding);
    return surface;
}

NSView* PreviewSurface(NSView* content, CGFloat padding)
{
    return PreviewSurfaceWithRadius(content, padding, 12);
}

NSView* PreviewWell(NSView* content, CGFloat padding)
{
    PreviewSurfaceView* well = [[PreviewSurfaceView alloc] init];
    well.translatesAutoresizingMaskIntoConstraints = NO;
    well.radius = 10;
    well.recessed = YES;
    PreviewPinContent(content, well, padding);
    return well;
}

NSView* PreviewGlass(NSView* content, CGFloat padding, CGFloat cornerRadius)
{
    if(NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceTransparency)
        return PreviewSurfaceWithRadius(content, padding, cornerRadius);

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
        material.material = NSVisualEffectMaterialSidebar;
        material.blendingMode = NSVisualEffectBlendingModeWithinWindow;
        material.state = NSVisualEffectStateFollowsWindowActiveState;
        material.wantsLayer = YES;
        material.layer.cornerRadius = cornerRadius;
        material.layer.masksToBounds = YES;
        [material addSubview:contentHost];
        [NSLayoutConstraint activateConstraints:@[
            [contentHost.leftAnchor constraintEqualToAnchor:material.leftAnchor],
            [contentHost.rightAnchor constraintEqualToAnchor:material.rightAnchor],
            [contentHost.topAnchor constraintEqualToAnchor:material.topAnchor],
            [contentHost.bottomAnchor constraintEqualToAnchor:material.bottomAnchor]
        ]];
        result = material;
    }
    result.translatesAutoresizingMaskIntoConstraints = NO;
    return result;
}

NSVisualEffectView* PreviewMaterial(NSVisualEffectMaterial material, NSVisualEffectBlendingMode blending)
{
    NSVisualEffectView* view = [[NSVisualEffectView alloc] init];
    view.material = material;
    view.blendingMode = blending;
    view.state = NSVisualEffectStateFollowsWindowActiveState;
    view.translatesAutoresizingMaskIntoConstraints = NO;
    return view;
}

@interface PreviewPanelView : NSView
@property(nonatomic) CGFloat radius;
@end

@implementation PreviewPanelView

-(instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if(self) self.wantsLayer = YES;
    return self;
}

-(BOOL)wantsUpdateLayer
{
    return YES;
}

-(void)updateLayer
{
    self.layer.cornerRadius = self.radius;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.layer.masksToBounds = YES;
    self.layer.borderWidth = PreviewHairline(self);
    [self.effectiveAppearance performAsCurrentDrawingAppearance:^{
        self.layer.borderColor = NSColor.separatorColor.CGColor;
    }];
}

-(void)viewDidChangeEffectiveAppearance
{
    [super viewDidChangeEffectiveAppearance];
    self.needsDisplay = YES;
}

-(void)viewDidChangeBackingProperties
{
    [super viewDidChangeBackingProperties];
    self.needsDisplay = YES;
}

@end

NSView* PreviewPanel(NSView* content, CGFloat cornerRadius)
{
    PreviewPanelView* panel = [[PreviewPanelView alloc] init];
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    panel.radius = cornerRadius;
    PreviewPinContent(content, panel, 0);
    return panel;
}

NSView* PreviewFrostedSurface(NSView* content, CGFloat padding)
{
    NSVisualEffectView* material = PreviewMaterial(NSVisualEffectMaterialPopover, NSVisualEffectBlendingModeWithinWindow);
    PreviewPinContent(content, material, padding);
    return PreviewPanel(material, 12);
}

#pragma mark - Symbol tile

NSView* PreviewSymbol(NSString* symbol, CGFloat size, NSColor* tint)
{
    PreviewSurfaceView* tile = [[PreviewSurfaceView alloc] init];
    tile.translatesAutoresizingMaskIntoConstraints = NO;
    tile.recessed = YES;
    tile.radius = round(size * 0.24);
    tile.accessibilityElement = NO;

    NSImageView* image = [[NSImageView alloc] init];
    image.image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil];
    image.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:round(size * 0.46) weight:NSFontWeightRegular];
    image.contentTintColor = tint;
    image.imageScaling = NSImageScaleProportionallyDown;
    image.translatesAutoresizingMaskIntoConstraints = NO;
    image.accessibilityElement = NO;
    [tile addSubview:image];
    [NSLayoutConstraint activateConstraints:@[
        [tile.widthAnchor constraintEqualToConstant:size],
        [tile.heightAnchor constraintEqualToConstant:size],
        [image.centerXAnchor constraintEqualToAnchor:tile.centerXAnchor],
        [image.centerYAnchor constraintEqualToAnchor:tile.centerYAnchor]
    ]];
    return tile;
}

#pragma mark - Badge

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
        [dot.widthAnchor constraintEqualToConstant:7.0],
        [dot.heightAnchor constraintEqualToConstant:7.0]
    ]];

    NSTextField* label = [NSTextField wrappingLabelWithString:text];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    label.textColor = NSColor.secondaryLabelColor;
    label.accessibilityLabel = text;
    [label setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

    NSStackView* badge = [NSStackView stackViewWithViews:@[dot, label]];
    badge.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    badge.alignment = NSLayoutAttributeCenterY;
    badge.spacing = 7.0;
    badge.translatesAutoresizingMaskIntoConstraints = NO;
    return badge;
}

#pragma mark - Dividers

@interface PreviewDividerView : NSView
@property(nonatomic) BOOL vertical;
@end

@implementation PreviewDividerView

-(void)drawRect:(NSRect)dirtyRect
{
    PreviewDrawWithAppearance(self, ^{
        CGFloat line = PreviewHairline(self);
        NSRect rect = self.bounds;
        if(self.vertical) rect.size.width = line;
        else rect.size.height = line;
        [NSColor.separatorColor setFill];
        NSRectFillUsingOperation(rect, NSCompositingOperationSourceOver);
    });
}

-(void)viewDidChangeEffectiveAppearance
{
    [super viewDidChangeEffectiveAppearance];
    self.needsDisplay = YES;
}

-(void)viewDidChangeBackingProperties
{
    [super viewDidChangeBackingProperties];
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

NSView* PreviewVerticalDivider(void)
{
    PreviewDividerView* divider = [[PreviewDividerView alloc] init];
    divider.vertical = YES;
    divider.translatesAutoresizingMaskIntoConstraints = NO;
    divider.accessibilityElement = NO;
    [divider.widthAnchor constraintEqualToConstant:1.0].active = YES;
    return divider;
}

#pragma mark - Sidebar navigation

@interface PreviewNavigationButtonControl : NSButton
@property(nonatomic, strong) NSImageView* iconView;
@property(nonatomic, strong) NSTextField* titleField;
@property(nonatomic, strong) NSTrackingArea* hoverArea;
@property(nonatomic) BOOL hovering;
@end

@implementation PreviewNavigationButtonControl

-(NSView*)hitTest:(NSPoint)point
{
    return [super hitTest:point] ? self : nil;
}

-(void)updateAppearance
{
    BOOL selected = self.state == NSControlStateValueOn;
    self.iconView.contentTintColor = NSColor.controlAccentColor;
    self.titleField.textColor = NSColor.labelColor;
    self.titleField.font = [NSFont systemFontOfSize:13 weight:selected ? NSFontWeightSemibold : NSFontWeightRegular];
    self.needsDisplay = YES;
}

-(void)setState:(NSControlStateValue)state
{
    [super setState:state];
    [self updateAppearance];
}

-(void)updateTrackingAreas
{
    [super updateTrackingAreas];
    if(self.hoverArea) [self removeTrackingArea:self.hoverArea];
    self.hoverArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect
        options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect owner:self userInfo:nil];
    [self addTrackingArea:self.hoverArea];
}

-(void)mouseEntered:(NSEvent*)event { self.hovering = YES; self.needsDisplay = YES; }
-(void)mouseExited:(NSEvent*)event { self.hovering = NO; self.needsDisplay = YES; }

-(void)drawRect:(NSRect)dirtyRect
{
    BOOL selected = self.state == NSControlStateValueOn;
    if(!selected && !self.hovering) return;
    PreviewDrawWithAppearance(self, ^{
        NSBezierPath* shape = [NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:8 yRadius:8];
        NSColor* fill = selected ? [NSColor.controlAccentColor colorWithAlphaComponent:PreviewIncreaseContrast() ? 0.28 : 0.16]
            : [NSColor.labelColor colorWithAlphaComponent:0.05];
        [fill setFill];
        [shape fill];
    });
}

-(void)drawFocusRingMask
{
    [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:8 yRadius:8] fill];
}

-(NSRect)focusRingMaskBounds
{
    return self.bounds;
}

-(void)viewDidChangeEffectiveAppearance
{
    [super viewDidChangeEffectiveAppearance];
    [self updateAppearance];
}

@end

NSButton* PreviewNavigationButton(NSString* title, NSString* symbol, NSString* shortcut, id target, SEL action)
{
    PreviewNavigationButtonControl* button = [[PreviewNavigationButtonControl alloc] init];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.buttonType = NSButtonTypePushOnPushOff;
    button.bordered = NO;
    button.title = @"";
    button.imagePosition = NSNoImage;
    button.focusRingType = NSFocusRingTypeExterior;
    button.target = target;
    button.action = action;
    button.accessibilityLabel = title;
    [button.cell setAccessibilityLabel:title];
    [button.cell setAccessibilityRole:NSAccessibilityButtonRole];

    NSImageView* icon = [[NSImageView alloc] init];
    icon.image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil];
    icon.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:14 weight:NSFontWeightMedium];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.accessibilityElement = NO;
    [icon.widthAnchor constraintEqualToConstant:20].active = YES;
    [icon setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];

    NSTextField* label = [NSTextField labelWithString:title];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.accessibilityElement = NO;
    [label setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
    [label setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

    NSTextField* key = [NSTextField labelWithString:shortcut];
    key.translatesAutoresizingMaskIntoConstraints = NO;
    key.font = [NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightRegular];
    key.textColor = NSColor.tertiaryLabelColor;
    key.identifier = @"technical";
    key.accessibilityElement = NO;
    [key setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    [key setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];

    NSStackView* row = [NSStackView stackViewWithViews:@[icon, label, key]];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeCenterY;
    row.spacing = 8;
    row.edgeInsets = NSEdgeInsetsMake(0, 9, 0, 10);
    PreviewPinContent(row, button, 0);

    button.iconView = icon;
    button.titleField = label;
    [button updateAppearance];
    [button.heightAnchor constraintEqualToConstant:30.0].active = YES;
    return button;
}
