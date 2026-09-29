// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSNotificationName const PreviewLanguageDidChangeNotification;
FOUNDATION_EXPORT NSArray<NSString*>* PreviewLanguageCodes(void);
FOUNDATION_EXPORT NSString* PreviewLanguageName(NSString* code);
FOUNDATION_EXPORT NSString* PreviewLanguageSelection(void);
FOUNDATION_EXPORT NSString* PreviewLanguageCode(void);
FOUNDATION_EXPORT NSString* PreviewLanguageCodeForPreferences(NSArray<NSString*>* preferences);
FOUNDATION_EXPORT BOOL PreviewConfigureLanguage(NSArray<NSString*>* arguments);
FOUNDATION_EXPORT BOOL PreviewSetLanguage(NSString* code);
FOUNDATION_EXPORT BOOL PreviewRightToLeft(void);
FOUNDATION_EXPORT NSString* PreviewText(NSString* key);
FOUNDATION_EXPORT NSString* PreviewNumber(NSUInteger value);

NS_ASSUME_NONNULL_END
