/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2016 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */
#import "TiUIView.h"
#import "MTBBarcodeScanner.h"

@interface TiBarcodescannerScannerView : TiUIView {
    MTBBarcodeScanner *scanner;

    TiDimension width;
    TiDimension height;
    CGFloat autoHeight;
    CGFloat autoWidth;
}

- (MTBBarcodeScanner*)scanner;

@end
