//
//  CodeAttributedString.m
//  Highlightr
//
//  Created by Bruno Philipe on 4/12/17.
//

#import <Highlightr/Highlightr-Swift.h>

#import "CodeAttributedString.h"
#import "HighlightHints.h"
#import "NSString+RangeHelpers.h"
#import "NSTextStorage+Helpers.h"

#define NSTextStorageEditedBoth (NSTextStorageEditedCharacters|NSTextStorageEditedAttributes)

@implementation CodeAttributedString
{
	NSTextStorage *_stringStorage;
	NSString *_language;
	NSValue *_aggregateNeedHighlightRangeValue;
}

- (instancetype)init
{
	self = [super init];
	if (self)
	{
		[self initializeMembers];
		[self setupListeners];
	}
	return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	if (self)
	{
		[self initializeMembers];
		[self setupListeners];
	}
	return self;
}

- (instancetype)initWithAttributedString:(NSAttributedString *)attrStr
{
	self = [super init];
	if (self)
	{
		[self initializeMembers];
		[_stringStorage appendAttributedString:attrStr];
		[self setupListeners];
	}
	return self;
}

- (void)initializeMembers
{
	// By using a NSTextStorage object, the CodeAttributedString class behaves simply as a router, and also provides a ginormous
	// performance enhancement compared to using something like a NSMutableAttributedString.
	_stringStorage = [[NSTextStorage alloc] initWithString:@""];
	_highlightr = [[Highlightr alloc] init];
	_aggregateNeedHighlightRangeValue = nil;
}

+ (NSArray<NSAttributedStringKey> *)controlAttributeKeys
{
	static NSArray<NSAttributedStringKey> *controlAttributeKeys = nil;

	if (controlAttributeKeys == nil)
	{
		controlAttributeKeys = @[HighlightCommentBlock, HighlightLanguageBlock, HighlightMultiLineElementBlock];
	}

	return controlAttributeKeys;
}

- (NSString *)string
{
	return [_stringStorage string];
}

- (NSDictionary<NSAttributedStringKey, id> *)attributesAtIndex:(NSUInteger)location effectiveRange:(NSRangePointer)range
{
	return [_stringStorage attributesAtIndex:location effectiveRange:range];
}

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)string
{
	[self replaceCharactersInRange:range withString:string applyAttributes:YES];
}

- (void)replaceCharactersInRange:(NSRange)range withAttributedString:(NSAttributedString *)attrString
{
	[self replaceCharactersInRange:range withAttributedString:attrString applyAttributes:YES];
}

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)string applyAttributes:(BOOL)applyAttributes
{
	if (range.location > 0 && applyAttributes)
	{
		NSAttributedString *attributedString = [self applyAttributesAtLocation:range.location - 1 toString:string];
		[_stringStorage replaceCharactersInRange:range withAttributedString:attributedString];
		[self edited:NSTextStorageEditedBoth range:range changeInLength:([attributedString length] - range.length)];
	}
	else
	{
		[_stringStorage replaceCharactersInRange:range withString:string];
		[self edited:NSTextStorageEditedCharacters range:range changeInLength:([string length] - range.length)];
	}
}

- (void)replaceCharactersInRange:(NSRange)range withAttributedString:(NSAttributedString *)string applyAttributes:(BOOL)applyAttributes
{
	if (range.location > 0 && applyAttributes)
	{
		NSAttributedString *attributedString = [self applyAttributesAtLocation:range.location - 1 toAttributedString:string];
		[_stringStorage replaceCharactersInRange:range withAttributedString:attributedString];
		[self edited:NSTextStorageEditedBoth range:range changeInLength:([attributedString length] - range.length)];
	}
	else
	{
		[_stringStorage replaceCharactersInRange:range withAttributedString:string];
		[self edited:NSTextStorageEditedBoth range:range changeInLength:([string length] - range.length)];
	}
}

- (void)setAttributes:(NSDictionary<NSAttributedStringKey,id> *)attrs range:(NSRange)range
{
	[_stringStorage setAttributes:attrs range:range];
	[self edited:NSTextStorageEditedAttributes range:range changeInLength:0];
}

- (NSAttributedString *)applyAttributesAtLocation:(NSUInteger)location toString:(NSString *)string
{
	NSDictionary *attributes = [_stringStorage attributesAtIndex:location effectiveRange:nil];

	if ([self enforcedFont] != nil)
	{
		NSMutableDictionary *mutableAttributes = [attributes mutableCopy];
		[mutableAttributes setObject:[self enforcedFont] forKey:NSFontAttributeName];
		attributes = mutableAttributes;
	}

	return [[NSAttributedString alloc] initWithString:string attributes:attributes];
}

- (NSAttributedString *)applyAttributesAtLocation:(NSUInteger)location toAttributedString:(NSAttributedString *)string
{
	NSMutableAttributedString *mutableString = [string mutableCopy];
	NSDictionary *attributes = [_stringStorage attributesAtIndex:location effectiveRange:nil];

	if ([self enforcedFont] != nil)
	{
		NSMutableDictionary *mutableAttributes = [attributes mutableCopy];
		[mutableAttributes setObject:[self enforcedFont] forKey:NSFontAttributeName];
		attributes = mutableAttributes;
	}

	[mutableString setAttributes:attributes range:NSMakeRange(0, [mutableString length])];
	return mutableString;
}

- (void)processEditing
{
	[super processEditing];

	if (_language && ([self editedMask] & NSTextStorageEditedCharacters))
	{
		[self setNeedsHighlightInRange:[self editedRange]];
	}
}

- (void)setNeedsHighlight
{
	[self setNeedsHighlightInRange:NSMakeRange(0, [self length])];
}

- (void)setNeedsHighlightInRange:(NSRange)range
{
	// If we have just called needsHighlight on another range, cancel that request before placing a new one:
	if (_aggregateNeedHighlightRangeValue != nil)
	{
		[NSObject cancelPreviousPerformRequestsWithTarget:self
												 selector:@selector(highlightRangeValue:)
												   object:_aggregateNeedHighlightRangeValue];

		// Create a union for the total range needing highlight
		NSRange aggregateRangeValue = _aggregateNeedHighlightRangeValue.rangeValue;
		_aggregateNeedHighlightRangeValue = [NSValue valueWithRange:NSUnionRange(aggregateRangeValue, range)];
	}
	else
	{
		// Store the range needing highlight in case a second call comes before the timeout
		_aggregateNeedHighlightRangeValue = [NSValue valueWithRange:range];
	}

	// Request highlight after a small delay:
	[self performSelector:@selector(highlightRangeValue:) withObject:_aggregateNeedHighlightRangeValue afterDelay:0.2];
}

#pragma mark - Accessors

- (void)setLanguage:(NSString *)language
{
	_language = language;
	[self setNeedsHighlightInRange:NSMakeRange(0, [_stringStorage length])];
}

- (NSString *)language
{
	return _language;
}

#pragma mark - Private

- (void)setupListeners
{
	NSTextStorage __weak *stringStorage = _stringStorage;
	
	[[self highlightr] setThemeChanged:^(Theme *theme)
	{
		[self setNeedsHighlightInRange:NSMakeRange(0, [stringStorage length])];
	}];
}

/**
 Highlights the parameter range.

 This method attempts to perform a series of adjustments to the parameter range in order to ensure that the
 highlighting generates a correct result. First it attempts to find out if we are inside a sublanguage block,
 and uses that information to request highlighting in the correct language.

 It also attempts to make sure we always highlight a contiguous language block, since some languages require
 pre-processor tags and other markup that breaks highlighting otherwise (such as PHP's <?php ?> tags).

 @param range The range to highlight.
 */
- (void)highlightRange:(NSRange)range
{
	// Bounds check
	range = [[self string] boundedRangeFrom:range];

	if ([_highlightDelegate respondsToSelector:@selector(shouldHighlightRange:)] && ![_highlightDelegate shouldHighlightRange:range])
	{
		return;
	}

	NSString *configuredLanguage = _language != nil ? _language : @"";
	
	Highlightr __weak *highlightr = _highlightr;
	NSTextStorage *stringStorage = [[NSTextStorage alloc] initWithAttributedString:_stringStorage];
	NSString *string = [stringStorage string];

	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		NSRange highlightRange;
		NSRange fullRange = NSMakeRange(0, [string length]);
		NSString *language = configuredLanguage;
		BOOL usingLanguageBoundaries = NO;
		
		if (!highlightr || !stringStorage)
		{
			// nil checking
			return;
		}

		if (NSEqualRanges(range, fullRange))
		{
			highlightRange = range;
		}
		else
		{
			NSRange languageBounds = [stringStorage languageBoundariesForRange:range
																	  language:language
															 effectiveLanguage:&language];

			if (languageBounds.location != NSNotFound && !NSEqualRanges(languageBounds, fullRange))
			{
				highlightRange = languageBounds;
				usingLanguageBoundaries = YES;
			}
			else
			{
				NSRange hintedBounds = [HighlightHints highlightRangeFor:range
																inString:[stringStorage string]
															 forLanguage:language
												isInCommentBlockBoundary:[stringStorage isRangeInCommentBoundary:range]];

				if (hintedBounds.location != NSNotFound)
				{
					highlightRange = [self contiguousElementRangeFor:hintedBounds];
				}
				else
				{
					highlightRange = [self contiguousElementRangeFor:[[stringStorage string] lineRangeForRange:range]];
				}
			}
		}

		if (highlightRange.length == 0 || [language isEqualToString:@""])
		{
			[self sendDelegateMethodDidHighlightRange:range success:YES];
			return;
		}

		// Checks if this highlighting is still valid.
		if (NSMaxRange(highlightRange) > [string length])
		{
			[self sendDelegateMethodDidHighlightRange:range success:NO];
			return;
		}

		NSString *line = [string substringWithRange:highlightRange];
		NSMutableAttributedString *highlightedString = [highlightr highlight:line as:language fastRender:YES];

		if (highlightedString == nil)
		{
			[self sendDelegateMethodDidHighlightRange:range success:NO];
			return;
		}
		else if (usingLanguageBoundaries && [highlightedString length] > 0
				 && [highlightedString attribute:HighlightLanguageBlock atIndex:0 effectiveRange:nil] == nil
				 && language != configuredLanguage)
		{
			NSString *effectiveLanguage = language;
			
			if (!effectiveLanguage && configuredLanguage)
			{
				effectiveLanguage = configuredLanguage;
				
				// This is useful for the automatic language hinting system in case the highlighted text
				// contains some malformation. When this happens, highlight.js will not insert any language span
				// blocks. In this case, we add a hintting manually. This will stop the highlighting from going
				// backwards into the previous language section, which is not necessary.
				// But in case it works, or the language changes, for example, this block will be skipped.
				[highlightedString addAttribute:HighlightLanguageBlock
										  value:language
										  range:NSMakeRange(0, [highlightedString length])];
			}
		}

		dispatch_async(dispatch_get_main_queue(), ^{
			NSTextStorage *originalStringStorage = self->_stringStorage;

			// Checks if this highlighting is still valid.
			if (NSMaxRange(highlightRange) > [originalStringStorage length])
			{
				[self sendDelegateMethodDidHighlightRange:range success:NO];
				return;
			}

			NSInteger originalRangeHash = [[[originalStringStorage string] substringWithRange:highlightRange] hash];
			NSInteger highlightedRangeHash = [[highlightedString string] hash];

			if (originalRangeHash != highlightedRangeHash)
			{
				// The string has changed. Bail out.
				[self sendDelegateMethodDidHighlightRange:range success:NO];
				return;
			}

			[originalStringStorage replaceCharactersInRange:highlightRange withAttributedString:highlightedString];
			[self edited:NSTextStorageEditedAttributes range:highlightRange changeInLength:0];

			[self sendDelegateMethodDidHighlightRange:range success:YES];
		});
	});
}

/// Private helper method so that `highlightRange:` can be invoked using `performSelector`.
- (void)highlightRangeValue:(NSValue *)value
{
	_aggregateNeedHighlightRangeValue = nil;
	[self highlightRange:[value rangeValue]];
}

- (void)sendDelegateMethodDidHighlightRange:(NSRange)range success:(BOOL)success
{
	if (_highlightDelegate && [_highlightDelegate respondsToSelector:@selector(didHighlightRange:success:)])
	{
		NSObject<HighlightDelegate> __weak *delegate = _highlightDelegate;
		
		dispatch_async(dispatch_get_main_queue(), ^{
			[delegate didHighlightRange:range success:success];
		});
	}
}

@end
