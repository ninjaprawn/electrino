//
//  ENOCPPExposer.m
//  Electrino
//
//  Created by George Dan on 9/5/17.
//  Copyright © 2017 Lacquer. All rights reserved.
//

#import "ENOCPPExposer.h"


struct objc_object_ret {
	id out;
	NSString *type;
};

objc_object_ret parse_cpp_object(ENOType obj) {
	NSString *type = stringToNSString(obj.type);
	if ([type isEqualToString:@"string"]) {
		std::string newString = boost::any_cast<std::string>(obj.value);
		objc_object_ret output;
		output.type = @"NSString";
		output.out = stringToNSString(newString);
		return output;
	}
	objc_object_ret out;
	return out;
}

id getter(id self, SEL _cmd) {
	NSLog(@"%s = %@", sel_getName(_cmd), object_getIvar(self, class_getInstanceVariable([self class], sel_getName(_cmd))));
	return object_getIvar(self, class_getInstanceVariable([self class], sel_getName(_cmd)));
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
		
		NSMutableArray<NSString*> *extendedMethodTypes = [[NSMutableArray alloc] init];
		int i = 0;
		for ( auto const& item : obj) {
			if (item.first[0] != '@') {
				ENOType currentItem = item.second;
				objc_object_ret ret = parse_cpp_object(currentItem);
				if (ret.type == nil) { continue; }
//				__block id currentObjCObject = ret.out;
				const char* _className = ret.type.UTF8String;
				NSLog(@"%s", item.first.c_str());
				
				char propertyType[strlen(_className) + 3];
				strcpy(propertyType, "@\"");
				strcat(propertyType, _className);
				strcat(propertyType, "\"");
				
				// Create a basic property
				objc_property_attribute_t type = { "T", propertyType };
				objc_property_attribute_t n = {"N",""};
				objc_property_attribute_t c = {"C",""};
				objc_property_attribute_t protoAttr[] = {type, c, n};
				
				// Add the property to the protocol
				protocol_addProperty(customProtocol, item.first.c_str(), protoAttr, 3, YES, YES);
				
				// Add getter and setter to the protocol
				string capitalFirst = item.first;
				capitalFirst[0] = toupper(capitalFirst[0]);
				protocol_addMethodDescription(customProtocol, sel_getUid([NSString stringWithFormat:@"set%s:", capitalFirst.c_str()].UTF8String), "v24@0:8@16", YES, YES);
				protocol_addMethodDescription(customProtocol, sel_getUid(item.first.c_str()), "@16@0:8", YES, YES);
				
				NSString *getterMethodType = [NSString stringWithFormat:@"@\"%s\"16@0:8", _className];
				NSString *setterMethodType = [NSString stringWithFormat:@"v24@0:8@\"%s\"16", _className];
				
				[extendedMethodTypes addObject:setterMethodType];
				[extendedMethodTypes addObject:getterMethodType];
				
				// Create the instance variable
				class_addIvar(runtimeClass, item.first.c_str(), class_getInstanceSize(objc_getClass(_className)), log2(class_getInstanceSize(objc_getClass(_className))), propertyType);
				// Create our class property, this time referencing the instance variable
				objc_property_attribute_t v = {"V", item.first.c_str()};
				objc_property_attribute_t classAttr[] = {type, c, n, v};
				class_addProperty(runtimeClass, item.first.c_str(), classAttr, 4);
				
				// Simple function to read the variable
//				IMP getter = imp_implementationWithBlock(^id (id self) {
//					
////					unsigned int count;
////					Method *m = class_copyMethodList([self class], &count);
////					for (int i = 0; i < count; i++) {
////						Method currentM = m[i];
////						
////					}
//					
//					return object_getIvar(self, class_getInstanceVariable([self class], "platform"));
//				});
				class_addMethod(runtimeClass, sel_registerName(item.first.c_str()), (IMP)getter, "@16@0:8");
				
				// We disregard writing (better to set readonly on
//				IMP setter = imp_implementationWithBlock(^void (id self, id val) {
//					NSLog(@"Write method called! Doing nothing: %@", val);
////					currentObjCObject = val;
//				});
//				class_addMethod(runtimeClass, sel_registerName([NSString stringWithFormat:@"set%s:", capitalFirst.c_str()].UTF8String), setter, "v24@0:8@16");
				i += 1;
			}
		}
		
		/*
		 In summary, when Objective-C is compiled, the true method signatures are generated. When we create our class and protocol at runtime, the compiler cannot generate those signatures. This means we have to do it ourselves.
		 We've done this by type-casting Protocol* to its more structured representation known as protocol_t. This contains a property called "extendedMethodTypes". Here, we add the corresponding method signatures to the methods we added above, in order.
		 */
		
		protocol_t *proto2 = (__bridge protocol_t*)customProtocol;
		proto2->extendedMethodTypes = (const char**)malloc(extendedMethodTypes.count*sizeof(char*));;
		for (int i = 0; i < extendedMethodTypes.count; i++) {
			proto2->extendedMethodTypes [i] = [extendedMethodTypes objectAtIndex:i].UTF8String;
		}
		

		// Finally we can register our class and protocol
		objc_registerProtocol(customProtocol);
		class_addProtocol(runtimeClass, customProtocol);
		objc_registerClassPair(runtimeClass);
		
		
		NSLog(@"Huh");
		
	}
	
	id runtimeObject = [[objc_getClass(className.c_str()) alloc] init];
	
	
	
	object_setIvar(runtimeObject, class_getInstanceVariable([runtimeObject class], "platform"), getNSString(obj, "platform"));
	object_setIvar(runtimeObject, class_getInstanceVariable([runtimeObject class], "meme"), getNSString(obj, "meme"));
	
//	std::function<string(string)> realFunc = boost::any_cast<std::function<string(string)>>(obj.at("coolFunc").value);
//	NSLog(@"%@", stringToNSString(realFunc(NSStringToString(@"kappa: "))));
//	
//	Ivar platformProperty = class_getInstanceVariable(objc_getClass(className.c_str()), "platform");
//	object_setIvar(runtimeObject, platformProperty, getNSString(obj, "platform"));
	
	return runtimeObject;
}
