// SPDX-License-Identifier: GPL-3.0-only
#import "PreviewController.h"
#import "PreviewModel.h"
#import "PreviewStyle.h"


static void ApplyDirection(NSView* view)
{
    BOOL technical = [view.identifier isEqual:@"technical"];
    view.userInterfaceLayoutDirection = PreviewRightToLeft() && !technical ? NSUserInterfaceLayoutDirectionRightToLeft : NSUserInterfaceLayoutDirectionLeftToRight;
    if([view isKindOfClass:NSControl.class])
    {
        NSControl* control = (NSControl*)view;
        control.baseWritingDirection = technical ? NSWritingDirectionLeftToRight : NSWritingDirectionNatural;
        control.alignment = technical ? NSTextAlignmentLeft : NSTextAlignmentNatural;
    }
    for(NSView* child in view.subviews) ApplyDirection(child);
}

static NSColor* StatusColor(BOOL allowed)
{
    return [NSColor colorWithName:allowed ? @"PreviewAllowed" : @"PreviewBlocked" dynamicProvider:^NSColor*(NSAppearance* appearance) {
        BOOL dark = [[appearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]] isEqual:NSAppearanceNameDarkAqua];
        if(dark) return allowed ? NSColor.systemGreenColor : NSColor.systemRedColor;
        return allowed ? [NSColor colorWithSRGBRed:0.16 green:0.43 blue:0.19 alpha:1] : [NSColor colorWithSRGBRed:0.65 green:0.18 blue:0.12 alpha:1];
    }];
}

static NSTextField* Label(NSString* text, CGFloat size, NSFontWeight weight)
{
    NSTextField* field = [NSTextField wrappingLabelWithString:text];
    field.font = [NSFont systemFontOfSize:size weight:weight];
    field.textColor = NSColor.labelColor;
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

static NSTextField* Technical(NSString* text)
{
    NSTextField* field = Secondary(text);
    field.identifier = @"technical";
    return field;
}

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

static void AddWide(NSStackView* stack, NSView* view)
{
    [stack addArrangedSubview:view];
    [view.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
}

static NSView* Spacer(void)
{
    NSView* view = [[NSView alloc] init];
    [view setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
    return view;
}

static NSImageView* AppIcon(NSString* path, NSString* fallback, CGFloat size)
{
    NSImageView* view = [[NSImageView alloc] init];
    if([NSFileManager.defaultManager fileExistsAtPath:path]) view.image = [NSWorkspace.sharedWorkspace iconForFile:path.stringByResolvingSymlinksInPath];
    else
    {
        view.image = [NSImage imageWithSystemSymbolName:fallback accessibilityDescription:nil];
        view.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:size * 0.65 weight:NSFontWeightRegular];
        view.contentTintColor = NSColor.secondaryLabelColor;
    }
    view.imageScaling = NSImageScaleProportionallyUpOrDown;
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.accessibilityElement = NO;
    [view.widthAnchor constraintEqualToConstant:size].active = YES;
    [view.heightAnchor constraintEqualToConstant:size].active = YES;
    return view;
}

static NSImageView* LuLuIcon(CGFloat size)
{
    NSImageView* icon = AppIcon(@"", @"shield.lefthalf.filled", size);
    icon.image = [[NSImage alloc] initWithContentsOfFile:[NSBundle.mainBundle pathForResource:@"LuLuIcon" ofType:@"png"]];
    icon.contentTintColor = nil;
    return icon;
}

static NSButton* Button(NSString* title, id target, SEL action)
{
    NSButton* button = [NSButton buttonWithTitle:title target:target action:action];
    button.bezelStyle = NSBezelStyleRounded;
    button.controlSize = NSControlSizeRegular;
    button.translatesAutoresizingMaskIntoConstraints = NO;
    return button;
}

@interface PreviewCanvas : NSView
@end
@implementation PreviewCanvas
-(void)drawRect:(NSRect)dirtyRect
{
    [PreviewCanvasColor() setFill];
    NSRectFill(NSIntersectionRect(dirtyRect, self.bounds));
}
-(void)viewDidChangeEffectiveAppearance { [super viewDidChangeEffectiveAppearance]; self.needsDisplay = YES; }
@end

@interface PreviewDocumentView : NSView
@end
@implementation PreviewDocumentView
-(BOOL)isFlipped { return YES; }
@end

@interface PreviewRuleCell : NSTableCellView
@property(nonatomic, strong) NSColor* statusColor;
@end
@implementation PreviewRuleCell
-(void)setBackgroundStyle:(NSBackgroundStyle)backgroundStyle
{
    [super setBackgroundStyle:backgroundStyle];
    if(self.statusColor)
        self.textField.textColor = backgroundStyle == NSBackgroundStyleEmphasized ? NSColor.alternateSelectedControlTextColor : self.statusColor;
}
@end

static NSView* Card(NSView* contents)
{
    return PreviewSurface(contents, 20);
}

@interface PreviewController ()
@property(nonatomic, strong) PreviewModel* model;
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
@property(nonatomic, strong) NSTextField* emptyLabel;
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
@property(nonatomic, strong) NSStackView* connectionDetails;
@end

@implementation PreviewController
-(instancetype)init
{
    NSWindow* window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1120, 740)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered defer:NO];
    self = [super initWithWindow:window];
    if(self)
    {
        self.model = [[PreviewModel alloc] init];
        window.title = @"LuLu Interface Preview";
        window.subtitle = PreviewText(@"Interface preview · Sample data");
        window.minSize = NSMakeSize(1000, 700);
        window.backgroundColor = PreviewCanvasColor();
        window.titlebarAppearsTransparent = YES;
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

-(void)buildShell
{
    NSView* root = self.window.contentView;
    NSVisualEffectView* backdrop = [[NSVisualEffectView alloc] init];
    backdrop.material = NSVisualEffectMaterialSidebar;
    backdrop.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    backdrop.state = NSVisualEffectStateFollowsWindowActiveState;
    Fill(backdrop, root, 0);

    NSStackView* brand = Stack(@[LuLuIcon(38),
        Stack(@[Label(@"LuLu", 20, NSFontWeightSemibold), Secondary(PreviewText(@"Interface preview"))], NSUserInterfaceLayoutOrientationVertical, 2)], NSUserInterfaceLayoutOrientationHorizontal, 12);
    NSStackView* navigation = Stack(@[brand], NSUserInterfaceLayoutOrientationVertical, 22);
    NSArray* titles = @[PreviewText(@"Overview"), PreviewText(@"App Rules"), PreviewText(@"Connection Alert"), PreviewText(@"Settings")];
    NSArray* symbols = @[@"square.grid.2x2", @"line.3.horizontal.decrease.circle", @"bell", @"gearshape"];
    NSMutableArray* buttons = [NSMutableArray array];
    for(NSUInteger index = 0; index < titles.count; index++)
    {
        NSButton* button = PreviewNavigationButton(titles[index], symbols[index], self, @selector(navigate:));
        button.tag = index;
        button.keyEquivalent = [NSString stringWithFormat:@"%lu", index + 1];
        button.keyEquivalentModifierMask = NSEventModifierFlagCommand;
        AddWide(navigation, button);
        [navigation setCustomSpacing:5 afterView:button];
        [buttons addObject:button];
    }
    self.navigation = buttons;
    NSView* gap = Spacer();
    [gap setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationVertical];
    NSStackView* footer = Stack(@[Secondary(PreviewText(@"Sample data")),
        Secondary(PreviewText(@"Firewall service disconnected")), PreviewDivider(), Secondary(@"Objective-See · GPL-3.0")], NSUserInterfaceLayoutOrientationVertical, 12);
    NSStackView* sidebarContent = Stack(@[navigation, gap, footer], NSUserInterfaceLayoutOrientationVertical, 20);
    [navigation.widthAnchor constraintEqualToAnchor:sidebarContent.widthAnchor].active = YES;
    [footer.widthAnchor constraintEqualToAnchor:sidebarContent.widthAnchor].active = YES;
    NSView* sidebar = PreviewGlass(sidebarContent, 18, 22);
    [root addSubview:sidebar];
    self.pageView = [[PreviewCanvas alloc] init];
    self.pageView.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:self.pageView];
    CGFloat sidebarWidth = 204;
    for(NSString* title in titles)
        sidebarWidth = MAX(sidebarWidth, ceil([title sizeWithAttributes:@{NSFontAttributeName: [NSFont systemFontOfSize:13.5 weight:NSFontWeightMedium]}].width) + 84);
    [NSLayoutConstraint activateConstraints:@[
        PreviewRightToLeft() ? [sidebar.rightAnchor constraintEqualToAnchor:root.rightAnchor constant:-12] : [sidebar.leftAnchor constraintEqualToAnchor:root.leftAnchor constant:12],
        [sidebar.topAnchor constraintEqualToAnchor:root.topAnchor constant:12],
        [sidebar.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-12],
        [sidebar.widthAnchor constraintEqualToConstant:sidebarWidth],
        PreviewRightToLeft() ? [self.pageView.rightAnchor constraintEqualToAnchor:sidebar.leftAnchor constant:-12] : [self.pageView.leftAnchor constraintEqualToAnchor:sidebar.rightAnchor constant:12],
        PreviewRightToLeft() ? [self.pageView.leftAnchor constraintEqualToAnchor:root.leftAnchor] : [self.pageView.rightAnchor constraintEqualToAnchor:root.rightAnchor],
        [self.pageView.topAnchor constraintEqualToAnchor:root.topAnchor],
        [self.pageView.bottomAnchor constraintEqualToAnchor:root.bottomAnchor]
    ]];
}

-(NSStackView*)pageWithTitle:(NSString*)title subtitle:(NSString*)subtitle
{
    for(NSView* view in self.pageView.subviews.copy) [view removeFromSuperview];
    NSScrollView* scroll = [[NSScrollView alloc] init];
    scroll.drawsBackground = NO;
    scroll.hasVerticalScroller = YES;
    scroll.autohidesScrollers = YES;
    scroll.borderType = NSNoBorder;
    Fill(scroll, self.pageView, 0);
    NSView* document = [[PreviewDocumentView alloc] init];
    document.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.documentView = document;
    NSStackView* stack = Stack(@[], NSUserInterfaceLayoutOrientationVertical, 20);
    Fill(stack, document, 24);
    [document.widthAnchor constraintEqualToAnchor:scroll.contentView.widthAnchor].active = YES;
    NSStackView* header = Stack(@[Label(title, 23, NSFontWeightSemibold), Secondary(subtitle)], NSUserInterfaceLayoutOrientationVertical, 6);
    AddWide(stack, header);
    return stack;
}

-(void)navigate:(NSButton*)sender { [self showPage:sender.tag]; }

-(void)showPage:(NSInteger)page
{
    if(self.currentPage == 1 && self.search) [self saveRuleViewState];
    self.currentPage = page;
    for(NSButton* button in self.navigation) button.state = button.tag == page ? NSControlStateValueOn : NSControlStateValueOff;
    if(page == 0) [self buildOverview];
    else if(page == 1) [self buildRules];
    else if(page == 2) [self buildConnections];
    else [self buildSettings];
    ApplyDirection(self.window.contentView);
}

-(void)buildOverview
{
    NSStackView* page = [self pageWithTitle:PreviewText(@"Overview") subtitle:PreviewText(@"Default profile · Sample data")];
    NSStackView* service = Stack(@[LuLuIcon(56),
        Stack(@[Label(PreviewText(@"Firewall service disconnected"), 18, NSFontWeightSemibold),
            Secondary(PreviewText(@"This preview does not monitor or block network connections."))], NSUserInterfaceLayoutOrientationVertical, 6)], NSUserInterfaceLayoutOrientationHorizontal, 16);
    AddWide(page, Card(service));
    NSUInteger allowed = [[self.model rulesMatching:@"" filter:1] count];
    NSUInteger blocked = [[self.model rulesMatching:@"" filter:2] count];
    NSUInteger disabled = [[self.model rulesMatching:@"" filter:3] count];
    NSStackView* rules = Stack(@[], NSUserInterfaceLayoutOrientationVertical, 12);
    AddWide(rules, Stack(@[Label(PreviewText(@"App Rules"), 15, NSFontWeightSemibold), Spacer(),
        Button(PreviewText(@"Manage Rules"), self, @selector(openRules:))], NSUserInterfaceLayoutOrientationHorizontal, 12));
    AddWide(rules, Secondary([NSString stringWithFormat:PreviewText(@"Rules: %@ · Allowed: %@ · Blocked: %@ · Disabled: %@"), PreviewNumber(self.model.rules.count), PreviewNumber(allowed), PreviewNumber(blocked), PreviewNumber(disabled)]));
    for(PreviewRule* rule in self.model.rules)
    {
        AddWide(rules, PreviewDivider());
        NSTextField* action = Label(!rule.enabled ? PreviewText(@"Disabled") : (rule.allowed ? PreviewText(@"Allow") : PreviewText(@"Block")), 12, NSFontWeightMedium);
        action.textColor = !rule.enabled ? NSColor.secondaryLabelColor : StatusColor(rule.allowed);
        NSTextField* endpoint = Secondary([rule.endpoint isEqual:@"*"] ? PreviewText(@"All destinations") : rule.endpoint);
        endpoint.identifier = [rule.endpoint isEqual:@"*"] ? nil : @"technical";
        endpoint.maximumNumberOfLines = 1;
        endpoint.lineBreakMode = NSLineBreakByTruncatingMiddle;
        AddWide(rules, Stack(@[AppIcon(rule.path, rule.symbol, 28), Label(rule.name, 13, NSFontWeightMedium), Spacer(), endpoint, action], NSUserInterfaceLayoutOrientationHorizontal, 14));
    }
    AddWide(page, Card(rules));
    AddWide(page, Stack(@[Secondary(PreviewText(@"Changes last for this preview session.")), Spacer(),
        Button(PreviewText(@"View Connection Alert"), self, @selector(openConnections:))], NSUserInterfaceLayoutOrientationHorizontal, 12));
}

-(void)openRules:(id)sender { [self showPage:1]; }
-(void)openConnections:(id)sender { [self showPage:2]; }

-(void)buildRules
{
    NSStackView* page = [self pageWithTitle:PreviewText(@"App Rules") subtitle:PreviewText(@"Default profile · Sample data")];
    self.search = [[NSSearchField alloc] init];
    self.search.stringValue = self.ruleQuery ?: @"";
    self.search.placeholderString = PreviewText(@"Search apps, paths or destinations");
    self.search.accessibilityLabel = self.search.placeholderString;
    self.search.delegate = self;
    self.search.translatesAutoresizingMaskIntoConstraints = NO;
    [self.search.widthAnchor constraintGreaterThanOrEqualToConstant:240].active = YES;
    NSButton* add = Button(PreviewText(@"Add Rule"), self, @selector(addRule:));
    add.image = [NSImage imageWithSystemSymbolName:@"plus" accessibilityDescription:nil];
    add.imagePosition = NSImageLeading;
    NSStackView* tools = Stack(@[Stack(@[self.search, add], NSUserInterfaceLayoutOrientationHorizontal, 12)], NSUserInterfaceLayoutOrientationVertical, 12);
    [tools.arrangedSubviews.firstObject.widthAnchor constraintEqualToAnchor:tools.widthAnchor].active = YES;
    self.filter = [NSSegmentedControl segmentedControlWithLabels:@[PreviewText(@"All"), PreviewText(@"Allowed"), PreviewText(@"Blocked"), PreviewText(@"Disabled")]
        trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(filterChanged:)];
    self.filter.selectedSegment = self.ruleFilter;
    self.filter.accessibilityLabel = PreviewText(@"Rule category");
    [tools addArrangedSubview:self.filter];
    AddWide(page, PreviewGlass(tools, 14, 18));

    self.table = [[NSTableView alloc] init];
    self.table.userInterfaceLayoutDirection = PreviewRightToLeft() ? NSUserInterfaceLayoutDirectionRightToLeft : NSUserInterfaceLayoutDirectionLeftToRight;
    self.table.style = NSTableViewStyleInset;
    self.table.rowHeight = 54;
    self.table.intercellSpacing = NSMakeSize(12, 4);
    self.table.headerView = nil;
    self.table.usesAlternatingRowBackgroundColors = NO;
    self.table.backgroundColor = PreviewSurfaceColor();
    self.table.columnAutoresizingStyle = NSTableViewFirstColumnOnlyAutoresizingStyle;
    self.table.delegate = self;
    self.table.dataSource = self;
    self.table.allowsEmptySelection = YES;
    self.table.accessibilityLabel = PreviewText(@"App rules list");
    CGFloat actionWidth = 70;
    for(NSString* key in @[@"Allow", @"Block", @"Disabled"])
        actionWidth = MAX(actionWidth, ceil([PreviewText(key) sizeWithAttributes:@{NSFontAttributeName: [NSFont systemFontOfSize:12 weight:NSFontWeightMedium]}].width) + 24);
    for(NSString* identifier in @[@"app", @"action"])
    {
        NSTableColumn* column = [[NSTableColumn alloc] initWithIdentifier:identifier];
        column.width = [identifier isEqual:@"app"] ? 380 : actionWidth;
        column.minWidth = [identifier isEqual:@"app"] ? 220 : actionWidth;
        if([identifier isEqual:@"action"]) column.maxWidth = actionWidth;
        [self.table addTableColumn:column];
    }
    NSScrollView* listScroll = [[NSScrollView alloc] init];
    listScroll.documentView = self.table;
    listScroll.hasVerticalScroller = YES;
    listScroll.autohidesScrollers = YES;
    listScroll.borderType = NSNoBorder;
    listScroll.translatesAutoresizingMaskIntoConstraints = NO;
    [listScroll.heightAnchor constraintEqualToConstant:372].active = YES;
    [listScroll.widthAnchor constraintGreaterThanOrEqualToConstant:330].active = YES;
    self.inspector = Stack(@[], NSUserInterfaceLayoutOrientationVertical, 12);
    NSView* inspectorCard = self.inspector;
    [inspectorCard.widthAnchor constraintEqualToConstant:216].active = YES;
    NSStackView* list = Stack(@[Stack(@[Secondary(PreviewText(@"APP / DESTINATION")), Spacer(), Secondary(PreviewText(@"ACTION"))], NSUserInterfaceLayoutOrientationHorizontal, 12), PreviewDivider(), listScroll], NSUserInterfaceLayoutOrientationVertical, 10);
    for(NSView* view in list.arrangedSubviews) [view.widthAnchor constraintEqualToAnchor:list.widthAnchor].active = YES;
    NSBox* separator = [[NSBox alloc] init];
    separator.boxType = NSBoxSeparator;
    separator.translatesAutoresizingMaskIntoConstraints = NO;
    [separator.widthAnchor constraintEqualToConstant:1].active = YES;
    NSStackView* columns = Stack(@[PreviewSurface(list, 12), separator, inspectorCard], NSUserInterfaceLayoutOrientationHorizontal, 20);
    [separator.heightAnchor constraintEqualToAnchor:columns.heightAnchor].active = YES;
    columns.alignment = NSLayoutAttributeTop;
    AddWide(page, columns);
    self.emptyLabel = Secondary(PreviewText(@"No matching rules. Try another search or category."));
    AddWide(page, self.emptyLabel);
    self.countLabel = Secondary(@"");
    AddWide(page, self.countLabel);
    [self refreshRules];
    [self.window makeFirstResponder:self.table];
}

-(void)refreshRules
{
    PreviewRule* previous = [self selectedRule] ?: self.ruleSelection;
    self.visibleRules = [self.model rulesMatching:self.search.stringValue filter:self.filter.selectedSegment];
    [self.table reloadData];
    NSUInteger selection = [self.visibleRules indexOfObjectIdenticalTo:previous];
    if(selection == NSNotFound && self.visibleRules.count > 0) selection = 0;
    if(selection != NSNotFound) [self.table selectRowIndexes:[NSIndexSet indexSetWithIndex:selection] byExtendingSelection:NO];
    self.emptyLabel.hidden = self.visibleRules.count != 0;
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
        NSTextField* name = Label(rule.name, 13, NSFontWeightSemibold);
        if(!rule.enabled) name.textColor = NSColor.secondaryLabelColor;
        NSString* endpoint = [rule.endpoint isEqual:@"*"] ? PreviewText(@"All destinations") : rule.endpoint;
        NSTextField* detail = Secondary(endpoint);
        detail.identifier = [rule.endpoint isEqual:@"*"] ? nil : @"technical";
        detail.maximumNumberOfLines = 1;
        detail.lineBreakMode = NSLineBreakByTruncatingMiddle;
        NSStackView* rowView = Stack(@[AppIcon(rule.path, rule.symbol, 32), Stack(@[name, detail], NSUserInterfaceLayoutOrientationVertical, 4)], NSUserInterfaceLayoutOrientationHorizontal, 12);
        Fill(rowView, cell, 7);
        cell.textField = name;
        cell.statusColor = name.textColor;
        cell.toolTip = rule.path;
    }
    else
    {
        NSTextField* status = Label(!rule.enabled ? PreviewText(@"Disabled") : (rule.allowed ? PreviewText(@"Allow") : PreviewText(@"Block")), 12, NSFontWeightMedium);
        status.textColor = !rule.enabled ? NSColor.secondaryLabelColor : StatusColor(rule.allowed);
        cell.statusColor = status.textColor;
        [cell addSubview:status];
        [NSLayoutConstraint activateConstraints:@[
            [status.leftAnchor constraintEqualToAnchor:cell.leftAnchor constant:8],
            [status.rightAnchor constraintEqualToAnchor:cell.rightAnchor constant:-8],
            [status.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor]
        ]];
        cell.textField = status;
    }
    ApplyDirection(cell);
    return cell;
}

-(void)tableViewSelectionDidChange:(NSNotification*)notification { [self updateInspector]; }
-(void)controlTextDidChange:(NSNotification*)notification { if(notification.object == self.search) [self refreshRules]; }
-(void)filterChanged:(id)sender { [self refreshRules]; }
-(void)focusSearch:(id)sender { [self showPage:1]; [self.window makeFirstResponder:self.search]; }

-(void)updateInspector
{
    for(NSView* view in self.inspector.arrangedSubviews.copy) { [self.inspector removeArrangedSubview:view]; [view removeFromSuperview]; }
    PreviewRule* rule = [self selectedRule];
    if(!rule) { [self.inspector addArrangedSubview:Secondary(PreviewText(@"Select a rule to see details"))]; return; }
    [self.inspector addArrangedSubview:AppIcon(rule.path, rule.symbol, 48)];
    AddWide(self.inspector, Label(rule.name, 18, NSFontWeightSemibold));
    [self.inspector addArrangedSubview:PreviewBadge(!rule.enabled ? PreviewText(@"Disabled") : (rule.allowed ? PreviewText(@"Allow") : PreviewText(@"Block")), !rule.enabled ? NSColor.secondaryLabelColor : StatusColor(rule.allowed))];
    AddWide(self.inspector, PreviewDivider());
    [self.inspector addArrangedSubview:Secondary(PreviewText(@"APP PATH"))];
    NSTextField* path = Label(rule.path, 11, NSFontWeightRegular); path.selectable = YES;
    path.identifier = @"technical";
    AddWide(self.inspector, path);
    [self.inspector addArrangedSubview:Secondary(PreviewText(@"DESTINATION"))];
    NSTextField* endpoint = Label([rule.endpoint isEqual:@"*"] ? PreviewText(@"All destinations") : rule.endpoint, 12, NSFontWeightMedium); endpoint.selectable = YES;
    endpoint.identifier = [rule.endpoint isEqual:@"*"] ? nil : @"technical";
    AddWide(self.inspector, endpoint);
    NSPopUpButton* action = [[NSPopUpButton alloc] init];
    [action addItemsWithTitles:@[PreviewText(@"Allow connection"), PreviewText(@"Block connection")]];
    [action selectItemAtIndex:rule.allowed ? 0 : 1];
    action.target = self; action.action = @selector(changeAction:);
    action.accessibilityLabel = PreviewText(@"Connection action");
    AddWide(self.inspector, action);
    NSButton* enabled = [NSButton checkboxWithTitle:PreviewText(@"Enable this rule") target:self action:@selector(changeEnabled:)];
    enabled.state = rule.enabled ? NSControlStateValueOn : NSControlStateValueOff;
    [self.inspector addArrangedSubview:enabled];
    [self.inspector addArrangedSubview:Button(PreviewText(@"Delete Rule"), self, @selector(deleteRule:))];
    ApplyDirection(self.inspector);
}

-(void)changeAction:(NSPopUpButton*)sender
{
    [self.window makeFirstResponder:self.table];
    PreviewRule* rule = [self selectedRule];
    if(rule) [self.model setAllowed:sender.indexOfSelectedItem == 0 forRule:rule];
    [self refreshRules];
}
-(void)changeEnabled:(NSButton*)sender
{
    [self.window makeFirstResponder:self.table];
    PreviewRule* rule = [self selectedRule];
    if(rule) [self.model setEnabled:sender.state == NSControlStateValueOn forRule:rule];
    [self refreshRules];
}
-(void)deleteRule:(id)sender
{
    [self.window makeFirstResponder:self.table];
    PreviewRule* rule = [self selectedRule];
    if(rule) [self.model removeRule:rule];
    [self refreshRules];
}
-(NSUndoManager*)windowWillReturnUndoManager:(NSWindow*)window { return self.model.undoManager; }
-(void)undo:(id)sender { [self.model.undoManager undo]; [self showPage:self.currentPage]; }
-(void)redo:(id)sender { [self.model.undoManager redo]; [self showPage:self.currentPage]; }

-(NSStackView*)beginSheetWithTitle:(NSString*)title
{
    self.sheet = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 540, 480) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
    self.sheet.title = @"LuLu Interface Preview";
    NSStackView* stack = Stack(@[Secondary(PreviewText(@"Preview mode · Sample data")), Label(title, 23, NSFontWeightBold)], NSUserInterfaceLayoutOrientationVertical, 18);
    self.sheetStack = stack;
    [self.sheet.contentView addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leftAnchor constraintEqualToAnchor:self.sheet.contentView.leftAnchor constant:28],
        [stack.rightAnchor constraintEqualToAnchor:self.sheet.contentView.rightAnchor constant:-28],
        [stack.topAnchor constraintEqualToAnchor:self.sheet.contentView.topAnchor constant:28]
    ]];
    return stack;
}

-(void)resizeSheet
{
    [self.sheet.contentView layoutSubtreeIfNeeded];
    [self.sheet setContentSize:NSMakeSize(self.sheet.contentView.frame.size.width, self.sheetStack.fittingSize.height + 56)];
}

-(NSTextField*)inputWithValue:(NSString*)value label:(NSString*)label stack:(NSStackView*)stack
{
    NSTextField* input = [NSTextField textFieldWithString:value];
    input.accessibilityLabel = label;
    if([value hasPrefix:@"/"] || [value isEqual:@"*"]) input.identifier = @"technical";
    AddWide(stack, Stack(@[Secondary(label), input], NSUserInterfaceLayoutOrientationVertical, 6));
    [input.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
    return input;
}

-(void)addRule:(id)sender
{
    NSStackView* stack = [self beginSheetWithTitle:PreviewText(@"Add Rule")];
    self.nameInput = [self inputWithValue:@"" label:PreviewText(@"App name") stack:stack];
    self.pathInput = [self inputWithValue:@"/Applications/" label:PreviewText(@"Full app path") stack:stack];
    self.endpointInput = [self inputWithValue:@"*" label:PreviewText(@"Destination (* for all)") stack:stack];
    self.actionInput = [[NSPopUpButton alloc] init];
    [self.actionInput addItemsWithTitles:@[PreviewText(@"Allow connection"), PreviewText(@"Block connection")]];
    self.actionInput.accessibilityLabel = PreviewText(@"Connection action");
    AddWide(stack, self.actionInput);
    self.formError = Secondary(@""); self.formError.textColor = NSColor.systemRedColor;
    AddWide(stack, self.formError);
    NSButton* cancel = Button(PreviewText(@"Cancel"), self, @selector(cancelSheet:)); cancel.keyEquivalent = @"\e";
    NSButton* save = Button(PreviewText(@"Add"), self, @selector(saveRule:)); save.keyEquivalent = @"\r";
    AddWide(stack, Stack(@[Spacer(), cancel, save], NSUserInterfaceLayoutOrientationHorizontal, 8));
    [self resizeSheet];
    ApplyDirection(self.sheet.contentView);
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
        self.formError.stringValue = PreviewText(@"Enter a name, a full app path and a destination.");
        [self resizeSheet];
        NSAccessibilityPostNotification(self.formError, NSAccessibilityValueChangedNotification);
        return;
    }
    PreviewRule* rule = [[PreviewRule alloc] init];
    rule.name = name; rule.path = path; rule.endpoint = endpoint; rule.symbol = @"app";
    rule.allowed = self.actionInput.indexOfSelectedItem == 0; rule.enabled = YES;
    [self.model addRule:rule];
    [self cancelSheet:nil];
    self.search.stringValue = @""; self.filter.selectedSegment = 0;
    [self refreshRules];
    [self.table selectRowIndexes:[NSIndexSet indexSetWithIndex:self.visibleRules.count - 1] byExtendingSelection:NO];
    [self.table scrollRowToVisible:self.visibleRules.count - 1];
}

-(void)buildConnections
{
    NSStackView* page = [self pageWithTitle:PreviewText(@"Connection Alert") subtitle:PreviewText(@"Sample connection request")];
    NSStackView* content = Stack(@[AppIcon(@"", @"curlybraces", 48),
        Label(@"Sample Editor", 19, NSFontWeightSemibold),
        Secondary(PreviewText(@"Sample Editor wants to connect to updates.example.com.")),
        Button(PreviewText(@"Open Sample Alert"), self, @selector(showConnection:))], NSUserInterfaceLayoutOrientationVertical, 16);
    AddWide(page, PreviewSurface(content, 24));
    self.noticeLabel = Secondary([self decisionSummary]);
    AddWide(page, self.noticeLabel);
}

-(void)showConnection:(id)sender
{
    NSStackView* stack = [self beginSheetWithTitle:PreviewText(@"Allow this connection?")];
    [stack addArrangedSubview:Stack(@[AppIcon(@"", @"curlybraces", 40),
        Stack(@[Label(@"Sample Editor", 17, NSFontWeightSemibold), Secondary(PreviewText(@"Requests an outgoing connection"))], NSUserInterfaceLayoutOrientationVertical, 4)], NSUserInterfaceLayoutOrientationHorizontal, 12)];
    NSTextField* hostname = Label(@"updates.example.com", 18, NSFontWeightMedium);
    hostname.identifier = @"technical";
    NSStackView* destination = Stack(@[Secondary(PreviewText(@"DESTINATION")), hostname, Technical(@"TCP · 443 · HTTPS")], NSUserInterfaceLayoutOrientationVertical, 5);
    AddWide(stack, Card(destination));
    self.scopeInput = [[NSPopUpButton alloc] init];
    [self.scopeInput addItemsWithTitles:@[PreviewText(@"This destination"), PreviewText(@"All connections from this app"), PreviewText(@"This app and child processes")]];
    self.scopeInput.accessibilityLabel = PreviewText(@"Rule scope");
    self.durationInput = [[NSPopUpButton alloc] init];
    [self.durationInput addItemsWithTitles:@[PreviewText(@"Just once"), PreviewText(@"Until the app quits"), PreviewText(@"Always"), PreviewText(@"Custom duration")]];
    self.durationInput.target = self; self.durationInput.action = @selector(durationChanged:);
    self.durationInput.accessibilityLabel = PreviewText(@"Duration");
    NSStackView* scopeRow = Stack(@[Secondary(PreviewText(@"Applies to")), Spacer(), self.scopeInput], NSUserInterfaceLayoutOrientationHorizontal, 10);
    NSStackView* durationRow = Stack(@[Secondary(PreviewText(@"Duration")), Spacer(), self.durationInput], NSUserInterfaceLayoutOrientationHorizontal, 10);
    AddWide(stack, scopeRow); AddWide(stack, durationRow);
    self.minutesInput = [NSTextField textFieldWithString:@"15"];
    self.minutesInput.identifier = @"technical";
    self.minutesInput.placeholderString = PreviewText(@"Minutes (1–1440)");
    self.minutesInput.accessibilityLabel = self.minutesInput.placeholderString;
    self.minutesInput.hidden = YES;
    AddWide(stack, self.minutesInput);
    NSButton* details = [NSButton checkboxWithTitle:PreviewText(@"Show app details") target:self action:@selector(toggleConnectionDetails:)];
    [stack addArrangedSubview:details];
    self.connectionDetails = Stack(@[Technical(@"/Applications/Sample Editor.app"), Secondary(PreviewText(@"Signature: Not verified"))], NSUserInterfaceLayoutOrientationVertical, 5);
    self.connectionDetails.hidden = YES;
    AddWide(stack, self.connectionDetails);
    self.formError = Secondary(@""); self.formError.textColor = NSColor.systemRedColor;
    AddWide(stack, self.formError);
    NSButton* cancel = Button(PreviewText(@"Cancel"), self, @selector(cancelSheet:)); cancel.keyEquivalent = @"\e";
    NSButton* block = Button(PreviewText(@"Block Connection"), self, @selector(respondToConnection:)); block.tag = 0;
    NSButton* allow = Button(PreviewText(@"Allow Connection"), self, @selector(respondToConnection:)); allow.tag = 1;
    AddWide(stack, Stack(@[cancel, Spacer(), block, allow], NSUserInterfaceLayoutOrientationHorizontal, 8));
    [self.sheet setContentSize:NSMakeSize(560, 610)];
    [self resizeSheet];
    ApplyDirection(self.sheet.contentView);
    [self.window beginSheet:self.sheet completionHandler:nil];
}
-(void)durationChanged:(id)sender { self.minutesInput.hidden = self.durationInput.indexOfSelectedItem != 3; [self resizeSheet]; }
-(void)toggleConnectionDetails:(NSButton*)sender { self.connectionDetails.hidden = sender.state != NSControlStateValueOn; [self resizeSheet]; }
-(void)respondToConnection:(NSButton*)sender
{
    if(self.durationInput.indexOfSelectedItem == 3)
    {
        NSScanner* scanner = [NSScanner scannerWithString:self.minutesInput.stringValue];
        NSInteger minutes = 0;
        if(![scanner scanInteger:&minutes] || !scanner.isAtEnd || minutes < 1 || minutes > 1440)
        {
            self.formError.stringValue = PreviewText(@"Enter a whole number from 1 to 1440 minutes.");
            [self resizeSheet];
            return;
        }
    }
    self.lastDecision = @{@"allowed": @(sender.tag == 1), @"scope": @(self.scopeInput.indexOfSelectedItem),
        @"duration": @(self.durationInput.indexOfSelectedItem), @"minutes": @(self.minutesInput.integerValue)};
    self.noticeLabel.stringValue = [self decisionSummary];
    [self cancelSheet:nil];
}

-(NSString*)decisionSummary
{
    if(!self.lastDecision) return PreviewText(@"No decision yet");
    NSArray* scopes = @[@"This destination", @"All connections from this app", @"This app and child processes"];
    NSArray* durations = @[@"Just once", @"Until the app quits", @"Always"];
    NSUInteger durationIndex = [self.lastDecision[@"duration"] unsignedIntegerValue];
    NSString* duration = durationIndex == 3 ? [NSString stringWithFormat:PreviewText(@"%@ min"), PreviewNumber([self.lastDecision[@"minutes"] unsignedIntegerValue])] : PreviewText(durations[durationIndex]);
    return [NSString stringWithFormat:PreviewText(@"Sample decision: %1$@ · %2$@ · %3$@"),
        PreviewText([self.lastDecision[@"allowed"] boolValue] ? @"Allow" : @"Block"),
        PreviewText(scopes[[self.lastDecision[@"scope"] unsignedIntegerValue]]), duration];
}

-(NSView*)settingGroup:(NSString*)title items:(NSArray<NSArray<NSString*>*>*)items
{
    NSString* symbol = [items.firstObject.firstObject isEqual:@"apple"] ? @"checkmark.shield" : ([items.firstObject.firstObject isEqual:@"passive"] ? @"slider.horizontal.3" : @"gearshape");
    NSStackView* group = Stack(@[Stack(@[PreviewSymbol(symbol, 28, NSColor.secondaryLabelColor), Label(title, 16, NSFontWeightSemibold)], NSUserInterfaceLayoutOrientationHorizontal, 12)], NSUserInterfaceLayoutOrientationVertical, 14);
    for(NSArray* item in items)
    {
        AddWide(group, PreviewDivider());
        NSSwitch* toggle = [[NSSwitch alloc] init];
        toggle.identifier = item[0];
        toggle.accessibilityLabel = item[1];
        toggle.state = [self.model.settings[item[0]] boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
        toggle.target = self; toggle.action = @selector(toggleSetting:);
        NSStackView* copy = Stack(@[Label(item[1], 13, NSFontWeightMedium), Secondary(item[2])], NSUserInterfaceLayoutOrientationVertical, 4);
        NSStackView* row = Stack(@[copy, Spacer(), toggle], NSUserInterfaceLayoutOrientationHorizontal, 20);
        AddWide(group, row);
    }
    return Card(group);
}

-(void)buildSettings
{
    NSStackView* page = [self pageWithTitle:PreviewText(@"Settings") subtitle:PreviewText(@"Default profile · Sample preferences")];
    NSPopUpButton* language = [[NSPopUpButton alloc] init];
    for(NSString* code in [@[@"system"] arrayByAddingObjectsFromArray:PreviewLanguageCodes()])
    {
        [language addItemWithTitle:PreviewLanguageName(code)];
        language.lastItem.representedObject = code;
        if([code isEqual:PreviewLanguageSelection()]) [language selectItem:language.lastItem];
    }
    language.target = self; language.action = @selector(changeLanguage:);
    language.accessibilityLabel = PreviewText(@"Language");
    NSStackView* languageCopy = Stack(@[Label(PreviewText(@"Language"), 14, NSFontWeightMedium),
        Secondary(PreviewText(@"Language changes apply to this preview session."))], NSUserInterfaceLayoutOrientationVertical, 4);
    AddWide(page, Card(Stack(@[languageCopy, Spacer(), language], NSUserInterfaceLayoutOrientationHorizontal, 20)));
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
