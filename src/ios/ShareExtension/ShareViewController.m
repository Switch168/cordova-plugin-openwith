//
//  ShareViewController.m
//  OpenWith - Share Extension
//

//
// The MIT License (MIT)
//
// Copyright (c) 2017 Jean-Christophe Hoelt
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import <UIKit/UIKit.h>
#import <Social/Social.h>
#import "ShareViewController.h"

@interface ShareViewController : SLComposeServiceViewController {
    int _verbosityLevel;
    NSUserDefaults *_userDefaults;
    NSString *_backURL;
}
@property (nonatomic) int verbosityLevel;
@property (nonatomic,retain) NSUserDefaults *userDefaults;
@property (nonatomic,retain) NSString *backURL;
@end

/*
 * Constants
 */

#define VERBOSITY_DEBUG  0
#define VERBOSITY_INFO  10
#define VERBOSITY_WARN  20
#define VERBOSITY_ERROR 30

@implementation ShareViewController

@synthesize verbosityLevel = _verbosityLevel;
@synthesize userDefaults = _userDefaults;
@synthesize backURL = _backURL;

- (void) log:(int)level message:(NSString*)message {
    if (level >= self.verbosityLevel) {
        NSLog(@"[ShareViewController.m]%@", message);
    }
}
- (void) debug:(NSString*)message { [self log:VERBOSITY_DEBUG message:message]; }
- (void) info:(NSString*)message { [self log:VERBOSITY_INFO message:message]; }
- (void) warn:(NSString*)message { [self log:VERBOSITY_WARN message:message]; }
- (void) error:(NSString*)message { [self log:VERBOSITY_ERROR message:message]; }

- (void) setup {
    self.userDefaults = [[NSUserDefaults alloc] initWithSuiteName:SHAREEXT_GROUP_IDENTIFIER];
    self.verbosityLevel = [self.userDefaults integerForKey:@"verbosityLevel"];
    [self debug:@"[setup]"];
}

- (BOOL) isContentValid {
    return YES;
}

- (void) openURL:(nonnull NSURL *)url {

    SEL selector = NSSelectorFromString(@"openURL:options:completionHandler:");

    UIResponder* responder = self;
    while ((responder = [responder nextResponder]) != nil) {
        NSLog(@"responder = %@", responder);
        if([responder respondsToSelector:selector] == true) {
            NSMethodSignature *methodSignature = [responder methodSignatureForSelector:selector];
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];

            // Arguments
            void (^completion)(BOOL success) = ^void(BOOL success) {
                NSLog(@"Completions block: %i", success);
            };
            if (@available(iOS 13.0, *)) {
                UISceneOpenExternalURLOptions * options = [[UISceneOpenExternalURLOptions alloc] init];
                options.universalLinksOnly = false;
                
                [invocation setTarget: responder];
                [invocation setSelector: selector];
                [invocation setArgument: &url atIndex: 2];
                [invocation setArgument: &options atIndex:3];
                [invocation setArgument: &completion atIndex: 4];
                [invocation invoke];
                break;
            } else {
                NSDictionary<NSString *, id> *options = [NSDictionary dictionary];
                
                [invocation setTarget: responder];
                [invocation setSelector: selector];
                [invocation setArgument: &url atIndex: 2];
                [invocation setArgument: &options atIndex:3];
                [invocation setArgument: &completion atIndex: 4];
                [invocation invoke];
                break;
            }
        }
    }
}

- (void) didSelectPost {

    [self setup];
    [self debug:@"[didSelectPost]"];

    // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
    for (NSItemProvider* itemProvider in ((NSExtensionItem*)self.extensionContext.inputItems[0]).attachments) {
        
        
        
        
        if ([itemProvider hasItemConformingToTypeIdentifier:SHAREEXT_UNIFORM_TYPE_IDENTIFIER]) {
            [self debug:[NSString stringWithFormat:@"item provider = %@", itemProvider]];
            
            
            // movie created by phone, save it in the group container and pass the pointer
            // because https://developer.apple.com/forums/thread/121527
            if ([itemProvider hasItemConformingToTypeIdentifier:@"com.apple.quicktime-movie"]) {
                [itemProvider loadItemForTypeIdentifier:@"com.apple.quicktime-movie" options:nil completionHandler:^(NSURL *url, NSError *error) {
                    NSLog(@"dataPath------------------------------------------------------------");
                    [self debug:url.absoluteString];
                    NSString *uti = @"";
                    
                    NSError* readError = nil;
                    NSData *data = [NSData dataWithContentsOfURL:url options: 0 error: &readError];
                    if (data == nil) {
                        NSLog(@"Failed to read file, error %@", readError);
                    }
                    
                    NSUUID *uuid = [NSUUID UUID];
                    NSString *str = [uuid UUIDString];
                    
                    NSURL  *containerURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:SHAREEXT_GROUP_IDENTIFIER];
                    NSString *dataPath =
                    [containerURL.absoluteString stringByAppendingPathComponent: [str stringByAppendingString:@".mov"]];
                    containerURL = [containerURL URLByAppendingPathComponent:[NSString stringWithFormat: [str.lowercaseString stringByAppendingString:@".mov"]]];
                    
                    NSError* writeError = nil;
                    [[NSFileManager defaultManager] createFileAtPath:dataPath contents:nil attributes:nil];
                    [data writeToURL:containerURL options: NSDataWritingAtomic error: &writeError];
                    
                    NSArray<NSString *> *utis = [NSArray new];
                    if ([itemProvider.registeredTypeIdentifiers count] > 0) {
                        uti = itemProvider.registeredTypeIdentifiers[0];
                        utis = itemProvider.registeredTypeIdentifiers;
                    }
                    NSDictionary *dict = @{
                        @"text": self.contentText,
                        @"backURL": self.backURL,
                        @"data" : [[NSData alloc] init],
                        @"uti": uti,
                        @"utis": utis,
                        @"name": containerURL.absoluteString
                    };
                    [self.userDefaults setObject:dict forKey:@"image"];
                    [self.userDefaults synchronize];
                    NSString *urlApp = [NSString stringWithFormat:@"%@://image", SHAREEXT_URL_SCHEME];
                    [self openURL:[NSURL URLWithString:urlApp]];
                    [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil]; }];
                return;
            }
            
            if ([itemProvider hasItemConformingToTypeIdentifier:@"public.mpeg"]) {
                [itemProvider loadItemForTypeIdentifier:@"public.mpeg" options:nil completionHandler:^(NSURL *url, NSError *error) {
                    NSLog(@"dataPath------------------------------------------------------------");
                    [self debug:url.absoluteString];
                    NSString *uti = @"";
                    
                    NSError* readError = nil;
                    NSData *data = [NSData dataWithContentsOfURL:url options: 0 error: &readError];
                    if (data == nil) {
                        NSLog(@"Failed to read file, error %@", readError);
                    }
                    
                    NSUUID *uuid = [NSUUID UUID];
                    NSString *str = [uuid UUIDString];
                    
                    NSURL  *containerURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:SHAREEXT_GROUP_IDENTIFIER];
                    NSString *dataPath =
                    [containerURL.absoluteString stringByAppendingPathComponent: [str stringByAppendingString:@".mp4"]];
                    containerURL = [containerURL URLByAppendingPathComponent:[NSString stringWithFormat: [str.lowercaseString stringByAppendingString:@".mp4"]]];
                    
                    NSError* writeError = nil;
                    [[NSFileManager defaultManager] createFileAtPath:dataPath contents:nil attributes:nil];
                    [data writeToURL:containerURL options: NSDataWritingAtomic error: &writeError];
                    
                    NSArray<NSString *> *utis = [NSArray new];
                    if ([itemProvider.registeredTypeIdentifiers count] > 0) {
                        uti = itemProvider.registeredTypeIdentifiers[0];
                        utis = itemProvider.registeredTypeIdentifiers;
                    }
                    NSDictionary *dict = @{
                        @"text": self.contentText,
                        @"backURL": self.backURL,
                        @"data" : [[NSData alloc] init],
                        @"uti": uti,
                        @"utis": utis,
                        @"name": containerURL.absoluteString
                    };
                    [self.userDefaults setObject:dict forKey:@"image"];
                    [self.userDefaults synchronize];
                    NSString *urlApp = [NSString stringWithFormat:@"%@://image", SHAREEXT_URL_SCHEME];
                    [self openURL:[NSURL URLWithString:urlApp]];
                    [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil]; }];
                return;
            }
            
            if ([itemProvider hasItemConformingToTypeIdentifier:@"org.openxmlformats.spreadsheetml.sheet"]) {
                [itemProvider loadItemForTypeIdentifier:@"org.openxmlformats.spreadsheetml.sheet" options:nil completionHandler:^(NSURL *url, NSError *error) {
                    NSLog(@"dataPath------------------------------------------------------------");
                    [self debug:url.absoluteString];
                    NSString *uti = @"";
                    
                    NSError* readError = nil;
                    NSData *data = [NSData dataWithContentsOfURL:url options: 0 error: &readError];
                    if (data == nil) {
                        NSLog(@"Failed to read file, error %@", readError);
                    }
                    
                    NSUUID *uuid = [NSUUID UUID];
                    NSString *str = [uuid UUIDString];
                    
                    NSURL  *containerURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:SHAREEXT_GROUP_IDENTIFIER];
                    NSString *dataPath =
                    [containerURL.absoluteString stringByAppendingPathComponent: [str stringByAppendingString:@".xlsx"]];
                    containerURL = [containerURL URLByAppendingPathComponent:[NSString stringWithFormat: [str.lowercaseString stringByAppendingString:@".xlsx"]]];
                    
                    NSError* writeError = nil;
                    [[NSFileManager defaultManager] createFileAtPath:dataPath contents:nil attributes:nil];
                    [data writeToURL:containerURL options: NSDataWritingAtomic error: &writeError];
                    
                    NSArray<NSString *> *utis = [NSArray new];
                    if ([itemProvider.registeredTypeIdentifiers count] > 0) {
                        uti = itemProvider.registeredTypeIdentifiers[0];
                        utis = itemProvider.registeredTypeIdentifiers;
                    }
                    NSDictionary *dict = @{
                        @"text": self.contentText,
                        @"backURL": self.backURL,
                        @"data" : [[NSData alloc] init],
                        @"uti": uti,
                        @"utis": utis,
                        @"name": containerURL.absoluteString
                    };
                    [self.userDefaults setObject:dict forKey:@"image"];
                    [self.userDefaults synchronize];
                    NSString *urlApp = [NSString stringWithFormat:@"%@://image", SHAREEXT_URL_SCHEME];
                    [self openURL:[NSURL URLWithString:urlApp]];
                    [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil]; }];
                return;
            }
            
            if ([itemProvider hasItemConformingToTypeIdentifier:@"org.openxmlformats.wordprocessingml.document"]) {
                [itemProvider loadItemForTypeIdentifier:@"org.openxmlformats.wordprocessingml.document" options:nil completionHandler:^(NSURL *url, NSError *error) {
                    NSLog(@"dataPath------------------------------------------------------------");
                    [self debug:url.absoluteString];
                    NSString *uti = @"";
                    
                    NSError* readError = nil;
                    NSData *data = [NSData dataWithContentsOfURL:url options: 0 error: &readError];
                    if (data == nil) {
                        NSLog(@"Failed to read file, error %@", readError);
                    }
                    
                    NSUUID *uuid = [NSUUID UUID];
                    NSString *str = [uuid UUIDString];
                    
                    NSURL  *containerURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:SHAREEXT_GROUP_IDENTIFIER];
                    NSString *dataPath =
                    [containerURL.absoluteString stringByAppendingPathComponent: [str stringByAppendingString:@".docx"]];
                    containerURL = [containerURL URLByAppendingPathComponent:[NSString stringWithFormat: [str.lowercaseString stringByAppendingString:@".docx"]]];
                    
                    NSError* writeError = nil;
                    [[NSFileManager defaultManager] createFileAtPath:dataPath contents:nil attributes:nil];
                    [data writeToURL:containerURL options: NSDataWritingAtomic error: &writeError];
                    
                    NSArray<NSString *> *utis = [NSArray new];
                    if ([itemProvider.registeredTypeIdentifiers count] > 0) {
                        uti = itemProvider.registeredTypeIdentifiers[0];
                        utis = itemProvider.registeredTypeIdentifiers;
                    }
                    NSDictionary *dict = @{
                        @"text": self.contentText,
                        @"backURL": self.backURL,
                        @"data" : [[NSData alloc] init],
                        @"uti": uti,
                        @"utis": utis,
                        @"name": containerURL.absoluteString
                    };
                    [self.userDefaults setObject:dict forKey:@"image"];
                    [self.userDefaults synchronize];
                    NSString *urlApp = [NSString stringWithFormat:@"%@://image", SHAREEXT_URL_SCHEME];
                    [self openURL:[NSURL URLWithString:urlApp]];
                    [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil]; }];
                return;
            }
            
            if ([itemProvider hasItemConformingToTypeIdentifier:@"org.openxmlformats.presentationml.presentation"]) {
                [itemProvider loadItemForTypeIdentifier:@"org.openxmlformats.presentationml.presentation" options:nil completionHandler:^(NSURL *url, NSError *error) {
                    NSLog(@"dataPath------------------------------------------------------------");
                    [self debug:url.absoluteString];
                    NSString *uti = @"";
                    
                    NSError* readError = nil;
                    NSData *data = [NSData dataWithContentsOfURL:url options: 0 error: &readError];
                    if (data == nil) {
                        NSLog(@"Failed to read file, error %@", readError);
                    }
                    
                    NSUUID *uuid = [NSUUID UUID];
                    NSString *str = [uuid UUIDString];
                    
                    NSURL  *containerURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:SHAREEXT_GROUP_IDENTIFIER];
                    NSString *dataPath =
                    [containerURL.absoluteString stringByAppendingPathComponent: [str stringByAppendingString:@".pptx"]];
                    containerURL = [containerURL URLByAppendingPathComponent:[NSString stringWithFormat: [str.lowercaseString stringByAppendingString:@".pptx"]]];
                    
                    NSError* writeError = nil;
                    [[NSFileManager defaultManager] createFileAtPath:dataPath contents:nil attributes:nil];
                    [data writeToURL:containerURL options: NSDataWritingAtomic error: &writeError];
                    
                    NSArray<NSString *> *utis = [NSArray new];
                    if ([itemProvider.registeredTypeIdentifiers count] > 0) {
                        uti = itemProvider.registeredTypeIdentifiers[0];
                        utis = itemProvider.registeredTypeIdentifiers;
                    }
                    NSDictionary *dict = @{
                        @"text": self.contentText,
                        @"backURL": self.backURL,
                        @"data" : [[NSData alloc] init],
                        @"uti": uti,
                        @"utis": utis,
                        @"name": containerURL.absoluteString
                    };
                    [self.userDefaults setObject:dict forKey:@"image"];
                    [self.userDefaults synchronize];
                    NSString *urlApp = [NSString stringWithFormat:@"%@://image", SHAREEXT_URL_SCHEME];
                    [self openURL:[NSURL URLWithString:urlApp]];
                    [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil]; }];
                return;
            }
            
             if ([itemProvider hasItemConformingToTypeIdentifier:@"public.jpeg"]) {
                [itemProvider loadItemForTypeIdentifier:@"public.jpeg" options:nil completionHandler:^(NSURL *url, NSError *error) {
                    NSLog(@"dataPath------------------------------------------------------------");
                    [self debug:url.absoluteString];
                    NSString *uti = @"";
                    
                    NSError* readError = nil;
                    NSData *data = [NSData dataWithContentsOfURL:url options: 0 error: &readError];
                    if (data == nil) {
                        NSLog(@"Failed to read file, error %@", readError);
                    }
                    
                    NSUUID *uuid = [NSUUID UUID];
                    NSString *str = [uuid UUIDString];
                    
                    NSURL  *containerURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:SHAREEXT_GROUP_IDENTIFIER];
                    NSString *dataPath =
                    [containerURL.absoluteString stringByAppendingPathComponent: [str stringByAppendingString:@".jpeg"]];
                    containerURL = [containerURL URLByAppendingPathComponent:[NSString stringWithFormat: [str.lowercaseString stringByAppendingString:@".jpeg"]]];
                    
                    NSError* writeError = nil;
                    [[NSFileManager defaultManager] createFileAtPath:dataPath contents:nil attributes:nil];
                    [data writeToURL:containerURL options: NSDataWritingAtomic error: &writeError];
                    
                    NSArray<NSString *> *utis = [NSArray new];
                    if ([itemProvider.registeredTypeIdentifiers count] > 0) {
                        uti = itemProvider.registeredTypeIdentifiers[0];
                        utis = itemProvider.registeredTypeIdentifiers;
                    }
                    NSDictionary *dict = @{
                        @"text": self.contentText,
                        @"backURL": self.backURL,
                        @"data" : [[NSData alloc] init],
                        @"uti": uti,
                        @"utis": utis,
                        @"name": containerURL.absoluteString
                    };
                    [self.userDefaults setObject:dict forKey:@"image"];
                    [self.userDefaults synchronize];
                    NSString *urlApp = [NSString stringWithFormat:@"%@://image", SHAREEXT_URL_SCHEME];
                    [self openURL:[NSURL URLWithString:urlApp]];
                    [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil]; }];
                return;
            }
            
            if ([itemProvider hasItemConformingToTypeIdentifier:@"public.png"]) {
                [itemProvider loadItemForTypeIdentifier:@"public.png" options:nil completionHandler:^(NSURL *url, NSError *error) {
                    if(error) {
                        return;
                    }
                    NSLog(@"dataPath------------------------------------------------------------");
                    [self debug:url.absoluteString];
                    NSString *uti = @"";
                    
                    NSError* readError = nil;
                    NSData *data = [NSData dataWithContentsOfURL:url options: 0 error: &readError];
                    if (data == nil) {
                        NSLog(@"Failed to read file, error %@", readError);
                    }
                    
                    NSUUID *uuid = [NSUUID UUID];
                    NSString *str = [uuid UUIDString];
                    
                    NSURL  *containerURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:SHAREEXT_GROUP_IDENTIFIER];
                    NSString *dataPath =
                    [containerURL.absoluteString stringByAppendingPathComponent: [str stringByAppendingString:@".png"]];
                    containerURL = [containerURL URLByAppendingPathComponent:[NSString stringWithFormat: [str.lowercaseString stringByAppendingString:@".png"]]];
                    
                    NSError* writeError = nil;
                    [[NSFileManager defaultManager] createFileAtPath:dataPath contents:nil attributes:nil];
                    [data writeToURL:containerURL options: NSDataWritingAtomic error: &writeError];
                    
                    NSArray<NSString *> *utis = [NSArray new];
                    if ([itemProvider.registeredTypeIdentifiers count] > 0) {
                        uti = itemProvider.registeredTypeIdentifiers[0];
                        utis = itemProvider.registeredTypeIdentifiers;
                    }
                    NSDictionary *dict = @{
                        @"text": self.contentText,
                        @"backURL": self.backURL,
                        @"data" : [[NSData alloc] init],
                        @"uti": uti,
                        @"utis": utis,
                        @"name": containerURL.absoluteString
                    };
                    [self.userDefaults setObject:dict forKey:@"image"];
                    [self.userDefaults synchronize];
                    NSString *urlApp = [NSString stringWithFormat:@"%@://image", SHAREEXT_URL_SCHEME];
                    [self openURL:[NSURL URLWithString:urlApp]];
                    [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil]; }];
                return;
            }
            
            // screenshot codepath
            if ([itemProvider hasItemConformingToTypeIdentifier:@"public.image"]) {
                [itemProvider loadItemForTypeIdentifier:@"public.image" options:nil completionHandler:^(NSURL *url, NSError *error) {
                    NSArray *registeredTypeIdentifiers = itemProvider.registeredTypeIdentifiers;
                    if ([itemProvider hasItemConformingToTypeIdentifier:@"public.image"]) {
                              [itemProvider loadItemForTypeIdentifier:registeredTypeIdentifiers.firstObject options:nil completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                                  if (item) {
                                      // For all selected photos/files
                                      if([(NSObject*)item isKindOfClass:[NSURL class]]) {
                                          NSData *contentData = [NSData dataWithContentsOfURL:(NSURL *)item];
                                        // continue working with selected image/file
                                      }
                                      if([(NSObject*)item isKindOfClass:[UIImage class]]) {
                                         NSData  *contentData = UIImagePNGRepresentation((UIImage*)item);
                                        // continue working with screenshot data
                                      
                                      
                                      NSLog(@"dataPath------------------------------------------------------------");
                                      [self debug:url.absoluteString];
                                      [self debug:error.localizedDescription];
                                      
                                      NSString *uti = @"";
                                      
                                      NSError* readError = nil;
                                      NSData *data = contentData;
                                      if (data == nil) {
                                          NSLog(@"Failed to read file, error %@", readError);
                                      }
                                      
                                      NSUUID *uuid = [NSUUID UUID];
                                      NSString *str = [uuid UUIDString];
                                      
                                      NSURL  *containerURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:SHAREEXT_GROUP_IDENTIFIER];
                                      NSString *dataPath =
                                      [containerURL.absoluteString stringByAppendingPathComponent: [str stringByAppendingString:@".png"]];
                                      containerURL = [containerURL URLByAppendingPathComponent:[NSString stringWithFormat: [str.lowercaseString stringByAppendingString:@".png"]]];
                                      
                                      NSError* writeError = nil;
                                      [[NSFileManager defaultManager] createFileAtPath:dataPath contents:nil attributes:nil];
                                      [data writeToURL:containerURL options: NSDataWritingAtomic error: &writeError];
                                      
                                      NSArray<NSString *> *utis = [NSArray new];
                                      if ([itemProvider.registeredTypeIdentifiers count] > 0) {
                                          uti = itemProvider.registeredTypeIdentifiers[0];
                                          utis = itemProvider.registeredTypeIdentifiers;
                                      }
                                      NSDictionary *dict = @{
                                          @"text": self.contentText,
                                          @"backURL": self.backURL,
                                          @"data" : [[NSData alloc] init],
                                          @"uti": uti,
                                          @"utis": utis,
                                          @"name": containerURL.absoluteString,
                                          @"isScreenshotData": @"true"
                                      };
                                      [self.userDefaults setObject:dict forKey:@"image"];
                                      [self.userDefaults synchronize];
                                      NSString *urlApp = [NSString stringWithFormat:@"%@://image", SHAREEXT_URL_SCHEME];
                                      [self openURL:[NSURL URLWithString:urlApp]];
                                      [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
                                      }
                                            
                                  }
                              }];
                    }
                }];
                return;
            }
            
            if ([itemProvider hasItemConformingToTypeIdentifier:@"public.file-url"]) {
                  [itemProvider loadItemForTypeIdentifier:@"public.file-url" options:nil completionHandler:^(NSURL *url, NSError *error) {
                      NSLog(@"dataPath------------------------------------------------------------");
                      [self debug:url.absoluteString];
                      NSString *uti = @"";

                      NSError* readError = nil;
                      NSData *data = [NSData dataWithContentsOfURL:url options: 0 error: &readError];
                      if (data == nil) {
                          NSLog(@"Failed to read file, error %@", readError);
                      }

                      NSUUID *uuid = [NSUUID UUID];
                      NSString *str = [uuid UUIDString];

                      NSURL  *containerURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:SHAREEXT_GROUP_IDENTIFIER];

                      NSString *dot = @".";
                      NSString *ext = [dot stringByAppendingString: [url.absoluteString pathExtension]];

                      NSString *dataPath =
                      [containerURL.absoluteString stringByAppendingPathComponent: [str stringByAppendingString:ext]];
                      containerURL = [containerURL URLByAppendingPathComponent:[NSString stringWithFormat: @"%@", [str.lowercaseString stringByAppendingString:ext] ]];

                      NSError* writeError = nil;
                      [[NSFileManager defaultManager] createFileAtPath:dataPath contents:nil attributes:nil];
                      [data writeToURL:containerURL options: NSDataWritingAtomic error: &writeError];

                      NSArray<NSString *> *utis = [NSArray new];
                      if ([itemProvider.registeredTypeIdentifiers count] > 0) {
                          uti = itemProvider.registeredTypeIdentifiers[0];
                          utis = itemProvider.registeredTypeIdentifiers;
                      }
                      NSDictionary *dict = @{
                          @"text": self.contentText,
                          @"backURL": self.backURL,
                          @"data" : [[NSData alloc] init],
                          @"uti": uti,
                          @"utis": utis,
                          @"name": containerURL.absoluteString
                      };
                      [self.userDefaults setObject:dict forKey:@"image"];
                      [self.userDefaults synchronize];
                      NSString *urlApp = [NSString stringWithFormat:@"%@://image", SHAREEXT_URL_SCHEME];
                      [self openURL:[NSURL URLWithString:urlApp]];
                      [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil]; }];
                  return;
              }
            
            if ([itemProvider hasItemConformingToTypeIdentifier:@"public.movie"]) {
                 [itemProvider loadItemForTypeIdentifier:@"public.movie" options:nil completionHandler:^(NSURL *url, NSError *error) {
                     NSLog(@"dataPath------------------------------------------------------------");
                     [self debug:url.absoluteString];
                     NSString *uti = @"";

                     NSError* readError = nil;
                     NSData *data = [NSData dataWithContentsOfURL:url options: 0 error: &readError];
                     if (data == nil) {
                         NSLog(@"Failed to read file, error %@", readError);
                     }

                     NSUUID *uuid = [NSUUID UUID];
                     NSString *str = [uuid UUIDString];

                     NSURL  *containerURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:SHAREEXT_GROUP_IDENTIFIER];

                     NSString *dot = @".";
                     NSString *ext = [dot stringByAppendingString: [url.absoluteString pathExtension]];

                     NSString *dataPath =
                     [containerURL.absoluteString stringByAppendingPathComponent: [str stringByAppendingString:ext]];
                     containerURL = [containerURL URLByAppendingPathComponent:[NSString stringWithFormat: @"%@", [str.lowercaseString stringByAppendingString:ext] ]];

                     NSError* writeError = nil;
                     [[NSFileManager defaultManager] createFileAtPath:dataPath contents:nil attributes:nil];
                     [data writeToURL:containerURL options: NSDataWritingAtomic error: &writeError];

                     NSArray<NSString *> *utis = [NSArray new];
                     if ([itemProvider.registeredTypeIdentifiers count] > 0) {
                         uti = itemProvider.registeredTypeIdentifiers[0];
                         utis = itemProvider.registeredTypeIdentifiers;
                     }
                     NSDictionary *dict = @{
                         @"text": self.contentText,
                         @"backURL": self.backURL,
                         @"data" : [[NSData alloc] init],
                         @"uti": uti,
                         @"utis": utis,
                         @"name": containerURL.absoluteString
                     };
                     [self.userDefaults setObject:dict forKey:@"image"];
                     [self.userDefaults synchronize];
                     NSString *urlApp = [NSString stringWithFormat:@"%@://image", SHAREEXT_URL_SCHEME];
                     [self openURL:[NSURL URLWithString:urlApp]];
                     [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil]; }];
                 return;
             }


             // URL
             if ([itemProvider hasItemConformingToTypeIdentifier:@"public.url"]) {
                [itemProvider loadItemForTypeIdentifier:@"public.url" options:nil completionHandler:^(NSURL *url, NSError *error) {
                    [self debug:url.absoluteString];
                    NSString *uti = @"";
                       NSData *data = [[NSData alloc] init];
                    NSArray<NSString *> *utis = [NSArray new];
                    if ([itemProvider.registeredTypeIdentifiers count] > 0) {
                        uti = itemProvider.registeredTypeIdentifiers[0];
                        utis = itemProvider.registeredTypeIdentifiers;
                    }
                       NSDictionary *dict = @{
                           @"text": self.contentText,
                           @"backURL": self.backURL,
                           @"data" : data,
                           @"uti": uti,
                           @"utis": utis,
                           @"name": url.absoluteString
                       };
                    [self.userDefaults setObject:dict forKey:@"image"];
                    [self.userDefaults synchronize];
                    NSString *urlApp = [NSString stringWithFormat:@"%@://image", SHAREEXT_URL_SCHEME];
                    [self openURL:[NSURL URLWithString:urlApp]];
                    [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil]; }];
                 return;
             }
            
            if ([itemProvider hasItemConformingToTypeIdentifier:@"com.adobe.pdf"]) {
                [itemProvider loadItemForTypeIdentifier:@"com.adobe.pdf" options:nil completionHandler:^(NSURL *url, NSError *error) {
                    NSLog(@"dataPath------------------------------------------------------------");
                    [self debug:url.absoluteString];
                    NSString *uti = @"";
                    
                    NSError* readError = nil;
                    NSData *data = [NSData dataWithContentsOfURL:url options: 0 error: &readError];
                    if (data == nil) {
                        NSLog(@"Failed to read file, error %@", readError);
                    }
                    
                    NSUUID *uuid = [NSUUID UUID];
                    NSString *str = [uuid UUIDString];
                    
                    NSURL  *containerURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:SHAREEXT_GROUP_IDENTIFIER];
                    NSString *dataPath =
                    [containerURL.absoluteString stringByAppendingPathComponent: [str stringByAppendingString:@".pdf"]];
                    containerURL = [containerURL URLByAppendingPathComponent:[NSString stringWithFormat: [str.lowercaseString stringByAppendingString:@".pdf"]]];
                    
                    NSError* writeError = nil;
                    [[NSFileManager defaultManager] createFileAtPath:dataPath contents:nil attributes:nil];
                    [data writeToURL:containerURL options: NSDataWritingAtomic error: &writeError];
                    
                    NSArray<NSString *> *utis = [NSArray new];
                    if ([itemProvider.registeredTypeIdentifiers count] > 0) {
                        uti = itemProvider.registeredTypeIdentifiers[0];
                        utis = itemProvider.registeredTypeIdentifiers;
                    }
                    NSDictionary *dict = @{
                        @"text": self.contentText,
                        @"backURL": self.backURL,
                        @"data" : [[NSData alloc] init],
                        @"uti": uti,
                        @"utis": utis,
                        @"name": containerURL.absoluteString
                    };
                    [self.userDefaults setObject:dict forKey:@"image"];
                    [self.userDefaults synchronize];
                    NSString *urlApp = [NSString stringWithFormat:@"%@://image", SHAREEXT_URL_SCHEME];
                    [self openURL:[NSURL URLWithString:urlApp]];
                    [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil]; }];
                return;
            }
     
             // URL
             if ([itemProvider hasItemConformingToTypeIdentifier:@"public.url"]) {
                [itemProvider loadItemForTypeIdentifier:@"public.url" options:nil completionHandler:^(NSURL *url, NSError *error) {
                    [self debug:url.absoluteString];
                    NSString *uti = @"";
                       NSData *data = [[NSData alloc] init];
                    NSArray<NSString *> *utis = [NSArray new];
                    if ([itemProvider.registeredTypeIdentifiers count] > 0) {
                        uti = itemProvider.registeredTypeIdentifiers[0];
                        utis = itemProvider.registeredTypeIdentifiers;
                    }
                       NSDictionary *dict = @{
                           @"text": self.contentText,
                           @"backURL": self.backURL,
                           @"data" : data,
                           @"uti": uti,
                           @"utis": utis,
                           @"name": url.absoluteString
                       };
                    [self.userDefaults setObject:dict forKey:@"image"];
                    [self.userDefaults synchronize];
                    NSString *urlApp = [NSString stringWithFormat:@"%@://image", SHAREEXT_URL_SCHEME];
                    [self openURL:[NSURL URLWithString:urlApp]];
                    [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil]; }];
                 return;
             }
            
            // video mov
            if ([itemProvider hasItemConformingToTypeIdentifier:@"com.apple.quicktime-movie"]) {
                   [itemProvider loadItemForTypeIdentifier:@"com.apple.quicktime-movie" options:nil completionHandler:^(NSURL *url, NSError *error) {
                       [self debug:url.absoluteString];
                       NSString *uti = @"";
                          NSData *data = [[NSData alloc] init];
                       NSArray<NSString *> *utis = [NSArray new];
                       if ([itemProvider.registeredTypeIdentifiers count] > 0) {
                           uti = itemProvider.registeredTypeIdentifiers[0];
                           utis = itemProvider.registeredTypeIdentifiers;
                       }
                          NSDictionary *dict = @{
                              @"text": self.contentText,
                              @"backURL": self.backURL,
                              @"data" : data,
                              @"uti": uti,
                              @"utis": utis,
                              @"name": url.absoluteString
                          };
                       [self.userDefaults setObject:dict forKey:@"image"];
                       [self.userDefaults synchronize];
                       NSString *urlApp = [NSString stringWithFormat:@"%@://image", SHAREEXT_URL_SCHEME];
                       [self openURL:[NSURL URLWithString:urlApp]];
                       [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil]; }];
                    return;
                }
            
            [itemProvider loadItemForTypeIdentifier:SHAREEXT_UNIFORM_TYPE_IDENTIFIER options:nil completionHandler: ^(id<NSSecureCoding> item, NSError *error) {
                
                NSData *data = [[NSData alloc] init];
                if([(NSObject*)item isKindOfClass:[NSURL class]]) {
                    data = [NSData dataWithContentsOfURL:(NSURL*)item];
                }
                if([(NSObject*)item isKindOfClass:[UIImage class]]) {
                    data = UIImagePNGRepresentation((UIImage*)item);
                }

                NSString *suggestedName = @"";
                if ([itemProvider respondsToSelector:NSSelectorFromString(@"getSuggestedName")]) {
                    suggestedName = [itemProvider valueForKey:@"suggestedName"];
                }

                NSString *uti = @"";
                NSArray<NSString *> *utis = [NSArray new];
                if ([itemProvider.registeredTypeIdentifiers count] > 0) {
                    uti = itemProvider.registeredTypeIdentifiers[0];
                    utis = itemProvider.registeredTypeIdentifiers;
                }
                else {
                    if([itemProvider hasItemConformingToTypeIdentifier:@"public.video"]) {
                        uti = @"public.video";
                    }
                    if([itemProvider hasItemConformingToTypeIdentifier:@"public.image"]) {
                        uti = @"public.image";
                    }
                    if([itemProvider hasItemConformingToTypeIdentifier:@"public.url"]) {
                        uti = @"public.url";
                    }
                }
                NSDictionary *dict = @{
                    @"text": self.contentText,
                    @"backURL": self.backURL,
                    @"data" : data,
                    @"uti": uti,
                    @"utis": utis,
                    @"name": suggestedName
                };
                [self.userDefaults setObject:dict forKey:@"image"];
                [self.userDefaults synchronize];

                // Emit a URL that opens the cordova app
                NSString *url = [NSString stringWithFormat:@"%@://image", SHAREEXT_URL_SCHEME];

                // Not allowed:
                // [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
                
                // Crashes:
                // [self.extensionContext openURL:[NSURL URLWithString:url] completionHandler:nil];
                
                // From https://stackoverflow.com/a/25750229/2343390
                // Reported not to work since iOS 8.3
                // NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:url]];
                // [self.webView loadRequest:request];
                
                [self openURL:[NSURL URLWithString:url]];

                // Inform the host that we're done, so it un-blocks its UI.
                [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
            }];

            return;
        }
    }

    // Inform the host that we're done, so it un-blocks its UI.
    [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
}

- (NSArray*) configurationItems {
    // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
    return @[];
}

- (NSString*) backURLFromBundleID: (NSString*)bundleId {
    if (bundleId == nil) return nil;
    // App Store - com.apple.AppStore
    if ([bundleId isEqualToString:@"com.apple.AppStore"]) return @"itms-apps://";
    // Calculator - com.apple.calculator
    // Calendar - com.apple.mobilecal
    // Camera - com.apple.camera
    // Clock - com.apple.mobiletimer
    // Compass - com.apple.compass
    // Contacts - com.apple.MobileAddressBook
    // FaceTime - com.apple.facetime
    // Find Friends - com.apple.mobileme.fmf1
    // Find iPhone - com.apple.mobileme.fmip1
    // Game Center - com.apple.gamecenter
    // Health - com.apple.Health
    // iBooks - com.apple.iBooks
    // iTunes Store - com.apple.MobileStore
    // Mail - com.apple.mobilemail - message://
    if ([bundleId isEqualToString:@"com.apple.mobilemail"]) return @"message://";
    // Maps - com.apple.Maps - maps://
    if ([bundleId isEqualToString:@"com.apple.Maps"]) return @"maps://";
    // Messages - com.apple.MobileSMS
    // Music - com.apple.Music
    // News - com.apple.news - applenews://
    if ([bundleId isEqualToString:@"com.apple.news"]) return @"applenews://";
    // Notes - com.apple.mobilenotes - mobilenotes://
    if ([bundleId isEqualToString:@"com.apple.mobilenotes"]) return @"mobilenotes://";
    // Phone - com.apple.mobilephone
    // Photos - com.apple.mobileslideshow
    if ([bundleId isEqualToString:@"com.apple.mobileslideshow"]) return @"photos-redirect://";
    // Podcasts - com.apple.podcasts
    // Reminders - com.apple.reminders - x-apple-reminder://
    if ([bundleId isEqualToString:@"com.apple.reminders"]) return @"x-apple-reminder://";
    // Safari - com.apple.mobilesafari
    // Settings - com.apple.Preferences
    // Stocks - com.apple.stocks
    // Tips - com.apple.tips
    // Videos - com.apple.videos - videos://
    if ([bundleId isEqualToString:@"com.apple.videos"]) return @"videos://";
    // Voice Memos - com.apple.VoiceMemos - voicememos://
    if ([bundleId isEqualToString:@"com.apple.VoiceMemos"]) return @"voicememos://";
    // Wallet - com.apple.Passbook
    // Watch - com.apple.Bridge
    // Weather - com.apple.weather
    return @"";
}

// This is called at the point where the Post dialog is about to be shown.
// We use it to store the _hostBundleID
- (void) willMoveToParentViewController: (UIViewController*)parent {
    NSString *hostBundleID = [parent valueForKey:(@"_hostBundleID")];
    self.backURL = [self backURLFromBundleID:hostBundleID];
}

@end
