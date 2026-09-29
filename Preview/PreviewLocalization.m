// SPDX-License-Identifier: GPL-3.0-only
#import "PreviewLocalization.h"

NSNotificationName const PreviewLanguageDidChangeNotification = @"PreviewLanguageDidChange";
static NSString* languageSelection = @"system";

NSArray<NSString*>* PreviewLanguageCodes(void)
{
    return @[@"en", @"zh-Hant", @"zh-Hans", @"de", @"es", @"fr", @"it", @"ko", @"pl", @"pt-BR", @"tr", @"uk", @"ur"];
}

NSString* PreviewLanguageName(NSString* code)
{
    NSDictionary* names = @{@"en": @"English", @"zh-Hant": @"繁體中文", @"zh-Hans": @"简体中文",
        @"de": @"Deutsch", @"es": @"Español", @"fr": @"Français", @"it": @"Italiano", @"ko": @"한국어",
        @"pl": @"Polski", @"pt-BR": @"Português (Brasil)", @"tr": @"Türkçe", @"uk": @"Українська", @"ur": @"اردو"};
    return [code isEqual:@"system"] ? PreviewText(@"System language") : (names[code] ?: code);
}

NSString* PreviewLanguageSelection(void) { return languageSelection; }

NSString* PreviewLanguageCodeForPreferences(NSArray<NSString*>* preferences)
{
    NSString* match = [NSBundle preferredLocalizationsFromArray:PreviewLanguageCodes() forPreferences:preferences].firstObject;
    return match ?: @"en";
}

NSString* PreviewLanguageCode(void)
{
    return [languageSelection isEqual:@"system"] ? PreviewLanguageCodeForPreferences(NSLocale.preferredLanguages) : languageSelection;
}

BOOL PreviewSetLanguage(NSString* code)
{
    if(![code isEqual:@"system"] && ![PreviewLanguageCodes() containsObject:code]) return NO;
    if([languageSelection isEqual:code]) return YES;
    languageSelection = [code copy];
    [NSNotificationCenter.defaultCenter postNotificationName:PreviewLanguageDidChangeNotification object:nil];
    return YES;
}

BOOL PreviewConfigureLanguage(NSArray<NSString*>* arguments)
{
    NSString* selection = @"system";
    for(NSUInteger index = 1; index < arguments.count; index++)
    {
        NSString* argument = arguments[index];
        if([argument isEqual:@"--english"]) selection = @"en";
        else if([argument isEqual:@"--language"])
        {
            if(++index >= arguments.count) return NO;
            selection = arguments[index];
        }
        else if([argument hasPrefix:@"--language="]) selection = [argument substringFromIndex:11];
    }
    return PreviewSetLanguage(selection);
}

BOOL PreviewRightToLeft(void) { return [PreviewLanguageCode() isEqual:@"ur"]; }

NSString* PreviewText(NSString* key)
{
    NSString* path = [NSBundle.mainBundle pathForResource:PreviewLanguageCode() ofType:@"lproj"];
    NSBundle* bundle = path ? [NSBundle bundleWithPath:path] : nil;
    return [bundle localizedStringForKey:key value:key table:@"Localizable"] ?: key;
}

NSString* PreviewNumber(NSUInteger value)
{
    NSNumberFormatter* formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    formatter.locale = [NSLocale localeWithLocaleIdentifier:PreviewLanguageCode()];
    return [formatter stringFromNumber:@(value)];
}
