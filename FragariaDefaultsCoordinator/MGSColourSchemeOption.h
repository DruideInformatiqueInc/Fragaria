//
//  MGSColorSchemeOption.h
//  Fragaria
//
//  Created by Daniele Cattaneo on 20/10/17.
//
/// @cond PRIVATE

#import "MGSMutableColourScheme.h"


/** A subclass of MGSColorScheme that stores preferences-UI-only properties. */
@interface MGSColourSchemeOption : MGSMutableColourScheme


/** Indicates if this definition was loaded from a bundle. */
@property (nonatomic, assign) BOOL loadedFromBundle;

/** Indicates the complete and path and filename this instance was loaded
 *  from (if any). */
@property (nonatomic, strong) NSString *sourceFile;


@end
