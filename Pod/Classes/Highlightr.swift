//
//  Highlightr.swift
//  Pods
//
//  Created by Illanes, J.P. on 4/10/16.
//
//

import Foundation
import JavaScriptCore

/// Utility class for generating a highlighted NSAttributedString from a String.
@objc open class Highlightr: NSObject
{
    /// Returns the current Theme.
    @objc open var theme : Theme!
    {
        didSet
        {
            themeChanged?(theme)
        }
    }
    
    /// This block will be called every time the theme changes.
    @objc open var themeChanged : ((Theme) -> Void)?

    internal var multilineClasses: [String] = ["hljs-regexp", "hljs-string"]
    
    fileprivate let jsContext : JSContext
    fileprivate let hljs = "window.hljs"
    fileprivate let bundle : Bundle
    fileprivate let htmlStart = "<"
    fileprivate let spanStart = "span class=\""
    fileprivate let spanStartClose = "\">"
    fileprivate let spanEnd = "/span>"
    fileprivate let htmlEscape = try! NSRegularExpression(pattern: "&#?[a-zA-Z0-9]+?;", options: .caseInsensitive)
    /**
     Default init method.

     - returns: Highlightr instance.
     */
    @objc public override init()
    {
        jsContext = JSContext()
        jsContext.evaluateScript("var window = {};")
        bundle = Bundle(for: Highlightr.self)
        guard let hgPath = bundle.path(forResource: "highlight.min", ofType: "js") else
        {
            abort()
        }

        let hgJs = try! String.init(contentsOfFile: hgPath)
        let value = jsContext.evaluateScript(hgJs+" window.hljs = hljs; true")
        if !(value?.toBool())!
        {
            abort()
        }

        if let languageAddonsPath = bundle.path(forResource: "language-addons", ofType: "js"),
           let code = try? String(contentsOfFile: languageAddonsPath) {
            let value = jsContext.evaluateScript(code+" true;")
            if !(value?.toBool())!
            {
                abort()
            }
        }

        super.init()

        guard setTheme(to: "pojoaque") else
        {
            abort()
        }

    }

    /// Attributes that are added to the entire string after parsing. This is a useful place to change
    /// line height and other global features of the document.
    @objc open var documentAttributes: [NSAttributedString.Key: Any] = [:]

    /**
     Set the theme to use for highlighting.

     - returns: true if it was possible to set the given theme, false otherwise
     */
    @discardableResult
    @objc(setThemeToName:) open func setTheme(to name: String) -> Bool
    {
        guard let defTheme = bundle.path(forResource: name+".min", ofType: "css") else
        {
            return false
        }
        let themeString = try! String.init(contentsOfFile: defTheme)
        theme =  Theme(themeString: themeString)

        
        return true
    }
    
    /**
     Takes a String and returns a NSAttributedString with the given language highlighted.
     
     - parameter code:           Code to highlight.
     - parameter languageName:   Language name or alias. Set to `nil` to use auto detection.
     - parameter fastRender:     Defaults to true - When *true* will use the custom made html parser rather than Apple's solution.
     
     - returns: NSAttributedString with the detected code highlighted.
     */
    @objc open func highlight(_ code: String, as languageName: String? = nil, fastRender: Bool = true) -> NSMutableAttributedString?
    {
        var fixedCode = code.replacingOccurrences(of: "\\",with: "\\\\");
        fixedCode = fixedCode.replacingOccurrences(of: "\'",with: "\\\'");
        fixedCode = fixedCode.replacingOccurrences(of: "\"", with:"\\\"");
        fixedCode = fixedCode.replacingOccurrences(of: "\n", with:"\\n");
        fixedCode = fixedCode.replacingOccurrences(of: "\r", with:"\\r");

        let command: String
        if let languageName = languageName
        {
            command = String.init(format: "%@.highlight(\"%@\",\"%@\",true).value;", hljs, languageName, fixedCode)
        }
		else
        {
            // language auto detection
            command = String.init(format: "%@.highlightAuto(\"%@\").value;", hljs, fixedCode)
        }
        
        let res = jsContext.evaluateScript(command)
        guard var string = res!.toString() else
        {
            return nil
        }
        
        let returnString : NSMutableAttributedString
        if fastRender
        {
            returnString = processHTMLString(string, defaultLanguage: languageName)
        }
		else
        {
        	string = "<style>"+theme.lightTheme+"</style><pre><code class=\"hljs\">"+string+"</code></pre>"
			let opt: [NSAttributedString.DocumentReadingOptionKey : Any] = [
				.documentType: NSAttributedString.DocumentType.html,
				.characterEncoding: String.Encoding.utf8
			]

			let data = string.data(using: String.Encoding.utf8)!
			returnString = try! NSMutableAttributedString(data:data, options:opt, documentAttributes:nil)
        }

		if documentAttributes.count > 0
		{
			returnString.addAttributes(documentAttributes, range: NSMakeRange(0, returnString.length))
		}
        
        return returnString
    }
    
    /**
     Returns a list of all the available themes.
     
     - returns: Array of Strings
     */
    @objc open func availableThemes() -> [String]
    {
        let paths = bundle.paths(forResourcesOfType: "css", inDirectory: nil) as [NSString]
        var result = [String]()
        for path in paths {
            result.append(path.lastPathComponent.replacingOccurrences(of: ".min.css", with: ""))
        }
        
        return result
    }
    
    /**
     Returns a list of all supported languages.
     
     - returns: Array of Strings
     */
    @objc open func supportedLanguages() -> [String]
    {
        let command =  String.init(format: "%@.listLanguages();", hljs)
        let res = jsContext.evaluateScript(command)
        return res!.toArray() as! [String]
    }
	
	private enum LanguageUpperBound
	{
		// Means the language runs all the way to the end of the text buffer.
		case toEnd
		
		// Means the language runs for a certain length.
		case length(Int)
		
		// Means the upper bound is still being calculated.
		case undefined

        var isUndefined: Bool
        {
            if case .undefined = self
            {
                return true
            }

            return false
        }
	}
    
    //Private & Internal
	fileprivate func processHTMLString(_ string: String, defaultLanguage: String?) -> NSMutableAttributedString
    {
        let scanner = Scanner(string: string)
        scanner.charactersToBeSkipped = nil

        var scannedString: NSString?
        let resultString = NSMutableAttributedString(string: "")
        var propStack = ["hljs"]

        var languageMap: [Int: (upperBound: LanguageUpperBound, language: String)] = [:]
        var multilineElementMap: [Int: (upperBound: LanguageUpperBound, className: String)] = [:]
		var didPopLanguage = false
		
		if let language = defaultLanguage
		{
			// First we add a default highlight attribute to the entire range.
			languageMap[0] = (.toEnd, language)
		}
        
        while !scanner.isAtEnd
        {
            var ended = false
            if scanner.scanUpTo(htmlStart, into: &scannedString)
            {
                if scanner.isAtEnd
                {
                    ended = true
                }
            }
            
            if let scannedString = scannedString, scannedString.length > 0
			{
                if didPopLanguage, let startLocation = languageMap.keys.max()
				{
                    // We found the end of a language range. We need to calculate its length. Language attributes are
                    // cascading, so they end either before or with their "partent" attributes. In the end this makes
                    // no difference, as NSAttributedString only stores different versions of the same attribute in one
                    // dimension (there can be no overlap between attributes of the same key).
					languageMap[startLocation]?.upperBound = .length(resultString.length - startLocation)
					didPopLanguage = false
				}
				
				let attrScannedString = theme.applyStyleToString(scannedString as String, styleList: propStack)
				resultString.append(attrScannedString)

				if ended
                {
                    continue
                }
            }
            
            scanner.scanLocation += 1
            
            let string = scanner.string as NSString
            let nextCharRange = string.rangeOfComposedCharacterSequence(at: UInt(scanner.scanLocation), count: 1)
            let nextChar = string.substring(with: nextCharRange);
            if nextChar == "s"
            {
                scanner.scanLocation += (spanStart as NSString).length
                scanner.scanUpTo(spanStartClose, into:&scannedString)
                scanner.scanLocation += (spanStartClose as NSString).length

				if let property: String = scannedString as String?
				{
					propStack.append(property)

                    if multilineClasses.contains(property)
                    {
                        // This property class can be multi-line. We need to prepare to insert a multiline element
                        // attribute, and start by registering the current location and property class to the
                        // multi-language map.
                        multilineElementMap[resultString.length] = (.undefined, property)
                    }
					else if !property.hasPrefix("hljs"), property != "undefined"
					{
						// If the class name doesn't have the "hsjs" prefix, it is a language name, like "php".
						// We need to prepare to insert a language attibute, and begin by registering the current
                        // location and detected language name into the language map.
						languageMap[resultString.length] = (.undefined, property)
					}
				}
            }
            else if nextChar == "/"
            {
                scanner.scanLocation += (spanEnd as NSString).length
                let removed = propStack.removeLast()

                if multilineClasses.contains(removed)
                {
                    // We found a closing tag that can be multi-line. We need to prepare to update a multiline element
                    // element on the multiline element map, and so we set didPopPropertyOfClass with the class name
                    // that was just popped.

                    // A multi-line class was just popped from the property stack. We need to update its reference in
                    // the multi-language map.
                    let reversedKeys = multilineElementMap.keys.reversed()

                    // Find the las registered multi-line element of the same class as the one that was popped.
                    if let lowerBound = reversedKeys.first(where:
                        {
                            multilineElementMap[$0]?.className == removed
                                && multilineElementMap[$0]?.upperBound.isUndefined == true
                        })
                    {
                        // The lower bound index is also the key in the multi-line map.
                        multilineElementMap[lowerBound]?.upperBound = .length(resultString.length - lowerBound)
                    }
                    else
                    {
                        NSLog("Highlightr error: Could not pop multi-line element of class \(removed)")
                    }
                }
                if !removed.hasPrefix("hljs"), removed != "undefined"
				{
                    // If we found a closing tag without the "hsjs" prefix, it is a language name, like "php". We need
                    // to update a language registration on language map, and so we set didPopLanguage to true.
					didPopLanguage = true
				}
            }
			else
            {
                let attrScannedString = theme.applyStyleToString("<", styleList: propStack)
                resultString.append(attrScannedString)
                scanner.scanLocation += 1
            }
            
            scannedString = nil
        }
		
		// We can now apply the language attributes.
		for lowerBound in languageMap.keys.sorted()
		{
			guard let (upperBound, language) = languageMap[lowerBound] else
			{
				continue
			}
			
			let rangeLength: Int
			
			switch upperBound
			{
			case .length(let length):
				rangeLength = length
			
			default:
				rangeLength = resultString.length - lowerBound
			}

            // We have detected a span with a language-name class. To aid when highlighting changed text,
            // we add a custom attribute to the string with the language name.
			resultString.applyLanguageAttribute(language: language, range: NSMakeRange(lowerBound, rangeLength))
		}

        // We can now apply the multi-line attributes.
        for lowerBound in multilineElementMap.keys.sorted()
        {
            guard let (upperBound, className) = multilineElementMap[lowerBound] else
            {
                continue
            }

            let rangeLength: Int

            switch upperBound
            {
            case .length(let length):
                rangeLength = length

            default:
                rangeLength = resultString.length - lowerBound
            }

            resultString.addAttribute(.HighlightMultiLineElementBlock,
                                      value: className,
                                      range: NSMakeRange(lowerBound, rangeLength))
        }
        
        let results = htmlEscape.matches(in: resultString.string,
                                               options: [.reportCompletion],
                                               range: NSMakeRange(0, resultString.length))

        var locOffset = 0
        for result in results
        {
            let fixedRange = NSMakeRange(result.range.location-locOffset, result.range.length)
            let entity = (resultString.string as NSString).substring(with: fixedRange)
            if let decodedEntity = HTMLUtils.decode(entity)
            {
                resultString.replaceCharacters(in: fixedRange, with: String(decodedEntity))
                locOffset += result.range.length - 1;
            }
        }

        return resultString
    }
}

#if SYNTAX_DEBUG
private var colors = [UIColor.red, .green, .blue, .orange, .yellow, .brown, .purple]
private var colorIterator: IndexingIterator<[UIColor]>? = nil

var nextDebugColor: UIColor
{
	if let color = colorIterator?.next()
	{
		return color
	}
	else
	{
		var iterator = colors.makeIterator()
		colorIterator = iterator
		return iterator.next()!
	}
}
#endif

private extension NSMutableAttributedString
{
	func applyLanguageAttribute(language: String, range: NSRange)
	{
		addAttribute(.HighlightLanguageBlock, value: language, range: range)
		
		#if SYNTAX_DEBUG
		addAttribute(.backgroundColor, value: nextDebugColor, range: range)
		#endif
	}
}
