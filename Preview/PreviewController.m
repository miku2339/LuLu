// SPDX-License-Identifier: GPL-3.0-only
#import "PreviewController.h"
#import "PreviewModel.h"
#import "PreviewStyle.h"

#define T(zh, en) PreviewText(zh, en)

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

static NSStackView* Stack(NSArray<NSView*>* views, NSUserInterfaceLayoutOrientation orientation, CGFloat spacing)
{
    NSStackView* stack = [NSStackView stackViewWithViews:views];
    stack.orientation = orientation;
    stack.alignment = orientation == NSUserInterfaceLayoutOrientationVertical ? NSLayoutAttributeLeading : NSLayoutAttributeCenterY;
    stack.spacing = spacing;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    return stack;
}

static void Fill(NSView* child, NSView* parent, CGFloat padding)
{
    child.translatesAutoresizingMaskIntoConstraints = NO;
    [parent addSubview:child];
    [NSLayoutConstraint activateConstraints:@[
        [child.leadingAnchor constraintEqualToAnchor:parent.leadingAnchor constant:padding],
        [child.trailingAnchor constraintEqualToAnchor:parent.trailingAnchor constant:-padding],
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
@property(nonatomic, strong) NSStackView* inspector;
@property(nonatomic, strong) NSTextField* countLabel;
@property(nonatomic, strong) NSTextField* emptyLabel;
@property(nonatomic, strong) NSTextField* noticeLabel;
@property(nonatomic, copy) NSString* lastDecision;
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
        window.subtitle = T(@"介面預覽 · 範例資料", @"Interface preview · Sample data");
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

-(void)buildShell
{
    NSView* root = self.window.contentView;
    NSVisualEffectView* backdrop = [[NSVisualEffectView alloc] init];
    backdrop.material = NSVisualEffectMaterialSidebar;
    backdrop.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    backdrop.state = NSVisualEffectStateFollowsWindowActiveState;
    Fill(backdrop, root, 0);

    NSStackView* brand = Stack(@[LuLuIcon(38),
        Stack(@[Label(@"LuLu", 20, NSFontWeightSemibold), Secondary(T(@"介面預覽", @"Interface preview"))], NSUserInterfaceLayoutOrientationVertical, 2)], NSUserInterfaceLayoutOrientationHorizontal, 12);
    NSStackView* navigation = Stack(@[brand], NSUserInterfaceLayoutOrientationVertical, 22);
    NSArray* titles = @[T(@"總覽", @"Overview"), T(@"程式規則", @"App Rules"), T(@"連線提示", @"Connection Alert"), T(@"設定", @"Settings")];
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
    NSStackView* footer = Stack(@[Secondary(T(@"範例資料", @"Sample data")),
        Secondary(T(@"未連接防護服務", @"Firewall service disconnected")), PreviewDivider(), Secondary(@"Objective-See · GPL-3.0")], NSUserInterfaceLayoutOrientationVertical, 12);
    NSStackView* sidebarContent = Stack(@[navigation, gap, footer], NSUserInterfaceLayoutOrientationVertical, 20);
    [navigation.widthAnchor constraintEqualToAnchor:sidebarContent.widthAnchor].active = YES;
    [footer.widthAnchor constraintEqualToAnchor:sidebarContent.widthAnchor].active = YES;
    NSView* sidebar = PreviewGlass(sidebarContent, 18, 22);
    [root addSubview:sidebar];
    self.pageView = [[PreviewCanvas alloc] init];
    self.pageView.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:self.pageView];
    [NSLayoutConstraint activateConstraints:@[
        [sidebar.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:12],
        [sidebar.topAnchor constraintEqualToAnchor:root.topAnchor constant:12],
        [sidebar.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-12],
        [sidebar.widthAnchor constraintEqualToConstant:204],
        [self.pageView.leadingAnchor constraintEqualToAnchor:sidebar.trailingAnchor constant:12],
        [self.pageView.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
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
    self.currentPage = page;
    for(NSButton* button in self.navigation) button.state = button.tag == page ? NSControlStateValueOn : NSControlStateValueOff;
    if(page == 0) [self buildOverview];
    else if(page == 1) [self buildRules];
    else if(page == 2) [self buildConnections];
    else [self buildSettings];
}

-(void)buildOverview
{
    NSStackView* page = [self pageWithTitle:T(@"總覽", @"Overview") subtitle:T(@"預設設定檔 · 範例資料", @"Default profile · Sample data")];
    NSStackView* service = Stack(@[LuLuIcon(56),
        Stack(@[Label(T(@"防護服務未連接", @"Firewall service disconnected"), 18, NSFontWeightSemibold),
            Secondary(T(@"此預覽不會監控或攔截網絡連線。", @"This preview does not monitor or block network connections."))], NSUserInterfaceLayoutOrientationVertical, 6)], NSUserInterfaceLayoutOrientationHorizontal, 16);
    AddWide(page, Card(service));
    NSUInteger allowed = [[self.model rulesMatching:@"" filter:1] count];
    NSUInteger blocked = [[self.model rulesMatching:@"" filter:2] count];
    NSUInteger disabled = [[self.model rulesMatching:@"" filter:3] count];
    NSStackView* rules = Stack(@[], NSUserInterfaceLayoutOrientationVertical, 12);
    AddWide(rules, Stack(@[Label(T(@"程式規則", @"App Rules"), 15, NSFontWeightSemibold), Spacer(),
        Button(T(@"管理規則", @"Manage Rules"), self, @selector(openRules:))], NSUserInterfaceLayoutOrientationHorizontal, 12));
    AddWide(rules, Secondary([NSString stringWithFormat:T(@"%lu 項規則　·　%lu 允許　·　%lu 封鎖　·　%lu 已停用", @"%lu rules  ·  %lu allowed  ·  %lu blocked  ·  %lu disabled"), self.model.rules.count, allowed, blocked, disabled]));
    for(PreviewRule* rule in self.model.rules)
    {
        AddWide(rules, PreviewDivider());
        NSTextField* action = Label(!rule.enabled ? T(@"已停用", @"Disabled") : (rule.allowed ? T(@"允許", @"Allow") : T(@"封鎖", @"Block")), 12, NSFontWeightMedium);
        action.textColor = !rule.enabled ? NSColor.secondaryLabelColor : StatusColor(rule.allowed);
        NSTextField* endpoint = Secondary([rule.endpoint isEqual:@"*"] ? T(@"所有目的地", @"All destinations") : rule.endpoint);
        endpoint.maximumNumberOfLines = 1;
        endpoint.lineBreakMode = NSLineBreakByTruncatingMiddle;
        AddWide(rules, Stack(@[AppIcon(rule.path, rule.symbol, 28), Label(rule.name, 13, NSFontWeightMedium), Spacer(), endpoint, action], NSUserInterfaceLayoutOrientationHorizontal, 14));
    }
    AddWide(page, Card(rules));
    AddWide(page, Stack(@[Secondary(T(@"所有變更只在本次預覽保留。", @"Changes last for this preview session.")), Spacer(),
        Button(T(@"檢視連線提示", @"View Connection Alert"), self, @selector(openConnections:))], NSUserInterfaceLayoutOrientationHorizontal, 12));
}

-(void)openRules:(id)sender { [self showPage:1]; }
-(void)openConnections:(id)sender { [self showPage:2]; }

-(void)buildRules
{
    NSStackView* page = [self pageWithTitle:T(@"程式規則", @"App Rules") subtitle:T(@"預設設定檔 · 範例資料", @"Default profile · Sample data")];
    self.search = [[NSSearchField alloc] init];
    self.search.placeholderString = T(@"搜尋程式、路徑或目的地", @"Search apps, paths or destinations");
    self.search.accessibilityLabel = self.search.placeholderString;
    self.search.delegate = self;
    self.search.translatesAutoresizingMaskIntoConstraints = NO;
    [self.search.widthAnchor constraintGreaterThanOrEqualToConstant:240].active = YES;
    NSButton* add = Button(T(@"新增規則", @"Add Rule"), self, @selector(addRule:));
    add.image = [NSImage imageWithSystemSymbolName:@"plus" accessibilityDescription:nil];
    add.imagePosition = NSImageLeading;
    NSStackView* tools = Stack(@[Stack(@[self.search, add], NSUserInterfaceLayoutOrientationHorizontal, 12)], NSUserInterfaceLayoutOrientationVertical, 12);
    [tools.arrangedSubviews.firstObject.widthAnchor constraintEqualToAnchor:tools.widthAnchor].active = YES;
    self.filter = [NSSegmentedControl segmentedControlWithLabels:@[T(@"全部", @"All"), T(@"允許", @"Allowed"), T(@"封鎖", @"Blocked"), T(@"已停用", @"Disabled")]
        trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(filterChanged:)];
    self.filter.selectedSegment = 0;
    self.filter.accessibilityLabel = T(@"規則類別", @"Rule category");
    [tools addArrangedSubview:self.filter];
    AddWide(page, PreviewGlass(tools, 14, 18));

    self.table = [[NSTableView alloc] init];
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
    self.table.accessibilityLabel = T(@"程式規則列表", @"App rules list");
    for(NSString* identifier in @[@"app", @"action"])
    {
        NSTableColumn* column = [[NSTableColumn alloc] initWithIdentifier:identifier];
        column.width = [identifier isEqual:@"app"] ? 380 : 70;
        column.minWidth = [identifier isEqual:@"app"] ? 220 : 70;
        if([identifier isEqual:@"action"]) column.maxWidth = 80;
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
    NSStackView* list = Stack(@[Stack(@[Secondary(T(@"程式 / 目的地", @"APP / DESTINATION")), Spacer(), Secondary(T(@"動作", @"ACTION"))], NSUserInterfaceLayoutOrientationHorizontal, 12), PreviewDivider(), listScroll], NSUserInterfaceLayoutOrientationVertical, 10);
    for(NSView* view in list.arrangedSubviews) [view.widthAnchor constraintEqualToAnchor:list.widthAnchor].active = YES;
    NSBox* separator = [[NSBox alloc] init];
    separator.boxType = NSBoxSeparator;
    separator.translatesAutoresizingMaskIntoConstraints = NO;
    [separator.widthAnchor constraintEqualToConstant:1].active = YES;
    NSStackView* columns = Stack(@[PreviewSurface(list, 12), separator, inspectorCard], NSUserInterfaceLayoutOrientationHorizontal, 20);
    [separator.heightAnchor constraintEqualToAnchor:columns.heightAnchor].active = YES;
    columns.alignment = NSLayoutAttributeTop;
    AddWide(page, columns);
    self.emptyLabel = Secondary(T(@"沒有符合條件的規則。試試其他關鍵字或類別。", @"No matching rules. Try another search or category."));
    AddWide(page, self.emptyLabel);
    self.countLabel = Secondary(@"");
    AddWide(page, self.countLabel);
    [self refreshRules];
    [self.window makeFirstResponder:self.table];
}

-(void)refreshRules
{
    PreviewRule* previous = [self selectedRule];
    self.visibleRules = [self.model rulesMatching:self.search.stringValue filter:self.filter.selectedSegment];
    [self.table reloadData];
    NSUInteger selection = [self.visibleRules indexOfObjectIdenticalTo:previous];
    if(selection == NSNotFound && self.visibleRules.count > 0) selection = 0;
    if(selection != NSNotFound) [self.table selectRowIndexes:[NSIndexSet indexSetWithIndex:selection] byExtendingSelection:NO];
    self.emptyLabel.hidden = self.visibleRules.count != 0;
    self.countLabel.stringValue = [NSString stringWithFormat:T(@"%lu 項規則 · 範例資料", @"%lu rules · Sample data"), self.visibleRules.count];
    [self updateInspector];
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
        NSString* endpoint = [rule.endpoint isEqual:@"*"] ? T(@"所有目的地", @"All destinations") : rule.endpoint;
        NSTextField* detail = Secondary(endpoint);
        detail.maximumNumberOfLines = 1;
        detail.lineBreakMode = NSLineBreakByTruncatingMiddle;
        NSStackView* rowView = Stack(@[AppIcon(rule.path, rule.symbol, 32), Stack(@[name, detail], NSUserInterfaceLayoutOrientationVertical, 4)], NSUserInterfaceLayoutOrientationHorizontal, 12);
        Fill(rowView, cell, 7);
        cell.textField = name;
        cell.toolTip = rule.path;
    }
    else
    {
        NSTextField* status = Label(!rule.enabled ? T(@"已停用", @"Disabled") : (rule.allowed ? T(@"允許", @"Allow") : T(@"封鎖", @"Block")), 12, NSFontWeightMedium);
        status.textColor = !rule.enabled ? NSColor.secondaryLabelColor : StatusColor(rule.allowed);
        cell.statusColor = status.textColor;
        [cell addSubview:status];
        [NSLayoutConstraint activateConstraints:@[
            [status.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:8],
            [status.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-8],
            [status.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor]
        ]];
        cell.textField = status;
    }
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
    if(!rule) { [self.inspector addArrangedSubview:Secondary(T(@"選取規則以查看詳情", @"Select a rule to see details"))]; return; }
    [self.inspector addArrangedSubview:AppIcon(rule.path, rule.symbol, 48)];
    AddWide(self.inspector, Label(rule.name, 18, NSFontWeightSemibold));
    [self.inspector addArrangedSubview:PreviewBadge(!rule.enabled ? T(@"已停用", @"Disabled") : (rule.allowed ? T(@"允許", @"Allow") : T(@"封鎖", @"Block")), !rule.enabled ? NSColor.secondaryLabelColor : StatusColor(rule.allowed))];
    AddWide(self.inspector, PreviewDivider());
    [self.inspector addArrangedSubview:Secondary(T(@"程式路徑", @"APP PATH"))];
    NSTextField* path = Label(rule.path, 11, NSFontWeightRegular); path.selectable = YES;
    AddWide(self.inspector, path);
    [self.inspector addArrangedSubview:Secondary(T(@"目的地", @"DESTINATION"))];
    NSTextField* endpoint = Label([rule.endpoint isEqual:@"*"] ? T(@"所有目的地", @"All destinations") : rule.endpoint, 12, NSFontWeightMedium); endpoint.selectable = YES;
    AddWide(self.inspector, endpoint);
    NSPopUpButton* action = [[NSPopUpButton alloc] init];
    [action addItemsWithTitles:@[T(@"允許連線", @"Allow connection"), T(@"封鎖連線", @"Block connection")]];
    [action selectItemAtIndex:rule.allowed ? 0 : 1];
    action.target = self; action.action = @selector(changeAction:);
    action.accessibilityLabel = T(@"連線動作", @"Connection action");
    AddWide(self.inspector, action);
    NSButton* enabled = [NSButton checkboxWithTitle:T(@"啟用此規則", @"Enable this rule") target:self action:@selector(changeEnabled:)];
    enabled.state = rule.enabled ? NSControlStateValueOn : NSControlStateValueOff;
    [self.inspector addArrangedSubview:enabled];
    [self.inspector addArrangedSubview:Button(T(@"刪除規則", @"Delete Rule"), self, @selector(deleteRule:))];
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
    NSStackView* stack = Stack(@[Secondary(T(@"預覽模式 · 範例資料", @"Preview mode · Sample data")), Label(title, 23, NSFontWeightBold)], NSUserInterfaceLayoutOrientationVertical, 18);
    self.sheetStack = stack;
    [self.sheet.contentView addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.sheet.contentView.leadingAnchor constant:28],
        [stack.trailingAnchor constraintEqualToAnchor:self.sheet.contentView.trailingAnchor constant:-28],
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
    AddWide(stack, Stack(@[Secondary(label), input], NSUserInterfaceLayoutOrientationVertical, 6));
    [input.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
    return input;
}

-(void)addRule:(id)sender
{
    NSStackView* stack = [self beginSheetWithTitle:T(@"新增規則", @"Add Rule")];
    self.nameInput = [self inputWithValue:@"" label:T(@"程式名稱", @"App name") stack:stack];
    self.pathInput = [self inputWithValue:@"/Applications/" label:T(@"完整程式路徑", @"Full app path") stack:stack];
    self.endpointInput = [self inputWithValue:@"*" label:T(@"目的地（* 代表全部）", @"Destination (* for all)") stack:stack];
    self.actionInput = [[NSPopUpButton alloc] init];
    [self.actionInput addItemsWithTitles:@[T(@"允許連線", @"Allow connection"), T(@"封鎖連線", @"Block connection")]];
    self.actionInput.accessibilityLabel = T(@"連線動作", @"Connection action");
    AddWide(stack, self.actionInput);
    self.formError = Secondary(@""); self.formError.textColor = NSColor.systemRedColor;
    AddWide(stack, self.formError);
    NSButton* cancel = Button(T(@"取消", @"Cancel"), self, @selector(cancelSheet:)); cancel.keyEquivalent = @"\e";
    NSButton* save = Button(T(@"新增", @"Add"), self, @selector(saveRule:)); save.keyEquivalent = @"\r";
    AddWide(stack, Stack(@[Spacer(), cancel, save], NSUserInterfaceLayoutOrientationHorizontal, 8));
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
        self.formError.stringValue = T(@"請填寫名稱、完整程式路徑及目的地。", @"Enter a name, a full app path and a destination.");
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
    NSStackView* page = [self pageWithTitle:T(@"連線提示", @"Connection Alert") subtitle:T(@"範例連線要求", @"Sample connection request")];
    NSStackView* content = Stack(@[AppIcon(@"", @"curlybraces", 48),
        Label(@"Sample Editor", 19, NSFontWeightSemibold),
        Secondary(T(@"Sample Editor 想連線至 updates.example.com。", @"Sample Editor wants to connect to updates.example.com.")),
        Button(T(@"開啟範例提示", @"Open Sample Alert"), self, @selector(showConnection:))], NSUserInterfaceLayoutOrientationVertical, 16);
    AddWide(page, PreviewSurface(content, 24));
    self.noticeLabel = Secondary(self.lastDecision ?: T(@"尚未作出決定", @"No decision yet"));
    AddWide(page, self.noticeLabel);
}

-(void)showConnection:(id)sender
{
    NSStackView* stack = [self beginSheetWithTitle:T(@"允許這個連線？", @"Allow this connection?")];
    [stack addArrangedSubview:Stack(@[AppIcon(@"", @"curlybraces", 40),
        Stack(@[Label(@"Sample Editor", 17, NSFontWeightSemibold), Secondary(T(@"正在要求對外連線", @"Requests an outgoing connection"))], NSUserInterfaceLayoutOrientationVertical, 4)], NSUserInterfaceLayoutOrientationHorizontal, 12)];
    NSStackView* destination = Stack(@[Secondary(T(@"目的地", @"DESTINATION")), Label(@"updates.example.com", 18, NSFontWeightMedium), Secondary(@"TCP · 443 · HTTPS")], NSUserInterfaceLayoutOrientationVertical, 5);
    AddWide(stack, Card(destination));
    self.scopeInput = [[NSPopUpButton alloc] init];
    [self.scopeInput addItemsWithTitles:@[T(@"僅此目的地", @"This destination"), T(@"此程式的所有連線", @"All connections from this app"), T(@"此程式與子程序", @"This app and child processes")]];
    self.scopeInput.accessibilityLabel = T(@"規則範圍", @"Rule scope");
    self.durationInput = [[NSPopUpButton alloc] init];
    [self.durationInput addItemsWithTitles:@[T(@"僅此一次", @"Just once"), T(@"程式結束前", @"Until the app quits"), T(@"永久", @"Always"), T(@"自訂時間", @"Custom duration")]];
    self.durationInput.target = self; self.durationInput.action = @selector(durationChanged:);
    self.durationInput.accessibilityLabel = T(@"有效時間", @"Duration");
    NSStackView* scopeRow = Stack(@[Secondary(T(@"套用範圍", @"Applies to")), Spacer(), self.scopeInput], NSUserInterfaceLayoutOrientationHorizontal, 10);
    NSStackView* durationRow = Stack(@[Secondary(T(@"有效時間", @"Duration")), Spacer(), self.durationInput], NSUserInterfaceLayoutOrientationHorizontal, 10);
    AddWide(stack, scopeRow); AddWide(stack, durationRow);
    self.minutesInput = [NSTextField textFieldWithString:@"15"];
    self.minutesInput.placeholderString = T(@"分鐘（1–1440）", @"Minutes (1–1440)");
    self.minutesInput.accessibilityLabel = self.minutesInput.placeholderString;
    self.minutesInput.hidden = YES;
    AddWide(stack, self.minutesInput);
    NSButton* details = [NSButton checkboxWithTitle:T(@"顯示程式詳情", @"Show app details") target:self action:@selector(toggleConnectionDetails:)];
    [stack addArrangedSubview:details];
    self.connectionDetails = Stack(@[Secondary(@"/Applications/Sample Editor.app"), Secondary(T(@"簽署狀態：未驗證", @"Signature: Not verified"))], NSUserInterfaceLayoutOrientationVertical, 5);
    self.connectionDetails.hidden = YES;
    AddWide(stack, self.connectionDetails);
    self.formError = Secondary(@""); self.formError.textColor = NSColor.systemRedColor;
    AddWide(stack, self.formError);
    NSButton* cancel = Button(T(@"取消", @"Cancel"), self, @selector(cancelSheet:)); cancel.keyEquivalent = @"\e";
    NSButton* block = Button(T(@"封鎖連線", @"Block Connection"), self, @selector(respondToConnection:)); block.tag = 0;
    NSButton* allow = Button(T(@"允許連線", @"Allow Connection"), self, @selector(respondToConnection:)); allow.tag = 1;
    AddWide(stack, Stack(@[cancel, Spacer(), block, allow], NSUserInterfaceLayoutOrientationHorizontal, 8));
    [self.sheet setContentSize:NSMakeSize(560, 610)];
    [self resizeSheet];
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
            self.formError.stringValue = T(@"請輸入 1 至 1440 的整數分鐘。", @"Enter a whole number from 1 to 1440 minutes.");
            [self resizeSheet];
            return;
        }
    }
    NSString* duration = self.durationInput.titleOfSelectedItem;
    if(self.durationInput.indexOfSelectedItem == 3) duration = [NSString stringWithFormat:T(@"%@ 分鐘", @"%@ minutes"), self.minutesInput.stringValue];
    self.lastDecision = [NSString stringWithFormat:T(@"範例決定：%@ · %@ · %@", @"Sample decision: %@ · %@ · %@"),
        sender.tag == 1 ? T(@"允許", @"Allow") : T(@"封鎖", @"Block"), self.scopeInput.titleOfSelectedItem, duration];
    self.noticeLabel.stringValue = self.lastDecision;
    [self cancelSheet:nil];
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
    NSStackView* page = [self pageWithTitle:T(@"設定", @"Settings") subtitle:T(@"預設設定檔 · 範例偏好設定", @"Default profile · Sample preferences")];
    AddWide(page, [self settingGroup:T(@"自動允許", @"Automatically allow") items:@[
        @[@"apple", T(@"Apple 程式", @"Apple apps"), T(@"Apple 簽署的程式連線。", @"Connections from apps signed by Apple.")],
        @[@"installed", T(@"已安裝的程式", @"Previously installed apps"), T(@"安裝 LuLu 前已存在的程式。", @"Apps present before LuLu was installed.")],
        @[@"dns", @"DNS", T(@"網域名稱解析的連線。", @"Connections used to resolve domain names.")],
        @[@"localhost", T(@"本機連線", @"Localhost connections"), T(@"此 Mac 上程式之間的連線。", @"Connections between apps on this Mac.")],
        @[@"simulator", T(@"iOS 模擬器", @"iOS Simulator"), T(@"在模擬器中執行的程式。", @"Apps running inside the simulator.")]
    ]]);
    AddWide(page, [self settingGroup:T(@"運作模式", @"Operating mode") items:@[
        @[@"passive", T(@"被動模式", @"Passive mode"), T(@"未知連線依預設動作處理，不顯示提示。", @"Handle unknown connections without showing alerts.")],
        @[@"block", T(@"全部封鎖", @"Block mode"), T(@"封鎖新對外連線；既有連線不受影響。", @"Block new outgoing connections; existing connections are unaffected.")]
    ]]);
    AddWide(page, [self settingGroup:T(@"一般", @"General") items:@[
        @[@"menubar", T(@"選單列圖示", @"Menu bar icon"), T(@"在選單列顯示 LuLu。", @"Show LuLu in the menu bar.")],
        @[@"virustotal", T(@"VirusTotal 查詢", @"VirusTotal lookup"), T(@"在連線提示中提供手動查詢。", @"Offer a manual lookup from connection alerts.")],
        @[@"updates", T(@"自動檢查更新", @"Check for updates"), T(@"取得可用版本的通知。", @"Get notified when an update is available.")]
    ]]);
}
-(void)toggleSetting:(NSSwitch*)sender { self.model.settings[sender.identifier] = @(sender.state == NSControlStateValueOn); }
@end
