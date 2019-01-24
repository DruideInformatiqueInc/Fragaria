//
//  MGSColourScheme.m
//  Fragaria
//
//  Created by Jim Derry on 3/16/15.
//
//

#import <objc/message.h>
#import "MGSColourScheme.h"
#import "MGSFragariaView+Definitions.h"
#import "MGSColourToPlainTextTransformer.h"
#import "NSColor+TransformedCompare.h"
#import "MGSMutableColourScheme.h"
#import "MGSColourSchemePrivate.h"


NSString * const MGSColourSchemeErrorDomain = @"MGSColourSchemeErrorDomain";


/*
 * NSDictionary keys used for propertyList/dictionaryRepresentation
 * Do not change!
 */

NSString * const MGSColourSchemeKeyCurrentLineHighlightColour    = @"currentLineHighlightColour";
NSString * const MGSColourSchemeKeyDefaultErrorHighlightingColor = @"defaultSyntaxErrorHighlightingColour";
NSString * const MGSColourSchemeKeyTextInvisibleCharactersColour = @"textInvisibleCharactersColour";
NSString * const MGSColourSchemeKeyTextColor                     = @"textColor";
NSString * const MGSColourSchemeKeyBackgroundColor               = @"backgroundColor";
NSString * const MGSColourSchemeKeyInsertionPointColor           = @"insertionPointColor";
NSString * const MGSColourSchemeKeyDisplayName                   = @"displayName";


/* New color options keys used in version 3+
 * The format was changed in order to represent extensible syntax
 * groups and additional properties other than color (like bold or
 * underline) */

NSString * const MGSColourSchemeKeySyntaxGroupOptions            = @"syntaxGroupOptions";

MGSColourSchemeGroupOptionKey MGSColourSchemeGroupOptionKeyEnabled = @"enabled";
MGSColourSchemeGroupOptionKey MGSColourSchemeGroupOptionKeyColour = @"colour";


/* Old color options used in version 2 */

NSString * const MGSColourSchemeKeyColourForAutocomplete = @"colourForAutocomplete";
NSString * const MGSColourSchemeKeyColourForAttributes   = @"colourForAttributes";
NSString * const MGSColourSchemeKeyColourForCommands     = @"colourForCommands";
NSString * const MGSColourSchemeKeyColourForComments     = @"colourForComments";
NSString * const MGSColourSchemeKeyColourForInstructions = @"colourForInstructions";
NSString * const MGSColourSchemeKeyColourForKeywords     = @"colourForKeywords";
NSString * const MGSColourSchemeKeyColourForNumbers      = @"colourForNumbers";
NSString * const MGSColourSchemeKeyColourForStrings      = @"colourForStrings";
NSString * const MGSColourSchemeKeyColourForVariables    = @"colourForVariables";

NSString * const MGSColourSchemeKeyColoursAttributes     = @"coloursAttributes";
NSString * const MGSColourSchemeKeyColoursAutocomplete   = @"coloursAutocomplete";
NSString * const MGSColourSchemeKeyColoursCommands       = @"coloursCommands";
NSString * const MGSColourSchemeKeyColoursComments       = @"coloursComments";
NSString * const MGSColourSchemeKeyColoursInstructions   = @"coloursInstructions";
NSString * const MGSColourSchemeKeyColoursKeywords       = @"coloursKeywords";
NSString * const MGSColourSchemeKeyColoursNumbers        = @"coloursNumbers";
NSString * const MGSColourSchemeKeyColoursStrings        = @"coloursStrings";
NSString * const MGSColourSchemeKeyColoursVariables      = @"coloursVariables";


static NSString * const KMGSColourSchemesFolder = @"Colour Schemes";
static NSString * const KMGSColourSchemeExt = @"plist";


@implementation MGSColourScheme
{
    NSMutableDictionary<SMLSyntaxGroup, MGSColourSchemeGroupData *> *_groupData;
}


#pragma mark - Initializers


- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
{
    self = [super init];
    
    _groupData = [[NSMutableDictionary alloc] init];
    
    NSDictionary *defaults = [[self class] defaultValues];
    NSMutableDictionary *tmp = [defaults mutableCopy];
    [tmp addEntriesFromDictionary:dictionary];
    NSDictionary *safe = [tmp dictionaryWithValuesForKeys:[defaults allKeys]];
    [self setPropertiesFromDictionary:safe];

    return self;
}


- (instancetype)initWithSchemeFileURL:(NSURL *)file error:(NSError **)err
{
    self = [self init];
    
    if (![self loadFromSchemeFileURL:file error:err])
        return nil;

    return self;
}


- (instancetype)initWithPropertyList:(id)plist error:(NSError **)err
{
    self = [self init];
    
    if (![self setPropertiesFromPropertyList:plist error:err])
        return nil;

    return self;
}


- (instancetype)initWithColourScheme:(MGSColourScheme *)scheme
{
    return [self initWithDictionary:[scheme dictionaryRepresentation]];
}


- (instancetype)init
{
	return [self initWithDictionary:@{}];
}


#pragma mark - Default Color Schemes


+ (instancetype)defaultColorSchemeForAppearance:(NSAppearance *)appearance
{
    return [[self alloc] initWithDictionary:[self defaultValuesForAppearance:appearance]];
}


+ (NSArray <MGSColourScheme *> *)builtinColourSchemes
{
    NSBundle *myBundle = [NSBundle bundleForClass:[self class]];
    NSArray <NSURL *> *paths = [myBundle URLsForResourcesWithExtension:KMGSColourSchemeExt subdirectory:KMGSColourSchemesFolder];
    
    NSMutableArray <MGSColourScheme *> *res = [NSMutableArray array];
    for (NSURL *path in paths) {
        MGSColourScheme *sch = [[MGSColourScheme alloc] initWithSchemeFileURL:path error:nil];
        if (!sch) {
            NSLog(@"loading of scheme %@ failed", path);
            continue;
        }
        [res addObject:sch];
    }
    
    return res;
}


// private
+ (NSDictionary *)defaultValues
{
    return [[self class] defaultValuesForAppearance:nil];
}


// private
+ (NSDictionary *)defaultValuesForAppearance:(NSAppearance *)appearance
{
    if (!appearance)
        appearance = [NSAppearance currentAppearance];
    
    NSString *dispName = NSLocalizedStringFromTableInBundle(
            @"Custom Settings", nil, [NSBundle bundleForClass:[self class]],
            @"Name for Custom Settings scheme.");
    NSMutableDictionary *common = [@{
            MGSColourSchemeKeyDisplayName  : dispName}
        mutableCopy];
    NSDictionary *commonEnabled = @{
        SMLSyntaxGroupAttribute     : @YES,
        SMLSyntaxGroupAutoComplete  : @NO,
        SMLSyntaxGroupCommand       : @YES,
        SMLSyntaxGroupComment       : @YES,
        SMLSyntaxGroupInstruction   : @YES,
        SMLSyntaxGroupKeyword       : @YES,
        SMLSyntaxGroupNumber        : @YES,
        SMLSyntaxGroupString        : @YES,
        SMLSyntaxGroupVariable      : @YES};
    
    BOOL dark = NO;
    if (@available(macOS 10.14.0, *)) {
        NSString *best = [appearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
        dark = [best isEqual:NSAppearanceNameDarkAqua];
    }
    
    NSDictionary *colors;
    NSDictionary *groupColors;
    if (!dark) {
        colors = @{
            MGSColourSchemeKeyDefaultErrorHighlightingColor : [NSColor colorWithCalibratedRed:1 green:1 blue:0.7 alpha:1],
            MGSColourSchemeKeyTextInvisibleCharactersColour : [NSColor blackColor],
            MGSColourSchemeKeyTextColor                     : [NSColor blackColor],
            MGSColourSchemeKeyBackgroundColor               : [NSColor whiteColor],
            MGSColourSchemeKeyInsertionPointColor           : [NSColor blackColor],
            MGSColourSchemeKeyCurrentLineHighlightColour    : [NSColor colorWithCalibratedRed:0.96f green:0.96f blue:0.71f alpha:1.0]};
        groupColors = @{
            SMLSyntaxGroupAutoComplete : [NSColor colorWithCalibratedRed:0.84f green:0.41f blue:0.006f alpha:1.0],
            SMLSyntaxGroupAttribute    : [NSColor colorWithCalibratedRed:0.50f green:0.5f blue:0.2f alpha:1.0],
            SMLSyntaxGroupCommand      : [NSColor colorWithCalibratedRed:0.031f green:0.0f blue:0.855f alpha:1.0],
            SMLSyntaxGroupComment      : [NSColor colorWithCalibratedRed:0.0f green:0.45f blue:0.0f alpha:1.0],
            SMLSyntaxGroupInstruction  : [NSColor colorWithCalibratedRed:0.737f green:0.0f blue:0.647f alpha:1.0],
            SMLSyntaxGroupKeyword      : [NSColor colorWithCalibratedRed:0.737f green:0.0f blue:0.647f alpha:1.0],
            SMLSyntaxGroupNumber       : [NSColor colorWithCalibratedRed:0.031f green:0.0f blue:0.855f alpha:1.0],
            SMLSyntaxGroupString       : [NSColor colorWithCalibratedRed:0.804f green:0.071f blue:0.153f alpha:1.0],
            SMLSyntaxGroupVariable     : [NSColor colorWithCalibratedRed:0.73f green:0.0f blue:0.74f alpha:1.0]};
    } else {
        colors = @{
            MGSColourSchemeKeyDefaultErrorHighlightingColor : [NSColor colorWithCalibratedWhite:0.4 alpha:1.0],
            MGSColourSchemeKeyTextInvisibleCharactersColour : [NSColor colorWithCalibratedRed:0.905882f green:0.905882f blue:0.905882f alpha:1.0],
            MGSColourSchemeKeyTextColor                     : [NSColor whiteColor],
            MGSColourSchemeKeyBackgroundColor               : [NSColor blackColor],
            MGSColourSchemeKeyInsertionPointColor           : [NSColor whiteColor],
            MGSColourSchemeKeyCurrentLineHighlightColour    : [NSColor blackColor]};
        groupColors = @{
            SMLSyntaxGroupAutoComplete : [NSColor colorWithCalibratedRed:0.84f green:0.41f blue:0.006f alpha:1.0],
            SMLSyntaxGroupAttribute    : [NSColor colorWithCalibratedRed:0.5f green:0.5f blue:0.2f alpha:1.0],
            SMLSyntaxGroupCommand      : [NSColor colorWithCalibratedRed:0.031f green:0.0f blue:0.855f alpha:1.0],
            SMLSyntaxGroupComment      : [NSColor colorWithCalibratedRed:0.254902f green:0.8f blue:0.270588f alpha:1.0],
            SMLSyntaxGroupInstruction  : [NSColor colorWithCalibratedRed:0.737f green:0.0f blue:0.647f alpha:1.0],
            SMLSyntaxGroupKeyword      : [NSColor colorWithCalibratedRed:0.827451f green:0.094118f blue:0.580392f alpha:1.0],
            SMLSyntaxGroupNumber       : [NSColor colorWithCalibratedRed:0.466667f green:0.427451f blue:1.0f alpha:1.0],
            SMLSyntaxGroupString       : [NSColor colorWithCalibratedRed:1.0f green:0.172549f blue:0.219608f alpha:1.0],
            SMLSyntaxGroupVariable     : [NSColor colorWithCalibratedRed:0.73f green:0.0f blue:0.74f alpha:1.0]};
    }
    
    [common addEntriesFromDictionary:colors];
    NSMutableDictionary *groups = [NSMutableDictionary dictionary];
    for (NSString *group in commonEnabled) {
        NSDictionary *options = @{
            MGSColourSchemeGroupOptionKeyEnabled: commonEnabled[group],
            MGSColourSchemeGroupOptionKeyColour:  groupColors[group]};
        [groups setObject:options forKey:group];
    }
    [common setObject:groups forKey:MGSColourSchemeKeySyntaxGroupOptions];
    return [common copy];
}


#pragma mark - Bulk Property Accessors


+ (NSSet *)keyPathsForValuesAffectingDictionaryRepresentation
{
    static NSSet *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [NSSet setWithObjects:
            NSStringFromSelector(@selector(displayName)),
            NSStringFromSelector(@selector(insertionPointColor)),
            NSStringFromSelector(@selector(currentLineHighlightColour)),
            NSStringFromSelector(@selector(defaultSyntaxErrorHighlightingColour)),
            NSStringFromSelector(@selector(textColor)),
            NSStringFromSelector(@selector(backgroundColor)),
            NSStringFromSelector(@selector(textInvisibleCharactersColour)),
            NSStringFromSelector(@selector(syntaxGroupOptions)),
            nil];
    });
    return cache;
}


- (NSDictionary *)dictionaryRepresentation
{
    return @{
        MGSColourSchemeKeyDisplayName:                   self.displayName,
        MGSColourSchemeKeyInsertionPointColor:           self.insertionPointColor,
        MGSColourSchemeKeyCurrentLineHighlightColour:    self.currentLineHighlightColour,
        MGSColourSchemeKeyDefaultErrorHighlightingColor: self.defaultSyntaxErrorHighlightingColour,
        MGSColourSchemeKeyTextColor:                     self.textColor,
        MGSColourSchemeKeyBackgroundColor:               self.backgroundColor,
        MGSColourSchemeKeyTextInvisibleCharactersColour: self.textInvisibleCharactersColour,
        MGSColourSchemeKeySyntaxGroupOptions:            self.syntaxGroupOptions };
}


// private
- (void)setPropertiesFromDictionary:(NSDictionary *)dict
{
    self.displayName                          = dict[MGSColourSchemeKeyDisplayName];
    self.insertionPointColor                  = dict[MGSColourSchemeKeyInsertionPointColor];
    self.currentLineHighlightColour           = dict[MGSColourSchemeKeyCurrentLineHighlightColour];
    self.defaultSyntaxErrorHighlightingColour = dict[MGSColourSchemeKeyDefaultErrorHighlightingColor];
    self.textColor                            = dict[MGSColourSchemeKeyTextColor];
    self.backgroundColor                      = dict[MGSColourSchemeKeyBackgroundColor];
    self.textInvisibleCharactersColour        = dict[MGSColourSchemeKeyTextInvisibleCharactersColour];
    self.syntaxGroupOptions                   = dict[MGSColourSchemeKeySyntaxGroupOptions];
}


- (id)propertyListRepresentation
{
    NSValueTransformer *xformer = [NSValueTransformer valueTransformerForName:@"MGSColourToPlainTextTransformer"];
    
    NSMutableDictionary *groupOptions = [NSMutableDictionary dictionary];
    [_groupData enumerateKeysAndObjectsUsingBlock:^(NSString *key, MGSColourSchemeGroupData *obj, BOOL *stop) {
        NSMutableDictionary *opts = [[obj optionDictionary] mutableCopy];
        NSString *newColor = [xformer transformedValue:opts[MGSColourSchemeGroupOptionKeyColour]];
        [opts setObject:newColor forKey:MGSColourSchemeGroupOptionKeyColour];
        [groupOptions setObject:opts forKey:key];
    }];
    
    return @{
        MGSColourSchemeKeyDisplayName:
            self.displayName,
        MGSColourSchemeKeyInsertionPointColor:
            [xformer transformedValue:self.insertionPointColor],
        MGSColourSchemeKeyCurrentLineHighlightColour:
            [xformer transformedValue:self.currentLineHighlightColour],
        MGSColourSchemeKeyDefaultErrorHighlightingColor:
            [xformer transformedValue:self.defaultSyntaxErrorHighlightingColour],
        MGSColourSchemeKeyTextColor:
            [xformer transformedValue:self.textColor],
        MGSColourSchemeKeyBackgroundColor:
            [xformer transformedValue:self.backgroundColor],
        MGSColourSchemeKeyTextInvisibleCharactersColour:
            [xformer transformedValue:self.textInvisibleCharactersColour],
        MGSColourSchemeKeySyntaxGroupOptions:
            groupOptions};
}


// private
- (BOOL)setPropertiesFromPropertyList:(id)fileContents error:(NSError **)err
{
    NSMutableDictionary *dictionary = [[[self class] defaultValues] mutableCopy];
    NSError *outerror = [self parseFragaria3PropertyList:fileContents intoDictionary:dictionary];
    if (outerror) {
        outerror = [self parseFragaria2PropertyList:fileContents intoDictionary:dictionary];
    }
    
    if (outerror) {
        if (err) *err = outerror;
        return NO;
    }
    
    [self setPropertiesFromDictionary:dictionary];
    return YES;
}


- (NSError *)parseFragaria3PropertyList:(id)fileContents intoDictionary:(NSMutableDictionary *)dictionary
{
    NSError *err = [NSError errorWithDomain:MGSColourSchemeErrorDomain code:MGSColourSchemeWrongFileFormat userInfo:@{}];
    NSValueTransformer *xformer = [NSValueTransformer valueTransformerForName:@"MGSColourToPlainTextTransformer"];
    
    if (![fileContents isKindOfClass:[NSDictionary class]])
        return err;
    
    if (![fileContents objectForKey:MGSColourSchemeKeySyntaxGroupOptions])
        return err;
    
    NSDictionary *rootKeyTypes = @{
        MGSColourSchemeKeyDisplayName:                      [NSString class],
        MGSColourSchemeKeyInsertionPointColor:              [NSString class],
        MGSColourSchemeKeyCurrentLineHighlightColour:       [NSString class],
        MGSColourSchemeKeyDefaultErrorHighlightingColor:    [NSString class],
        MGSColourSchemeKeyTextColor:                        [NSString class],
        MGSColourSchemeKeyBackgroundColor:                  [NSString class],
        MGSColourSchemeKeyTextInvisibleCharactersColour:    [NSString class],
        MGSColourSchemeKeySyntaxGroupOptions:               [NSDictionary class]};
    if (![self checkObjectTypes:rootKeyTypes inDictionary:fileContents])
        return err;
    
    id tmp;
    if ((tmp = [fileContents objectForKey:MGSColourSchemeKeyDisplayName]))
        [dictionary setObject:tmp forKey:MGSColourSchemeKeyDisplayName];
    NSArray *baseColors = @[
        MGSColourSchemeKeyInsertionPointColor,
        MGSColourSchemeKeyCurrentLineHighlightColour,
        MGSColourSchemeKeyDefaultErrorHighlightingColor,
        MGSColourSchemeKeyTextColor,
        MGSColourSchemeKeyBackgroundColor,
        MGSColourSchemeKeyTextInvisibleCharactersColour];
    for (NSString *key in baseColors) {
        if (!(tmp = [fileContents objectForKey:key]))
            continue;
        NSColor *new = [xformer reverseTransformedValue:tmp];
        if (!new)
            return err;
        [dictionary setObject:new forKey:key];
    }
    
    NSDictionary *optionTypes = @{
        MGSColourSchemeGroupOptionKeyEnabled:               [NSNumber class],
        MGSColourSchemeGroupOptionKeyColour:                [NSString class],
        MGSColourSchemeGroupOptionKeyFontVariant:           [NSNumber class]};
    NSMutableDictionary *newOptions = [NSMutableDictionary dictionary];
    NSDictionary *optionDict = fileContents[MGSColourSchemeKeySyntaxGroupOptions];
    for (id key in optionDict) {
        if (![key isKindOfClass:[NSString class]])
            return err;
        id options = [optionDict objectForKey:key];
        if (![options isKindOfClass:[NSDictionary class]])
            return err;
        if (![self checkObjectTypes:optionTypes inDictionary:options])
            return err;
        
        NSMutableDictionary *fixedOptionDict = [options mutableCopy];
        NSString *colorstring;
        if ((colorstring = [fixedOptionDict objectForKey:MGSColourSchemeGroupOptionKeyColour])) {
            NSColor *newcolor = [xformer reverseTransformedValue:colorstring];
            [fixedOptionDict setObject:newcolor forKey:MGSColourSchemeGroupOptionKeyColour];
        }
        [newOptions setObject:fixedOptionDict forKey:key];
    }
    [dictionary setObject:newOptions forKey:MGSColourSchemeKeySyntaxGroupOptions];
    
    return nil;
}


- (BOOL)checkObjectTypes:(NSDictionary<id, Class> *)keyToType inDictionary:(NSDictionary *)dict
{
    __block BOOL res = YES;
    [dict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        Class expected = [keyToType objectForKey:key];
        if (!expected) {
            NSLog(@"unrecognized key %@ when loading colour scheme from V3 deserialized plist", key);
        } else if (![obj isKindOfClass:expected]) {
            *stop = YES;
            res = NO;
        }
    }];
    return res;
}


// private
- (NSError *)parseFragaria2PropertyList:(id)fileContents intoDictionary:(NSMutableDictionary *)dictionary
{
    NSError *err = [NSError errorWithDomain:MGSColourSchemeErrorDomain code:MGSColourSchemeWrongFileFormat userInfo:@{}];
    NSValueTransformer *xformer = [NSValueTransformer valueTransformerForName:@"MGSColourToPlainTextTransformer"];
    
    NSDictionary *syntaxGroups = @{
        SMLSyntaxGroupNumber:       [NSMutableDictionary dictionary],
        SMLSyntaxGroupString:       [NSMutableDictionary dictionary],
        SMLSyntaxGroupCommand:      [NSMutableDictionary dictionary],
        SMLSyntaxGroupComment:      [NSMutableDictionary dictionary],
        SMLSyntaxGroupKeyword:      [NSMutableDictionary dictionary],
        SMLSyntaxGroupVariable:     [NSMutableDictionary dictionary],
        SMLSyntaxGroupAttribute:    [NSMutableDictionary dictionary],
        SMLSyntaxGroupInstruction:  [NSMutableDictionary dictionary],
        SMLSyntaxGroupAutoComplete: [NSMutableDictionary dictionary]};
    
    NSDictionary *keyToGroup = @{
        MGSColourSchemeKeyColourForAutocomplete:    SMLSyntaxGroupAutoComplete,
        MGSColourSchemeKeyColourForAttributes:      SMLSyntaxGroupAttribute,
        MGSColourSchemeKeyColourForCommands:        SMLSyntaxGroupCommand,
        MGSColourSchemeKeyColourForComments:        SMLSyntaxGroupComment,
        MGSColourSchemeKeyColourForInstructions:    SMLSyntaxGroupInstruction,
        MGSColourSchemeKeyColourForKeywords:        SMLSyntaxGroupKeyword,
        MGSColourSchemeKeyColourForNumbers:         SMLSyntaxGroupNumber,
        MGSColourSchemeKeyColourForStrings:         SMLSyntaxGroupString,
        MGSColourSchemeKeyColourForVariables:       SMLSyntaxGroupVariable,
        MGSColourSchemeKeyColoursAttributes:        SMLSyntaxGroupAttribute,
        MGSColourSchemeKeyColoursAutocomplete:      SMLSyntaxGroupAutoComplete,
        MGSColourSchemeKeyColoursCommands:          SMLSyntaxGroupCommand,
        MGSColourSchemeKeyColoursComments:          SMLSyntaxGroupComment,
        MGSColourSchemeKeyColoursInstructions:      SMLSyntaxGroupInstruction,
        MGSColourSchemeKeyColoursKeywords:          SMLSyntaxGroupKeyword,
        MGSColourSchemeKeyColoursNumbers:           SMLSyntaxGroupNumber,
        MGSColourSchemeKeyColoursStrings:           SMLSyntaxGroupString,
        MGSColourSchemeKeyColoursVariables:         SMLSyntaxGroupVariable};

    NSSet *stringKeys = [NSSet setWithArray:@[
        MGSColourSchemeKeyDisplayName]];
    NSSet *colorKeys = [NSSet setWithArray:@[
        MGSColourSchemeKeyInsertionPointColor,
        MGSColourSchemeKeyCurrentLineHighlightColour,
        MGSColourSchemeKeyDefaultErrorHighlightingColor,
        MGSColourSchemeKeyTextColor,
        MGSColourSchemeKeyBackgroundColor,
        MGSColourSchemeKeyTextInvisibleCharactersColour,
        MGSColourSchemeKeyColourForAutocomplete,
        MGSColourSchemeKeyColourForAttributes,
        MGSColourSchemeKeyColourForCommands,
        MGSColourSchemeKeyColourForComments,
        MGSColourSchemeKeyColourForInstructions,
        MGSColourSchemeKeyColourForKeywords,
        MGSColourSchemeKeyColourForNumbers,
        MGSColourSchemeKeyColourForStrings,
        MGSColourSchemeKeyColourForVariables]];
    NSSet *boolKeys = [NSSet setWithArray:@[
        MGSColourSchemeKeyColoursAttributes,
        MGSColourSchemeKeyColoursAutocomplete,
        MGSColourSchemeKeyColoursCommands,
        MGSColourSchemeKeyColoursComments,
        MGSColourSchemeKeyColoursInstructions,
        MGSColourSchemeKeyColoursKeywords,
        MGSColourSchemeKeyColoursNumbers,
        MGSColourSchemeKeyColoursStrings,
        MGSColourSchemeKeyColoursVariables]];
    
    if (![fileContents isKindOfClass:[NSDictionary class]])
        return err;
    
    for (NSString *key in fileContents) {
        id object;
    
        if ([stringKeys containsObject:key]) {
            object = [fileContents objectForKey:key];
            if (![object isKindOfClass:[NSString class]])
                return err;
            
        } else if ([colorKeys containsObject:key]) {
            id data = [fileContents objectForKey:key];
            if ([data isKindOfClass:[NSData class]]) {
                object = [NSUnarchiver unarchiveObjectWithData:data];
            } else if ([data isKindOfClass:[NSString class]]) {
                object = [xformer reverseTransformedValue:[fileContents objectForKey:key]];
            } else {
                return err;
            }
            if (![object isKindOfClass:[NSColor class]])
                return err;
        
        } else if ([boolKeys containsObject:key]) {
            object = [fileContents objectForKey:key];
            if (![object isKindOfClass:[NSNumber class]])
                return err;
            
        } else {
            NSLog(@"unrecognized key %@ when loading colour scheme from deserialized plist", key);
            continue;
        }
    
        [dictionary setObject:object forKey:key];
    }
    
    [keyToGroup enumerateKeysAndObjectsUsingBlock:^(NSString *plistkey, NSString *group, BOOL *stop) {
        id val = [dictionary objectForKey:plistkey];
        [dictionary removeObjectForKey:plistkey];
        NSMutableDictionary *groupOpts = [syntaxGroups objectForKey:group];
        if ([val isKindOfClass:[NSNumber class]]) {
            [groupOpts setObject:val forKey:MGSColourSchemeGroupOptionKeyEnabled];
        } else {
            [groupOpts setObject:val forKey:MGSColourSchemeGroupOptionKeyColour];
        }
    }];
    [dictionary setObject:syntaxGroups forKey:MGSColourSchemeKeySyntaxGroupOptions];
    
    return nil;
}


#pragma mark - Colour Scheme File I/O


- (BOOL)loadFromSchemeFileURL:(NSURL *)file error:(NSError **)err
{
    NSInputStream *fp = [NSInputStream inputStreamWithURL:file];
    [fp open];
    if (!fp) {
        if (err)
            *err = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadUnknownError userInfo:nil];
        return NO;
    }
    
    id fileContents = [NSPropertyListSerialization propertyListWithStream:fp options:NSPropertyListImmutable format:nil error:err];
    if (!fileContents)
        goto plistError;
    [fp close];

    return [self setPropertiesFromPropertyList:fileContents error:err];
    
plistError:
    if (err) {
        if ([[*err domain] isEqual:NSCocoaErrorDomain]) {
            if ([*err code] != NSPropertyListReadStreamError)
                *err = [NSError errorWithDomain:MGSColourSchemeErrorDomain code:MGSColourSchemeWrongFileFormat userInfo:@{NSUnderlyingErrorKey: *err}];
            else if ([[*err userInfo] objectForKey:NSUnderlyingErrorKey])
                *err = [[*err userInfo] objectForKey:NSUnderlyingErrorKey];
        }
    }
    return NO;
}


- (BOOL)writeToSchemeFileURL:(NSURL *)file error:(NSError **)err
{
    NSDictionary *props = [self propertyListRepresentation];
    
    NSOutputStream *fp = [NSOutputStream outputStreamWithURL:file append:NO];
    if (!fp) {
        if (err)
            *err = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError userInfo:nil];
    }
    
    [fp open];
    BOOL res = [NSPropertyListSerialization writePropertyList:props toStream:fp format:NSPropertyListXMLFormat_v1_0 options:0 error:err];
    [fp close];
    
    return res;
}


#pragma mark - NSObject / NSCopying


/*
 * - isEqualToScheme:
 */
- (BOOL)isEqualToScheme:(MGSColourScheme *)scheme
{
    return [self.dictionaryRepresentation isEqual:scheme.dictionaryRepresentation];
}


- (BOOL)isEqual:(id)other
{
    if ([super isEqual:other])
        return YES;
    if ([other isKindOfClass:[self class]] && [self class] != [other class])
        return [other isEqual:self];
    if (![self isKindOfClass:[other class]])
        return NO;
    return [self isEqualToScheme:other];
}


- (NSUInteger)hash
{
    NSUInteger res = [self.displayName hash];
    res ^= [self.textColor hash] ^ [self.backgroundColor hash];
    res ^= [[self colourForSyntaxGroup:SMLSyntaxGroupString] hash];
    res ^= [[self colourForSyntaxGroup:SMLSyntaxGroupKeyword] hash];
    return res;
}


- (NSString *)description
{
    return [NSString stringWithFormat:@"<(%@ *)%p displayName=\"%@\">",
        NSStringFromClass([self class]),
        self,
        self.displayName];
}


- (id)copyWithZone:(NSZone *)zone
{
    return self;
}


- (id)mutableCopyWithZone:(NSZone *)zone
{
    return [[MGSMutableColourScheme alloc] initWithColourScheme:self];
}


#pragma mark - Colour Scheme Properties


- (NSColor *)colourForSyntaxGroup:(SMLSyntaxGroup)syntaxGroup
{
    MGSColourSchemeGroupData *data = [_groupData objectForKey:syntaxGroup];
    if (!data)
        return nil;
    return data.color;
}


- (BOOL)coloursSyntaxGroup:(SMLSyntaxGroup)syntaxGroup
{
    MGSColourSchemeGroupData *data = [_groupData objectForKey:syntaxGroup];
    if (!data)
        return NO;
    return data.enabled;
}


- (MGSColourSchemeGroupData *)returnOrCreateDataForGroup:(SMLSyntaxGroup)group
{
    MGSColourSchemeGroupData *data = [_groupData objectForKey:group];
    if (data)
        return data;
    return [[MGSColourSchemeGroupData alloc] init];
}


- (void)setColour:(NSColor *)color forSyntaxGroup:(SMLSyntaxGroup)group
{
    [self willChangeValueForKey:NSStringFromSelector(@selector(syntaxGroupOptions))];
    
    MGSColourSchemeGroupData *data = [self returnOrCreateDataForGroup:group];
    data.color = color;
    
    [self didChangeValueForKey:NSStringFromSelector(@selector(syntaxGroupOptions))];
}


- (void)setColours:(BOOL)enabled syntaxGroup:(SMLSyntaxGroup)group
{
    [self willChangeValueForKey:NSStringFromSelector(@selector(syntaxGroupOptions))];
    
    MGSColourSchemeGroupData *data = [self returnOrCreateDataForGroup:group];
    data.enabled = enabled;
    
    [self didChangeValueForKey:NSStringFromSelector(@selector(syntaxGroupOptions))];
}


- (NSDictionary<NSAttributedStringKey, id> *)attributesForSyntaxGroup:(SMLSyntaxGroup)group textFont:(NSFont *)font
{
    if (![self coloursSyntaxGroup:group])
        return @{};
    NSColor *color = [self colourForSyntaxGroup:group];
    if (!color)
        color = self.textColor;
    return @{NSForegroundColorAttributeName: color};
}


- (NSDictionary<SMLSyntaxGroup, NSDictionary<MGSColourSchemeGroupOptionKey, id> *> *)syntaxGroupOptions
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [_groupData enumerateKeysAndObjectsUsingBlock:^(NSString *group, MGSColourSchemeGroupData *data, BOOL *stop) {
        [dict setObject:[data optionDictionary] forKey:group];
    }];
    return [dict copy];
}


- (void)setSyntaxGroupOptions:(NSDictionary<SMLSyntaxGroup, NSDictionary<MGSColourSchemeGroupOptionKey, id> *> *)syntaxGroupOptions
{
    [_groupData removeAllObjects];
    [syntaxGroupOptions enumerateKeysAndObjectsUsingBlock:^(NSString *group, NSDictionary<NSString *,id> *opts, BOOL *stop) {
        MGSColourSchemeGroupData *data = [[MGSColourSchemeGroupData alloc] initWithOptionDictionary:opts];
        [self->_groupData setObject:data forKey:group];
    }];
}


@end


#pragma mark - Group Data Object


@implementation MGSColourSchemeGroupData


- (instancetype)init
{
    self = [super init];
    _enabled = YES;
    _color = nil;
    return self;
}


- (instancetype)initWithOptionDictionary:(NSDictionary<MGSColourSchemeGroupOptionKey, id> *)optionDictionary
{
    self = [self init];
    NSNumber *enabled = [optionDictionary objectForKey:MGSColourSchemeGroupOptionKeyEnabled];
    if (enabled)
        _enabled = [enabled boolValue];
    NSColor *color = [optionDictionary objectForKey:MGSColourSchemeGroupOptionKeyColour];
    if (color)
        _color = color;
    return self;
}


- (NSDictionary<MGSColourSchemeGroupOptionKey, id> *)optionDictionary
{
    NSMutableDictionary *res = [NSMutableDictionary dictionary];
    [res setObject:@(self.enabled) forKey:MGSColourSchemeGroupOptionKeyEnabled];
    if (self.color)
        [res setObject:self.color forKey:MGSColourSchemeGroupOptionKeyColour];
    return [res copy];
}


@end

