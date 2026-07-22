#import <Foundation/Foundation.h>
#import <SafariServices/SafariServices.h>

@interface SafariWebExtensionHandler : NSObject <NSExtensionRequestHandling>
@end

@implementation SafariWebExtensionHandler

- (void)beginRequestWithExtensionContext:(NSExtensionContext *)context {
    NSExtensionItem *requestItem = context.inputItems.firstObject;
    id message = requestItem.userInfo[SFExtensionMessageKey];

    NSExtensionItem *responseItem = [[NSExtensionItem alloc] init];
    responseItem.userInfo = @{
        SFExtensionMessageKey: message ?: @{}
    };

    [context completeRequestReturningItems:@[responseItem] completionHandler:nil];
}

@end
