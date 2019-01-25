//
//  MGSPrefsColourPropertiesViewController.h
//  Fragaria
//
//  Created by Jim Derry on 3/15/15.
//
//

#import "MGSPrefsViewController.h"
#import "MGSSyntaxParserClient.h"

@class MGSMutableColourScheme;


/**
 *  MGSPrefsColourPropertiesViewController provides a basic class for managing
 *  instances of the MGSPrefsColourProperties nib.
 **/

@interface MGSPrefsColourPropertiesViewController : MGSPrefsViewController <NSTableViewDelegate, NSTableViewDataSource>


@property (nonatomic, weak) IBOutlet NSObjectController *currentSchemeObjectController;


@property (nonatomic, strong) MGSMutableColourScheme *currentScheme;


@end


@interface MGSColourSchemeTableCellView: NSView

@property (nonatomic) IBOutlet NSButton *enabled;
@property (nonatomic) IBOutlet NSTextField *label;
@property (nonatomic) IBOutlet NSColorWell *colorWell;
@property (nonatomic) IBOutlet NSSegmentedControl *textVariant;

@property (nonatomic, weak) MGSPrefsColourPropertiesViewController *parentVc;
@property (nonatomic) SMLSyntaxGroup syntaxGroup;

- (void)updateView;
- (IBAction)updateScheme:(id)sender;

@end
