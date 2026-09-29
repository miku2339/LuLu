// SPDX-License-Identifier: GPL-3.0-only
#import <Cocoa/Cocoa.h>

NSString* PreviewText(NSString* traditionalChinese, NSString* english);

@interface PreviewRule : NSObject <NSCopying>
@property(nonatomic, copy) NSString* name;
@property(nonatomic, copy) NSString* path;
@property(nonatomic, copy) NSString* endpoint;
@property(nonatomic, copy) NSString* symbol;
@property(nonatomic) BOOL allowed;
@property(nonatomic) BOOL enabled;
@end

@interface PreviewModel : NSObject
@property(nonatomic, readonly) NSMutableArray<PreviewRule*>* rules;
@property(nonatomic, readonly) NSMutableDictionary<NSString*, NSNumber*>* settings;
@property(nonatomic, readonly) NSUndoManager* undoManager;
-(NSArray<PreviewRule*>*)rulesMatching:(NSString*)query filter:(NSInteger)filter;
-(void)setAllowed:(BOOL)allowed forRule:(PreviewRule*)rule;
-(void)setEnabled:(BOOL)enabled forRule:(PreviewRule*)rule;
-(void)addRule:(PreviewRule*)rule;
-(void)removeRule:(PreviewRule*)rule;
@end
