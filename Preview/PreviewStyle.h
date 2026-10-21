// SPDX-License-Identifier: GPL-3.0-only
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSColor* PreviewCanvasColor(void);
FOUNDATION_EXPORT NSColor* PreviewSurfaceColor(void);

// Opaque, hairline-bordered content surface (lists, grouped forms).
FOUNDATION_EXPORT NSView* PreviewSurface(NSView* content, CGFloat padding);
FOUNDATION_EXPORT NSView* PreviewSurfaceWithRadius(NSView* content, CGFloat padding, CGFloat cornerRadius);
// Recessed fill used for read-only detail blocks inside a surface or sheet.
FOUNDATION_EXPORT NSView* PreviewWell(NSView* content, CGFloat padding);
// Frosted system material. The system makes it opaque when Reduce Transparency is on.
FOUNDATION_EXPORT NSVisualEffectView* PreviewMaterial(NSVisualEffectMaterial material, NSVisualEffectBlendingMode blending);
// Container that clips its children to rounded corners and draws a hairline border above them.
FOUNDATION_EXPORT NSView* PreviewPanel(NSView* content, CGFloat cornerRadius);
// Rounded, hairline-bordered card on a frosted material, for grouped content on the frosted page background.
FOUNDATION_EXPORT NSView* PreviewFrostedSurface(NSView* content, CGFloat padding);
// Liquid Glass on macOS 26, a material on older systems, opaque with Reduce Transparency.
FOUNDATION_EXPORT NSView* PreviewGlass(NSView* content, CGFloat padding, CGFloat cornerRadius);
// Rounded tile with an SF Symbol, used where no real app icon exists.
FOUNDATION_EXPORT NSView* PreviewSymbol(NSString* symbol, CGFloat size, NSColor* tint);
FOUNDATION_EXPORT NSView* PreviewBadge(NSString* text, NSColor* tint);
FOUNDATION_EXPORT NSView* PreviewDivider(void);
FOUNDATION_EXPORT NSView* PreviewVerticalDivider(void);
FOUNDATION_EXPORT NSButton* PreviewNavigationButton(NSString* title, NSString* symbol, NSString* shortcut, id target, SEL action);

NS_ASSUME_NONNULL_END
