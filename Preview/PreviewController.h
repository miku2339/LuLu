// SPDX-License-Identifier: GPL-3.0-only
#import <Cocoa/Cocoa.h>

@interface PreviewController : NSWindowController <NSWindowDelegate, NSTableViewDelegate, NSTableViewDataSource, NSSearchFieldDelegate>
-(void)showPage:(NSInteger)page;
-(void)focusSearch:(id)sender;
-(void)showConnection:(id)sender;
-(void)undo:(id)sender;
-(void)redo:(id)sender;
-(void)reloadLanguage;
@end
