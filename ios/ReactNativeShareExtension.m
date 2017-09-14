#import "ReactNativeShareExtension.h"
#import "React/RCTRootView.h"
#import <MobileCoreServices/MobileCoreServices.h>

#define URL_IDENTIFIER @"public.url"
#define IMAGE_IDENTIFIER @"public.image"
#define MOVIE_IDENTIFIER @"public.movie"
#define TEXT_IDENTIFIER (NSString *)kUTTypePlainText

NSExtensionContext* extensionContext;

@implementation ReactNativeShareExtension {
    NSTimer *autoTimer;
    NSString* type;
    NSString* value;
}

- (UIView*) shareView {
    return nil;
}

RCT_EXPORT_MODULE();

- (void)viewDidLoad {
    [super viewDidLoad];

    //object variable for extension doesn't work for react-native. It must be assign to gloabl
    //variable extensionContext. in this way, both exported method can touch extensionContext
    extensionContext = self.extensionContext;

    UIView *rootView = [self shareView];
    if (rootView.backgroundColor == nil) {
        rootView.backgroundColor = [[UIColor alloc] initWithRed:1 green:1 blue:1 alpha:0.1];
    }

    self.view = rootView;

    [self extractDataFromContext: extensionContext withCallback:^(NSString* val, NSString* contentType, NSException* err) {
        if(err) {
            NSLog(@"Share extension exploded %@",err);
        } else {
            NSCharacterSet *allowedCharacters = [NSCharacterSet URLQueryAllowedCharacterSet];
            NSString *scheme = @"gredismartmobi://share?type=";
            NSString *encodedType = [contentType stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters];
            NSString *encodedVal = [val stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters];
            NSString *url = [@[scheme, encodedType, @"&value=", encodedVal] componentsJoinedByString:@""];

            [self openScheme:url];
        }
    }];
}


RCT_EXPORT_METHOD(close) {
    [extensionContext completeRequestReturningItems:nil
                                  completionHandler:nil];
}

- (void)openScheme:(NSString *)scheme {
    UIApplication *application = [UIApplication sharedApplication];
    NSURL *URL = [NSURL URLWithString:scheme];
    [application openURL:URL options:@{} completionHandler:^(BOOL success) {
        if (success) {
            NSLog(@"Opened %@",scheme);
        }
    }];
}

-(NSArray *)listFileAtPath:(NSString *)path
{
    int count;

    NSArray *directoryContent = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:NULL];
    for (count = 0; count < (int)[directoryContent count]; count++)
    {
        NSLog(@"File %d: %@", (count + 1), [directoryContent objectAtIndex:count]);
    }
    return directoryContent;
}

RCT_REMAP_METHOD(data,
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    [self extractDataFromContext: extensionContext withCallback:^(NSString* val, NSString* contentType, NSException* err) {
        if(err) {
            reject(@"error", err.description, nil);
        } else {
            resolve(@{
                      @"type": contentType,
                      @"value": val
                      });
        }
    }];
}

- (void)extractDataFromContext:(NSExtensionContext *)context withCallback:(void(^)(NSString *value, NSString* contentType, NSException *exception))callback {
    @try {
        NSExtensionItem *item = [context.inputItems firstObject];
        NSArray *attachments = item.attachments;

        __block NSItemProvider *urlProvider = nil;
        __block NSItemProvider *imageProvider = nil;
        __block NSItemProvider *textProvider = nil;
        __block NSItemProvider *movieProvider = nil;

        [attachments enumerateObjectsUsingBlock:^(NSItemProvider *provider, NSUInteger idx, BOOL *stop) {
            if([provider hasItemConformingToTypeIdentifier:URL_IDENTIFIER]) {
                urlProvider = provider;
                *stop = YES;
            } else if ([provider hasItemConformingToTypeIdentifier:TEXT_IDENTIFIER]){
                textProvider = provider;
                *stop = YES;
            } else if ([provider hasItemConformingToTypeIdentifier:IMAGE_IDENTIFIER]){
                imageProvider = provider;
                *stop = YES;
            } else if ([provider hasItemConformingToTypeIdentifier:MOVIE_IDENTIFIER]){
                movieProvider = provider;
                *stop = YES;
            }
        }];

        if(urlProvider) {
            [urlProvider loadItemForTypeIdentifier:URL_IDENTIFIER options:nil completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                NSLog(@"URL PROVIDER");
                NSError *fError = nil;
                NSURL *url = (NSURL *)item;

                NSLog(@"Item url %@",url);
                NSURL *containerURL = [[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.com.gredimobile.Share"] URLByAppendingPathComponent:@"Library/Caches"];
                NSString *filename = [[url absoluteString] lastPathComponent];
                NSString *destinationUrl = [[containerURL path] stringByAppendingPathComponent:filename];
                [[NSFileManager defaultManager] copyItemAtPath:[url path] toPath:destinationUrl error:&fError];
                NSLog(@"Copying file failed %@",fError);
                NSLog(@"Shared container data:%@",[self listFileAtPath:[[[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.com.gredimobile.Share"] path] stringByAppendingPathComponent:@"Library/Caches"]]);
                NSString *newUrl = [[containerURL path] stringByAppendingPathComponent:filename];

                if(callback) {
                    callback(newUrl, [[[url absoluteString] pathExtension] lowercaseString], nil);
                }

            }];
        } else if (imageProvider) {
            [imageProvider loadItemForTypeIdentifier:IMAGE_IDENTIFIER options:nil completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                NSLog(@"IMAGE PROVIDER");
                NSError *fError = nil;
                NSURL *url = (NSURL *)item;
                NSLog(@"Item url %@",url);
                NSURL *containerURL = [[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.com.gredimobile.Share"] URLByAppendingPathComponent:@"Library/Caches"];
                NSString *filename = [[url absoluteString] lastPathComponent];
                NSString *destinationUrl = [[containerURL path] stringByAppendingPathComponent:filename];
                [[NSFileManager defaultManager] copyItemAtPath:[url path] toPath:destinationUrl error:&fError];
                NSLog(@"Copying image failed %@",fError);
                NSLog(@"Shared container data:%@",[self listFileAtPath:[[[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.com.gredimobile.Share"] path] stringByAppendingPathComponent:@"Library/Caches"]]);
                NSString *newUrl = [[containerURL path] stringByAppendingPathComponent:filename];

                if(callback) {
                    callback(newUrl, [[[url absoluteString] pathExtension] lowercaseString], nil);
                }
            }];
        } else if (textProvider) {
            [textProvider loadItemForTypeIdentifier:TEXT_IDENTIFIER options:nil completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                NSString *text = (NSString *)item;

                if(callback) {
                    callback(text, @"text/plain", nil);
                }
            }];
        } else if (movieProvider) {
            [movieProvider loadItemForTypeIdentifier:MOVIE_IDENTIFIER options:nil completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                NSLog(@"MOVIE PROVIDER");
                NSError *fError = nil;
                NSURL *url = (NSURL *)item;
                NSLog(@"Item url %@",url);
                NSURL *containerURL = [[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.com.gredimobile.Share"] URLByAppendingPathComponent:@"Library/Caches"];
                NSString *filename = [[url absoluteString] lastPathComponent];
                NSString *destinationUrl = [[containerURL path] stringByAppendingPathComponent:filename];
                [[NSFileManager defaultManager] copyItemAtPath:[url path] toPath:destinationUrl error:&fError];
                NSLog(@"Copying movie failed %@",fError);
                NSLog(@"Shared container data:%@",[self listFileAtPath:[[[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.com.gredimobile.Share"] path] stringByAppendingPathComponent:@"Library/Caches"]]);
                NSString *newUrl = [[containerURL path] stringByAppendingPathComponent:filename];

                if(callback) {
                    callback(newUrl, [[[url absoluteString] pathExtension] lowercaseString], nil);
                }
            }];
        } else {
            if(callback) {
                callback(nil, nil, [NSException exceptionWithName:@"Error" reason:@"couldn't find provider" userInfo:nil]);
            }
        }
    }
    @catch (NSException *exception) {
        if(callback) {
            callback(nil, nil, exception);
        }
    }
}

@end
