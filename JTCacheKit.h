//
//  JTCacheKit.h
//  JTCacheKitDemo
//
//  Created by tmy on 13-6-23.
//  Copyright (c) 2013年 tmy. All rights reserved.
//

#import <Foundation/Foundation.h>

#define JTGlobalCache [JTCache globalCache]

#define JTCache_Value(getter, setter, varType)\
@interface JTCache(getter)\
- (void)set##setter:(varType)value;\
- (varType)getter;\
@end\

#define JTCache_Value_Synthesize(getter, setter, varType, defaultValue, synchronizeType, expireTime)\
@implementation JTCache (getter)\
- (void)set##setter:(varType)value\
{\
NSString *key = @#getter;\
if(![_cacheInfo objectForKey:key])\
{\
Class class;\
if(@encode(varType)[0]=='{')\
{\
class = [NSValue class];\
}\
else\
{\
class = [NSNumber class];\
}\
[self createCache:key type:class syncType:synchronizeType expire:expireTime];\
}\
id valueObject = nil;\
if(@encode(varType)[0]=='{')\
{\
valueObject = [NSValue valueWithBytes:&value objCType:@encode(varType)];\
}\
else\
{\
valueObject = @(value);\
}\
[self setValue:valueObject forName:key];\
}\
- (varType)getter\
{\
NSString *key = @#getter;\
if(![_cacheInfo objectForKey:key])\
{\
Class class;\
if(@encode(varType)[0]=='{')\
{\
class = [NSValue class];\
}\
else\
{\
class = [NSNumber class];\
}\
[self createCache:key type:class syncType:synchronizeType expire:expireTime];\
\
varType __default = defaultValue;\
id valueObject = nil;\
if(@encode(varType)[0]=='{')\
{\
valueObject = [NSValue valueWithBytes:&__default objCType:@encode(varType)];\
}\
else\
{\
valueObject = @(__default);\
}\
[self setValue:valueObject forName:key];\
}\
id valueObject = [self value:key];\
varType varValue;\
if(@encode(varType)[0]!='{')\
{\
varValue = 0;\
}\
NSUInteger bufferSize = 0;\
NSGetSizeAndAlignment(@encode(varType), &bufferSize, NULL);\
void *buffer = calloc(bufferSize, 1);\
if(valueObject){\
[valueObject getValue:buffer];\
}\
varValue = *((varType *)buffer);\
free(buffer);\
return varValue;\
}\
@end\

#define JTCache_Object(getter, setter, varType)\
@interface JTCache(getter)\
- (void)set##setter:(varType*)value;\
- (varType*)getter;\
@end\

#define JTCache_Object_Synthesize(getter, setter, varType, defaultValue, synchronizeType, expireTime)\
@implementation JTCache (getter)\
- (void)set##setter:(varType*)value\
{\
NSString *key = @#getter;\
if(![_cacheInfo objectForKey:key])\
{\
Class class = NSClassFromString(@#varType);\
[self createCache:key type:class syncType:synchronizeType expire:expireTime];\
}\
[self setValue:value forName:key];\
}\
- (varType*)getter\
{\
NSString *key = @#getter;\
if(![_cacheInfo objectForKey:key])\
{\
Class class = NSClassFromString(@#varType);\
[self createCache:key type:class syncType:synchronizeType expire:expireTime];\
[self setValue:defaultValue forName:key];\
}\
id valueObject = [self value:key];\
return valueObject;\
}\
@end\

#define XYCache_Object_Synthesize_Lazy(getter, setter, varType, defaultValue, expireTime)\
@implementation XYPHCache (getter)\
- (void)set##setter:(varType*)value\
{\
NSString *key = @#getter;\
if(![_cacheInfo objectForKey:key])\
{\
Class class = NSClassFromString(@#varType);\
[self createCache:key type:class syncType:XYPHSyncTypeArchive expire:expireTime lazy:YES];\
}\
[self setValue:value forName:key];\
}\
- (varType*)getter\
{\
NSString *key = @#getter;\
if(![_cacheInfo objectForKey:key])\
{\
Class class = NSClassFromString(@#varType);\
[self createCache:key type:class syncType:XYPHSyncTypeArchive expire:expireTime lazy:YES];\
[self setValue:defaultValue forName:key];\
}\
id valueObject = [self value:key];\
return valueObject;\
}\
@end\


typedef enum
{
    JTSyncTypeArchive = 1,
    JTSyncTypePreference =2,
    JTSyncTypeKeychain =3,
    JTSyncTypeNone =4
}JTSyncType;

@interface JTCache : NSObject
{
    NSMutableDictionary *_cacheValues;
    NSMutableDictionary *_cacheInfo;
    NSMutableDictionary *_lazyCacheValues;
}

+ (JTCache *)globalCache;

- (void)createCache:(NSString *)name type:(Class)classType syncType:(JTSyncType)syncType expire:(int)expireTime;
- (void)createCache:(NSString *)name type:(Class)classType syncType:(JTSyncType)syncType expire:(int)expireTime  lazy:(BOOL)lazyLoad;
- (id)value:(NSString *)name;
- (void)setValue:(id)value forName:(NSString *)name;
- (void)deleteCache:(NSString *)name;
- (BOOL)synchronize;

@end
