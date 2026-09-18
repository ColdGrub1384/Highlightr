//
//  HighlightHints.m
//  Highlightr
//
//  Created by Bruno Philipe on 4/3/18.
//

#import "HighlightHints.h"
#import "NSString+RangeHelpers.h"

@implementation HighlightHints

+ (NSRange)highlightRangeFor:(NSRange)range
                    inString:(nonnull NSString *)string
                 forLanguage:(nullable NSString *)language
          multilineDelimiters:(nonnull NSArray<NSArray<NSString *> *> *)delimiters
      isInCommentBlockBoundary:(BOOL)isCommentBlockBoundary
{
    range = [string boundedRangeFrom:range];
    NSUInteger stringLength = [string length];

    if (language == nil)
    {
        // Fallback
        return [string paragraphRangeForRange:range];
    }

    NSUInteger bestLower = NSNotFound;
    NSUInteger bestUpper = NSNotFound;

    // The `begin`/`end` pairs are derived from highlight.js's own grammar, so this loop
    // transparently handles block comments, multi-line strings, heredocs, verbatim
    // strings, etc., without a hardcoded per-language table.
    for (NSArray<NSString *> *pair in delimiters)
    {
        if (pair.count < 2)
        {
            continue;
        }

        NSString *begin = pair[0];
        NSString *end   = pair[1];

        if (begin.length == 0 || end.length == 0)
        {
            continue;
        }

        // Locate the most recent `begin` whose start lies at or before the end of the
        // edited range. This deliberately includes a `begin` that was just typed,
        // because the range covers the freshly inserted characters.
        NSUInteger editUpper = MIN(NSMaxRange(range), stringLength);
        NSRange lastBegin = [string rangeOfString:begin
                                          options:NSRegularExpressionSearch | NSBackwardsSearch
                                            range:NSMakeRange(0, editUpper)];

        if (lastBegin.location == NSNotFound)
        {
            continue;
        }

        // Find the first matching `end` after the `begin`.
        NSUInteger endSearchStart = NSMaxRange(lastBegin);
        NSRange firstEnd = NSMakeRange(NSNotFound, 0);

        if (endSearchStart < stringLength)
        {
            firstEnd = [string rangeOfString:end
                                     options:NSRegularExpressionSearch
                                       range:NSMakeRange(endSearchStart, stringLength - endSearchStart)];
        }

        NSUInteger constructEnd = (firstEnd.location != NSNotFound)
            ? NSMaxRange(firstEnd)
            : stringLength;

        // If the construct closes before our edit begins, we are not inside it.
        if (constructEnd <= range.location)
        {
            continue;
        }

        NSUInteger lower = lastBegin.location;
        NSUInteger upper = MAX(constructEnd, NSMaxRange(range));

        if (bestLower == NSNotFound || lower < bestLower)
        {
            bestLower = lower;
            bestUpper = upper;
        }
        else if (lower == bestLower && upper > bestUpper)
        {
            bestUpper = upper;
        }
    }

    // Preserve the pre-existing CSS behavior: extend to the enclosing `{}` block.
    if ([language isEqualToString:@"css"])
    {
        NSUInteger openBrace = [string rangeOfString:@"{"
                                             options:NSBackwardsSearch
                                               range:NSMakeRange(0, range.location)].location;

        if (openBrace != NSNotFound)
        {
            NSUInteger afterEdit = NSMaxRange(range);
            NSUInteger closeBrace = NSNotFound;

            if (afterEdit < stringLength)
            {
                closeBrace = [string rangeOfString:@"}"
                                           options:0
                                             range:NSMakeRange(afterEdit, stringLength - afterEdit)].location;
            }

            NSUInteger upper = (closeBrace != NSNotFound) ? closeBrace + 1 : stringLength;

            if (bestLower == NSNotFound || openBrace < bestLower)
            {
                bestLower = openBrace;
                bestUpper = MAX(upper, NSMaxRange(range));
            }
        }
    }

    // If nothing matched but the edit sits on a comment-block boundary, extend to the
    // end of the document
    if (bestLower == NSNotFound && isCommentBlockBoundary)
    {
        NSRange lineRange = [string lineRangeForRange:range];
        bestLower = lineRange.location;
        bestUpper = stringLength;
    }

    if (bestLower == NSNotFound)
    {
        return NSMakeRange(NSNotFound, 0);
    }

    if (bestUpper < NSMaxRange(range))
    {
        bestUpper = NSMaxRange(range);
    }

    return NSMakeRange(bestLower, bestUpper - bestLower);
}

@end
