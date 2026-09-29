// SPDX-License-Identifier: GPL-3.0-only
#import "PreviewController.h"
#import "PreviewModel.h"

@interface PreviewApplication : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) PreviewController* controller;
@end

@implementation PreviewApplication
-(void)applicationDidFinishLaunching:(NSNotification*)notification
{
    NSMenu* main = [[NSMenu alloc] init];
    NSMenu* app = [[NSMenu alloc] initWithTitle:@"LuLu Interface Preview"];
    NSMenuItem* appItem = [[NSMenuItem alloc] init];
    appItem.submenu = app;
    [main addItem:appItem];
    [app addItemWithTitle:PreviewText(@"結束 LuLu Interface Preview", @"Quit LuLu Interface Preview") action:@selector(terminate:) keyEquivalent:@"q"];
    NSMenu* edit = [[NSMenu alloc] initWithTitle:PreviewText(@"編輯", @"Edit")];
    NSMenuItem* editItem = [[NSMenuItem alloc] init]; editItem.submenu = edit; [main addItem:editItem];
    NSMenuItem* undo = [edit addItemWithTitle:PreviewText(@"復原", @"Undo") action:@selector(undo:) keyEquivalent:@"z"];
    undo.target = self;
    NSMenuItem* redo = [edit addItemWithTitle:PreviewText(@"重做", @"Redo") action:@selector(redo:) keyEquivalent:@"z"];
    redo.target = self;
    redo.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
    [edit addItem:NSMenuItem.separatorItem];
    [edit addItemWithTitle:PreviewText(@"剪下", @"Cut") action:@selector(cut:) keyEquivalent:@"x"];
    [edit addItemWithTitle:PreviewText(@"複製", @"Copy") action:@selector(copy:) keyEquivalent:@"c"];
    [edit addItemWithTitle:PreviewText(@"貼上", @"Paste") action:@selector(paste:) keyEquivalent:@"v"];
    [edit addItemWithTitle:PreviewText(@"全選", @"Select All") action:@selector(selectAll:) keyEquivalent:@"a"];
    NSApp.mainMenu = main;
    if([NSProcessInfo.processInfo.arguments containsObject:@"--light"]) NSApp.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
    if([NSProcessInfo.processInfo.arguments containsObject:@"--dark"]) NSApp.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    self.controller = [[PreviewController alloc] init];
    [self.controller showWindow:nil];
    [NSApp activateIgnoringOtherApps:YES];
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
