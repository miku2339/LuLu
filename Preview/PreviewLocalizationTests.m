// SPDX-License-Identifier: GPL-3.0-only
#import <Cocoa/Cocoa.h>
#import "PreviewLocalization.h"

static NSUInteger failures = 0;
static NSUInteger assertions = 0;

static void Check(BOOL condition, NSString* format, ...)
{
    assertions++;
    if(condition) return;

    va_list arguments;
    va_start(arguments, format);
    NSString* message = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    fprintf(stderr, "FAIL: %s\n", message.UTF8String);
    failures++;
}

static NSDictionary<NSString*, NSString*>* Catalog(NSString* code)
{
    NSString* directory = [NSBundle.mainBundle pathForResource:code ofType:@"lproj"];
    Check(directory != nil, @"missing packaged catalog directory for %@", code);
    if(!directory) return @{};

    NSString* path = [directory stringByAppendingPathComponent:@"Localizable.strings"];
    NSData* data = [NSData dataWithContentsOfFile:path];
    Check(data != nil, @"cannot read packaged catalog for %@", code);
    if(!data) return @{};

    NSError* error = nil;
    id propertyList = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:&error];
    Check([propertyList isKindOfClass:NSDictionary.class], @"invalid catalog for %@: %@", code, error.localizedDescription ?: @"unknown error");
    return [propertyList isKindOfClass:NSDictionary.class] ? propertyList : @{};
}

static NSArray<NSString*>* PlaceholderSignature(NSString* value)
{
    NSString* pattern = @"%(?:(\\d+)\\$)?[-+ #0']*(?:\\d+|\\*)?(?:\\.(?:\\d+|\\*))?(?:hh|h|ll|l|q|z|t|j)?([@diuoxXfFeEgGaAcCsSp])";
    NSRegularExpression* expression = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:NULL];
    NSArray<NSTextCheckingResult*>* matches = [expression matchesInString:value options:0 range:NSMakeRange(0, value.length)];
    NSMutableArray<NSString*>* signature = [NSMutableArray arrayWithCapacity:matches.count];
    NSUInteger implicitIndex = 1;
    for(NSTextCheckingResult* match in matches)
    {
        NSRange explicitRange = [match rangeAtIndex:1];
        NSUInteger argumentIndex = explicitRange.location == NSNotFound ? implicitIndex++ : [[value substringWithRange:explicitRange] integerValue];
        NSString* type = [value substringWithRange:[match rangeAtIndex:2]];
        [signature addObject:[NSString stringWithFormat:@"%lu:%@", (unsigned long)argumentIndex, type]];
    }
    [signature sortUsingSelector:@selector(compare:)];
    return signature;
}

static void TestCatalogs(void)
{
    NSArray<NSString*>* expectedCodes = @[@"en", @"zh-Hant", @"zh-Hans", @"de", @"es", @"fr", @"it", @"ko", @"pl", @"pt-BR", @"tr", @"uk", @"ur"];
    Check([PreviewLanguageCodes() isEqualToArray:expectedCodes], @"supported language list changed: %@", PreviewLanguageCodes());

    NSDictionary<NSString*, NSString*>* english = Catalog(@"en");
    Check(english.count == 104, @"English catalog has %lu keys, expected 104", (unsigned long)english.count);
    NSSet<NSString*>* englishKeys = [NSSet setWithArray:english.allKeys];

    for(NSString* code in expectedCodes)
    {
        NSDictionary<NSString*, NSString*>* catalog = Catalog(code);
        NSSet<NSString*>* keys = [NSSet setWithArray:catalog.allKeys];
        Check([keys isEqualToSet:englishKeys], @"%@ keys differ from English (missing %@, extra %@)", code,
            [englishKeys objectsPassingTest:^BOOL(NSString* key, BOOL* stop) { (void)stop; return ![keys containsObject:key]; }],
            [keys objectsPassingTest:^BOOL(NSString* key, BOOL* stop) { (void)stop; return ![englishKeys containsObject:key]; }]);
        Check(catalog.count == english.count, @"%@ has %lu values, expected %lu", code, (unsigned long)catalog.count, (unsigned long)english.count);

        Check(PreviewSetLanguage(code), @"could not select %@", code);
        Check([PreviewLanguageCode() isEqual:code], @"selected %@ but active language is %@", code, PreviewLanguageCode());
        for(NSString* key in english)
        {
            NSString* value = catalog[key];
            Check([value isKindOfClass:NSString.class] && value.length > 0, @"%@ has an empty value for %@", code, key);
            Check([PlaceholderSignature(value ?: @"") isEqual:PlaceholderSignature(english[key])],
                @"%@ placeholder signature differs for %@: %@ vs %@", code, key,
                PlaceholderSignature(value ?: @""), PlaceholderSignature(english[key]));
            Check([PreviewText(key) isEqual:value], @"PreviewText failed for %@ / %@: got %@, expected %@", code, key, PreviewText(key), value);
        }
    }
}

static void TestLanguageMatchingAndArguments(void)
{
    NSDictionary<NSArray<NSString*>*, NSString*>* cases = @{
        @[@"zh-HK"]: @"zh-Hant", @[@"zh-TW"]: @"zh-Hant", @[@"zh-CN"]: @"zh-Hans",
        @[@"de-AT"]: @"de", @[@"fr-CA"]: @"fr", @[@"ja"]: @"en", @[@"ja", @"fr"]: @"fr"
    };
    for(NSArray<NSString*>* preferences in cases)
        Check([PreviewLanguageCodeForPreferences(preferences) isEqual:cases[preferences]], @"preferences %@ resolved to %@, expected %@",
            preferences, PreviewLanguageCodeForPreferences(preferences), cases[preferences]);

    Check(PreviewSetLanguage(@"fr"), @"could not select French before invalid selection test");
    Check(!PreviewSetLanguage(@"ja"), @"unsupported language was accepted");
    Check([PreviewLanguageSelection() isEqual:@"fr"] && [PreviewLanguageCode() isEqual:@"fr"], @"invalid selection changed the current language");

    Check(PreviewConfigureLanguage(@[@"tests", @"--language", @"ko"]), @"--language CODE was rejected");
    Check([PreviewLanguageSelection() isEqual:@"ko"], @"--language CODE did not select Korean");
    Check(PreviewConfigureLanguage(@[@"tests", @"--language=pt-BR"]), @"--language=CODE was rejected");
    Check([PreviewLanguageSelection() isEqual:@"pt-BR"], @"--language=CODE did not select Brazilian Portuguese");
    Check(PreviewConfigureLanguage(@[@"tests", @"--english"]), @"legacy --english was rejected");
    Check([PreviewLanguageSelection() isEqual:@"en"], @"legacy --english did not select English");
    Check(PreviewConfigureLanguage(@[@"tests", @"--english", @"--language=fr"]), @"multiple language arguments were rejected");
    Check([PreviewLanguageSelection() isEqual:@"fr"], @"last language argument did not win");

    Check(PreviewSetLanguage(@"de"), @"could not select German before malformed argument test");
    Check(!PreviewConfigureLanguage(@[@"tests", @"--language"]), @"missing --language value was accepted");
    Check([PreviewLanguageSelection() isEqual:@"de"], @"malformed arguments changed the current language");
    Check(!PreviewConfigureLanguage(@[@"tests", @"--language=ja"]), @"unsupported --language value was accepted");
    Check([PreviewLanguageSelection() isEqual:@"de"], @"unsupported arguments changed the current language");
}

static void TestDirectionNumbersAndFallback(void)
{
    for(NSString* code in PreviewLanguageCodes())
    {
        Check(PreviewSetLanguage(code), @"could not select %@ for direction test", code);
        Check(PreviewRightToLeft() == [code isEqual:@"ur"], @"%@ has the wrong layout direction", code);

        NSNumberFormatter* expectedFormatter = [[NSNumberFormatter alloc] init];
        expectedFormatter.numberStyle = NSNumberFormatterDecimalStyle;
        expectedFormatter.locale = [NSLocale localeWithLocaleIdentifier:code];
        NSString* expected = [expectedFormatter stringFromNumber:@(1234567)];
        Check([PreviewNumber(1234567) isEqual:expected], @"%@ number formatting is %@, expected %@", code, PreviewNumber(1234567), expected);
    }

    PreviewSetLanguage(@"en");
    NSString* englishNumber = PreviewNumber(1234567);
    PreviewSetLanguage(@"de");
    NSString* germanNumber = PreviewNumber(1234567);
    Check(![englishNumber isEqual:germanNumber], @"English and German number formatting unexpectedly match: %@", englishNumber);

    PreviewSetLanguage(@"ur");
    NSString* missingKey = @"Translation unavailable — showing the original text";
    Check([PreviewText(missingKey) isEqual:missingKey], @"missing-key fallback is unreadable: %@", PreviewText(missingKey));
}

static void TestSourceKeyCoverage(NSDictionary<NSString*, NSString*>* english)
{
    NSString* sourceRoot = NSProcessInfo.processInfo.environment[@"PREVIEW_SOURCE_ROOT"];
    Check(sourceRoot.length > 0, @"PREVIEW_SOURCE_ROOT is not set");
    if(!sourceRoot.length) return;

    NSDirectoryEnumerator<NSURL*>* files = [NSFileManager.defaultManager enumeratorAtURL:[NSURL fileURLWithPath:sourceRoot]
        includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:nil];
    NSRegularExpression* expression = [NSRegularExpression regularExpressionWithPattern:@"PreviewText\\s*\\(\\s*@\"((?:\\\\.|[^\"\\\\])*)\"\\s*\\)" options:0 error:NULL];
    NSMutableSet<NSString*>* usedKeys = [NSMutableSet set];
    for(NSURL* file in files)
    {
        if(![@[@"m", @"h"] containsObject:file.pathExtension] || [file.lastPathComponent isEqual:@"PreviewLocalizationTests.m"]) continue;
        NSString* source = [NSString stringWithContentsOfURL:file encoding:NSUTF8StringEncoding error:NULL];
        for(NSTextCheckingResult* match in [expression matchesInString:source ?: @"" options:0 range:NSMakeRange(0, source.length)])
            [usedKeys addObject:[source substringWithRange:[match rangeAtIndex:1]]];
    }
    Check(usedKeys.count > 0, @"no literal PreviewText keys found in Preview sources");
    for(NSString* key in usedKeys)
        Check(english[key] != nil, @"Preview source uses a key absent from the English catalog: %@", key);
}

int main(void)
{
    @autoreleasepool
    {
        Check([NSBundle.mainBundle.bundleURL.pathExtension isEqual:@"app"], @"tests are not running from an app bundle: %@", NSBundle.mainBundle.bundleURL.path);
        Check([[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleExecutable"] isEqual:@"PreviewLocalizationTests"], @"test bundle executable metadata does not match");

        NSDictionary<NSString*, NSString*>* english = Catalog(@"en");
        TestCatalogs();
        TestLanguageMatchingAndArguments();
        TestDirectionNumbersAndFallback();
        TestSourceKeyCoverage(english);

        if(failures)
        {
            fprintf(stderr, "%lu localization assertion(s) failed out of %lu.\n", (unsigned long)failures, (unsigned long)assertions);
            return 1;
        }
        printf("Localization tests passed: 13 catalogs, 104 keys, %lu assertions.\n", (unsigned long)assertions);
    }
    return 0;
}
