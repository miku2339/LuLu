// SPDX-License-Identifier: GPL-3.0-only
#import "PreviewController.h"
#import "PreviewModel.h"

@interface PreviewApplication : NSObject <NSApplicationDelegate, NSMenuItemValidation>
@property(nonatomic, strong) PreviewController* controller;
@end

@implementation PreviewApplication
-(void)buildMenu
{
    NSMenu* main = [[NSMenu alloc] init];
    NSMenu* app = [[NSMenu alloc] initWithTitle:@"LuLu Interface Preview"];
    NSMenuItem* appItem = [[NSMenuItem alloc] init];
    appItem.submenu = app;
    [main addItem:appItem];
    [app addItemWithTitle:PreviewText(@"Quit LuLu Interface Preview") action:@selector(terminate:) keyEquivalent:@"q"];
    NSMenu* edit = [[NSMenu alloc] initWithTitle:PreviewText(@"Edit")];
    NSMenuItem* editItem = [[NSMenuItem alloc] init]; editItem.submenu = edit; [main addItem:editItem];
    NSMenuItem* undo = [edit addItemWithTitle:PreviewText(@"Undo") action:@selector(undo:) keyEquivalent:@"z"];
    undo.target = self;
    NSMenuItem* redo = [edit addItemWithTitle:PreviewText(@"Redo") action:@selector(redo:) keyEquivalent:@"z"];
    redo.target = self;
    redo.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
    [edit addItem:NSMenuItem.separatorItem];
    [edit addItemWithTitle:PreviewText(@"Cut") action:@selector(cut:) keyEquivalent:@"x"];
    [edit addItemWithTitle:PreviewText(@"Copy") action:@selector(copy:) keyEquivalent:@"c"];
    [edit addItemWithTitle:PreviewText(@"Paste") action:@selector(paste:) keyEquivalent:@"v"];
    [edit addItemWithTitle:PreviewText(@"Select All") action:@selector(selectAll:) keyEquivalent:@"a"];
    NSMenu* languages = [[NSMenu alloc] initWithTitle:PreviewText(@"Language")];
    NSMenuItem* languageItem = [[NSMenuItem alloc] init]; languageItem.submenu = languages; [main addItem:languageItem];
    for(NSString* code in [@[@"system"] arrayByAddingObjectsFromArray:PreviewLanguageCodes()])
    {
        NSMenuItem* item = [languages addItemWithTitle:PreviewLanguageName(code) action:@selector(changeLanguage:) keyEquivalent:@""];
        item.representedObject = code;
        item.target = self;
        item.state = [PreviewLanguageSelection() isEqual:code] ? NSControlStateValueOn : NSControlStateValueOff;
        if([code isEqual:@"system"]) [languages addItem:NSMenuItem.separatorItem];
    }
    for(NSMenu* menu in @[main, app, edit, languages])
        menu.userInterfaceLayoutDirection = PreviewRightToLeft() ? NSUserInterfaceLayoutDirectionRightToLeft : NSUserInterfaceLayoutDirectionLeftToRight;
    NSApp.mainMenu = main;
}
-(void)applicationDidFinishLaunching:(NSNotification*)notification
{
    if(!PreviewConfigureLanguage(NSProcessInfo.processInfo.arguments))
    {
        fprintf(stderr, "Unsupported language. Use system, en, zh-Hant, zh-Hans, de, es, fr, it, ko, pl, pt-BR, tr, uk or ur.\n");
        exit(2);
    }
    [self buildMenu];
    if([NSProcessInfo.processInfo.arguments containsObject:@"--light"]) NSApp.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
    if([NSProcessInfo.processInfo.arguments containsObject:@"--dark"]) NSApp.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    self.controller = [[PreviewController alloc] init];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(languageDidChange:) name:PreviewLanguageDidChangeNotification object:nil];
    [self.controller showWindow:nil];
    [NSApp activateIgnoringOtherApps:YES];
}
-(void)languageDidChange:(NSNotification*)notification
{
    [self buildMenu];
    [self.controller reloadLanguage];
}
-(void)changeLanguage:(NSMenuItem*)sender
{
    if(!self.controller.window.attachedSheet) PreviewSetLanguage(sender.representedObject);
}
-(BOOL)validateMenuItem:(NSMenuItem*)item
{
    return item.action != @selector(changeLanguage:) || !self.controller.window.attachedSheet;
}
-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender { return YES; }
-(void)undo:(id)sender
{
    NSResponder* responder = self.controller.window.firstResponder;
    if([responder isKindOfClass:NSTextView.class] && [(NSTextView*)responder isFieldEditor]) [responder.undoManager undo];
    else [self.controller undo:sender];
}
-(void)redo:(id)sender
{
    NSResponder* responder = self.controller.window.firstResponder;
    if([responder isKindOfClass:NSTextView.class] && [(NSTextView*)responder isFieldEditor]) [responder.undoManager redo];
    else [self.controller redo:sender];
}
@end

int main(int argc, const char* argv[])
{
    @autoreleasepool
    {
        NSApplication* application = NSApplication.sharedApplication;
        PreviewApplication* delegate = [[PreviewApplication alloc] init];
        application.delegate = delegate;
        [application setActivationPolicy:NSApplicationActivationPolicyRegular];
        [application run];
    }
    return 0;
}
