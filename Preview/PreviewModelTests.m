// SPDX-License-Identifier: GPL-3.0-only
#import "PreviewModel.h"

static void Check(BOOL condition, NSString* message)
{
    if(!condition) { fprintf(stderr, "FAIL: %s\n", message.UTF8String); exit(1); }
}

int main(void)
{
    @autoreleasepool
    {
        PreviewModel* model = [[PreviewModel alloc] init];
        model.undoManager.groupsByEvent = NO;
        Check(model.rules.count == 6, @"Seed count");
        Check([model rulesMatching:@"SAFARI" filter:0].count == 1, @"Case-insensitive app search");
        Check([model rulesMatching:@"Utilities/Terminal" filter:0].count == 1, @"Path search");
        Check([model rulesMatching:@"example.com" filter:0].count == 3, @"Endpoint search");
        Check([model rulesMatching:@"missing" filter:0].count == 0, @"Empty results");
        Check([model rulesMatching:@"" filter:1].count == 4, @"Allowed filter");
        Check([model rulesMatching:@"" filter:2].count == 2, @"Blocked filter");
        PreviewRule* rule = model.rules[0];
        [model.undoManager beginUndoGrouping];
        [model setEnabled:NO forRule:rule];
        [model.undoManager endUndoGrouping];
        Check([model rulesMatching:@"" filter:3].count == 1, @"Disabled filter");
        Check([model rulesMatching:@"" filter:1].count == 3, @"Disabled rule excluded from allowed filter");
        [model.undoManager undo];
        Check(rule.enabled, @"Undo disable");
        [model.undoManager redo];
        Check(!rule.enabled, @"Redo disable");
        [model.undoManager beginUndoGrouping];
        [model removeRule:rule];
        [model.undoManager endUndoGrouping];
        Check(model.rules.count == 5, @"Delete");
        [model.undoManager undo];
        Check(model.rules[0] == rule, @"Undo delete preserves order and identity");
        [model.undoManager beginUndoGrouping];
        [model setAllowed:NO forRule:model.rules[1]];
        [model.undoManager endUndoGrouping];
        Check(!model.rules[1].allowed, @"Change action");
        [model.undoManager undo];
        Check(model.rules[1].allowed, @"Undo change action");
        PreviewRule* added = [rule copy]; added.name = @"New Sample";
        [model.undoManager beginUndoGrouping];
        [model addRule:added];
        [model.undoManager endUndoGrouping];
        Check(model.rules.lastObject == added && model.rules.count == 7, @"Add");
        [model.undoManager undo];
        Check(model.rules.count == 6, @"Undo add");
        [model.undoManager redo];
        Check(model.rules.lastObject == added && model.rules.count == 7, @"Redo add");
        puts("PASS: 18 preview model checks");
    }
    return 0;
}
