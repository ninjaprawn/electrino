//
//  ENOCPPExposer.m
//  Electrino
//
//  Created by George Dan on 9/5/17.
//  Copyright © 2017 Lacquer. All rights reserved.
//

#import "ENOCPPExposer.h"

id parse_cpp_object(ENOType obj) {
	NSString *type = stringToNSString(obj.type);
	if ([type isEqualToString:@"string"]) {
		std::string newString = boost::any_cast<std::string>(obj.value);
		return stringToNSString(newString);
	}
	return nil;
}

id exposeCPPObjectToJS(Object obj) {
	
	Object realObj(obj);
	
	std::string className = getString(obj, "@name");
	
	// Make sure the class doesn't exist before we create it.
	if (!objc_getClass(className.c_str())) {
	
		// Create the class, inheriting to NSObject
		Class runtimeClass = objc_allocateClassPair(objc_getClass("NSObject"), className.c_str(), 0);
		
		// Create the protocol
		char protocolName[strlen(className.c_str()) + 3];
		strcpy(protocolName, className.c_str());
		strcat(protocolName, "JS");
		
		Protocol *customProtocol = objc_allocateProtocol(protocolName);
		// Make it be exportable to JS
		protocol_addProtocol(customProtocol, objc_getProtocol("JSExport"));
		
		// Create a basic property
		objc_property_attribute_t type = { "T", "@\"NSString\"" };
		objc_property_attribute_t n = {"N",""};
		objc_property_attribute_t c = {"C",""};
		objc_property_attribute_t attr[] = {type, c, n};
		
		// Add the property to the protocol
		protocol_addProperty(customProtocol, "platform", attr, 3, YES, YES);
		
		// Add the getter and setter to the protocol
		protocol_addMethodDescription(customProtocol, sel_getUid("setPlatform:"), "v24@0:8@16", YES, YES);
		protocol_addMethodDescription(customProtocol, sel_getUid("platform"), "@16@0:8", YES, YES);
		
		/*
		 In summary, when Objective-C is compiled, the true method signatures are generated. When we create our class and protocol at runtime, the compiler cannot generate those signatures. This means we have to do it ourselves.
		 We've done this by type-casting Protocol* to its more structured representation known as protocol_t. This contains a property called "extendedMethodTypes". Here, we add the corresponding method signatures to the methods we added above, in order.
		 */
		const char **newMethTypes = (const char**)malloc(2*sizeof(char*));
		newMethTypes[0] = "v24@0:8@\"NSString\"16";
		newMethTypes[1] = "@\"NSString\"16@0:8";
		protocol_t *proto2 = (__bridge protocol_t*)customProtocol;
		proto2->extendedMethodTypes = newMethTypes;
		
		// Pointers rule! And we are finished with the protocol
		objc_registerProtocol(customProtocol);
		class_addProtocol(runtimeClass, customProtocol);
		
		// Create the instance variable
		class_addIvar(runtimeClass, "platform", 0, 0, "@\"NSString\"");
		
		// Create our class property, this time referencing the instance variable
		objc_property_attribute_t v = {"V", "platform"};
		objc_property_attribute_t attr2[] = {type, c, n, v};
		class_addProperty(runtimeClass, "platform", attr2, 4);
		
		// Simple function to read the variable
		IMP platformRead = imp_implementationWithBlock(^NSString* (id self) {
			return getNSString(obj, "platform");
		});
		class_addMethod(runtimeClass, sel_registerName("platform"), platformRead, "@16@0:8");
		
		// We disregard writing (better to set readonly on
		IMP platformWrite = imp_implementationWithBlock(^void (id self, NSString*que) {
			NSLog(@"Write method called! Doing nothing: %@", que);
//			ENOType tmp = obj.at("platform");
//			tmp.value =  SStringToString(que);
		});
		class_addMethod(runtimeClass, sel_registerName("setPlatform:"), platformWrite, "v24@0:8@16");
		
		// Finally we can register our class
		objc_registerClassPair(runtimeClass);
	
	}
	
	id runtimeObject = [[objc_getClass(className.c_str()) alloc] init];
	
	std::function<string(string)> realFunc = boost::any_cast<std::function<string(string)>>(obj.at("coolFunc").value);
	NSLog(@"%@", stringToNSString(realFunc(NSStringToString(@"kappa: "))));
	
//	Ivar platformProperty = class_getInstanceVariable(objc_getClass(className.c_str()), "platform");
//	object_setIvar(runtimeObject, platformProperty, getNSString(obj, "platform"));
	
	return runtimeObject;
}
