//
//  ENOJavaScriptApp.m
//  Electrino
//
//  Created by Pauli Olavi Ojala on 03/05/17.
//  Copyright © 2017 Pauli Olavi Ojala.
//
//  This software may be modified and distributed under the terms of the MIT license.  See the LICENSE file for details.
//

#import "ENOJavaScriptApp.h"
#import "ENOJSPath.h"
#import "ENOJSUrl.h"
#import "ENOJSBrowserWindow.h"
#import "ENOJSApp.h"
#import "ENOJSProcess.h"
#import "ENOJSConsole.h"

#import "ENOCPPExposer.h"

extern "C"
const char *_protocol_getMethodTypeEncoding(Protocol *p, SEL sel, BOOL isRequiredMethod, BOOL isInstanceMethod);


NSString * const kENOJavaScriptErrorDomain = @"ENOJavaScriptErrorDomain";


@interface ENOJavaScriptApp ()

@property (nonatomic, strong) JSVirtualMachine *jsVM;
@property (nonatomic, strong) JSContext *jsContext;
@property (nonatomic, strong) NSDictionary *jsModules;
@property (nonatomic, strong) ENOJSApp *jsAppGlobalObject;

@property (nonatomic, assign) BOOL inException;

@end


@implementation ENOJavaScriptApp

+ (instancetype)sharedApp
{
    static ENOJavaScriptApp *s_app = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_app = [[self alloc] init];
    });
    return s_app;
}

- (id)init
{
    self = [super init];
    
    self.jsVM = [[JSVirtualMachine alloc] init];
    self.jsContext = [[JSContext alloc] initWithVirtualMachine:self.jsVM];
    
    self.jsAppGlobalObject = [[ENOJSApp alloc] init];
    self.jsAppGlobalObject.jsApp = self;
    
    
    // initialize available modules
    
    NSMutableDictionary *modules = [NSMutableDictionary dictionary];
    
    modules[@"electrino"] = @{
                              @"app": self.jsAppGlobalObject,
                              @"BrowserWindow": [ENOJSBrowserWindow class],
                              };
    modules[@"path"] = [[ENOJSPath alloc] init];
    modules[@"url"] = [[ENOJSUrl alloc] init];
    
    self.jsModules = modules;
    
    
    // add exception handler and global functions
    
    __block __weak ENOJavaScriptApp *weakSelf = self;
    
    self.jsContext.exceptionHandler = ^(JSContext *context, JSValue *exception) {
        [weakSelf _jsException:exception];
    };
    
	self.jsContext[@"require"] = ^(NSString *arg) {
		
		NSString *appDir = [[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"app"] stringByAppendingString:@"/"];
		
		if ([arg hasSuffix:@".js"]) { // If a javascript file is being directly referenced
			JSContext *tmpContext = [weakSelf newContextForEvaluation];
			
			[tmpContext evaluateScript:[NSString stringWithContentsOfURL:[NSURL fileURLWithPath:[appDir stringByAppendingString:arg]] encoding:NSUTF8StringEncoding error:NULL]];
			return (id)[tmpContext objectForKeyedSubscript:@"exports"]; // Casted to id as the compile doesn't like multiple types of return values when no return value is specified
		} else if (weakSelf.jsModules[arg] != nil) {
			id module = weakSelf.jsModules[arg];
			return module;
		}
		
		BOOL isDirectory;
		BOOL doesExist = [[NSFileManager defaultManager] fileExistsAtPath:[appDir stringByAppendingString:arg] isDirectory:&isDirectory];
		if (doesExist && isDirectory) {
			// Find where the starting point is within package.json
			NSData *packageJSON = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:[[appDir stringByAppendingString:arg] stringByAppendingString:@"/package.json"]]];
			if (packageJSON == nil) {
				return (id)nil;
			}
			NSDictionary *packageDictionary = [NSJSONSerialization JSONObjectWithData:packageJSON options:0 error:NULL];
			if (packageDictionary == nil || packageDictionary[@"main"] == nil) {
				return (id)nil;
			}
			NSString *mainJSFile = packageDictionary[@"main"];
			NSURL *fileURL = [NSURL fileURLWithPath:packageDictionary[@"main"] relativeToURL:[NSURL fileURLWithPath:[appDir stringByAppendingString:arg]]];
			mainJSFile = [@"/" stringByAppendingString:mainJSFile];
			NSString *jsFileContents = [NSString stringWithContentsOfURL:fileURL encoding:NSUTF8StringEncoding error:NULL];
			
			JSContext *tmpContext = [weakSelf newContextForEvaluation];
			
			[tmpContext evaluateScript:jsFileContents];
			return (id)[tmpContext objectForKeyedSubscript:@"exports"]; // Casted to id as the compile doesn't like multiple types of return values when no return value is specified

		} else {
			// Module doesn't exist!
		}
		return (id)nil;
		
    };

	Object test;
	test.insert(pair<string, ENOType>("platform", CreateString("darwin")));
	test.insert(pair<string, ENOType>("@name", CreateString("RuntimeProcess")));
	
	ENOType func;
	func.type = "fstring<string>";
	std::function<string(string)> realfunc = [](string str) -> string {
		return str + std::string("r/MadLads");
	};
	func.value = realfunc;
	test.insert(pair<string, ENOType>("coolFunc", func));
	
	id runtimeObj = exposeCPPObjectToJS(test);
	
	self.jsContext[@"process"] = runtimeObj;
	
	ENOJSPath *p = [[ENOJSPath alloc] init];
//
	printf("----------- Properties -----------\n");
//
	unsigned int count;
	objc_property_t *props = class_copyPropertyList([self.jsAppGlobalObject class], &count);
	for (int i = 0; i < count; i++) {
//		if (strstr("platform", property_getName(props[i])))
			NSLog(@"Real Class - %s: %s", property_getName(props[i]), property_getAttributes(props[i]));
	}
	
	props = protocol_copyPropertyList(objc_getProtocol("ENOJSAppExports"), &count);
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
	Method* m = class_copyMethodList(object_getClass(self.jsAppGlobalObject), &count);
	for (int i = 0; i < count; i++) {
		NSLog(@"Real Class - %s: %s, %s", sel_getName(method_getName(m[i])), method_copyReturnType(m[i]), method_getTypeEncoding(m[i]));
	}

	objc_method_description *methods = protocol_copyMethodDescriptionList(objc_getProtocol("ENOJSAppExports"), YES, YES, &count);
	for (int i = 0; i < count; i++) {
		NSLog(@"Real Protocol - %s: %s, %s", sel_getName(methods[i].name), methods[i].types, _protocol_getMethodTypeEncoding(objc_getProtocol("ENOJSAppExports"), methods[i].name, YES, YES));
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
	Ivar *ivars = class_copyIvarList([self.jsAppGlobalObject class], &count);
	for (int i = 0; i < count; i++) {
//		if (strstr("platform", ivar_getName(iva÷rs[i])))
			NSLog(@"Real Protocol - %s: %s with %ld", ivar_getName(ivars[i]), ivar_getTypeEncoding(ivars[i]), ivar_getOffset(ivars[i]));
	}
//
//	ivars = class_copyIvarList([runtimeObj class], &count);
//	for (int i = 0; i < count; i++) {
//		if (strstr("platform", ivar_getName(ivars[i])))
//			NSLog(@"Runtime Protocol - %s: %s with %ld", ivar_getName(ivars[i]), ivar_getTypeEncoding(ivars[i]), ivar_getOffset(ivars[i]));
//	}
//	
//	
//	printf("----------- Voodoo -----------\n");
	//
//	protocol_t *proto = (__bridge protocol_t*)objc_getProtocol("ENOJSProcessExports");
//	const char **methTypes = proto->extendedMethodTypes;
//	NSLog(@"Huh %s", methTypes[0]);
//	
//	protocol_t *proto2 = (__bridge protocol_t*)objc_getProtocol("RuntimeClassJS");
//	const char **methTypes2 = proto2->extendedMethodTypes;
//	NSLog(@"Huh %s", methTypes2[0]);
//
//	printf("----------- End Debug -----------\n");

	
//	
//	unsigned int count;
//	Method* m = class_copyMethodList(object_getClass(p), &count);
//	for (int i = 0; i < count; i++) {
//		NSLog(@"Real Class - %s: %s, %s", sel_getName(method_getName(m[i])), method_copyReturnType(m[i]), method_getTypeEncoding(m[i]));
//	}
//	
//	objc_method_description *methods = protocol_copyMethodDescriptionList(objc_getProtocol("ENOJSProcessExports"), YES, YES, &count);
//	for (int i = 0; i < count; i++) {
//		NSLog(@"Real Protocol - %s: %s", sel_getName(methods[i].name), methods[i].types);
//	}
//	
//	m = class_copyMethodList(object_getClass(runtimeObj), &count);
//	for (int i = 0; i < count; i++) {
//		NSLog(@"Runtime - %s: %s, %s", sel_getName(method_getName(m[i])), method_copyReturnType(m[i]), method_getTypeEncoding(m[i]));
//	}
//	
//	methods = protocol_copyMethodDescriptionList(objc_getProtocol("RuntimeClassJS"), YES, YES, &count);
//	for (int i = 0; i < count; i++) {
//		NSLog(@"Runtime Protocol - %s: %s", sel_getName(methods[i].name), methods[i].types);
//	}
	
	
//
	
//	count;
//	Ivar *te = class_copyIvarList([ENOJSProcess class], &count);
//	NSLog(@"count: %d", count);
//	Ivar ivar = te[0];
//	NSLog(@"%s", ivar_getTypeEncoding(ivar));
//	
//	unsigned int count;
//	objc_property_t *props = class_copyPropertyList([ENOJSProcess class], &count);
//	NSLog(@"count: %d", count);
//	objc_property_t first = props[0];
//	NSLog(@"%s", property_getAttributes(first));
	
//	props = protocol_copyPropertyList(objc_getProtocol("ENOJSProcessExports"), &count);
//	NSLog(@"count: %d", count);
//	first = props[0];
//	NSLog(@"%s", property_getName(first));
	
	
    self.jsContext[@"console"] = [[ENOJSConsole alloc] init];
    
    return self;
}

// Create a new context for just evaluating the file
// ISSUE: JSContext does not include -copyWithZone: method, so we have to manually copy the required methods.
-(JSContext*)newContextForEvaluation
{
	JSContext* newContext = [[JSContext alloc] initWithVirtualMachine:self.jsVM];
	newContext[@"require"] = self.jsContext[@"require"];
	newContext[@"process"] = self.jsContext[@"process"];
	newContext[@"console"] = self.jsContext[@"console"];
	[newContext evaluateScript:@"var exports = {};"]; // Evaluated so the developer doesnt have to
	return newContext;
}

- (void)dealloc
{
    self.jsContext.exceptionHandler = NULL;
    self.jsContext[@"require"] = nil;
}

- (void)_jsException:(JSValue *)exception
{
    NSLog(@"%s, %@", __func__, exception);
    
    if (self.inException) {  // prevent recursion, just in case
        return; // --
    }
    
    self.inException = YES;
    
    self.lastException = exception.toString;
    self.lastExceptionLine = [exception valueForProperty:@"line"].toInt32;
    
    self.inException = NO;
}

- (BOOL)loadMainJS:(NSString *)js error:(NSError **)outError
{
    self.lastException = nil;
    
    NSLog(@"%s...", __func__);
    
    [self.jsContext evaluateScript:js];
    
    if (self.lastException) {
        if (outError) {
            *outError = [NSError errorWithDomain:kENOJavaScriptErrorDomain
                                           code:101
                                       userInfo:@{
                                                  NSLocalizedDescriptionKey: self.lastException,
                                                  @"SourceLineNumber": @(self.lastExceptionLine),
                                                  }];
        }
        return NO; // --
    }
	
    NSLog(@"%s done", __func__);
    
    return YES;
}

@end
