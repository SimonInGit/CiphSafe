/*
 * Copyright � 2003,2006-2007,2011, Bryan L Blackburn.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in
 *    the documentation and/or other materials provided with the
 *    distribution.
 *
 * 3. Neither the names Bryan L Blackburn, Withay.com, nor the names of
 *    any contributors may be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY BRYAN L BLACKBURN ``AS IS'' AND ANY
 * EXPRESSED OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
 * BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 * OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
 * IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */
// Interesting security issues are noted with XXX in comments
/* CSWinCtrlChange.m */

#import "CSWinCtrlChange.h"
#import "CSDocument.h"
#import "CSDocModel.h"
#import "CSPrefsController.h"


@interface CSWinCtrlChange (InternalMethods)
- (void) updateFields;
@end


@implementation CSWinCtrlChange

static NSMutableDictionary *controllerList;   // Indexed by document, of arrays


#pragma mark -
#pragma mark Initialization
/*
 * Create our controller list
 */
+ (void) initialize
{
   controllerList = [[NSMutableDictionary alloc] initWithCapacity:25];
}


/*
 * Initialize for the given entry
 */
- (id) initForEntryName:(NSString *)name
{
   self = [super initWithWindowNibName:@"CSDocumentChange"];
   if(self != nil)
      myEntryName = [name copy];

   return self;
}


#pragma mark -
#pragma mark Controller List Helpers
/*
 * Return an NSNumber representing the document
 */
+ (NSNumber *) numberForDocument:(NSDocument *)document
{
   return [NSNumber numberWithUnsignedInteger:[document hash]];
}


/*
 * Add the controller to the list of controllers
 */
+ (void) addController:(CSWinCtrlChange *)newController
           forDocument:(NSDocument *)document
{
   NSMutableArray *arrayForDocument = [controllerList objectForKey:
                                                         [CSWinCtrlChange numberForDocument:document]];
   if(arrayForDocument == nil)
   {
      arrayForDocument = [NSMutableArray arrayWithCapacity:5];
      [controllerList setObject:arrayForDocument forKey:[CSWinCtrlChange numberForDocument:document]];
   }
   [arrayForDocument addObject:newController];
}


/*
 * Remove the controller
 */
+ (void) removeController:(CSWinCtrlChange *)oldController
              forDocument:(NSDocument *)document
{
   NSMutableArray *arrayForDocument = [controllerList objectForKey:
                                                         [CSWinCtrlChange numberForDocument:document]];
   NSAssert(arrayForDocument != nil,
            @"attempt to remove controller for document with no controllers");
   [arrayForDocument removeObject:oldController];
}


/*
 * Find the controller responsible for the given entry
 */
+ (CSWinCtrlChange *) controllerForEntryName:(NSString *)entryName
                                  inDocument:(NSDocument *)document
{
   NSArray *arrayForDocument = [controllerList objectForKey:[CSWinCtrlChange numberForDocument:document]];
   if(arrayForDocument != nil)
   {
      NSEnumerator *controllerEnumerator = [arrayForDocument objectEnumerator];
      id currentController;
      while((currentController = [controllerEnumerator nextObject]) != nil)
      {
         if([[currentController entryName] isEqualToString:entryName])
            return currentController;
      }
   }

   return nil;
}


/*
 * Close all open controllers
 */
+ (void) closeOpenControllersForDocument:(NSDocument *)document
{
   NSArray *arrayForDocument = [controllerList objectForKey:[CSWinCtrlChange numberForDocument:document]];
   if(arrayForDocument != nil)
   {
      while([arrayForDocument count] > 0)
         [[[arrayForDocument objectAtIndex:0] window] performClose:self];
   }
}


#pragma mark -
#pragma mark Configuration
/*
 * Override so we can setup to be on the list for this document
 */
- (void) setDocument:(NSDocument *)document
{
   [super setDocument:document];
   [CSWinCtrlChange addController:self forDocument:document];
}


/*
 * Return the entry for which we are in charge
 */
- (NSString *) entryName
{
   return myEntryName;
}


/*
 * Change the entry being edited/viewed
 */
- (void) setEntryName:(NSString *)newEntryName
{
   if(myEntryName != newEntryName)
   {
      [myEntryName autorelease];
      myEntryName = [newEntryName retain];
      [self updateFields];
      [self synchronizeWindowTitleWithDocumentName];
   }
}


#pragma mark -
#pragma mark Button Handling
/*
 * Change the entry
 */
- (IBAction) change:(id)sender
{
   NSRange fullNotesRange = NSMakeRange(0, [[notes textStorage] length]);
   if([[self document] changeEntryWithName:myEntryName
                                   newName:[nameText stringValue]
                                   account:[accountText stringValue]
                                  password:[passwordText stringValue]
                                       URL:[urlText stringValue]
                                  category:[category stringValue]
                                 notesRTFD:[notes RTFDFromRange:fullNotesRange]])
   {
      [[self window] setDocumentEdited:NO];
      if(![[NSUserDefaults standardUserDefaults] boolForKey:CSPrefDictKey_CloseEdit])
      {
         [self setEntryName:[nameText stringValue]];
         // This won't work if we do it right away, so put it on the event queue
         [[NSRunLoop currentRunLoop]
          performSelector:@selector(makeFirstResponder:)
                   target:[self window]
                 argument:nameText
                    order:9999
                    modes:[NSArray arrayWithObjects:NSDefaultRunLoopMode, NSModalPanelRunLoopMode, nil]];
      }
      else
         [[self window] performClose:self];
   }
   else
      NSBeginInformationalAlertSheet(CSWINCTRLENTRY_LOC_ENTRYEXISTS,
                                     nil,
                                     nil,
                                     nil,
                                     [self window],
                                     nil,
                                     nil,
                                     nil,
                                     NULL,
                                     CSWINCTRLENTRY_LOC_ENTRYEXISTSRENAME);
}


#pragma mark -
#pragma mark Window Handling
/*
 * Update the fields and set first responder to the name field
 */
- (IBAction) showWindow:(id)sender
{
   [self updateFields];
   [[self window] makeFirstResponder:nameText];
   [super showWindow:sender];
}


/*
 * Remove this instance from the list when the window closes (use ShouldClose:
 * as the document reference is lost by the time WillClose: is called)
 */
- (BOOL) windowShouldClose:(id)sender
{
   BOOL superShouldClose = [super windowShouldClose:sender];
   if(superShouldClose)
      [CSWinCtrlChange removeController:self forDocument:[self document]];
   
   return superShouldClose;
}


/*
 * We don't want to have the file represented (icon) in the title bar
 */
- (void) synchronizeWindowTitleWithDocumentName
{
   [[self window] setTitle:[NSString stringWithFormat:NSLocalizedString(@"View/Change %@ in %@", @""),
                                                      myEntryName,
                                                      [[self document] displayName]]];
}


#pragma mark -
#pragma mark Miscellaneous
/*
 * Return YES if the value in the given field matches the represented entry's
 * original value for the given key
 */
- (BOOL) doesField:(NSTextField *)field matchStringWithKey:(NSString *)key
{
   NSInteger row = [[self document] rowForName:myEntryName];
   
   return [[field stringValue] isEqualToString:[[self document] stringForKey:key atRow:row]];
}


/*
 * Update all the fields in the window
 */
- (void) updateFields
{
   // XXX If it were possible, we'd clear out controls here
   [nameText setStringValue:myEntryName];
   NSInteger myEntryRowNum = [[self document] rowForName:myEntryName];
   if(myEntryRowNum >= 0)
   {
      [mainButton setEnabled:YES];
      CSDocument *document = [self document];
      [accountText setStringValue:[document stringForKey:CSDocModelKey_Acct atRow:myEntryRowNum]];
      [passwordText setStringValue:[document stringForKey:CSDocModelKey_Passwd atRow:myEntryRowNum]];
      [urlText setStringValue:[document stringForKey:CSDocModelKey_URL atRow:myEntryRowNum]];
      [category setStringValue:[document stringForKey:CSDocModelKey_Category atRow:myEntryRowNum]];
      NSRange fullNotesRange = NSMakeRange(0, [[notes textStorage] length]);
      [notes replaceCharactersInRange:fullNotesRange withRTFD:[document RTFDNotesAtRow:myEntryRowNum]];
      [self updateDocumentEditedStatus];
   }
}


/*
 * Cleanup
 */
- (void) dealloc
{
   [myEntryName release];
   [super dealloc];
}


#pragma mark -
#pragma mark Flagging Changes
/*
 * Check if any of the fields have been changed
 */
- (BOOL) nameChanged
{
   return ![[nameText stringValue] isEqualToString:myEntryName];
}

- (BOOL) accountChanged
{
   return ![self doesField:accountText matchStringWithKey:CSDocModelKey_Acct];
}

- (BOOL) passwordChanged
{
   return ![self doesField:passwordText matchStringWithKey:CSDocModelKey_Passwd];
}

- (BOOL) urlChanged
{
   return ![self doesField:urlText matchStringWithKey:CSDocModelKey_URL];
}

- (BOOL) categoryChanged
{
   return ![self doesField:category matchStringWithKey:CSDocModelKey_Category];
}

- (BOOL) notesChanged
{
   NSInteger row = [[self document] rowForName:myEntryName];

   return ![[notes textStorage] isEqualToAttributedString:[[self document] RTFDStringNotesAtRow:row]];
}

@end
