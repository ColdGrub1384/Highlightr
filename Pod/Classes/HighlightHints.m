//
//  HighlightHints.m
//  Highlightr
//
//  Created by Bruno Philipe on 4/3/18.
//

#import "HighlightHints.h"
#import "NSString+RangeHelpers.h"

@implementation HighlightHints

+ (nonnull NSSet<NSString *> *)blockCommentLanguages
{
	static NSSet<NSString *> *languagesSet = nil;

	if (languagesSet == nil)
	{
		languagesSet = [[NSSet<NSString *> alloc] initWithObjects:@"actionscript", @"arduino", @"armasm", @"aspectj",
						@"autohotkey", @"avrasm", @"axapta", @"bnf", @"cal", @"clean", @"cos", @"cpp", @"cs", @"css",
						@"d", @"dart", @"delphi", @"dts", @"ebnf", @"flix", @"gams", @"gauss", @"gcode", @"glsl", @"go",
						@"gradle", @"groovy", @"haxe", @"hsp", @"java", @"javascript", @"kotlin", @"lasso", @"less",
						@"livecodeserver", @"mathematica", @"mel", @"mercury", @"mipsasm", @"n1ql", @"nix", @"nsis",
						@"objectivec", @"openscad", @"php", @"pony", @"processing", @"prolog", @"qml", @"rsl",
						@"ruleslanguage", @"scala", @"scss", @"sqf", @"sql", @"stan", @"stata", @"step21", @"stylus",
						@"swift", @"thrift", @"typescript", @"vala", @"verilog", @"vhdl", @"xl", @"zephir", nil];
	}

	return languagesSet;
}

+ (NSRange)highlightRangeFor:(NSRange)range inString:(nonnull NSString *)string forLanguage:(nullable NSString *)language
{
	range = [string boundedRangeFrom:range];

	if (language == nil)
	{
		// Fallback
		return [string paragraphRangeForRange:range];
	}

	NSUInteger lowerBoundary = NSNotFound;
	NSUInteger upperBoundary = NSNotFound;

	NSRange lowerSearchRange = NSMakeRange(0, range.location);
	NSRange upperSearchRange = NSMakeRange(NSMaxRange(range), [string length] - NSMaxRange(range));

	BOOL lowerBoundayIsCommentBlock = NO;

	if ([language isEqualToString:@"css"])
	{
		// Looks for the curly braces, which define the inner blocks of CSS
		lowerBoundary = [string rangeOfString:@"{" options:NSBackwardsSearch range:lowerSearchRange].location;
	}
	else if ([[self blockCommentLanguages] containsObject:language])
	{
		NSRange offsetRange = NSMakeRange(lowerSearchRange.location, lowerSearchRange.length + range.length);
		NSUInteger openLocation = [string rangeOfString:@"/*" options:NSBackwardsSearch range:offsetRange].location;
		NSUInteger closeLocation = NSMaxRange([string rangeOfString:@"*/" options:NSBackwardsSearch range:offsetRange]);

		//  we found open location         but no close location       or the close location is before the open location
		if (openLocation != NSNotFound && (closeLocation == NSNotFound || openLocation > closeLocation))
		{
			// We are inside a comment block so we must include the open tag it in the highlight.
			lowerBoundary = openLocation;
			lowerBoundayIsCommentBlock = YES;
		}
	}

	if ([language isEqualToString:@"css"])
	{
		// Looks for the curly braces, which define the inner blocks of CSS
		upperBoundary = [string rangeOfString:@"}" options:0 range:upperSearchRange].location;
	}
	else if ([[self blockCommentLanguages] containsObject:language])
	{
		NSUInteger openLocation = [string rangeOfString:@"/*" options:0 range:upperSearchRange].location;
		NSUInteger closeLocation = NSMaxRange([string rangeOfString:@"*/" options:0 range:upperSearchRange]);

		if (openLocation != NSNotFound && closeLocation != NSNotFound && openLocation > closeLocation)
		{
			// We found out that we are inside a comment block so we must include the close tag it in the highlight.
			upperBoundary = closeLocation;
		}
		else if (lowerBoundayIsCommentBlock && closeLocation == NSNotFound)
		{
			upperBoundary = [string length];
		}
	}

	if (lowerBoundary != NSNotFound && upperBoundary != NSNotFound)
	{
		return NSMakeRange(lowerBoundary, upperBoundary - lowerBoundary);
	}
	else if (lowerBoundary != NSNotFound)
	{
		return NSMakeRange(lowerBoundary, NSMaxRange(range) - lowerBoundary);
	}
	else if (upperBoundary != NSNotFound)
	{
		return NSMakeRange(range.location, upperBoundary - range.location);
	}
	else
	{
		// Fallback
		return [string paragraphRangeForRange:range];
	}
}

@end
