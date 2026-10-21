// SPDX-License-Identifier: GPL-3.0-only
#import "PreviewController.h"
#import "PreviewModel.h"
#import "PreviewStyle.h"

static const CGFloat PreviewSidebarInset = 8;
static const CGFloat PreviewPageMargin = 28;
static const CGFloat PreviewPageTop = 40;
static const CGFloat PreviewInspectorWidth = 272;
static const CGFloat PreviewReadableWidth = 760;

#pragma mark - Direction

static void ApplyDirection(NSView* view)
{
    BOOL rightToLeft = PreviewRightToLeft();
    BOOL technical = [view.identifier isEqual:@"technical"];
    BOOL trailing = [view.identifier isEqual:@"trailing"];
    view.userInterfaceLayoutDirection = rightToLeft && !technical ? NSUserInterfaceLayoutDirectionRightToLeft : NSUserInterfaceLayoutDirectionLeftToRight;
    if([view isKindOfClass:NSControl.class])
    {
        NSControl* control = (NSControl*)view;
        control.baseWritingDirection = technical ? NSWritingDirectionLeftToRight : NSWritingDirectionNatural;
        if(technical) control.alignment = NSTextAlignmentLeft;
        else if(trailing) control.alignment = rightToLeft ? NSTextAlignmentLeft : NSTextAlignmentRight;
        else if(control.alignment != NSTextAlignmentCenter) control.alignment = NSTextAlignmentNatural;
    }
    for(NSView* child in view.subviews) ApplyDirection(child);
}

// Explicit leading / trailing anchors. Constants passed through Edge() keep their meaning in both directions.
static NSLayoutXAxisAnchor* Leading(NSView* view) { return PreviewRightToLeft() ? view.rightAnchor : view.leftAnchor; }
static NSLayoutXAxisAnchor* Trailing(NSView* view) { return PreviewRightToLeft() ? view.leftAnchor : view.rightAnchor; }
static CGFloat Edge(CGFloat value) { return PreviewRightToLeft() ? -value : value; }

#pragma mark - Colors and text

static NSColor* StatusColor(BOOL allowed)
{
    return [NSColor colorWithName:allowed ? @"PreviewAllowed" : @"PreviewBlocked" dynamicProvider:^NSColor*(NSAppearance* appearance) {
        BOOL dark = [[appearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]] isEqual:NSAppearanceNameDarkAqua];
        if(dark) return allowed ? NSColor.systemGreenColor : NSColor.systemRedColor;
        return allowed ? [NSColor colorWithSRGBRed:0.16 green:0.43 blue:0.19 alpha:1] : [NSColor colorWithSRGBRed:0.65 green:0.18 blue:0.12 alpha:1];
    }];
}

static CGFloat TextWidth(NSString* text, NSFont* font)
{
    return ceil([text sizeWithAttributes:@{NSFontAttributeName: font}].width);
}

// Wrapping label.
static NSTextField* Label(NSString* text, CGFloat size, NSFontWeight weight)
{
    NSTextField* field = [NSTextField wrappingLabelWithString:text];
    field.font = [NSFont systemFontOfSize:size weight:weight];
    field.textColor = NSColor.labelColor;
    field.translatesAutoresizingMaskIntoConstraints = NO;
    [field setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    return field;
}

// Single-line, truncating label.
static NSTextField* Line(NSString* text, CGFloat size, NSFontWeight weight)
{
    NSTextField* field = [NSTextField labelWithString:text];
    field.font = [NSFont systemFontOfSize:size weight:weight];
    field.textColor = NSColor.labelColor;
    field.lineBreakMode = NSLineBreakByTruncatingTail;
    field.translatesAutoresizingMaskIntoConstraints = NO;
    [field setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    return field;
}

static NSTextField* Secondary(NSString* text)
{
    NSTextField* field = Label(text, 12, NSFontWeightRegular);
    field.textColor = NSColor.secondaryLabelColor;
    return field;
}

static NSTextField* Caption(NSString* text)
{
    NSTextField* field = Label(text, 11, NSFontWeightRegular);
    field.textColor = NSColor.secondaryLabelColor;
    return field;
}

static NSTextField* FieldLabel(NSString* text)
{
    NSTextField* field = Label(text, 11, NSFontWeightMedium);
    field.textColor = NSColor.secondaryLabelColor;
    return field;
}

static NSTextField* SectionTitle(NSString* text)
{
    return Label(text, 13, NSFontWeightSemibold);
}

static NSTextField* Technical(NSString* text)
{
    NSTextField* field = Secondary(text);
    field.identifier = @"technical";
    return field;
}

// Selectable monospaced value for paths, hosts and ports. Always left-to-right.
static NSTextField* Code(NSString* text, CGFloat size, NSFontWeight weight)
{
    NSTextField* field = Label(text, size, weight);
    field.font = [NSFont monospacedSystemFontOfSize:size weight:weight];
    field.identifier = @"technical";
    field.selectable = YES;
    field.lineBreakMode = NSLineBreakByCharWrapping;
    return field;
}

static NSImageView* Symbol(NSString* name, CGFloat size, NSColor* tint)
{
    NSImageView* view = [[NSImageView alloc] init];
    view.image = [NSImage imageWithSystemSymbolName:name accessibilityDescription:nil];
    view.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:size weight:NSFontWeightSemibold];
    view.contentTintColor = tint;
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.accessibilityElement = NO;
    [view setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    [view setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    return view;
}

#pragma mark - Layout helpers

static NSStackView* Stack(NSArray<NSView*>* views, NSUserInterfaceLayoutOrientation orientation, CGFloat spacing)
{
    NSStackView* stack = [NSStackView stackViewWithViews:views];
    stack.orientation = orientation;
    stack.alignment = orientation == NSUserInterfaceLayoutOrientationVertical ? NSLayoutAttributeLeading : NSLayoutAttributeCenterY;
    stack.spacing = spacing;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.userInterfaceLayoutDirection = PreviewRightToLeft() ? NSUserInterfaceLayoutDirectionRightToLeft : NSUserInterfaceLayoutDirectionLeftToRight;
    return stack;
}

static void Fill(NSView* child, NSView* parent, CGFloat padding)
{
    child.translatesAutoresizingMaskIntoConstraints = NO;
    [parent addSubview:child];
    [NSLayoutConstraint activateConstraints:@[
        [child.leftAnchor constraintEqualToAnchor:parent.leftAnchor constant:padding],
        [child.rightAnchor constraintEqualToAnchor:parent.rightAnchor constant:-padding],
        [child.topAnchor constraintEqualToAnchor:parent.topAnchor constant:padding],
        [child.bottomAnchor constraintEqualToAnchor:parent.bottomAnchor constant:-padding]
    ]];
}

// Adds a view that spans the stack's width inside its edge insets.
static void AddWide(NSStackView* stack, NSView* view)
{
    [stack addArrangedSubview:view];
    CGFloat insets = stack.edgeInsets.left + stack.edgeInsets.right;
    [view.widthAnchor constraintEqualToAnchor:stack.widthAnchor constant:-insets].active = YES;
}

static NSView* Spacer(void)
{
    NSView* view = [[NSView alloc] init];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    [view setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
    [view setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationVertical];
    return view;
}

#pragma mark - Icons and controls

static NSView* AppIcon(NSString* path, NSString* fallback, CGFloat size)
{
    if(path.length == 0 || ![NSFileManager.defaultManager fileExistsAtPath:path])
        return PreviewSymbol(fallback, size, NSColor.secondaryLabelColor);
    NSImageView* view = [[NSImageView alloc] init];
    view.image = [NSWorkspace.sharedWorkspace iconForFile:path.stringByResolvingSymlinksInPath];
    view.imageScaling = NSImageScaleProportionallyUpOrDown;
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.accessibilityElement = NO;
    [view.widthAnchor constraintEqualToConstant:size].active = YES;
    [view.heightAnchor constraintEqualToConstant:size].active = YES;
    return view;
}

static NSView* LuLuIcon(CGFloat size)
{
    NSString* path = [NSBundle.mainBundle pathForResource:@"LuLuIcon" ofType:@"png"];
    NSImage* image = path ? [[NSImage alloc] initWithContentsOfFile:path] : nil;
    if(!image) return PreviewSymbol(@"shield.lefthalf.fill", size, NSColor.secondaryLabelColor);
    NSImageView* view = [[NSImageView alloc] init];
    view.image = image;
    view.imageScaling = NSImageScaleProportionallyUpOrDown;
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.accessibilityElement = NO;
    [view.widthAnchor constraintEqualToConstant:size].active = YES;
    [view.heightAnchor constraintEqualToConstant:size].active = YES;
    return view;
}

static NSButton* Button(NSString* title, id target, SEL action)
{
    NSButton* button = [NSButton buttonWithTitle:title target:target action:action];
    button.bezelStyle = NSBezelStyleRounded;
    button.controlSize = NSControlSizeRegular;
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button setContentCompressionResistancePriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationHorizontal];
    return button;
}

static NSButton* BarButton(NSString* symbol, NSString* label, id target, SEL action)
{
    NSImage* image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:label];
    NSButton* button = [NSButton buttonWithImage:[image imageWithSymbolConfiguration:
        [NSImageSymbolConfiguration configurationWithPointSize:13 weight:NSFontWeightMedium]] target:target action:action];
    button.bordered = NO;
    button.contentTintColor = NSColor.secondaryLabelColor;
    button.toolTip = label;
    button.accessibilityLabel = label;
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button.widthAnchor constraintEqualToConstant:28].active = YES;
    [button.heightAnchor constraintEqualToConstant:24].active = YES;
    return button;
}

#pragma mark - Rule presentation

static BOOL AllDestinations(PreviewRule* rule) { return [rule.endpoint isEqual:@"*"]; }
static NSString* EndpointText(PreviewRule* rule) { return AllDestinations(rule) ? PreviewText(@"All destinations") : rule.endpoint; }

static NSString* ActionTitle(PreviewRule* rule)
{
    if(!rule.enabled) return PreviewText(@"Disabled");
    return rule.allowed ? PreviewText(@"Allow") : PreviewText(@"Block");
}

static NSColor* ActionColor(PreviewRule* rule)
{
    return rule.enabled ? StatusColor(rule.allowed) : NSColor.secondaryLabelColor;
}

static NSString* ActionSymbol(PreviewRule* rule)
{
    if(!rule.enabled) return @"pause.circle";
    return rule.allowed ? @"checkmark.circle.fill" : @"xmark.octagon.fill";
}

static CGFloat ActionTagWidth(CGFloat size)
{
    NSFont* font = [NSFont systemFontOfSize:size weight:NSFontWeightMedium];
    CGFloat width = 0;
    for(NSString* text in @[PreviewText(@"Allow"), PreviewText(@"Block"), PreviewText(@"Disabled")])
        width = MAX(width, TextWidth(text, font));
    return width + size + 2 + 5;
}

// Symbol and text, so the action never depends on color alone.
static NSStackView* ActionTag(PreviewRule* rule, CGFloat size)
{
    NSTextField* text = Line(ActionTitle(rule), size, NSFontWeightMedium);
    text.textColor = ActionColor(rule);
    [text setContentCompressionResistancePriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSStackView* tag = Stack(@[Symbol(ActionSymbol(rule), size - 1, ActionColor(rule)), text], NSUserInterfaceLayoutOrientationHorizontal, 5);
    tag.accessibilityElement = YES;
    tag.accessibilityRole = NSAccessibilityStaticTextRole;
    tag.accessibilityLabel = ActionTitle(rule);
    text.accessibilityElement = NO;
    return tag;
}

#pragma mark - Views

// Opaque reading surface behind the rule list.
@interface PreviewCanvas : NSView
@end
@implementation PreviewCanvas
-(void)drawRect:(NSRect)dirtyRect
{
    [self.effectiveAppearance performAsCurrentDrawingAppearance:^{
        [PreviewSurfaceColor() setFill];
        NSRectFill(NSIntersectionRect(dirtyRect, self.bounds));
    }];
}
-(void)viewDidChangeEffectiveAppearance { [super viewDidChangeEffectiveAppearance]; self.needsDisplay = YES; }
@end

@interface PreviewDocumentView : NSView
@end
@implementation PreviewDocumentView
-(BOOL)isFlipped { return YES; }
@end

@interface PreviewRuleCell : NSTableCellView
@property(nonatomic, strong) NSArray<NSTextField*>* fields;
@property(nonatomic, strong) NSArray<NSColor*>* fieldColors;
@property(nonatomic, strong) NSImageView* statusImage;
@property(nonatomic, strong) NSColor* statusColor;
@end
@implementation PreviewRuleCell
-(void)setBackgroundStyle:(NSBackgroundStyle)backgroundStyle
{
    [super setBackgroundStyle:backgroundStyle];
    BOOL emphasized = backgroundStyle == NSBackgroundStyleEmphasized;
    for(NSUInteger index = 0; index < self.fields.count; index++)
        self.fields[index].textColor = emphasized ? NSColor.alternateSelectedControlTextColor : self.fieldColors[index];
    if(self.statusImage) self.statusImage.contentTintColor = emphasized ? NSColor.alternateSelectedControlTextColor : self.statusColor;
}
@end

@interface PreviewRuleTable : NSTableView
@end
@implementation PreviewRuleTable
-(void)keyDown:(NSEvent*)event
{
    NSString* characters = event.charactersIgnoringModifiers;
    unichar key = characters.length ? [characters characterAtIndex:0] : 0;
    if((key == NSDeleteCharacter || key == NSDeleteFunctionKey) && self.selectedRow >= 0)
    {
        [NSApp sendAction:@selector(deleteRule:) to:self.delegate from:self];
        return;
    }
    [super keyDown:event];
}
@end

#pragma mark - Controller

@interface PreviewController ()
@property(nonatomic, strong) PreviewModel* model;
@property(nonatomic, strong) NSUndoManager* textUndoManager;
@property(nonatomic, strong) NSView* pageView;
@property(nonatomic, strong) NSArray<NSButton*>* navigation;
@property(nonatomic, strong) NSTableView* table;
@property(nonatomic, strong) NSSearchField* search;
@property(nonatomic, strong) NSSegmentedControl* filter;
@property(nonatomic, strong) NSArray<PreviewRule*>* visibleRules;
@property(nonatomic, copy) NSString* ruleQuery;
@property(nonatomic) NSInteger ruleFilter;
@property(nonatomic, strong) PreviewRule* ruleSelection;
@property(nonatomic, strong) NSStackView* inspector;
@property(nonatomic, strong) NSTextField* countLabel;
@property(nonatomic, strong) NSView* emptyState;
@property(nonatomic, strong) NSButton* removeButton;
@property(nonatomic, strong) NSTextField* noticeLabel;
@property(nonatomic, copy) NSDictionary* lastDecision;
@property(nonatomic) NSInteger currentPage;
@property(nonatomic, strong) NSPanel* sheet;
@property(nonatomic, strong) NSStackView* sheetStack;
@property(nonatomic, strong) NSTextField* nameInput;
@property(nonatomic, strong) NSTextField* pathInput;
@property(nonatomic, strong) NSTextField* endpointInput;
@property(nonatomic, strong) NSTextField* formError;
@property(nonatomic, strong) NSPopUpButton* actionInput;
@property(nonatomic, strong) NSPopUpButton* scopeInput;
@property(nonatomic, strong) NSPopUpButton* durationInput;
@property(nonatomic, strong) NSTextField* minutesInput;
@property(nonatomic, strong) NSView* minutesRow;
@property(nonatomic, strong) NSButton* detailsToggle;
@property(nonatomic, strong) NSView* connectionDetails;
@end

@implementation PreviewController
-(instancetype)init
{
    NSWindow* window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1100, 720)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable | NSWindowStyleMaskFullSizeContentView
        backing:NSBackingStoreBuffered defer:NO];
    self = [super initWithWindow:window];
    if(self)
    {
        self.model = [[PreviewModel alloc] init];
        self.textUndoManager = [[NSUndoManager alloc] init];
        window.title = @"LuLu Interface Preview";
        window.subtitle = PreviewText(@"Interface preview · Sample data");
        window.titleVisibility = NSWindowTitleHidden;
        window.titlebarAppearsTransparent = YES;
        window.minSize = NSMakeSize(980, 640);
        window.backgroundColor = PreviewCanvasColor();
        window.autorecalculatesKeyViewLoop = YES;
        window.delegate = self;
        window.releasedWhenClosed = NO;
        [window center];
        [self buildShell];
        [self showPage:1];
    }
    return self;
}

-(void)saveRuleViewState
{
    self.ruleQuery = self.search.stringValue ?: @"";
    self.ruleFilter = MAX(0, self.filter.selectedSegment);
    self.ruleSelection = [self selectedRule];
}

-(void)reloadLanguage
{
    if(self.currentPage == 1) [self saveRuleViewState];
    for(NSView* view in self.window.contentView.subviews.copy) [view removeFromSuperview];
    self.window.subtitle = PreviewText(@"Interface preview · Sample data");
    [self buildShell];
    [self showPage:self.currentPage];
}

#pragma mark Shell

-(void)buildShell
{
    NSView* root = self.window.contentView;
    NSVisualEffectView* backdrop = [[NSVisualEffectView alloc] init];
    backdrop.material = NSVisualEffectMaterialSidebar;
    backdrop.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    backdrop.state = NSVisualEffectStateFollowsWindowActiveState;
    backdrop.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:backdrop];

    NSTextField* productName = Line(@"LuLu", 14, NSFontWeightSemibold);
    NSTextField* productNote = Line(PreviewText(@"Interface preview"), 11, NSFontWeightRegular);
    productNote.textColor = NSColor.secondaryLabelColor;
    NSStackView* brand = Stack(@[LuLuIcon(30), Stack(@[productName, productNote], NSUserInterfaceLayoutOrientationVertical, 0)],
        NSUserInterfaceLayoutOrientationHorizontal, 9);
    brand.edgeInsets = NSEdgeInsetsMake(0, 8, 0, 8);

    NSArray* titles = @[PreviewText(@"Overview"), PreviewText(@"App Rules"), PreviewText(@"Connection Alert"), PreviewText(@"Settings")];
    NSArray* symbols = @[@"shield", @"list.bullet.rectangle", @"bell.badge", @"gearshape"];
    NSStackView* navigation = Stack(@[], NSUserInterfaceLayoutOrientationVertical, 2);
    NSMutableArray* buttons = [NSMutableArray array];
    CGFloat titleWidth = 0;
    for(NSUInteger index = 0; index < titles.count; index++)
    {
        NSButton* button = PreviewNavigationButton(titles[index], symbols[index], [NSString stringWithFormat:@"⌘%lu", index + 1], self, @selector(navigate:));
        button.tag = index;
        button.keyEquivalent = [NSString stringWithFormat:@"%lu", index + 1];
        button.keyEquivalentModifierMask = NSEventModifierFlagCommand;
        AddWide(navigation, button);
        [buttons addObject:button];
        titleWidth = MAX(titleWidth, TextWidth(titles[index], [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold]));
    }
    self.navigation = buttons;

    NSView* status = PreviewBadge(PreviewText(@"Firewall service disconnected"), NSColor.systemOrangeColor);
    NSTextField* sample = Caption(PreviewText(@"Sample data"));
    sample.textColor = NSColor.tertiaryLabelColor;
    NSTextField* license = Caption(@"Objective-See · GPL-3.0");
    license.textColor = NSColor.tertiaryLabelColor;
    NSStackView* footer = Stack(@[], NSUserInterfaceLayoutOrientationVertical, 4);
    footer.edgeInsets = NSEdgeInsetsMake(0, 8, 0, 8);
    AddWide(footer, status);
    AddWide(footer, sample);
    [footer setCustomSpacing:12 afterView:sample];
    AddWide(footer, PreviewDivider());
    [footer setCustomSpacing:10 afterView:footer.arrangedSubviews.lastObject];
    AddWide(footer, license);

    NSView* gap = Spacer();
    NSStackView* sidebarContent = Stack(@[], NSUserInterfaceLayoutOrientationVertical, 0);
    sidebarContent.distribution = NSStackViewDistributionFill;
    sidebarContent.edgeInsets = NSEdgeInsetsMake(PreviewPageTop - PreviewSidebarInset, 10, 16, 10);
    AddWide(sidebarContent, brand);
    [sidebarContent setCustomSpacing:22 afterView:brand];
    AddWide(sidebarContent, navigation);
    AddWide(sidebarContent, gap);
    AddWide(sidebarContent, footer);
    for(NSStackView* stack in @[brand, navigation, footer])
        [stack setHuggingPriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationVertical];

    NSView* sidebar = PreviewGlass(sidebarContent, 0, 18);
    [root addSubview:sidebar];
    // Separate behind-window regions keep the sidebar material from overriding the content material.
    NSVisualEffectView* contentMaterial = PreviewMaterial(NSVisualEffectMaterialUnderWindowBackground, NSVisualEffectBlendingModeBehindWindow);
    [root addSubview:contentMaterial];
    self.pageView = [[NSView alloc] init];
    Fill(self.pageView, contentMaterial, 0);

    // Icon, gaps, row and sidebar insets, and the shortcut column.
    CGFloat shortcutWidth = TextWidth(@"⌘4", [NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightRegular]);
    CGFloat sidebarWidth = MIN(300, MAX(216, titleWidth + shortcutWidth + 20 + 8 + 8 + 19 + 20));
    [NSLayoutConstraint activateConstraints:@[
        [Leading(sidebar) constraintEqualToAnchor:Leading(root) constant:Edge(PreviewSidebarInset)],
        [sidebar.topAnchor constraintEqualToAnchor:root.topAnchor constant:PreviewSidebarInset],
        [sidebar.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-PreviewSidebarInset],
        [sidebar.widthAnchor constraintEqualToConstant:sidebarWidth],
        [Leading(contentMaterial) constraintEqualToAnchor:Trailing(sidebar) constant:Edge(PreviewSidebarInset)],
        [Trailing(contentMaterial) constraintEqualToAnchor:Trailing(root)],
        [contentMaterial.topAnchor constraintEqualToAnchor:root.topAnchor],
        [contentMaterial.bottomAnchor constraintEqualToAnchor:root.bottomAnchor],
        [Leading(backdrop) constraintEqualToAnchor:Leading(root)],
        [Trailing(backdrop) constraintEqualToAnchor:Leading(self.pageView)],
        [backdrop.topAnchor constraintEqualToAnchor:root.topAnchor],
        [backdrop.bottomAnchor constraintEqualToAnchor:root.bottomAnchor]
    ]];
}

-(NSStackView*)headerWithTitle:(NSString*)title subtitle:(NSString*)subtitle
{
    return Stack(@[Label(title, 22, NSFontWeightBold), Secondary(subtitle)], NSUserInterfaceLayoutOrientationVertical, 2);
}

-(void)clearPage
{
    for(NSView* view in self.pageView.subviews.copy) [view removeFromSuperview];
}

// Scrolling page with a readable column width.
-(NSStackView*)pageWithTitle:(NSString*)title subtitle:(NSString*)subtitle
{
    [self clearPage];
    NSScrollView* scroll = [[NSScrollView alloc] init];
    scroll.drawsBackground = NO;
    scroll.hasVerticalScroller = YES;
    scroll.autohidesScrollers = YES;
    scroll.borderType = NSNoBorder;
    scroll.automaticallyAdjustsContentInsets = NO;
    Fill(scroll, self.pageView, 0);
    NSView* document = [[PreviewDocumentView alloc] init];
    document.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.documentView = document;
    NSStackView* stack = Stack(@[], NSUserInterfaceLayoutOrientationVertical, 20);
    [document addSubview:stack];
    NSLayoutConstraint* preferredWidth = [stack.widthAnchor constraintEqualToAnchor:document.widthAnchor constant:-2 * PreviewPageMargin];
    preferredWidth.priority = NSLayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        [document.widthAnchor constraintEqualToAnchor:scroll.contentView.widthAnchor],
        [document.topAnchor constraintEqualToAnchor:scroll.contentView.topAnchor],
        [document.leftAnchor constraintEqualToAnchor:scroll.contentView.leftAnchor],
        [stack.topAnchor constraintEqualToAnchor:document.topAnchor constant:PreviewPageTop],
        [stack.bottomAnchor constraintEqualToAnchor:document.bottomAnchor constant:-PreviewPageMargin],
        [stack.centerXAnchor constraintEqualToAnchor:document.centerXAnchor],
        [stack.widthAnchor constraintLessThanOrEqualToConstant:PreviewReadableWidth],
        [stack.widthAnchor constraintLessThanOrEqualToAnchor:document.widthAnchor constant:-2 * PreviewPageMargin],
        preferredWidth
    ]];
    NSStackView* header = [self headerWithTitle:title subtitle:subtitle];
    AddWide(stack, header);
    [stack setCustomSpacing:24 afterView:header];
    return stack;
}

-(void)navigate:(NSButton*)sender
{
    if(self.window.attachedSheet) { sender.state = sender.tag == self.currentPage ? NSControlStateValueOn : NSControlStateValueOff; return; }
    [self showPage:sender.tag];
}

-(void)showPage:(NSInteger)page
{
    if(self.currentPage == 1 && self.search) [self saveRuleViewState];
    self.currentPage = page;
    for(NSButton* button in self.navigation) button.state = button.tag == page ? NSControlStateValueOn : NSControlStateValueOff;
    if(page != 1) { self.table = nil; self.removeButton = nil; self.emptyState = nil; }
    if(page != 2) self.noticeLabel = nil;
    if(page == 0) [self buildOverview];
    else if(page == 1) [self buildRules];
    else if(page == 2) [self buildConnections];
    else [self buildSettings];
    ApplyDirection(self.window.contentView);
    if(page == 1) [self.window makeFirstResponder:self.table];
}

#pragma mark Overview

-(void)buildOverview
{
    NSStackView* page = [self pageWithTitle:PreviewText(@"Overview") subtitle:PreviewText(@"Default profile · Sample data")];

    NSStackView* serviceText = Stack(@[Label(PreviewText(@"Firewall service disconnected"), 15, NSFontWeightSemibold),
        Secondary(PreviewText(@"This preview does not monitor or block network connections."))], NSUserInterfaceLayoutOrientationVertical, 3);
    NSStackView* service = Stack(@[LuLuIcon(44), serviceText], NSUserInterfaceLayoutOrientationHorizontal, 14);
    AddWide(page, PreviewFrostedSurface(service, 18));

    NSUInteger allowed = [[self.model rulesMatching:@"" filter:1] count];
    NSUInteger blocked = [[self.model rulesMatching:@"" filter:2] count];
    NSUInteger disabled = [[self.model rulesMatching:@"" filter:3] count];
    NSStackView* sectionText = Stack(@[SectionTitle(PreviewText(@"App Rules")),
        Caption([NSString stringWithFormat:PreviewText(@"Rules: %@ · Allowed: %@ · Blocked: %@ · Disabled: %@"),
            PreviewNumber(self.model.rules.count), PreviewNumber(allowed), PreviewNumber(blocked), PreviewNumber(disabled)])],
        NSUserInterfaceLayoutOrientationVertical, 2);
    NSStackView* section = Stack(@[sectionText, Spacer(), Button(PreviewText(@"Manage Rules"), self, @selector(openRules:))],
        NSUserInterfaceLayoutOrientationHorizontal, 12);
    section.alignment = NSLayoutAttributeBottom;
    section.edgeInsets = NSEdgeInsetsMake(0, 4, 0, 4);
    AddWide(page, section);
    [page setCustomSpacing:10 afterView:section];

    NSStackView* list = Stack(@[], NSUserInterfaceLayoutOrientationVertical, 0);
    list.edgeInsets = NSEdgeInsetsMake(4, 14, 4, 14);
    CGFloat tagWidth = ActionTagWidth(12);
    for(PreviewRule* rule in self.model.rules)
    {
        if(list.arrangedSubviews.count) AddWide(list, PreviewDivider());
        NSView* icon = AppIcon(rule.path, rule.symbol, 24);
        if(!rule.enabled) icon.alphaValue = 0.5;
        NSTextField* name = Line(rule.name, 13, NSFontWeightRegular);
        if(!rule.enabled) name.textColor = NSColor.secondaryLabelColor;
        NSTextField* endpoint = Line(EndpointText(rule), 11, NSFontWeightRegular);
        endpoint.textColor = NSColor.secondaryLabelColor;
        endpoint.lineBreakMode = NSLineBreakByTruncatingMiddle;
        endpoint.identifier = AllDestinations(rule) ? nil : @"technical";
        [endpoint setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow - 1 forOrientation:NSLayoutConstraintOrientationHorizontal];
        NSStackView* tag = ActionTag(rule, 12);
        [tag.widthAnchor constraintEqualToConstant:tagWidth].active = YES;
        NSStackView* row = Stack(@[icon, name, Spacer(), endpoint, tag], NSUserInterfaceLayoutOrientationHorizontal, 10);
        [row setCustomSpacing:18 afterView:endpoint];
        row.edgeInsets = NSEdgeInsetsMake(8, 0, 8, 0);
        AddWide(list, row);
    }
    AddWide(page, PreviewFrostedSurface(list, 0));

    NSStackView* footer = Stack(@[Caption(PreviewText(@"Changes last for this preview session.")), Spacer(),
        Button(PreviewText(@"View Connection Alert"), self, @selector(openConnections:))], NSUserInterfaceLayoutOrientationHorizontal, 12);
    footer.edgeInsets = NSEdgeInsetsMake(0, 4, 0, 4);
    AddWide(page, footer);
}

-(void)openRules:(id)sender { [self showPage:1]; }
-(void)openConnections:(id)sender { [self showPage:2]; }

#pragma mark App rules

-(void)buildRules
{
    [self clearPage];
    NSView* page = self.pageView;

    NSStackView* header = [self headerWithTitle:PreviewText(@"App Rules") subtitle:PreviewText(@"Default profile · Sample data")];

    self.filter = [NSSegmentedControl segmentedControlWithLabels:@[PreviewText(@"All"), PreviewText(@"Allowed"), PreviewText(@"Blocked"), PreviewText(@"Disabled")]
        trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(filterChanged:)];
    self.filter.selectedSegment = self.ruleFilter;
    self.filter.accessibilityLabel = PreviewText(@"Rule category");
    self.filter.translatesAutoresizingMaskIntoConstraints = NO;
    [self.filter setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];

    self.search = [[NSSearchField alloc] init];
    self.search.stringValue = self.ruleQuery ?: @"";
    self.search.placeholderString = PreviewText(@"Search apps, paths or destinations");
    self.search.accessibilityLabel = self.search.placeholderString;
    self.search.delegate = self;
    self.search.target = self;
    self.search.action = @selector(searchChanged:);
    self.search.translatesAutoresizingMaskIntoConstraints = NO;
    NSLayoutConstraint* searchWidth = [self.search.widthAnchor constraintEqualToConstant:300];
    searchWidth.priority = NSLayoutPriorityDefaultLow;
    [NSLayoutConstraint activateConstraints:@[searchWidth,
        [self.search.widthAnchor constraintGreaterThanOrEqualToConstant:180],
        [self.search.widthAnchor constraintLessThanOrEqualToConstant:360]]];

    NSStackView* controls = Stack(@[self.filter, Spacer(), self.search], NSUserInterfaceLayoutOrientationHorizontal, 12);
    NSView* controlBar = PreviewGlass(controls, 8, 14);

    // Rule list
    self.table = [[PreviewRuleTable alloc] init];
    self.table.userInterfaceLayoutDirection = PreviewRightToLeft() ? NSUserInterfaceLayoutDirectionRightToLeft : NSUserInterfaceLayoutDirectionLeftToRight;
    self.table.style = NSTableViewStyleInset;
    self.table.rowHeight = 44;
    self.table.intercellSpacing = NSMakeSize(8, 2);
    self.table.headerView = nil;
    self.table.usesAlternatingRowBackgroundColors = NO;
    self.table.backgroundColor = NSColor.clearColor;
    self.table.columnAutoresizingStyle = NSTableViewFirstColumnOnlyAutoresizingStyle;
    self.table.delegate = self;
    self.table.dataSource = self;
    self.table.allowsEmptySelection = YES;
    self.table.accessibilityLabel = PreviewText(@"App rules list");
    CGFloat actionWidth = ActionTagWidth(12) + 8;
    for(NSString* identifier in @[@"app", @"action"])
    {
        NSTableColumn* column = [[NSTableColumn alloc] initWithIdentifier:identifier];
        column.width = [identifier isEqual:@"app"] ? 360 : actionWidth;
        column.minWidth = [identifier isEqual:@"app"] ? 180 : actionWidth;
        if([identifier isEqual:@"action"]) column.maxWidth = actionWidth;
        [self.table addTableColumn:column];
    }
    NSScrollView* listScroll = [[NSScrollView alloc] init];
    listScroll.documentView = self.table;
    listScroll.drawsBackground = NO;
    listScroll.hasVerticalScroller = YES;
    listScroll.autohidesScrollers = YES;
    listScroll.borderType = NSNoBorder;
    listScroll.automaticallyAdjustsContentInsets = NO;
    listScroll.contentInsets = NSEdgeInsetsMake(6, 0, 6, 0);
    listScroll.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField* emptyText = Secondary(PreviewText(@"No matching rules. Try another search or category."));
    emptyText.alignment = NSTextAlignmentCenter;
    emptyText.preferredMaxLayoutWidth = 280;
    NSStackView* empty = Stack(@[Symbol(@"magnifyingglass", 20, NSColor.tertiaryLabelColor), emptyText], NSUserInterfaceLayoutOrientationVertical, 8);
    empty.alignment = NSLayoutAttributeCenterX;
    self.emptyState = empty;

    NSButton* add = BarButton(@"plus", PreviewText(@"Add Rule"), self, @selector(addRule:));
    add.keyEquivalent = @"n";
    add.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    self.removeButton = BarButton(@"minus", PreviewText(@"Delete Rule"), self, @selector(deleteRule:));
    self.countLabel = Line(@"", 11, NSFontWeightRegular);
    self.countLabel.textColor = NSColor.secondaryLabelColor;
    NSStackView* bar = Stack(@[add, self.removeButton, Spacer(), self.countLabel], NSUserInterfaceLayoutOrientationHorizontal, 2);
    [bar setCustomSpacing:12 afterView:self.removeButton];

    NSView* listPane = [[PreviewCanvas alloc] init];
    listPane.translatesAutoresizingMaskIntoConstraints = NO;
    NSView* barDivider = PreviewDivider();
    for(NSView* view in @[listScroll, empty, barDivider, bar]) [listPane addSubview:view];

    // Inspector
    NSView* inspectorPane = PreviewMaterial(NSVisualEffectMaterialSidebar, NSVisualEffectBlendingModeWithinWindow);
    self.inspector = Stack(@[], NSUserInterfaceLayoutOrientationVertical, 10);
    [inspectorPane addSubview:self.inspector];

    NSView* columnDivider = PreviewVerticalDivider();
    NSView* body = [[NSView alloc] init];
    body.translatesAutoresizingMaskIntoConstraints = NO;
    for(NSView* view in @[listPane, columnDivider, inspectorPane]) [body addSubview:view];
    NSView* surface = PreviewPanel(body, 12);

    for(NSView* view in @[header, controlBar, surface]) [page addSubview:view];

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:page.topAnchor constant:PreviewPageTop],
        [Leading(header) constraintEqualToAnchor:Leading(page) constant:Edge(PreviewPageMargin)],
        [Trailing(header) constraintEqualToAnchor:Trailing(page) constant:Edge(-PreviewPageMargin)],
        [controlBar.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:18],
        [Leading(controlBar) constraintEqualToAnchor:Leading(page) constant:Edge(PreviewPageMargin)],
        [Trailing(controlBar) constraintEqualToAnchor:Trailing(page) constant:Edge(-PreviewPageMargin)],
        [surface.topAnchor constraintEqualToAnchor:controlBar.bottomAnchor constant:12],
        [Leading(surface) constraintEqualToAnchor:Leading(page) constant:Edge(PreviewPageMargin)],
        [Trailing(surface) constraintEqualToAnchor:Trailing(page) constant:Edge(-PreviewPageMargin)],
        [surface.bottomAnchor constraintEqualToAnchor:page.bottomAnchor constant:-24],

        [listPane.topAnchor constraintEqualToAnchor:body.topAnchor],
        [listPane.bottomAnchor constraintEqualToAnchor:body.bottomAnchor],
        [Leading(listPane) constraintEqualToAnchor:Leading(body)],
        [Leading(columnDivider) constraintEqualToAnchor:Trailing(listPane)],
        [columnDivider.topAnchor constraintEqualToAnchor:body.topAnchor],
        [columnDivider.bottomAnchor constraintEqualToAnchor:body.bottomAnchor],
        [Leading(inspectorPane) constraintEqualToAnchor:Trailing(columnDivider)],
        [Trailing(inspectorPane) constraintEqualToAnchor:Trailing(body)],
        [inspectorPane.topAnchor constraintEqualToAnchor:body.topAnchor],
        [inspectorPane.bottomAnchor constraintEqualToAnchor:body.bottomAnchor],
        [inspectorPane.widthAnchor constraintEqualToConstant:PreviewInspectorWidth],
        [listPane.widthAnchor constraintGreaterThanOrEqualToConstant:340],

        [listScroll.topAnchor constraintEqualToAnchor:listPane.topAnchor],
        [listScroll.leftAnchor constraintEqualToAnchor:listPane.leftAnchor],
        [listScroll.rightAnchor constraintEqualToAnchor:listPane.rightAnchor],
        [listScroll.bottomAnchor constraintEqualToAnchor:barDivider.topAnchor],
        [barDivider.leftAnchor constraintEqualToAnchor:listPane.leftAnchor],
        [barDivider.rightAnchor constraintEqualToAnchor:listPane.rightAnchor],
        [barDivider.bottomAnchor constraintEqualToAnchor:bar.topAnchor],
        [Leading(bar) constraintEqualToAnchor:Leading(listPane) constant:Edge(6)],
        [Trailing(bar) constraintEqualToAnchor:Trailing(listPane) constant:Edge(-14)],
        [bar.bottomAnchor constraintEqualToAnchor:listPane.bottomAnchor],
        [bar.heightAnchor constraintEqualToConstant:32],
        [empty.centerXAnchor constraintEqualToAnchor:listScroll.centerXAnchor],
        [empty.centerYAnchor constraintEqualToAnchor:listScroll.centerYAnchor],
        [empty.widthAnchor constraintLessThanOrEqualToAnchor:listScroll.widthAnchor constant:-48],

        [self.inspector.topAnchor constraintEqualToAnchor:inspectorPane.topAnchor constant:22],
        [self.inspector.leftAnchor constraintEqualToAnchor:inspectorPane.leftAnchor constant:20],
        [self.inspector.rightAnchor constraintEqualToAnchor:inspectorPane.rightAnchor constant:-20],
        [self.inspector.bottomAnchor constraintLessThanOrEqualToAnchor:inspectorPane.bottomAnchor constant:-20]
    ]];

    [self refreshRules];
}

-(void)refreshRules
{
    PreviewRule* previous = [self selectedRule] ?: self.ruleSelection;
    self.visibleRules = [self.model rulesMatching:self.search.stringValue filter:self.filter.selectedSegment];
    [self.table reloadData];
    NSUInteger selection = [self.visibleRules indexOfObjectIdenticalTo:previous];
    if(selection == NSNotFound && self.visibleRules.count > 0) selection = 0;
    if(selection != NSNotFound) [self.table selectRowIndexes:[NSIndexSet indexSetWithIndex:selection] byExtendingSelection:NO];
    self.emptyState.hidden = self.visibleRules.count != 0;
    self.countLabel.stringValue = [NSString stringWithFormat:PreviewText(@"Rules: %@ · Sample data"), PreviewNumber(self.visibleRules.count)];
    [self updateInspector];
    [self saveRuleViewState];
}

-(PreviewRule*)selectedRule
{
    NSInteger row = self.table.selectedRow;
    return row >= 0 && row < (NSInteger)self.visibleRules.count ? self.visibleRules[row] : nil;
}

-(NSInteger)numberOfRowsInTableView:(NSTableView*)tableView { return self.visibleRules.count; }

-(NSView*)tableView:(NSTableView*)tableView viewForTableColumn:(NSTableColumn*)column row:(NSInteger)row
{
    PreviewRule* rule = self.visibleRules[row];
    PreviewRuleCell* cell = [[PreviewRuleCell alloc] init];
    if([column.identifier isEqual:@"app"])
    {
        NSView* icon = AppIcon(rule.path, rule.symbol, 26);
        if(!rule.enabled) icon.alphaValue = 0.5;
        NSTextField* name = Line(rule.name, 13, NSFontWeightMedium);
        name.textColor = rule.enabled ? NSColor.labelColor : NSColor.secondaryLabelColor;
        NSTextField* detail = Line(EndpointText(rule), 11, NSFontWeightRegular);
        detail.textColor = NSColor.secondaryLabelColor;
        detail.identifier = AllDestinations(rule) ? nil : @"technical";
        detail.lineBreakMode = NSLineBreakByTruncatingMiddle;
        NSStackView* text = Stack(@[name, detail], NSUserInterfaceLayoutOrientationVertical, 1);
        NSStackView* content = Stack(@[icon, text], NSUserInterfaceLayoutOrientationHorizontal, 10);
        [cell addSubview:content];
        [NSLayoutConstraint activateConstraints:@[
            [Leading(content) constraintEqualToAnchor:Leading(cell) constant:Edge(4)],
            PreviewRightToLeft() ? [Trailing(content) constraintGreaterThanOrEqualToAnchor:Trailing(cell) constant:Edge(-4)]
                : [Trailing(content) constraintLessThanOrEqualToAnchor:Trailing(cell) constant:Edge(-4)],
            [content.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor]
        ]];
        [text.widthAnchor constraintLessThanOrEqualToAnchor:cell.widthAnchor constant:-44].active = YES;
        cell.textField = name;
        cell.fields = @[name, detail];
        cell.fieldColors = @[name.textColor, detail.textColor];
        cell.toolTip = rule.path;
    }
    else
    {
        NSStackView* tag = ActionTag(rule, 12);
        [cell addSubview:tag];
        [NSLayoutConstraint activateConstraints:@[
            [Leading(tag) constraintEqualToAnchor:Leading(cell) constant:Edge(4)],
            [tag.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor]
        ]];
        NSTextField* status = (NSTextField*)tag.arrangedSubviews.lastObject;
        cell.textField = status;
        cell.fields = @[status];
        cell.fieldColors = @[status.textColor];
        cell.statusImage = (NSImageView*)tag.arrangedSubviews.firstObject;
        cell.statusColor = ActionColor(rule);
    }
    ApplyDirection(cell);
    return cell;
}

-(void)tableViewSelectionDidChange:(NSNotification*)notification { [self updateInspector]; }
-(void)controlTextDidChange:(NSNotification*)notification { if(notification.object == self.search) [self refreshRules]; }
-(void)filterChanged:(id)sender { [self refreshRules]; }
-(void)searchChanged:(id)sender { [self refreshRules]; }
-(void)focusSearch:(id)sender { [self showPage:1]; [self.window makeFirstResponder:self.search]; }

-(void)updateInspector
{
    if(!self.inspector) return;
    for(NSView* view in self.inspector.arrangedSubviews.copy) { [self.inspector removeArrangedSubview:view]; [view removeFromSuperview]; }
    PreviewRule* rule = [self selectedRule];
    self.removeButton.enabled = rule != nil;
    if(!rule)
    {
        NSTextField* hint = Secondary(PreviewText(@"Select a rule to see details"));
        AddWide(self.inspector, hint);
        ApplyDirection(self.inspector);
        return;
    }

    NSView* icon = AppIcon(rule.path, rule.symbol, 52);
    if(!rule.enabled) icon.alphaValue = 0.5;
    [self.inspector addArrangedSubview:icon];
    [self.inspector setCustomSpacing:12 afterView:icon];
    NSTextField* name = Label(rule.name, 17, NSFontWeightSemibold);
    AddWide(self.inspector, name);
    [self.inspector setCustomSpacing:4 afterView:name];
    NSStackView* tag = ActionTag(rule, 12);
    [self.inspector addArrangedSubview:tag];
    [self.inspector setCustomSpacing:16 afterView:tag];

    NSStackView* path = Stack(@[FieldLabel(PreviewText(@"APP PATH")), Code(rule.path, 11, NSFontWeightRegular)], NSUserInterfaceLayoutOrientationVertical, 3);
    NSView* destinationValue = AllDestinations(rule) ? Label(EndpointText(rule), 12, NSFontWeightRegular) : Code(rule.endpoint, 11, NSFontWeightRegular);
    NSStackView* destination = Stack(@[FieldLabel(PreviewText(@"DESTINATION")), destinationValue], NSUserInterfaceLayoutOrientationVertical, 3);
    NSStackView* facts = Stack(@[], NSUserInterfaceLayoutOrientationVertical, 12);
    facts.edgeInsets = NSEdgeInsetsMake(10, 12, 10, 12);
    AddWide(facts, path);
    AddWide(facts, destination);
    for(NSStackView* group in @[path, destination])
        for(NSView* view in group.arrangedSubviews) [view.widthAnchor constraintEqualToAnchor:group.widthAnchor].active = YES;
    NSView* well = PreviewWell(facts, 0);
    AddWide(self.inspector, well);
    [self.inspector setCustomSpacing:18 afterView:well];

    NSTextField* actionLabel = FieldLabel(PreviewText(@"Connection action"));
    [self.inspector addArrangedSubview:actionLabel];
    [self.inspector setCustomSpacing:6 afterView:actionLabel];
    NSSegmentedControl* action = [NSSegmentedControl segmentedControlWithLabels:@[PreviewText(@"Allow"), PreviewText(@"Block")]
        trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(changeAction:)];
    action.selectedSegment = rule.allowed ? 0 : 1;
    action.segmentDistribution = NSSegmentDistributionFillEqually;
    action.accessibilityLabel = PreviewText(@"Connection action");
    action.translatesAutoresizingMaskIntoConstraints = NO;
    AddWide(self.inspector, action);
    [self.inspector setCustomSpacing:14 afterView:action];

    NSSwitch* enabled = [[NSSwitch alloc] init];
    enabled.controlSize = NSControlSizeSmall;
    enabled.state = rule.enabled ? NSControlStateValueOn : NSControlStateValueOff;
    enabled.target = self;
    enabled.action = @selector(changeEnabled:);
    enabled.accessibilityLabel = PreviewText(@"Enable this rule");
    NSStackView* enabledRow = Stack(@[Label(PreviewText(@"Enable this rule"), 13, NSFontWeightRegular), Spacer(), enabled], NSUserInterfaceLayoutOrientationHorizontal, 12);
    AddWide(self.inspector, enabledRow);
    [self.inspector setCustomSpacing:18 afterView:enabledRow];

    AddWide(self.inspector, PreviewDivider());
    NSButton* remove = Button(PreviewText(@"Delete Rule"), self, @selector(deleteRule:));
    remove.hasDestructiveAction = YES;
    [self.inspector addArrangedSubview:remove];
    ApplyDirection(self.inspector);
}

-(void)changeAction:(NSSegmentedControl*)sender
{
    [self.window makeFirstResponder:self.table];
    PreviewRule* rule = [self selectedRule];
    if(rule) [self.model setAllowed:sender.selectedSegment == 0 forRule:rule];
    [self refreshRules];
}
-(void)changeEnabled:(NSSwitch*)sender
{
    [self.window makeFirstResponder:self.table];
    PreviewRule* rule = [self selectedRule];
    if(rule) [self.model setEnabled:sender.state == NSControlStateValueOn forRule:rule];
    [self refreshRules];
}
-(void)deleteRule:(id)sender
{
    if(self.window.attachedSheet || !self.table) return;
    [self.window makeFirstResponder:self.table];
    PreviewRule* rule = [self selectedRule];
    NSInteger row = self.table.selectedRow;
    if(!rule) return;
    [self.model removeRule:rule];
    self.ruleSelection = nil;
    self.visibleRules = [self.model rulesMatching:self.search.stringValue filter:self.filter.selectedSegment];
    [self.table reloadData];
    if(self.visibleRules.count)
        [self.table selectRowIndexes:[NSIndexSet indexSetWithIndex:MIN(row, (NSInteger)self.visibleRules.count - 1)] byExtendingSelection:NO];
    [self refreshRules];
}
// Text fields keep their own undo stack; rule changes are undone through -undo: / -redo:, which also refresh the page.
-(NSUndoManager*)windowWillReturnUndoManager:(NSWindow*)window { return self.textUndoManager; }
-(void)undo:(id)sender
{
    if(self.window.attachedSheet) { [self.sheet.firstResponder.undoManager undo]; return; }
    [self.model.undoManager undo];
    [self showPage:self.currentPage];
}
-(void)redo:(id)sender
{
    if(self.window.attachedSheet) { [self.sheet.firstResponder.undoManager redo]; return; }
    [self.model.undoManager redo];
    [self showPage:self.currentPage];
}

#pragma mark Sheets

-(NSStackView*)beginSheetWithTitle:(NSString*)title message:(NSString*)message icon:(NSView*)icon width:(CGFloat)width
{
    self.sheet = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, width, 420) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
    self.sheet.title = @"LuLu Interface Preview";
    Fill(PreviewMaterial(NSVisualEffectMaterialSheet, NSVisualEffectBlendingModeBehindWindow), self.sheet.contentView, 0);
    NSTextField* mode = Caption(PreviewText(@"Preview mode · Sample data"));
    NSStackView* text = Stack(@[mode, Label(title, 15, NSFontWeightBold)], NSUserInterfaceLayoutOrientationVertical, 2);
    if(message) { NSTextField* body = Secondary(message); [text addArrangedSubview:body]; [text setCustomSpacing:4 afterView:text.arrangedSubviews[1]]; }
    for(NSView* view in text.arrangedSubviews) [view.widthAnchor constraintEqualToAnchor:text.widthAnchor].active = YES;
    NSStackView* header = Stack(@[icon, text], NSUserInterfaceLayoutOrientationHorizontal, 14);
    header.alignment = NSLayoutAttributeTop;
    NSStackView* stack = Stack(@[], NSUserInterfaceLayoutOrientationVertical, 14);
    AddWide(stack, header);
    [text.widthAnchor constraintEqualToAnchor:header.widthAnchor constant:-(icon.fittingSize.width + 14)].active = YES;
    [stack setCustomSpacing:20 afterView:header];
    self.sheetStack = stack;
    [self.sheet.contentView addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leftAnchor constraintEqualToAnchor:self.sheet.contentView.leftAnchor constant:24],
        [stack.rightAnchor constraintEqualToAnchor:self.sheet.contentView.rightAnchor constant:-24],
        [stack.topAnchor constraintEqualToAnchor:self.sheet.contentView.topAnchor constant:22]
    ]];
    return stack;
}

-(void)resizeSheet
{
    NSView* content = self.sheet.contentView;
    [content layoutSubtreeIfNeeded];
    [content layoutSubtreeIfNeeded];
    CGFloat height = ceil(MAX(self.sheetStack.fittingSize.height, NSHeight(self.sheetStack.frame))) + 22 + 20;
    [self.sheet setContentSize:NSMakeSize(NSWidth(content.frame), height)];
}

-(CGFloat)formLabelWidth:(NSArray<NSString*>*)labels
{
    CGFloat width = 0;
    for(NSString* label in labels) width = MAX(width, TextWidth(label, [NSFont systemFontOfSize:13]));
    return MIN(170, MAX(80, width + 2));
}

-(NSStackView*)formRow:(NSString*)label control:(NSView*)control labelWidth:(CGFloat)width fill:(BOOL)fill
{
    NSTextField* title = Label(label, 13, NSFontWeightRegular);
    title.identifier = @"trailing";
    title.textColor = NSColor.labelColor;
    [title.widthAnchor constraintEqualToConstant:width].active = YES;
    NSMutableArray* views = [NSMutableArray arrayWithObjects:title, control, nil];
    if(!fill) [views addObject:Spacer()];
    NSStackView* row = Stack(views, NSUserInterfaceLayoutOrientationHorizontal, 10);
    if(fill) [control.widthAnchor constraintEqualToAnchor:row.widthAnchor constant:-(width + 10)].active = YES;
    return row;
}

-(NSTextField*)inputWithValue:(NSString*)value label:(NSString*)label
{
    NSTextField* input = [NSTextField textFieldWithString:value];
    input.accessibilityLabel = label;
    input.translatesAutoresizingMaskIntoConstraints = NO;
    if([value hasPrefix:@"/"] || [value isEqual:@"*"]) input.identifier = @"technical";
    return input;
}

-(NSTextField*)errorLabel
{
    NSTextField* error = Caption(@"");
    error.textColor = NSColor.systemRedColor;
    error.hidden = YES;
    return error;
}

-(void)showFormError:(NSString*)message
{
    self.formError.stringValue = message;
    self.formError.hidden = NO;
    [self resizeSheet];
    NSAccessibilityPostNotificationWithUserInfo(self.formError, NSAccessibilityAnnouncementRequestedNotification,
        @{NSAccessibilityAnnouncementKey: message, NSAccessibilityPriorityKey: @(NSAccessibilityPriorityHigh)});
}

-(void)addRule:(id)sender
{
    if(self.window.attachedSheet || self.currentPage != 1) return;
    NSStackView* stack = [self beginSheetWithTitle:PreviewText(@"Add Rule") message:nil icon:LuLuIcon(40) width:500];
    NSArray* labels = @[PreviewText(@"App name"), PreviewText(@"Full app path"), PreviewText(@"Destination (* for all)"), PreviewText(@"Connection action")];
    CGFloat width = [self formLabelWidth:labels];
    self.nameInput = [self inputWithValue:@"" label:labels[0]];
    self.pathInput = [self inputWithValue:@"/Applications/" label:labels[1]];
    self.endpointInput = [self inputWithValue:@"*" label:labels[2]];
    self.actionInput = [[NSPopUpButton alloc] init];
    [self.actionInput addItemsWithTitles:@[PreviewText(@"Allow connection"), PreviewText(@"Block connection")]];
    self.actionInput.accessibilityLabel = labels[3];
    AddWide(stack, [self formRow:labels[0] control:self.nameInput labelWidth:width fill:YES]);
    AddWide(stack, [self formRow:labels[1] control:self.pathInput labelWidth:width fill:YES]);
    AddWide(stack, [self formRow:labels[2] control:self.endpointInput labelWidth:width fill:YES]);
    NSStackView* actionRow = [self formRow:labels[3] control:self.actionInput labelWidth:width fill:NO];
    AddWide(stack, actionRow);
    self.formError = [self errorLabel];
    AddWide(stack, self.formError);
    [stack setCustomSpacing:22 afterView:self.formError];
    [stack setCustomSpacing:22 afterView:actionRow];

    NSButton* cancel = Button(PreviewText(@"Cancel"), self, @selector(cancelSheet:)); cancel.keyEquivalent = @"\e";
    NSButton* save = Button(PreviewText(@"Add"), self, @selector(saveRule:)); save.keyEquivalent = @"\r";
    AddWide(stack, Stack(@[Spacer(), cancel, save], NSUserInterfaceLayoutOrientationHorizontal, 10));
    ApplyDirection(self.sheet.contentView);
    [self resizeSheet];
    [self.window beginSheet:self.sheet completionHandler:nil];
    [self.sheet makeFirstResponder:self.nameInput];
}

-(void)cancelSheet:(id)sender { [self.window endSheet:self.sheet]; self.sheet = nil; }

-(void)saveRule:(id)sender
{
    NSString* name = [self.nameInput.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString* path = [self.pathInput.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString* endpoint = [self.endpointInput.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if(name.length == 0 || ![path hasPrefix:@"/"] || [path hasSuffix:@"/"] || endpoint.length == 0)
    {
        [self showFormError:PreviewText(@"Enter a name, a full app path and a destination.")];
        return;
    }
    PreviewRule* rule = [[PreviewRule alloc] init];
    rule.name = name; rule.path = path; rule.endpoint = endpoint; rule.symbol = @"app";
    rule.allowed = self.actionInput.indexOfSelectedItem == 0; rule.enabled = YES;
    [self.model addRule:rule];
    [self cancelSheet:nil];
    self.search.stringValue = @""; self.filter.selectedSegment = 0;
    [self refreshRules];
    NSUInteger index = [self.visibleRules indexOfObjectIdenticalTo:rule];
    if(index != NSNotFound)
    {
        [self.table selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
        [self.table scrollRowToVisible:index];
    }
    [self saveRuleViewState];
}

#pragma mark Connection alert

-(void)buildConnections
{
    NSStackView* page = [self pageWithTitle:PreviewText(@"Connection Alert") subtitle:PreviewText(@"Sample connection request")];

    NSStackView* appText = Stack(@[Label(@"Sample Editor", 15, NSFontWeightSemibold),
        Secondary(PreviewText(@"Sample Editor wants to connect to updates.example.com."))], NSUserInterfaceLayoutOrientationVertical, 3);
    NSButton* open = Button(PreviewText(@"Open Sample Alert"), self, @selector(showConnection:));
    open.keyEquivalent = @"\r";
    NSStackView* top = Stack(@[AppIcon(@"", @"curlybraces", 44), appText, Spacer(), open], NSUserInterfaceLayoutOrientationHorizontal, 14);

    NSStackView* destination = Stack(@[FieldLabel(PreviewText(@"DESTINATION")), Code(@"updates.example.com", 13, NSFontWeightMedium),
        Technical(@"TCP · 443 · HTTPS")], NSUserInterfaceLayoutOrientationVertical, 3);
    destination.edgeInsets = NSEdgeInsetsMake(10, 12, 10, 12);

    NSStackView* card = Stack(@[], NSUserInterfaceLayoutOrientationVertical, 16);
    AddWide(card, top);
    AddWide(card, PreviewWell(destination, 0));
    AddWide(page, PreviewFrostedSurface(card, 18));

    BOOL decided = self.lastDecision != nil;
    BOOL allowed = [self.lastDecision[@"allowed"] boolValue];
    NSImageView* mark = Symbol(!decided ? @"clock" : (allowed ? @"checkmark.circle.fill" : @"xmark.octagon.fill"), 12,
        !decided ? NSColor.tertiaryLabelColor : StatusColor(allowed));
    self.noticeLabel = Secondary([self decisionSummary]);
    NSStackView* notice = Stack(@[mark, self.noticeLabel], NSUserInterfaceLayoutOrientationHorizontal, 7);
    notice.edgeInsets = NSEdgeInsetsMake(0, 4, 0, 4);
    AddWide(page, notice);
}

-(void)showConnection:(id)sender
{
    if(self.window.attachedSheet) return;
    NSStackView* stack = [self beginSheetWithTitle:PreviewText(@"Allow this connection?")
        message:PreviewText(@"Sample Editor wants to connect to updates.example.com.") icon:LuLuIcon(44) width:520];

    NSStackView* app = Stack(@[AppIcon(@"", @"curlybraces", 32), Stack(@[Label(@"Sample Editor", 13, NSFontWeightSemibold),
        Caption(PreviewText(@"Requests an outgoing connection"))], NSUserInterfaceLayoutOrientationVertical, 1)], NSUserInterfaceLayoutOrientationHorizontal, 10);
    NSStackView* endpoint = Stack(@[FieldLabel(PreviewText(@"DESTINATION")), Code(@"updates.example.com", 15, NSFontWeightMedium),
        Technical(@"TCP · 443 · HTTPS")], NSUserInterfaceLayoutOrientationVertical, 3);
    NSStackView* facts = Stack(@[], NSUserInterfaceLayoutOrientationVertical, 12);
    facts.edgeInsets = NSEdgeInsetsMake(12, 14, 12, 14);
    AddWide(facts, app);
    AddWide(facts, PreviewDivider());
    AddWide(facts, endpoint);
    AddWide(stack, PreviewWell(facts, 0));
    [stack setCustomSpacing:18 afterView:stack.arrangedSubviews.lastObject];

    NSArray* labels = @[PreviewText(@"Applies to"), PreviewText(@"Duration")];
    CGFloat width = [self formLabelWidth:labels];
    self.scopeInput = [[NSPopUpButton alloc] init];
    [self.scopeInput addItemsWithTitles:@[PreviewText(@"This destination"), PreviewText(@"All connections from this app"), PreviewText(@"This app and child processes")]];
    self.scopeInput.accessibilityLabel = PreviewText(@"Rule scope");
    self.durationInput = [[NSPopUpButton alloc] init];
    [self.durationInput addItemsWithTitles:@[PreviewText(@"Just once"), PreviewText(@"Until the app quits"), PreviewText(@"Always"), PreviewText(@"Custom duration")]];
    self.durationInput.target = self; self.durationInput.action = @selector(durationChanged:);
    self.durationInput.accessibilityLabel = PreviewText(@"Duration");
    AddWide(stack, [self formRow:labels[0] control:self.scopeInput labelWidth:width fill:NO]);
    AddWide(stack, [self formRow:labels[1] control:self.durationInput labelWidth:width fill:NO]);

    self.minutesInput = [NSTextField textFieldWithString:@"15"];
    self.minutesInput.identifier = @"technical";
    self.minutesInput.placeholderString = PreviewText(@"Minutes (1–1440)");
    self.minutesInput.accessibilityLabel = self.minutesInput.placeholderString;
    self.minutesInput.translatesAutoresizingMaskIntoConstraints = NO;
    [self.minutesInput.widthAnchor constraintEqualToConstant:72].active = YES;
    NSStackView* minutes = Stack(@[self.minutesInput, Caption(PreviewText(@"Minutes (1–1440)"))], NSUserInterfaceLayoutOrientationHorizontal, 8);
    self.minutesRow = [self formRow:@"" control:minutes labelWidth:width fill:NO];
    self.minutesRow.hidden = YES;
    AddWide(stack, self.minutesRow);

    self.detailsToggle = [NSButton buttonWithTitle:@"" target:self action:@selector(toggleConnectionDetails:)];
    self.detailsToggle.bezelStyle = NSBezelStyleDisclosure;
    [self.detailsToggle setButtonType:NSButtonTypeOnOff];
    self.detailsToggle.title = @"";
    self.detailsToggle.accessibilityLabel = PreviewText(@"Show app details");
    [self.detailsToggle.cell setAccessibilityLabel:PreviewText(@"Show app details")];
    self.detailsToggle.translatesAutoresizingMaskIntoConstraints = NO;
    NSTextField* detailsTitle = Line(PreviewText(@"Show app details"), 13, NSFontWeightRegular);
    detailsTitle.accessibilityElement = NO;
    [detailsTitle addGestureRecognizer:[[NSClickGestureRecognizer alloc] initWithTarget:self action:@selector(clickDetailsTitle:)]];
    NSStackView* disclosure = Stack(@[self.detailsToggle, detailsTitle], NSUserInterfaceLayoutOrientationHorizontal, 4);
    [stack setCustomSpacing:16 afterView:self.minutesRow];
    [stack addArrangedSubview:disclosure];
    [stack setCustomSpacing:8 afterView:disclosure];

    NSStackView* details = Stack(@[Code(@"/Applications/Sample Editor.app", 11, NSFontWeightRegular),
        Caption(PreviewText(@"Signature: Not verified"))], NSUserInterfaceLayoutOrientationVertical, 4);
    details.edgeInsets = PreviewRightToLeft() ? NSEdgeInsetsMake(0, 0, 0, 22) : NSEdgeInsetsMake(0, 22, 0, 0);
    for(NSView* view in details.arrangedSubviews) [view.widthAnchor constraintEqualToAnchor:details.widthAnchor constant:-22].active = YES;
    self.connectionDetails = details;
    self.connectionDetails.hidden = YES;
    AddWide(stack, self.connectionDetails);

    self.formError = [self errorLabel];
    AddWide(stack, self.formError);
    NSView* last = self.formError;
    [stack setCustomSpacing:22 afterView:last];
    [stack setCustomSpacing:22 afterView:self.connectionDetails];
    [stack setCustomSpacing:22 afterView:disclosure];

    NSButton* cancel = Button(PreviewText(@"Cancel"), self, @selector(cancelSheet:)); cancel.keyEquivalent = @"\e";
    NSButton* block = Button(PreviewText(@"Block Connection"), self, @selector(respondToConnection:)); block.tag = 0;
    NSButton* allow = Button(PreviewText(@"Allow Connection"), self, @selector(respondToConnection:)); allow.tag = 1;
    AddWide(stack, Stack(@[cancel, Spacer(), block, allow], NSUserInterfaceLayoutOrientationHorizontal, 10));
    ApplyDirection(self.sheet.contentView);
    [self resizeSheet];
    [self.window beginSheet:self.sheet completionHandler:nil];
    [self.sheet makeFirstResponder:self.scopeInput];
}

-(void)durationChanged:(id)sender
{
    self.minutesRow.hidden = self.durationInput.indexOfSelectedItem != 3;
    if(self.minutesRow.hidden) self.formError.hidden = YES;
    [self resizeSheet];
    if(!self.minutesRow.hidden) [self.sheet makeFirstResponder:self.minutesInput];
}
-(void)clickDetailsTitle:(id)sender { [self.detailsToggle performClick:nil]; }
-(void)toggleConnectionDetails:(NSButton*)sender { self.connectionDetails.hidden = sender.state != NSControlStateValueOn; [self resizeSheet]; }
-(void)respondToConnection:(NSButton*)sender
{
    if(self.durationInput.indexOfSelectedItem == 3)
    {
        NSScanner* scanner = [NSScanner scannerWithString:self.minutesInput.stringValue];
        NSInteger minutes = 0;
        if(![scanner scanInteger:&minutes] || !scanner.isAtEnd || minutes < 1 || minutes > 1440)
        {
            [self showFormError:PreviewText(@"Enter a whole number from 1 to 1440 minutes.")];
            return;
        }
    }
    self.lastDecision = @{@"allowed": @(sender.tag == 1), @"scope": @(self.scopeInput.indexOfSelectedItem),
        @"duration": @(self.durationInput.indexOfSelectedItem), @"minutes": @(self.minutesInput.integerValue)};
    [self cancelSheet:nil];
    if(self.currentPage == 2) [self showPage:2];
}

-(NSString*)decisionSummary
{
    if(!self.lastDecision) return PreviewText(@"No decision yet");
    NSArray* scopes = @[@"This destination", @"All connections from this app", @"This app and child processes"];
    NSArray* durations = @[@"Just once", @"Until the app quits", @"Always"];
    NSUInteger durationIndex = [self.lastDecision[@"duration"] unsignedIntegerValue];
    NSString* duration = durationIndex == 3 ? [NSString stringWithFormat:PreviewText(@"%@ min"), PreviewNumber([self.lastDecision[@"minutes"] unsignedIntegerValue])] : PreviewText(durations[durationIndex]);
    return [NSString stringWithFormat:PreviewText(@"Sample decision: %1$@ · %2$@ · %3$@"),
        [self.lastDecision[@"allowed"] boolValue] ? PreviewText(@"Allow") : PreviewText(@"Block"),
        PreviewText(scopes[[self.lastDecision[@"scope"] unsignedIntegerValue]]), duration];
}

#pragma mark Settings

-(NSView*)settingsGroup:(NSString*)title rows:(NSArray<NSView*>*)rows
{
    NSStackView* list = Stack(@[], NSUserInterfaceLayoutOrientationVertical, 0);
    list.edgeInsets = NSEdgeInsetsMake(2, 14, 2, 14);
    for(NSView* row in rows)
    {
        if(list.arrangedSubviews.count) AddWide(list, PreviewDivider());
        AddWide(list, row);
    }
    NSView* surface = PreviewFrostedSurface(list, 0);
    if(!title) return surface;
    NSStackView* group = Stack(@[], NSUserInterfaceLayoutOrientationVertical, 8);
    NSStackView* heading = Stack(@[SectionTitle(title)], NSUserInterfaceLayoutOrientationHorizontal, 0);
    heading.edgeInsets = NSEdgeInsetsMake(0, 4, 0, 4);
    AddWide(group, heading);
    AddWide(group, surface);
    return group;
}

-(NSStackView*)settingsRow:(NSString*)title detail:(NSString*)detail control:(NSView*)control
{
    NSStackView* copy = Stack(@[Label(title, 13, NSFontWeightRegular), Caption(detail)], NSUserInterfaceLayoutOrientationVertical, 2);
    NSStackView* row = Stack(@[copy, Spacer(), control], NSUserInterfaceLayoutOrientationHorizontal, 16);
    row.edgeInsets = NSEdgeInsetsMake(10, 0, 10, 0);
    return row;
}

-(NSStackView*)settingRow:(NSArray<NSString*>*)item
{
    NSSwitch* toggle = [[NSSwitch alloc] init];
    toggle.controlSize = NSControlSizeSmall;
    toggle.identifier = item[0];
    toggle.accessibilityLabel = item[1];
    toggle.state = [self.model.settings[item[0]] boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
    toggle.target = self; toggle.action = @selector(toggleSetting:);
    return [self settingsRow:item[1] detail:item[2] control:toggle];
}

-(NSView*)settingGroup:(NSString*)title items:(NSArray<NSArray<NSString*>*>*)items
{
    NSMutableArray* rows = [NSMutableArray array];
    for(NSArray* item in items) [rows addObject:[self settingRow:item]];
    return [self settingsGroup:title rows:rows];
}

-(void)buildSettings
{
    NSStackView* page = [self pageWithTitle:PreviewText(@"Settings") subtitle:PreviewText(@"Default profile · Sample preferences")];
    page.spacing = 26;
    NSPopUpButton* language = [[NSPopUpButton alloc] init];
    for(NSString* code in [@[@"system"] arrayByAddingObjectsFromArray:PreviewLanguageCodes()])
    {
        [language addItemWithTitle:PreviewLanguageName(code)];
        language.lastItem.representedObject = code;
        if([code isEqual:PreviewLanguageSelection()]) [language selectItem:language.lastItem];
    }
    language.target = self; language.action = @selector(changeLanguage:);
    language.accessibilityLabel = PreviewText(@"Language");
    AddWide(page, [self settingsGroup:nil rows:@[[self settingsRow:PreviewText(@"Language")
        detail:PreviewText(@"Language changes apply to this preview session.") control:language]]]);
    AddWide(page, [self settingGroup:PreviewText(@"Automatically allow") items:@[
        @[@"apple", PreviewText(@"Apple apps"), PreviewText(@"Connections from apps signed by Apple.")],
        @[@"installed", PreviewText(@"Previously installed apps"), PreviewText(@"Apps present before LuLu was installed.")],
        @[@"dns", @"DNS", PreviewText(@"Connections used to resolve domain names.")],
        @[@"localhost", PreviewText(@"Localhost connections"), PreviewText(@"Connections between apps on this Mac.")],
        @[@"simulator", PreviewText(@"iOS Simulator"), PreviewText(@"Apps running inside the simulator.")]
    ]]);
    AddWide(page, [self settingGroup:PreviewText(@"Operating mode") items:@[
        @[@"passive", PreviewText(@"Passive mode"), PreviewText(@"Handle unknown connections without showing alerts.")],
        @[@"block", PreviewText(@"Block mode"), PreviewText(@"Block new outgoing connections; existing connections are unaffected.")]
    ]]);
    AddWide(page, [self settingGroup:PreviewText(@"General") items:@[
        @[@"menubar", PreviewText(@"Menu bar icon"), PreviewText(@"Show LuLu in the menu bar.")],
        @[@"virustotal", PreviewText(@"VirusTotal lookup"), PreviewText(@"Offer a manual lookup from connection alerts.")],
        @[@"updates", PreviewText(@"Check for updates"), PreviewText(@"Get notified when an update is available.")]
    ]]);
}
-(void)changeLanguage:(NSPopUpButton*)sender { PreviewSetLanguage(sender.selectedItem.representedObject); }
-(void)toggleSetting:(NSSwitch*)sender { self.model.settings[sender.identifier] = @(sender.state == NSControlStateValueOn); }
@end
