//
//  MGSColourSchemeListController.h
//  Fragaria
//
//  Created by Jim Derry on 3/16/15.
//
/// @cond PRIVATE

#import <Cocoa/Cocoa.h>

@class MGSPreferencesController;
@class MGSPrefsColourPropertiesViewController;


/**
 *  MGSColourSchemeListController manages a list of MGSColourSchemes,
 *  and provides bindings for use in UI applications to support basic editing
 *  operations. As an NSArrayController descendant, it can be instantiated by IB.
 *  All functions are performed by modifying the color scheme through a separate
 *  NSObjectController (set through the colourSchemeController property)
 *  which should manage the colour scheme displayed by the rest of the user
 *  interface.
 *
 *  By default, schemes are loaded first from the framework bundle, then the
 *  application bundle, then finally from the application's Application Support
 *  folder. Schemes are saved in the application's Application Support/Colour
 *  Schemes directory, and only those schemes can be deleted.
 *
 *  To create a new scheme, the user modifies an already existing scheme through
 *  the colourSchemeController, at which point the name of the scheme changes to
 *  Custom Settings. This scheme can then be saved when ready.
 *
 *  This makes it impossible to modify existing schemes per se, however the
 *  workaround is to modify the existing scheme and save it with a new name,
 *  The previous version can then be selected and deleted. This is consistent
 *  with the behaviour of many other text editors.
 **/
@interface MGSColourSchemeListController : NSArrayController


/** A reference to the NSObjectController whose content is the instance of
 *  MGSColourScheme being edited. */
@property (nonatomic, assign) IBOutlet NSObjectController *colourSchemeController;


#pragma mark - Support for a Save/Delete button
/// @name Support for a Save/Delete button

/** The current correct state of a save/delete button. Bind the button's
 *  enabled binding to this property in Interface Builder to ensure its correct
 *  state. */
@property (nonatomic, assign, readonly) BOOL buttonSaveDeleteEnabled;

/** A title for the save/delete button. Bind the button's title to this property
 *  in interface builder for automatic localized button name. */
@property (nonatomic, assign, readonly) NSString *buttonSaveDeleteTitle;

/** The add/delete button action.
 *  @note When your button's title is bound to buttonSaveDelete title,
 *  the title will update dynamically to reflect the correct action.
 *  @param sender The object that sent the action. */
- (IBAction)addDeleteButtonAction:(id)sender;



@end
