// SPDX-License-Identifier: GPL-3.0-only
#import "PreviewModel.h"

@implementation PreviewRule
-(id)copyWithZone:(NSZone*)zone
{
    PreviewRule* copy = [[PreviewRule allocWithZone:zone] init];
    copy.name = self.name;
    copy.path = self.path;
    copy.endpoint = self.endpoint;
    copy.symbol = self.symbol;
    copy.allowed = self.allowed;
    copy.enabled = self.enabled;
    return copy;
}
@end

@implementation PreviewModel
-(instancetype)init
{
    self = [super init];
    if(self)
    {
        _undoManager = [[NSUndoManager alloc] init];
        _settings = [@{@"apple": @YES, @"installed": @NO, @"dns": @YES, @"localhost": @YES,
                      @"simulator": @NO, @"passive": @NO, @"block": @NO,
                      @"menubar": @YES, @"virustotal": @YES, @"updates": @YES} mutableCopy];
        _rules = [NSMutableArray array];
        NSArray* samples = @[
            @[@"Safari", @"/Applications/Safari.app", @"*", @"safari", @YES],
            @[@"Mail", @"/System/Applications/Mail.app", @"mail.example.com:993", @"envelope", @YES],
            @[@"Terminal", @"/System/Applications/Utilities/Terminal.app", @"*", @"terminal", @NO],
            @[@"Sample Editor", @"/Applications/Sample Editor.app", @"updates.example.com:443", @"curlybraces", @YES],
            @[@"Sample Sync", @"/Applications/Sample Sync.app", @"sync.example.com:443", @"arrow.triangle.2.circlepath", @NO],
            @[@"Software Update", @"/System/Library/CoreServices/Software Update.app", @"*", @"arrow.down.circle", @YES]
        ];
        for(NSArray* sample in samples)
        {
            PreviewRule* rule = [[PreviewRule alloc] init];
            rule.name = sample[0]; rule.path = sample[1]; rule.endpoint = sample[2];
            rule.symbol = sample[3]; rule.allowed = [sample[4] boolValue]; rule.enabled = YES;
            [_rules addObject:rule];
        }
    }
    return self;
}

-(NSArray<PreviewRule*>*)rulesMatching:(NSString*)query filter:(NSInteger)filter
{
    return [self.rules filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(PreviewRule* rule, NSDictionary* bindings) {
        BOOL matches = query.length == 0 || [rule.name localizedCaseInsensitiveContainsString:query] ||
            [rule.path localizedCaseInsensitiveContainsString:query] || [rule.endpoint localizedCaseInsensitiveContainsString:query];
        return matches && (filter == 0 || (filter == 1 && rule.enabled && rule.allowed) ||
            (filter == 2 && rule.enabled && !rule.allowed) || (filter == 3 && !rule.enabled));
    }]];
}

-(void)setAllowed:(BOOL)allowed forRule:(PreviewRule*)rule
{
    BOOL previous = rule.allowed;
    [self.undoManager registerUndoWithTarget:self handler:^(PreviewModel* target) { [target setAllowed:previous forRule:rule]; }];
    rule.allowed = allowed;
    [self.undoManager setActionName:PreviewText(@"Change Rule")];
}

-(void)setEnabled:(BOOL)enabled forRule:(PreviewRule*)rule
{
    BOOL previous = rule.enabled;
    [self.undoManager registerUndoWithTarget:self handler:^(PreviewModel* target) { [target setEnabled:previous forRule:rule]; }];
    rule.enabled = enabled;
    [self.undoManager setActionName:PreviewText(@"Toggle Rule")];
}

-(void)insertRule:(PreviewRule*)rule atIndex:(NSUInteger)index
{
    [self.rules insertObject:rule atIndex:MIN(index, self.rules.count)];
    [self.undoManager registerUndoWithTarget:self handler:^(PreviewModel* target) { [target removeRule:rule]; }];
}

-(void)addRule:(PreviewRule*)rule
{
    [self insertRule:rule atIndex:self.rules.count];
    [self.undoManager setActionName:PreviewText(@"Add Rule")];
}

-(void)removeRule:(PreviewRule*)rule
{
    NSUInteger index = [self.rules indexOfObjectIdenticalTo:rule];
    if(index == NSNotFound) return;
    [self.rules removeObjectAtIndex:index];
    [self.undoManager registerUndoWithTarget:self handler:^(PreviewModel* target) { [target insertRule:rule atIndex:index]; }];
    [self.undoManager setActionName:PreviewText(@"Delete Rule")];
}
@end
