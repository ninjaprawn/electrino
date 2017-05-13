//
//  ENOCPPExposer.h
//  Electrino
//
//  Created by George Dan on 9/5/17.
//  Copyright © 2017 Lacquer. All rights reserved.
//

#ifndef ENOCPPExposer_h
#define ENOCPPExposer_h

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

#include <iostream>
#include <map>
#include <inttypes.h>
#include <functional>
#include <cstdarg>

#include <boost/any.hpp>
#import <objc/runtime.h>
#import <objc/message.h>
#import "objcruntime-special.h"

using namespace std;
using namespace boost;

#define stringToNSString(str) [NSString stringWithUTF8String:str.c_str()]
#define NSStringToString(str) std::string([str UTF8String])
#define getString(obj, key) boost::any_cast<std::string>(obj.at(key).value)
#define getNSString(obj, key) stringToNSString(getString(obj, key))

#define CreateString(str) [](std::string _str) -> ENOType { ENOType t; t.type="string"; t.value = _str; return t;}(std::string(str))

class ENOType {
public:
	string type;
	any value;
};


typedef std::map<std::string, ENOType> Object;

id exposeCPPObjectToJS(Object obj);

#endif /* ENOCPPExposer_h */
