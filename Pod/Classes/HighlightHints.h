//
//  HighlightHints.h
//  Highlightr
//
//  Created by Bruno Philipe on 4/3/18.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HighlightHints : NSObject

/// Returns a hint range that should be highlighted when the user edits `range`. The
/// hint is derived from the `delimiters` list — an array of `[beginSource, endSource]`
/// regex-source pairs obtained from highlight.js for the current language — together
/// with language-specific fallbacks (CSS `{}` blocks, comment-block boundaries).
///
/// `delimiters` may be empty; in that case the method falls back to the current line
/// (or, when `isCommentBlockBoundary` is `YES`, to the tail of the document).
+ (NSRange)highlightRangeFor:(NSRange)range
                    inString:(nonnull NSString *)string
                 forLanguage:(nullable NSString *)language
          multilineDelimiters:(nonnull NSArray<NSArray<NSString *> *> *)delimiters
      isInCommentBlockBoundary:(BOOL)isCommentBlockBoundary;

@end

NS_ASSUME_NONNULL_END
