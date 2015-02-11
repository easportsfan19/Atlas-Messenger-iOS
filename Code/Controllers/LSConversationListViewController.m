//
//  LSConversationListViewController.m
//  LayerSample
//
//  Created by Kevin Coleman on 8/29/14.
//  Copyright (c) 2014 Layer, Inc. All rights reserved.
//

#import "LSConversationListViewController.h"
#import "SVProgressHUD.h"
#import "LSUser.h"
#import "LSConversationViewController.h"
#import "LSSettingsViewController.h"
#import "LSConversationDetailViewController.h"
#import "LSNavigationController.h"

@interface LSConversationListViewController () <LYRUIConversationListViewControllerDelegate, LYRUIConversationListViewControllerDataSource, LSSettingsViewControllerDelegate, UIActionSheetDelegate>

@end

@implementation LSConversationListViewController

NSString *const LSConversationListTableViewAccessibilityLabel = @"Conversation List Table View";
NSString *const LSSettingsButtonAccessibilityLabel = @"Settings Button";
NSString *const LSComposeButtonAccessibilityLabel = @"Compose Button";

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.delegate = self;
    self.dataSource = self;
    self.tableView.accessibilityLabel = LSConversationListTableViewAccessibilityLabel;
    
    self.allowsEditing = YES;
    self.displaysSettingsItem = YES;
    
    // Left navigation item
    if (self.displaysSettingsItem) {
        UIBarButtonItem *settingsButton = [[UIBarButtonItem alloc] initWithTitle:@"Settings"
                                                                           style:UIBarButtonItemStylePlain
                                                                          target:self
                                                                          action:@selector(settingsButtonTapped)];
        settingsButton.accessibilityLabel = LSSettingsButtonAccessibilityLabel;
        [self.navigationItem setLeftBarButtonItem:settingsButton];
    }

    // Right navigation item
    UIBarButtonItem *composeButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose
                                                                                   target:self
                                                                                   action:@selector(composeButtonTapped)];
    composeButton.accessibilityLabel = LSComposeButtonAccessibilityLabel;
    [self.navigationItem setRightBarButtonItem:composeButton];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(conversationDeleted:) name:LSConversationDeletedNotification object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(conversationParticipantsDidChange:) name:LSConversationParticipantsDidChangeNotification object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - LYRUIConversationListViewControllerDelegate

/**
 
 LAYER UI KIT - Allows your application to react to a conversation selection. This application pushses a subclass of 
 the `LYRUIConversationViewController` component.
 
 */
- (void)conversationListViewController:(LYRUIConversationListViewController *)conversationListViewController didSelectConversation:(LYRConversation *)conversation
{
    [self presentControllerWithConversation:conversation];
}

/**
 
 LAYER UI KIT - Allows your application react to a conversations deletion if necessary. This application does not 
 need to react because the superclass component will handle removing the conversation in response to a deletion.
 
 */
- (void)conversationListViewController:(LYRUIConversationListViewController *)conversationListViewController didDeleteConversation:(LYRConversation *)conversation deletionMode:(LYRDeletionMode)deletionMode
{
    NSLog(@"Conversation Successsfully Deleted");
}

/**
 
 LAYER UI KIT - Allows your application react to a failed conversation deletion if necessary.
 
 */
- (void)conversationListViewController:(LYRUIConversationListViewController *)conversationListViewController didFailDeletingConversation:(LYRConversation *)conversation deletionMode:(LYRDeletionMode)deletionMode error:(NSError *)error
{
    NSLog(@"Conversation Deletion Failed with Error: %@", error);
}

#pragma mark - LYRUIConversationListViewControllerDataSource

/**
 
 LAYER UI KIT - Returns a label that is used to represent the conversation. This application puts the 
 name representing the `lastMessage.sentByUserID` property first in the string.
 
 */
- (NSString *)conversationListViewController:(LYRUIConversationListViewController *)conversationListViewController titleForConversation:(LYRConversation *)conversation
{
    NSString *conversationName = conversation.metadata[LSConversationMetadataNameKey];
    if (conversationName) return conversationName;
    
    NSMutableSet *participantIdentifiers = [conversation.participants mutableCopy];
    [participantIdentifiers minusSet:[NSSet setWithObject:self.layerClient.authenticatedUserID]];
    
    if (participantIdentifiers.count == 0) return @"Personal Conversation";
    
    NSMutableSet *participants = [[self.applicationController.persistenceManager usersForIdentifiers:participantIdentifiers] mutableCopy];
    if (participants.count == 0) return @"No Matching Participants";
    if (participants.count == 1) return [[participants allObjects][0] fullName];
    
    NSMutableArray *firstNames = [NSMutableArray new];
    [participants enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
        id<LYRUIParticipant> participant = obj;
        if (participant.firstName) {
            // Put the last message sender's name first
            if ([conversation.lastMessage.sentByUserID isEqualToString:participant.participantIdentifier]) {
                [firstNames insertObject:participant.firstName atIndex:0];
            } else {
                [firstNames addObject:participant.firstName];
            }
        }
    }];

    NSString *fullNamesString = [firstNames componentsJoinedByString:@", "];
    return fullNamesString;
}

/**
 
 LAYER UI KIT - If needed, your application can display an avatar image that represnts a conversation. If no image 
 is returned, no image will be displayed.
 
 */
- (UIImage *)conversationListViewController:(LYRUIConversationListViewController *)conversationListViewController imageForConversation:(LYRConversation *)conversation
{
    return nil;
}

#pragma mark - Conversation Selection

- (void)presentControllerWithConversation:(LYRConversation *)conversation
{
    LSConversationViewController *existingConversationViewController = [self existingConversationViewController];
    if (existingConversationViewController && existingConversationViewController.conversation == conversation) {
        if (self.navigationController.topViewController == existingConversationViewController) return;
        [self.navigationController popToViewController:existingConversationViewController animated:YES];
        return;
    }

    LSConversationViewController *conversationViewController = [LSConversationViewController conversationViewControllerWithLayerClient:self.applicationController.layerClient];
    conversationViewController.conversation = conversation;
    conversationViewController.applicationController = self.applicationController;
    conversationViewController.displaysAddressBar = YES;
    if (self.navigationController.topViewController == self) {
        [self.navigationController pushViewController:conversationViewController animated:YES];
    } else {
        NSMutableArray *viewControllers = [self.navigationController.viewControllers mutableCopy];
        NSUInteger listViewControllerIndex = [self.navigationController.viewControllers indexOfObject:self];
        NSRange replacementRange = NSMakeRange(listViewControllerIndex + 1, viewControllers.count - listViewControllerIndex - 1);
        [viewControllers replaceObjectsInRange:replacementRange withObjectsFromArray:@[conversationViewController]];
        [self.navigationController setViewControllers:viewControllers animated:YES];
    }
}

#pragma mark - Actions

- (void)settingsButtonTapped
{
    LSSettingsViewController *settingsViewController = [[LSSettingsViewController alloc] initWithStyle:UITableViewStyleGrouped];
    settingsViewController.applicationController = self.applicationController;
    settingsViewController.settingsDelegate = self;
    
    UINavigationController *controller = [[UINavigationController alloc] initWithRootViewController:settingsViewController];
    [self.navigationController presentViewController:controller animated:YES completion:nil];
}

- (void)composeButtonTapped
{
    [self presentControllerWithConversation:nil];
}

#pragma mark - Conversation Selection From Push Notification

- (void)selectConversation:(LYRConversation *)conversation
{
    if (conversation) {
        [self presentControllerWithConversation:conversation];
    }
}

#pragma mark - LSSettingsViewControllerDelegate

- (void)logoutTappedInSettingsViewController:(LSSettingsViewController *)settingsViewController
{
    [SVProgressHUD showWithMaskType:SVProgressHUDMaskTypeBlack];
    if (self.applicationController.layerClient.isConnected) {
        [self.applicationController.layerClient deauthenticateWithCompletion:^(BOOL success, NSError *error) {
            [SVProgressHUD dismiss];
        }];
    } else {
        [self.applicationController.APIManager deauthenticate];
        [SVProgressHUD dismiss];
    }
}

- (void)settingsViewControllerDidFinish:(LSSettingsViewController *)settingsViewController
{
    [settingsViewController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Notification Handlers

- (void)conversationDeleted:(NSNotification *)notification
{
    if (self.ls_navigationController.isAnimating) {
        [self.ls_navigationController notifyWhenCompletionEndsUsingBlock:^{
            [self conversationDeleted:notification];
        }];
        return;
    }

    LSConversationViewController *conversationViewController = [self existingConversationViewController];
    if (!conversationViewController) return;

    LYRConversation *deletedConversation = notification.object;
    if (![conversationViewController.conversation isEqual:deletedConversation]) return;

    [self.navigationController popToViewController:self animated:YES];

    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Conversation Deleted"
                                                        message:@"The conversation has been deleted."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
    [alertView show];
}

- (void)conversationParticipantsDidChange:(NSNotification *)notification
{
    if (self.ls_navigationController.isAnimating) {
        [self.ls_navigationController notifyWhenCompletionEndsUsingBlock:^{
            [self conversationParticipantsDidChange:notification];
        }];
        return;
    }

    NSString *authenticatedUserID = self.applicationController.layerClient.authenticatedUserID;
    if (!authenticatedUserID) return;
    LYRConversation *conversation = notification.object;
    if ([conversation.participants containsObject:authenticatedUserID]) return;

    LSConversationViewController *conversationViewController = [self existingConversationViewController];
    if (!conversationViewController) return;
    if (![conversationViewController.conversation isEqual:conversation]) return;

    [self.navigationController popToViewController:self animated:YES];

    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Removed From Conversation"
                                                        message:@"You have been removed from the conversation."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
    [alertView show];
}

#pragma mark - Helpers

- (LSConversationViewController *)existingConversationViewController
{
    if (!self.navigationController) return nil;

    NSUInteger listViewControllerIndex = [self.navigationController.viewControllers indexOfObject:self];
    if (listViewControllerIndex == NSNotFound) return nil;

    NSUInteger nextViewControllerIndex = listViewControllerIndex + 1;
    if (nextViewControllerIndex >= self.navigationController.viewControllers.count) return nil;

    id nextViewController = [self.navigationController.viewControllers objectAtIndex:nextViewControllerIndex];
    if (![nextViewController isKindOfClass:[LSConversationViewController class]]) return nil;

    return nextViewController;
}

@end
