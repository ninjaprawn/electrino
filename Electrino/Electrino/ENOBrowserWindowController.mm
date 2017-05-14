//
//  ENOBrowserWindowController.m
//  Electrino
//
//  Created by Pauli Olavi Ojala on 03/05/17.
//  Copyright © 2017 Pauli Olavi Ojala.
//
//  This software may be modified and distributed under the terms of the MIT license.  See the LICENSE file for details.
//

#import "ENOBrowserWindowController.h"
#import <JavaScriptCore/JavaScriptCore.h>


// The new WKWebView class doesn't give access to its JSContext (because it runs in a separate process);
// therefore it doesn't seem suitable for hosting Electrino apps.
// Let's just stick with good old WebView for now.
#define USE_WKWEBVIEW 0


#import "ENOCPPExposer.h"



@interface ENOBrowserWindowController () <WebFrameLoadDelegate>

#if USE_WKWEBVIEW
@property (nonatomic, strong) WKWebView *webView;
#else
@property (nonatomic, strong) WebView *webView;
#endif

@end



@implementation ENOBrowserWindowController

- (id)init
{
    NSWindowStyleMask styleMask = NSWindowStyleMaskTitled
    | NSWindowStyleMaskMiniaturizable
    | NSWindowStyleMaskResizable;
    
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(100, 100, 640, 480)
                                                   styleMask:styleMask
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    
    window.opaque = NO;
    window.hasShadow = YES;
    window.ignoresMouseEvents = NO;
    window.allowsConcurrentViewDrawing = YES;
    window.releasedWhenClosed = NO;
    
#if USE_WKWEBVIEW
    WKWebViewConfiguration *wkConf = [[WKWebViewConfiguration alloc] init];
    
    WKWebView *webView = [[WKWebView alloc] initWithFrame:window.contentView.bounds configuration:wkConf];
    
#else
    WebView *webView = [[WebView alloc] initWithFrame:window.contentView.frame];
    
    webView.frameLoadDelegate = self;
    
    webView.drawsBackground = NO;
    
    WebPreferences *prefs = [webView preferences];
    prefs.javaScriptEnabled = YES;
    prefs.plugInsEnabled = NO;
    //prefs.defaultFontSize = 20;
    
#endif
    
    window.contentView = webView;
    self.webView = webView;
    
    return [self initWithWindow:window];
}


- (void)loadURL:(NSURL *)url
{
    if (url.isFileURL) {
#if USE_WKWEBVIEW
        NSString *dir = [url.path stringByDeletingLastPathComponent];
        NSURL *baseURL = [NSURL fileURLWithPath:dir isDirectory:YES];
        
        NSLog(@"%s, using WKWebView, %@", __func__, url);

        [self.webView loadFileURL:url allowingReadAccessToURL:baseURL];
        
#else
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
        [self.webView.mainFrame loadRequest:req];
        
#endif
    }
    else {
        NSLog(@"** %s: only supports file urls", __func__);
    }
    
}

- (void)webView:(WebView *)webView didCreateJavaScriptContext:(JSContext *)jsContext forFrame:(WebFrame *)frame
{
	Object test;
	test.insert(pair<string, ENOType>("platform", CreateString("darwin")));
	test.insert(pair<string, ENOType>("meme", CreateString("w00t")));
	test.insert(pair<string, ENOType>("@name", CreateString("RuntimeProcess")));
	//
	//	ENOType func;
	//	func.type = "fstring<string>";
	//	std::function<string(string)> realfunc = [](string str) -> string {
	//		return str + std::string("r/MadLads");
	//	};
	//	func.value = realfunc;
	//	test.insert(pair<string, ENOType>("coolFunc", func));
	
	id runtimeObj = exposeCPPObjectToJS(test);
	printf("----------- Properties -----------\n");
	//
	unsigned int count;
	objc_property_t *props = class_copyPropertyList([runtimeObj class], &count);
	for (int i = 0; i < count; i++) {
		//		if (strstr("platform", property_getName(props[i])))
		NSLog(@"Real Class - %s: %s", property_getName(props[i]), property_getAttributes(props[i]));
	}
	
	props = protocol_copyPropertyList(objc_getProtocol("RuntimeProcessJS"), &count);
	for (int i = 0; i < count; i++) {
		//		if (strstr("platform", property_getName(props[i])))
		NSLog(@"Real Protocol - %s: %s", property_getName(props[i]), property_getAttributes(props[i]));
	}
	//
	//	props = class_copyPropertyList([runtimeObj class], &count);
	//	for (int i = 0; i < count; i++) {
	//		if (strstr("platform", property_getName(props[i])))
	//			NSLog(@"Runtime Class - %s: %s", property_getName(props[i]), property_getAttributes(props[i]));
	//	}
	//
	//	props = protocol_copyPropertyList(objc_getProtocol("RuntimeClassJS"), &count);
	//	for (int i = 0; i < count; i++) {
	//		if (strstr("platform", property_getName(props[i])))
	//			NSLog(@"Runtime Protocol - %s: %s", property_getName(props[i]), property_getAttributes(props[i]));
	//	}
	//
	printf("----------- Methods -----------\n");
	//
	Method* m = class_copyMethodList(object_getClass(runtimeObj), &count);
	for (int i = 0; i < count; i++) {
		NSLog(@"Real Class - %s: %s, %s", sel_getName(method_getName(m[i])), method_copyReturnType(m[i]), method_getTypeEncoding(m[i]));
	}
	
	objc_method_description *methods = protocol_copyMethodDescriptionList(objc_getProtocol("RuntimeProcessJS"), YES, YES, &count);
	for (int i = 0; i < count; i++) {
		NSLog(@"Real Protocol - %s: %s, %s", sel_getName(methods[i].name), methods[i].types, _protocol_getMethodTypeEncoding(objc_getProtocol("RuntimeProcessJS"), methods[i].name, YES, YES));
	}
	//
	//	m = class_copyMethodList(object_getClass(runtimeObj), &count);
	//	for (int i = 0; i < count; i++) {
	//		NSLog(@"Runtime Class - %s: %s, %s", sel_getName(method_getName(m[i])), method_copyReturnType(m[i]), method_getTypeEncoding(m[i]));
	//	}
	//
	//	methods = protocol_copyMethodDescriptionList(objc_getProtocol("RuntimeClassJS"), YES, YES, &count);
	//
	//	for (int i = 0; i < count; i++) {
	//		NSLog(@"Runtime Protocol - %s: %s, %s", sel_getName(methods[i].name), methods[i].types, _protocol_getMethodTypeEncoding(objc_getProtocol("RuntimeClassJS"), methods[i].name, YES, YES));
	//	}
	
	//
	printf("----------- Ivars -----------\n");
	//
	Ivar *ivars = class_copyIvarList([runtimeObj class], &count);
	for (int i = 0; i < count; i++) {
		//		if (strstr("platform", ivar_getName(iva÷rs[i])))
		NSLog(@"Real Protocol - %s: %s with %ld", ivar_getName(ivars[i]), ivar_getTypeEncoding(ivars[i]), ivar_getOffset(ivars[i]));
	}
	
	jsContext[@"process"] = runtimeObj;
}

- (void)webView:(WebView *)webView didReceiveTitle:(NSString *)title forFrame:(WebFrame *)frame
{
    if (frame == self.webView.mainFrame) {
        self.window.title = title;
    }
}

@end
