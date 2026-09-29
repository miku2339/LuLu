// SPDX-License-Identifier: GPL-3.0-only
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSColor* PreviewCanvasColor(void);
FOUNDATION_EXPORT NSColor* PreviewSurfaceColor(void);

FOUNDATION_EXPORT NSView* PreviewSurface(NSView* content, CGFloat padding);
FOUNDATION_EXPORT NSView* PreviewGlass(NSView* content, CGFloat padding, CGFloat cornerRadius);
FOUNDATION_EXPORT NSView* PreviewSymbol(NSString* symbol, CGFloat size, NSColor* tint);
FOUNDATION_EXPORT NSView* PreviewBadge(NSString* text, NSColor* tint);
FOUNDATION_EXPORT NSView* PreviewDivider(void);
FOUNDATION_EXPORT NSButton* PreviewNavigationButton(NSString* title, NSString* symbol, id target, SEL action);

NS_ASSUME_NONNULL_END
