//
//  MGSColourScheme.h
//  Fragaria
//
//  Created by Jim Derry on 3/16/15.
//

#import <Cocoa/Cocoa.h>
#import "MGSSyntaxParserClient.h"


extern NSString * const MGSColourSchemeErrorDomain;

typedef NS_ENUM(NSUInteger, MGSColourSchemeErrorCode) {
    MGSColourSchemeWrongFileFormat = 1
};

@class MGSFragariaView;


/**
 *  MGSColourScheme defines a colour scheme for MGSColourSchemeListController.
 *  @discussion Property names (except for displayName) are identical
 *      to the MGSFragariaView property names.
 */

@interface MGSColourScheme : NSObject <NSCopying, NSMutableCopying>


#pragma mark - Initializing a Colour Scheme
/// @name Initializing a Colour Scheme


/** Initialize a new colour scheme instance from a dictionary.
 *  @param dictionary The dictionary representation of the plist file that
 *      defines the color scheme. Each key must map to an NSColor value
 *      (no unarchiving will be attempted). */
- (instancetype)initWithDictionary:(NSDictionary *)dictionary NS_DESIGNATED_INITIALIZER;

/** Initializes a new colour scheme instance from a file.
 *  @param file The URL of the plist file which contains the colour scheme values.
 *  @param err Upon return, if the initialization failed, contains an NSError object
 *         that describes the problem. */
- (instancetype)initWithSchemeFileURL:(NSURL *)file error:(NSError **)err;

/** Initializes a new colour scheme instance from a deserialized property list.
 *  @param plist The deserialized plist
 *  @param err   Upon return, if the initialization failed, contains an NSError object
 *               which describes the problem. */
- (instancetype)initWithPropertyList:(id)plist error:(NSError **)err;

/** Initializes a new colour scheme instance by copying another colour scheme.
 *  @param scheme The original colour scheme to copy. */
- (instancetype)initWithColourScheme:(MGSColourScheme *)scheme;

/** Initializes a new colour scheme instance with the default properties for the current
 * appearance. */
- (instancetype)init;

/** Returns a colour scheme instance with the default properties for
 * the specified appearance (or the current appearance if appearance is nil)
 * @param appearance The appearance appropriate for the returned scheme */
+ (instancetype)defaultColorSchemeForAppearance:(NSAppearance *)appearance;


#pragma mark - Saving Colour Schemes
/// @name Saving Loading Colour Schemes


/** Writes the object as a plist to the given file.
 *  @param file The complete path and file to write.
 *  @param err Upon return, if the operation failed, contains an NSError object
 *         that describes the problem. */
- (BOOL)writeToSchemeFileURL:(NSURL *)file error:(NSError **)err;


/** An NSDictionary representation of the Colour Scheme Properties */
@property (nonatomic, assign, readonly) NSDictionary *dictionaryRepresentation;

/** An valid property list NSDictionary representation of the Colour Scheme
 *  properties.
 *  @discussion These are NSData objects already archived for disk. */
@property (nonatomic, assign, readonly) NSDictionary *propertyListRepresentation;


#pragma mark - Getting Information on Properties
/// @name Getting Information of Properties


/** An array of colour schemes included with Fragaria.
 *  @discussion A new copy of the schemes is generated for every invocation
 *      of this method, as colour schemes are mutable. */
+ (NSArray <MGSColourScheme *> *)builtinColourSchemes;


#pragma mark - Colour Scheme Properties
/// @name Colour Scheme Properties


/** Display name of the color scheme. */
@property (nonatomic, strong, readonly) NSString *displayName;

/** Base text color. */
@property (nonatomic, strong, readonly) NSColor *textColor;
/** Editor background color. */
@property (nonatomic, strong, readonly) NSColor *backgroundColor;
/** Syntax error background highlighting color. */
@property (nonatomic, strong, readonly) NSColor *defaultSyntaxErrorHighlightingColour;
/** Editor invisible characters color. */
@property (nonatomic, strong, readonly) NSColor *textInvisibleCharactersColour;
/** Editor current line highlight color. */
@property (nonatomic, strong, readonly) NSColor *currentLineHighlightColour;
/** Editor insertion point color. */
@property (nonatomic, strong, readonly) NSColor *insertionPointColor;

/** Returns the highlighting colour of specified syntax group.
 *  @param syntaxGroup The syntax group identifier. */
- (NSColor *)colourForSyntaxGroup:(SMLSyntaxGroup)syntaxGroup;

/** Returns if the specified syntax group will be highlighted.
 *  @param syntaxGroup The syntax group identifier. */
- (BOOL)coloursSyntaxGroup:(SMLSyntaxGroup)syntaxGroup;

/** Returns the dictionary of attributes to use for colouring a
 *  token of a given syntax group.
 *  @param group The syntax group of the token.
 *  @param font The font used for non-highlighted text. */
- (NSDictionary<NSAttributedStringKey, id> *)attributesForSyntaxGroup:(SMLSyntaxGroup)group textFont:(NSFont *)font;


#pragma mark - Checking Equality
/// @name Checking Equality


/** Indicates if two schemes have the same colour settings.
 *  @param scheme The scheme that you want to compare to the receiver. */
- (BOOL)isEqualToScheme:(MGSColourScheme *)scheme;


@end

