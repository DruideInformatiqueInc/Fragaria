//
//  MGSColourSchemeListController.m
//  Fragaria
//
//  Created by Jim Derry on 3/16/15.
//
//

#import "MGSColourSchemeListController.h"
#import "MGSColourSchemeOption.h"
#import "MGSColourSchemeSaveController.h"
#import "MGSPrefsColourPropertiesViewController.h"


#pragma mark - Constants

static NSString * const KMGSColourSchemesFolder = @"Colour Schemes";
static NSString * const KMGSColourSchemeExt = @"plist";


#pragma mark - Category


@interface MGSColourSchemeListController ()

@property (nonatomic, strong, readwrite) NSMutableArray *colourSchemes;

@property (nonatomic, strong) MGSColourSchemeOption *currentScheme;
@property (nonatomic, assign) BOOL currentSchemeIsCustom;

@property (nonatomic, assign) BOOL ignoreObservations;

@property (nonatomic, strong) MGSColourSchemeSaveController *saveController;

@end


#pragma mark - Implementation


@implementation MGSColourSchemeListController


#pragma mark - Initialization and Startup

/*
 *  - awakeFromNib
 */
- (void)awakeFromNib
{
    /* The objectController that gets its data from MGSUserDefaults
       might not be connected to any data, so we don't want to do too much
       while we wait for it to connect by monitoring it via KVO. */

    [self setupEarly];
}


/*
 * - dealloc
 */
- (void)dealloc
{
    [self teardownObservers];
}


/*
 * - setupEarly
 */
- (void)setupEarly
{
    /* Load our schemes and get them ready for use. */
	[self loadColourSchemes];
	
    [self setSortDescriptors:@[ [[NSSortDescriptor alloc] initWithKey:@"displayName"
                                                            ascending:YES
                                                             selector:@selector(localizedCaseInsensitiveCompare:)]
                                ]];

    [self setContent:self.colourSchemes];
    
    /* Listen for the objectController to connect, if it didn't already */
    if (!self.colourSchemeController.content)
        [self addObserver:self forKeyPath:@"colourSchemeController.content" options:NSKeyValueObservingOptionNew context:@"objectController"];
    else
        [self setupLate];
}


/*
 * - setupLate
 */
- (void)setupLate
{
    /* Setup observation of the properties of the connected outlets. */
    [self setupObservers];

    /* Set our current scheme based on the view settings. */
    self.currentScheme = [[MGSColourSchemeOption alloc] initWithColourScheme:self.parentViewController.currentScheme];

    /* If the current scheme matches an existing theme, then set it. */
    [self findAndSetCurrentScheme];
}


#pragma mark - Properties

/*
 * @property buttonSaveDeleteEnabled
 */
+ (NSSet *)keyPathsForValuesAffectingButtonSaveDeleteEnabled
{
    return [NSSet setWithArray:@[ @"self.selectionIndex", @"self.currentScheme", @"self.schemeMenu.selectedObject", @"self.currentScheme.loadedFromBundle" ]];
}

- (BOOL)buttonSaveDeleteEnabled
{
    BOOL result;
    result = self.currentScheme && !self.currentScheme.loadedFromBundle;
    result = result || self.currentSchemeIsCustom;

    return result;
}


/*
 * @property buttonSaveDeleteTitle
 */
+ (NSSet *)keyPathsForValuesAffectingButtonSaveDeleteTitle
{
    return [NSSet setWithArray:@[ @"self.selectionIndex", @"self.currentScheme", @"self.schemeMenu.selectedObject", @"self.currentScheme.loadedFromBundle" ]];
}

- (NSString *)buttonSaveDeleteTitle
{
    // Rules:
    // - If the current scheme is self.currentSchemeIsCustom, can save.
    // - If the current scheme is not built-in, can delete.
    // - Otherwise the button should read as saving (will be disabled).

    if ( self.currentSchemeIsCustom || self.currentScheme.loadedFromBundle)
    {
        return NSLocalizedStringFromTableInBundle(@"Save Scheme…", nil, [NSBundle bundleForClass:[self class]],  @"The text for the save/delete scheme button when it should read Save Scheme…");
    }

    return NSLocalizedStringFromTableInBundle(@"Delete Scheme…", nil, [NSBundle bundleForClass:[self class]],  @"The text for the save/delete scheme button when it should read Delete Scheme…");
}


#pragma mark - Actions

/*
 * - addDeleteButtonAction
 */
- (IBAction)addDeleteButtonAction:(id)sender
{
    // Rules:
    // - If the current scheme is self.currentSchemeIsCustom, will save.
    // - If the current scheme is not built-in, will delete.
    // - Otherwise someone forgot to bind to the enabled property properly.

    if (self.currentSchemeIsCustom)
    {
        NSURL *path = [self applicationSupportDirectory];
        path = [path URLByAppendingPathComponent:KMGSColourSchemesFolder];

        [[NSFileManager defaultManager] createDirectoryAtURL: path
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];

        self.saveController = [[MGSColourSchemeSaveController alloc] init];
        self.saveController.schemeName = NSLocalizedStringFromTableInBundle(@"New Scheme", nil, [NSBundle bundleForClass:[self class]],  @"Default name for new schemes.");

        NSWindow *senderWindow = ((NSButton *)sender).window;
        [senderWindow beginSheet:self.saveController.window completionHandler:^(NSModalResponse returnCode) {
            if (returnCode != NSModalResponseOK ) {
                return;
            }

            NSString *schemefilename = [NSString stringWithFormat:@"%@.%@", self.saveController.fileName, KMGSColourSchemeExt];
            NSURL *schemeurl = [path URLByAppendingPathComponent:schemefilename];
            self.currentScheme.displayName = self.saveController.schemeName;
            [self.currentScheme writeToSchemeFileURL:schemeurl error:nil];
            [self willChangeValueForKey:@"buttonSaveDeleteEnabled"];
            [self willChangeValueForKey:@"buttonSaveDeleteTitle"];
            self.currentSchemeIsCustom = NO;
            [self didChangeValueForKey:@"buttonSaveDeleteEnabled"];
            [self didChangeValueForKey:@"buttonSaveDeleteTitle"];
        }];
    }
    else if (!self.currentScheme.loadedFromBundle)
    {
        self.saveController = [[MGSColourSchemeSaveController alloc] init];
        NSWindow *senderWindow = ((NSButton *)sender).window;
        NSAlert *panel = self.saveController.alertPanel;
        
        [panel beginSheetModalForWindow:senderWindow completionHandler:^(NSModalResponse returnCode) {
            if (returnCode == NSAlertFirstButtonReturn) {
                NSError *error;
                [[NSFileManager defaultManager] removeItemAtPath:self.currentScheme.sourceFile error:&error];
                if (error)
                {
                    NSLog(@"%@", error);
                }
                [self removeObject:self.currentScheme];
            }
        }];
    }
}


#pragma mark - KVO/KVC

/*
 * -setupObservers
 */
- (void)setupObservers
{
    [self.colourSchemeController addObserver:self forKeyPath:@"selection.dictionaryRepresentation" options:NSKeyValueObservingOptionNew context:@"colourSchemeChanged"];
    [self addObserver:self forKeyPath:@"selectionIndex" options:NSKeyValueObservingOptionNew context:@"schemeMenu"];
}


/*
 * - teardownObservers
 */
- (void)teardownObservers
{
    [self.colourSchemeController removeObserver:self forKeyPath:@"selection.dictionaryRepresentation" context:@"colourSchemeChanged"];
    [self removeObserver:self forKeyPath:@"selectionIndex" context:@"schemeMenu"];
}


/*
 * - observeValueForKeyPath:ofObject:change:context:
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    NSString *localContext = (__bridge NSString *)(context);

    if ([localContext isEqualToString:@"objectController"])
    {
        [self removeObserver:self forKeyPath:@"colourSchemeController.content" context:@"objectController"];
        [self setupLate];
    }
    else if (!self.ignoreObservations && [@"colourSchemeChanged" isEqual:localContext])
    {
        [self willChangeValueForKey:@"buttonSaveDeleteEnabled"];
        [self willChangeValueForKey:@"buttonSaveDeleteTitle"];
        [self findAndSetCurrentScheme];
        [self didChangeValueForKey:@"buttonSaveDeleteEnabled"];
        [self didChangeValueForKey:@"buttonSaveDeleteTitle"];
    }
    else if ([object isEqualTo:self] && !self.ignoreObservations && [localContext isEqualToString:@"schemeMenu"])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self willChangeValueForKey:@"buttonSaveDeleteEnabled"];
            [self willChangeValueForKey:@"buttonSaveDeleteTitle"];
            MGSColourSchemeOption *newScheme = [self.arrangedObjects objectAtIndex:self.selectionIndex];
            if (self.currentSchemeIsCustom)
            {
                self.ignoreObservations = YES;
                [self removeObject:self.currentScheme];
                self.currentSchemeIsCustom = NO;
                self.ignoreObservations = NO;
            }
            self.currentScheme = newScheme;
            [self applyColourSchemeToView];
            [self didChangeValueForKey:@"buttonSaveDeleteEnabled"];
            [self didChangeValueForKey:@"buttonSaveDeleteTitle"];
        });
    }
}


#pragma mark - Private/Internal


/*
 * - findMatchingSchemeForScheme:
 *   We're not forcing applications to store the name of a scheme, so try
 *   to determine what the current theme is based on the properties.
 */
- (MGSColourSchemeOption *)findMatchingSchemeForScheme:(MGSColourScheme *)scheme
{
    NSArray *list = self.colourSchemes;

    // ignore the custom theme if it's in the list. Convoluted, but avoids string checking.
    list = [list objectsAtIndexes:[list indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        return !( self.currentSchemeIsCustom && [self.currentScheme isEqual:obj] );
    }]];

    for (MGSColourSchemeOption *item in list)
	{
		if ([scheme isEqualToScheme:item])
		{
            return item;
		}
	}

	return nil;
}


/*
 * - applyColourSchemeToView
 *   apply the current colour scheme directly to the defaultsObjectController.
 */
- (void)applyColourSchemeToView
{
    self.ignoreObservations = YES;
    self.parentViewController.currentScheme = [self.currentScheme mutableCopy];
    self.ignoreObservations = NO;
}


/*
 * - findAndSetCurrentScheme
 *   If the view's settings match a known scheme, then set that as the active
 *   scheme, otherwise create a new (unsaved) scheme.
 */
- (void)findAndSetCurrentScheme
{
	MGSColourScheme *currentViewScheme = self.parentViewController.currentScheme;
    MGSColourSchemeOption *matchingScheme = [self findMatchingSchemeForScheme:currentViewScheme];

	if (matchingScheme)
    {
        if (self.currentSchemeIsCustom)
        {
            [self removeObject:self.currentScheme];
        }
		self.currentScheme = matchingScheme;
        self.selectionIndex = [self.arrangedObjects indexOfObject:self.currentScheme];
        self.currentSchemeIsCustom = NO;
    }
    else
    {
        // Take the current controller values.
        self.currentScheme = [[MGSColourSchemeOption alloc] initWithColourScheme:currentViewScheme];
        
        if (!self.currentSchemeIsCustom)
        {
            // Create and activate a custom scheme.
            self.currentScheme.displayName = NSLocalizedStringFromTableInBundle(
                @"Custom Settings", nil, [NSBundle bundleForClass:[MGSColourScheme class]],
                @"Name for Custom Settings scheme.");
            self.currentSchemeIsCustom = YES;
            self.ignoreObservations = YES;
            [self addObject:self.currentScheme];
            self.ignoreObservations = NO;
		}
    }
}


#pragma mark - I/O and File Loading

/*
 * - applicationSupportDirectory
 *   Get access to the user's Application Support directory, creating if needed.
 */
- (NSURL *)applicationSupportDirectory
{
    NSArray *URLS = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
    
    if (!URLS)
        return nil;
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *appSup = [URLS firstObject];
    NSURL *finalURL;
    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];

    if (infoDictionary.count != 0)
    {
        finalURL = [appSup URLByAppendingPathComponent:[infoDictionary objectForKey:@"CFBundleExecutable"] isDirectory:YES];
    }
    else
    {
        // Unit testing results in empty infoDictionary, so use a custom location.
        finalURL = [appSup URLByAppendingPathComponent:@"MGSFragaria Framework Unit Tests" isDirectory:YES];
    }

    if (![fileManager changeCurrentDirectoryPath:[finalURL path]])
    {
        [fileManager createDirectoryAtURL:finalURL
              withIntermediateDirectories:YES
                               attributes:nil
                                    error:nil];
    }
    return finalURL;
}


/*
 * - loadColourSchemes
 *   Look in several possible locations for scheme files.
 */
- (void)loadColourSchemes
{
    self.colourSchemes = [[NSMutableArray alloc] init];
    
    NSArray<MGSColourScheme *> *builtinSchemes = [MGSColourScheme builtinColourSchemes];
    for (MGSColourScheme *scheme in builtinSchemes) {
        MGSColourSchemeOption *option = [[MGSColourSchemeOption alloc] initWithColourScheme:scheme];
        [option setLoadedFromBundle:YES];
        [self.colourSchemes addObject:option];
    }
    
    NSDictionary <NSURL *, NSNumber *> *searchPaths = @{
        [[NSBundle mainBundle] resourceURL]: @(YES),
        [self applicationSupportDirectory]: @(NO)
    };

    for (NSURL *path in searchPaths) {
        BOOL bundleflag = [[searchPaths objectForKey:path] boolValue];
        [self addColourSchemesFromURL:path bundleFlag:bundleflag];
    }
}


/*
 * - addColourSchemesFromPath
 *   Given a directory path, load all of the plist files that are there.
 */
- (void)addColourSchemesFromURL:(NSURL *)path bundleFlag:(BOOL)bundleFlag
{
    // Build list of files to load.
    NSURL *directory = [path URLByAppendingPathComponent:KMGSColourSchemesFolder];
    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSError *e;
    NSArray *fileArray = [fileManager contentsOfDirectoryAtURL:directory includingPropertiesForKeys:@[] options:0 error:&e];
    if (!fileArray) {
//        NSLog(@"failed to add color schemes from %@; error %@", path, e);
        return;
    }

    // Append each file to the dictionary of colour schemes. By design,
    // subsequently loaded schemes with the same name replace existing.
    // This lets the application bundle override the framework, and lets
    // the user's Application Support override everything else.
    for (NSURL *file in fileArray) {
        if (![[file pathExtension] isEqual:KMGSColourSchemeExt])
            continue;
        MGSColourSchemeOption *scheme = [[MGSColourSchemeOption alloc] initWithSchemeFileURL:file error:nil];
        scheme.loadedFromBundle = bundleFlag;
        [self.colourSchemes addObject:scheme];
    }
}


@end
