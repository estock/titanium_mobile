/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2010 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */
#ifdef USE_TI_UIEMAILDIALOG

#import "TiBase.h"
#import "TiUIEmailDialogProxy.h"
#import "TiUtils.h"
#import "TiBlob.h"
#import "TiColor.h"
#import "TiApp.h"
#import "TiFile.h"
#import "Mimetypes.h"

@implementation TiUIEmailDialogProxy

- (void) dealloc
{
	RELEASE_TO_NIL(attachments);
	[super dealloc];
}

-(void)_destroy
{
	RELEASE_TO_NIL(attachments);
	[super _destroy];
}

-(NSArray *)attachments
{
	return attachments;
}

-(void)addAttachment:(id)ourAttachment
{
	ENSURE_SINGLE_ARG(ourAttachment,NSObject);
	
	if (attachments == nil)
	{
		attachments = [[NSMutableArray alloc] initWithObjects:ourAttachment,nil];
	}
	else
	{
		[attachments addObject:ourAttachment];
	}
}

- (id)isSupported:(id)args
{
	return NUMBOOL([MFMailComposeViewController canSendMail]);
}

- (void)open:(id)args
{
	ENSURE_TYPE_OR_NIL(args,NSDictionary);
	Class arrayClass = [NSArray class];
	NSArray * toArray = [self valueForKey:@"toRecipients"];
	ENSURE_CLASS_OR_NIL(toArray,arrayClass);
	NSArray * bccArray = [self valueForKey:@"bccRecipients"];
	ENSURE_CLASS_OR_NIL(bccArray,arrayClass);
	NSArray * ccArray = [self valueForKey:@"ccRecipients"];
	ENSURE_CLASS_OR_NIL(ccArray,arrayClass);

	ENSURE_UI_THREAD(open,args);
		
	NSString * subject = [TiUtils stringValue:[self valueForKey:@"subject"]];
	NSString * message = [TiUtils stringValue:[self valueForKey:@"messageBody"]];

	if (![MFMailComposeViewController canSendMail])
	{
		NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:NUMINT(MFMailComposeResultFailed),@"result",
							   NUMBOOL(NO),@"success",
							   @"system can't send email",@"error",
							   nil];
		[self fireEvent:@"complete" withObject:event];
		return;
	}

	UIColor * barColor = [[TiUtils colorValue:[self valueForKey:@"barColor"]] _color];
	
	MFMailComposeViewController * composer = [[MFMailComposeViewController alloc] init];
	[composer setMailComposeDelegate:self];
	if (barColor != nil)
	{
		[[composer navigationBar] setTintColor:barColor];
	}

	[composer setSubject:subject];
	[composer setToRecipients:toArray];
	[composer setBccRecipients:bccArray];
	[composer setCcRecipients:ccArray];
	[composer setMessageBody:message isHTML:[TiUtils boolValue:[self valueForKey:@"html"] def:NO]];
	
	if (attachments != nil)
	{
		for (id attachment in attachments)
		{
			if ([attachment isKindOfClass:[TiBlob class]])
			{
				NSString *path = [attachment path];
				if (path==nil)
				{
					path = @"attachment";
				}
				else
				{
					path = [path lastPathComponent];
				}
				[composer addAttachmentData:[attachment data]
										mimeType:[attachment mimeType]
										fileName:path];
			}
			else if ([attachment isKindOfClass:[TiFile class]])
			{
				TiFile *file = (TiFile*)attachment;
				NSString *path = [file path];
				NSData *data = [NSData dataWithContentsOfFile:path];
				NSString *mimetype = [Mimetypes mimeTypeForExtension:path];
				[composer addAttachmentData:data mimeType:mimetype fileName:[path lastPathComponent]];
			}
		}
	}
	
	BOOL animated = [TiUtils boolValue:[self valueForKey:@"animated"] def:YES];
	[[TiApp app] showModalController:composer animated:animated];
}

MAKE_SYSTEM_PROP(SENT,MFMailComposeResultSent);
MAKE_SYSTEM_PROP(SAVED,MFMailComposeResultSaved);
MAKE_SYSTEM_PROP(CANCELLED,MFMailComposeResultCancelled);
MAKE_SYSTEM_PROP(FAILED,MFMailComposeResultFailed);

#pragma mark Delegate 

- (void)mailComposeController:(MFMailComposeViewController *)composer didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
	if(error!=nil)
	{
		NSLog(@"[ERROR] Unexpected composing error: %@",error);
	}
	
	BOOL animated = [TiUtils boolValue:[self valueForKey:@"animated"] def:YES];

	[[TiApp app] hideModalController:composer animated:animated];
	[composer autorelease];

	if ([self _hasListeners:@"complete"])
	{
		NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:NUMINT(result),@"result",
							   NUMBOOL(result==MFMailComposeResultSent),@"success",
							   error,@"error",
							   nil];
		[self fireEvent:@"complete" withObject:event];
	}
}

@end

#endif