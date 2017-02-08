/**
 * ti.barcodescanner
 *
 * Created by Your Name
 * Copyright (c) 2016 Your Company. All rights reserved.
 */

#import "TiBarcodescannerModule.h"
#import "TiBase.h"
#import "TiHost.h"
#import "TiUtils.h"
#import "TiViewProxy.h"
#import "TiApp.h"

@implementation TiBarcodescannerModule

#pragma mark Internal

-(id)moduleGUID
{
	return @"dcf42617-0190-48f1-b3a6-96070fb439fc";
}

-(NSString*)moduleId
{
	return @"ti.barcodescanner";
}

#pragma mark Lifecycle

-(void)startup
{
	[super startup];

	NSLog(@"[DEBUG] %@ loaded",self);
    
    [self initialize];
}

- (void)initialize
{
    selectedCamera = MTBCameraBack;
    selectedLEDMode = MTBTorchModeOff;
}

#pragma mark Public API's

- (id)canShow:(id)unused
{
    return NUMBOOL([MTBBarcodeScanner cameraIsPresent] && ![MTBBarcodeScanner scanningIsProhibited]);
}

- (void)capture:(id)args
{
    ENSURE_SINGLE_ARG(args, NSDictionary);
    
    BOOL keepOpen = [TiUtils boolValue:[args objectForKey:@"keepOpen"] def:NO];
    BOOL animate = [TiUtils boolValue:[args objectForKey:@"animate"] def:YES];
    NSMutableArray *acceptedFormats = [NSMutableArray arrayWithArray:[args objectForKey:@"acceptedFormats"]];
    TiViewProxy *overlayProxy = [args objectForKey:@"overlay"];
    
    barcodeViewController = [[TiBarcodeViewController alloc] init];
    
    NSError *error = nil;
    
    if (overlayProxy != nil) {
        [barcodeViewController setOverlayView:[self prepareOverlayWithProxy:overlayProxy]];
    }
    
    if (acceptedFormats != nil) {
        if ([acceptedFormats containsObject:@-1]) {
            NSLog(@"[WARN] The code-format FORMAT_NONE is deprecated. Use an empty array instead or don't specify formats.");
            [acceptedFormats removeObject:@-1];
        }
        [[barcodeViewController scanner] setMetaDataObjectTypes:[TiBarcodescannerModule formattedMetaDataObjectTypes:acceptedFormats]];
    }
    
    [[barcodeViewController scanner] setCamera:selectedCamera ?: MTBCameraBack];
    [barcodeViewController setShouldAutorotate:allowRotation];
    [[barcodeViewController scanner] setTorchMode:MTBTorchModeOff];
    
    [[barcodeViewController scanner] startScanningWithResultBlock:^(NSArray *codes) {
        if (!codes || [codes count] == 0) {
            return;
        }
        
        [self fireEvent:@"success" withObject:@{
            @"result": [(AVMetadataMachineReadableCodeObject*)[codes firstObject] stringValue],
            @"corners": [(AVMetadataMachineReadableCodeObject *)[codes firstObject] corners]
        }];
        
        if (!keepOpen) {
            [self closeScanner];
        }
    } error:&error];
    
    if (error) {
        [self fireEvent:@"error" withObject:@{
            @"message": [error localizedDescription] ?: @"Unknown error occurred.",
            @"contentType": @""
        }];
        
        if (!keepOpen) {
            [self closeScanner];
        }
    }
    
    [[[[TiApp app] controller] topPresentedController] presentViewController:barcodeViewController animated:animate completion:^{
        [[barcodeViewController scanner] setTorchMode:selectedLEDMode ?: MTBTorchModeOff];
    }];
}

- (void)cancel:(id)unused
{
    [self closeScanner];
    [self fireEvent:@"cancel" withObject:nil];
}

- (void)setUseLED:(id)value
{
    ENSURE_TYPE(value, NSNumber);
    [self replaceValue:value forKey:@"useLED" notification:NO];

    selectedLEDMode = [TiUtils boolValue:value def:YES] ? MTBTorchModeOn : MTBTorchModeOff;
    
    if (barcodeViewController) {
        [[barcodeViewController scanner] setTorchMode:selectedLEDMode];
    }
}

- (id)useLED
{
    return NUMBOOL(selectedLEDMode == MTBTorchModeOn);
}

- (void)setDisplayedMessage:(id)value
{
    NSLog(@"[ERROR] The \"displayedMessage\" property has been removed in the latest release. Place a label in a custom view instead.");
}

- (void)setAllowRotation:(id)value
{
    ENSURE_TYPE(value, NSNumber);
    [self replaceValue:value forKey:@"allowRotation" notification:NO];

    allowRotation = [TiUtils boolValue:value def:NO];
}

- (void)setUseFrontCamera:(id)value
{
    ENSURE_TYPE(value, NSNumber);
    [self replaceValue:value forKey:@"useFrontCamera" notification:NO];
    
    selectedCamera = [TiUtils boolValue:value def:YES] ? MTBCameraFront : MTBCameraBack;
    
    if (barcodeViewController) {
        [[barcodeViewController scanner] setCamera:selectedCamera];
    }
}

- (id)useFrontCamera
{
    return NUMBOOL(selectedCamera == MTBCameraFront);
}

#pragma mark Internal

+ (NSArray *)formattedMetaDataObjectTypes:(NSArray *)array
{
    return @[AVMetadataObjectTypeQRCode];
}

- (UIView *)prepareOverlayWithProxy:(TiViewProxy *)overlayProxy
{
        [overlayProxy windowWillOpen];
        
        CGSize size = [overlayProxy view].bounds.size;
        
#ifndef TI_USE_AUTOLAYOUT
        CGFloat width = [overlayProxy autoWidthForSize:CGSizeMake(MAXFLOAT,MAXFLOAT)];
        CGFloat height = [overlayProxy autoHeightForSize:CGSizeMake(width,0)];
#else
        CGSize s = [[overlayProxy view] sizeThatFits:CGSizeMake(MAXFLOAT,MAXFLOAT)];
        CGFloat width = s.width;
        CGFloat height = s.height;
#endif
        
        if (width > 0 && height > 0) {
            size = CGSizeMake(width, height);
        }
        
        if (CGSizeEqualToSize(size, CGSizeZero) || width==0 || height == 0) {
            size = [UIScreen mainScreen].bounds.size;
        }
        
        CGRect rect = CGRectMake(0, 0, size.width, size.height);
        [TiUtils setView:[overlayProxy view] positionRect:rect];
        [overlayProxy layoutChildren:NO];
    
    return [overlayProxy view];
}

- (void)closeScanner
{
    if (!barcodeViewController) {
        NSLog(@"[ERROR] Trying to dismiss a scanner that hasn't been created, yet. Try again, Marty!");
        return;
    }
    if ([[barcodeViewController scanner] isScanning]) {
        [[barcodeViewController scanner] stopScanning];
    }
    
    [barcodeViewController setScanner:nil];
    [[[[barcodeViewController view] subviews] objectAtIndex:0] removeFromSuperview];
    [barcodeViewController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark Constants


MAKE_SYSTEM_PROP(FORMAT_NONE, -1); // Deprecated, don't specify types
MAKE_SYSTEM_PROP(FORMAT_QR_CODE, AVMetadataObjectTypeQRCode);
MAKE_SYSTEM_PROP(FORMAT_DATA_MATRIX, AVMetadataObjectTypeDataMatrixCode);
MAKE_SYSTEM_PROP(FORMAT_UPC_E, AVMetadataObjectTypeUPCECode);
MAKE_SYSTEM_PROP(FORMAT_UPC_A, AVMetadataObjectTypeEAN13Code); // Sub-set
MAKE_SYSTEM_PROP(FORMAT_EAN_8 ,AVMetadataObjectTypeEAN8Code);
MAKE_SYSTEM_PROP(FORMAT_EAN_13, AVMetadataObjectTypeEAN13Code);
MAKE_SYSTEM_PROP(FORMAT_CODE_128, AVMetadataObjectTypeCode128Code);
MAKE_SYSTEM_PROP(FORMAT_CODE_39, AVMetadataObjectTypeCode39Code);
MAKE_SYSTEM_PROP(FORMAT_CODE_93, AVMetadataObjectTypeCode93Code); // New!
MAKE_SYSTEM_PROP(FORMAT_CODE_39_MOD_43, AVMetadataObjectTypeCode39Mod43Code); // New!
MAKE_SYSTEM_PROP(FORMAT_ITF, AVMetadataObjectTypeITF14Code);
MAKE_SYSTEM_PROP(FORMAT_PDF_417, AVMetadataObjectTypePDF417Code); // New!
MAKE_SYSTEM_PROP(FORMAT_AZTEC, AVMetadataObjectTypeAztecCode); // New!
MAKE_SYSTEM_PROP(FORMAT_FACE, AVMetadataObjectTypeFace); // New!
MAKE_SYSTEM_PROP(FORMAT_INTERLEAVED_2_OF_5, AVMetadataObjectTypeInterleaved2of5Code); // New!



@end
