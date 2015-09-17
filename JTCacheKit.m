//
//  JTCacheKit.m
//  JTCacheKitDemo
//
//  Created by tmy on 13-6-23.
//  Copyright (c) 2013年 tmy. All rights reserved.
//

#import "JTCacheKit.h"
#import "SFHFKeychainUtils.h"

#define FOLDER_NAME @"JTCache"
#define CACHE_NAME @"cache"
#define CACHE_INFO_NAME @"cache_info"
#define LAZY_CACHE_PREFIX @"lazy_cache_"


static JTCache *GlobalCache = nil;

@implementation JTCache

+ (JTCache *)globalCache
{
    @synchronized(self)
    {
        if(!GlobalCache)
        {
            GlobalCache = [[super allocWithZone:nil] init];
        }
    }
    
    return GlobalCache;
}

+ (id)allocWithZone:(NSZone *)zone
{
    return [[JTCache globalCache] retain];
}

- (id)retain
{
    return self;
}

- (oneway void)release
{
    
}

- (unsigned)retainCount
{
    return UINT_MAX;
}

- (id)init
{
    if(self = [super init])
    {
        [self initCache];
        [self checkExpireCache];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(synchronize) name:UIApplicationDidEnterBackgroundNotification object:nil];
  
    }
    
    return self;
}

- (void)initCache
{
    NSString *cachePath = [NSString stringWithFormat:@"%@/Documents/%@/%@",NSHomeDirectory(),FOLDER_NAME,CACHE_NAME];
    NSString *cacheDirectoryPath = [NSString stringWithFormat:@"%@/Documents/%@",NSHomeDirectory(),FOLDER_NAME];
    NSString *cacheInfoPath = [NSString stringWithFormat:@"%@/%@",cacheDirectoryPath,CACHE_INFO_NAME];
    _cacheInfo = [[NSMutableDictionary dictionaryWithContentsOfFile:cacheInfoPath] retain];
    if(!_cacheInfo)
    {
        _cacheInfo = [[NSMutableDictionary alloc] init];
        [[NSFileManager defaultManager] createDirectoryAtPath:cacheDirectoryPath withIntermediateDirectories:YES attributes:nil error:nil];
        [_cacheInfo writeToFile:cacheInfoPath atomically:YES];
    }

    @try {
        _cacheValues = [[NSKeyedUnarchiver unarchiveObjectWithFile:cachePath] retain];
    }
    @catch (NSException *exception) {
        _cacheValues = nil;
    }
    
    if(!_cacheValues)
    {
        _cacheValues = [[NSMutableDictionary alloc] init];
        [NSKeyedArchiver archiveRootObject:_cacheValues toFile:cachePath];
    }
    
    _lazyCacheValues = [[NSMutableDictionary alloc] init];
}

- (void)checkExpireCache
{
    for(NSString *key in _cacheInfo.allKeys)
    {
        NSDate *createTime = _cacheInfo[key][@"createTime"];
        int expireDays = [_cacheInfo[key][@"expire"] intValue];
        
        if(expireDays >0)
        {
            NSDate *expireDate = [createTime dateByAddingTimeInterval:expireDays*3600];
            BOOL isExpired =  ([expireDate earlierDate:[NSDate date]] == expireDate);
            
            if(isExpired)
            {
                BOOL isLazy = [self isLazyCacheForName:key];
                if (isLazy) {
                    [self deleteLazyCache:key];
                }else {
                    [self deleteCache:key];
                }
            }
        }
    }
}

- (void)createCache:(NSString *)name type:(Class)classType syncType:(JTSyncType)syncType expire:(int)expireTime
{
    [self createCache:name type:classType syncType:syncType expire:expireTime lazy:NO];
}
 
- (void)createCache:(NSString *)name type:(Class)classType syncType:(JTSyncType)syncType expire:(int)expireTime lazy:(BOOL)lazyLoad
{
    if(!_cacheInfo[name])
    {
        BOOL isLazyLoad = lazyLoad;
        if (syncType == JTSyncTypePreference || syncType == JTSyncTypeKeychain || syncType == JTSyncTypeNone) {
            isLazyLoad = NO;
        }
        
        _cacheInfo[name] = [NSMutableDictionary dictionaryWithObjectsAndKeys:name,@"name",NSStringFromClass(classType),@"class",[NSNumber numberWithInt:syncType],@"sync",@(expireTime),@"expire",[NSDate date],@"createTime", @(isLazyLoad), @"lazy", nil];

        
        JTSyncType type = [_cacheInfo[name][@"sync"] intValue];
        if(type == JTSyncTypePreference)
        {
            if(classType == [NSNumber class])
            {
                [self setValue:@(0) forKey:name security:NO];
            }
            else
            {
                [self setValue:nil forKey:name security:NO];
            }
        }
        else if(type == JTSyncTypeKeychain)
        {
            [self setValue:nil forKey:name security:YES];
        }
        else
        {
            if (!isLazyLoad) {
                id value = nil;
                
                if(classType == [NSNumber class])
                {
                    value = @(0);
                }
                
                if(value) {
                    _cacheValues[name] = value;
                }
            }
        }
        
        [self synchronizeCacheInfo];
     }
}

- (BOOL)isLazyCacheForName:(NSString *)name {
    id lazyValue = _cacheInfo[name][@"lazy"];
    BOOL isLazy = (lazyValue != nil && [lazyValue isKindOfClass:[NSNumber class]] && [lazyValue boolValue] == YES);
    return isLazy;
}

- (id)loadLazyCacheValueForName:(NSString *)name {
    NSString *lazyCacheFileName = [NSString stringWithFormat:@"%@%@", LAZY_CACHE_PREFIX, name];
    NSString *cachePath = [NSString stringWithFormat:@"%@/Documents/%@/%@",NSHomeDirectory(),FOLDER_NAME,lazyCacheFileName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:cachePath]) {
        id cacheValue = nil;
        
        @try {
            cacheValue = [NSKeyedUnarchiver unarchiveObjectWithFile:cachePath];
        }
        @catch (NSException *exception) {
            cacheValue = nil;
        }
        
        return cacheValue;
    }else {
        return nil;
    }
}

- (void)saveLazyCacheValueForName:(NSString *)name value:(id)value {
    NSString *lazyCacheFileName = [NSString stringWithFormat:@"%@%@", LAZY_CACHE_PREFIX, name];
    NSString *cachePath = [NSString stringWithFormat:@"%@/Documents/%@/%@",NSHomeDirectory(),FOLDER_NAME,lazyCacheFileName];
    
    @try {
        [NSKeyedArchiver archiveRootObject:value toFile:cachePath];
    }
    @catch (NSException *exception) {
        
    }
}

- (id)value:(NSString *)name
{
    JTSyncType type = [_cacheInfo[name][@"sync"] intValue];
    if(type == JTSyncTypePreference)
    {
       return [self valueForKey:name security:NO];
    }
    else if(type == JTSyncTypeKeychain)
    {
       return [self valueForKey:name security:YES];
    }
    else
    {
        BOOL isLazyCache = [self isLazyCacheForName:name];
        if (isLazyCache) {
            id lazyCacheValue = _lazyCacheValues[name];
            if (lazyCacheValue && (NSNull *)lazyCacheValue != [NSNull null]) {
                return lazyCacheValue;
            }else {
                lazyCacheValue = [self loadLazyCacheValueForName:name];
                if (lazyCacheValue && (NSNull *)lazyCacheValue != [NSNull null]) {
                    _lazyCacheValues[name] = lazyCacheValue;
                }
                
                return lazyCacheValue;
            }
        }else {
            return  _cacheValues[name];
        }
    }
}

- (void)setValue:(id)value forName:(NSString *)name
{
    if(_cacheInfo[name])
    {
        [_cacheInfo[name] setValue:[NSDate date] forKey:@"createTime"];
       
        JTSyncType type = [_cacheInfo[name][@"sync"] intValue];
        
        if(type == JTSyncTypePreference)
        {
            [self setValue:value forKey:name security:NO];
        }
        else if(type == JTSyncTypeKeychain)
        {
             NSAssert([value isKindOfClass:[NSString class]], @"You can only save string value into keychain.");
            
            [self setValue:value forKey:name security:YES];
        }
        else 
        {
            BOOL isLazyLoad = [self isLazyCacheForName:name];
            if (isLazyLoad) {
                if (value && (NSNull *)value != [NSNull null]) {
                    _lazyCacheValues[name] = value;
                    [self saveLazyCacheValueForName:name value:value];
                }else {
                    [_lazyCacheValues removeObjectForKey:name];
                    [self deleteLazyCache:name];
                }
            }else {
                if(value){
                    _cacheValues[name] = value;
                }else{
                    [_cacheValues removeObjectForKey:name];
                }
            }
        }
 
    }
}

- (void)deleteCache:(NSString *)name
{
    if(_cacheInfo[name])
    {
        JTSyncType type = [_cacheInfo[name][@"sync"] intValue];
        [_cacheInfo removeObjectForKey:name];
        
        if(type == JTSyncTypePreference)
        {
            [self removeValueForKey:name security:NO];
        }
        else if(type == JTSyncTypeKeychain)
        {
            [self removeValueForKey:name security:YES];
        }
        else  
        {
            [_cacheValues removeObjectForKey:name];
        }
        
         [self synchronizeCacheInfo];
    }
}

- (void)deleteLazyCache:(NSString *)name {
    if (_lazyCacheValues[name]) {
        [_lazyCacheValues removeObjectForKey:name];
    }
    
    if (_cacheInfo[name]) {
        [_cacheInfo removeObjectForKey:name];
    }
    
    NSString *lazyCacheFileName = [NSString stringWithFormat:@"%@%@", LAZY_CACHE_PREFIX, name];
    NSString *cachePath = [NSString stringWithFormat:@"%@/Documents/%@/%@",NSHomeDirectory(),FOLDER_NAME,lazyCacheFileName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:cachePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:cachePath error:nil];
    }
    
    [self synchronizeCacheInfo];
}


- (BOOL)synchronize
{
    return [self synchronizeCacheInfo] && [self synchronizeCacheValue];
}

- (BOOL)synchronizeCacheInfo
{
    NSString *cacheDirectoryPath = [NSString stringWithFormat:@"%@/Documents/%@",NSHomeDirectory(),FOLDER_NAME];
    NSString *cacheInfoPath = [NSString stringWithFormat:@"%@/%@",cacheDirectoryPath,CACHE_INFO_NAME];
    
    NSMutableDictionary *toSynchronizeCacheInfo = [NSMutableDictionary dictionary];
    for(NSString *key in _cacheInfo.allKeys)
    {
        JTSyncType type = [_cacheInfo[key][@"sync"] intValue];
        if(type != JTSyncTypeNone)
        {
            toSynchronizeCacheInfo[key] = _cacheInfo[key];
        }
    }
    
    return [toSynchronizeCacheInfo writeToFile:cacheInfoPath atomically:YES];
}

- (BOOL)synchronizeCacheValue
{
    NSString *cachePath = [NSString stringWithFormat:@"%@/Documents/%@/%@",NSHomeDirectory(),FOLDER_NAME,CACHE_NAME];
    
    NSMutableDictionary *cacheDict = [[[NSMutableDictionary alloc] init] autorelease];
    for(NSString *key in _cacheInfo.allKeys)
    {
        JTSyncType type = [_cacheInfo[key][@"sync"] intValue];
        if(type == JTSyncTypeArchive && _cacheValues[key])
        {
            cacheDict[key] = _cacheValues[key];
        }
    }
    
    return [NSKeyedArchiver archiveRootObject:cacheDict toFile:cachePath];
}

- (void)setValue:(id)value forKey:(NSString *)key security:(BOOL)isSecure
{
    if(!isSecure)
    {
        [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    else
    {
        NSAssert([value isKindOfClass:[NSString class]] || !value, @"You can only save NSString value into Keychain.");
        NSString *bundleId = [NSBundle mainBundle].bundleIdentifier;
        [SFHFKeychainUtils storeUsername:key andPassword:value forServiceName:bundleId updateExisting:YES error:nil];
    }
}

- (id)valueForKey:(NSString *)key security:(BOOL)isSecure
{
    if(!isSecure)
    {
        return [[NSUserDefaults standardUserDefaults] objectForKey:key];
    }
    else
    {
        NSString *bundleId = [NSBundle mainBundle].bundleIdentifier;
        return  [SFHFKeychainUtils getPasswordForUsername:key andServiceName:bundleId error:nil];
    }
}

- (void)removeValueForKey:(NSString *)key security:(BOOL)isSecure
{
    if(!isSecure)
    {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    else
    {
        NSString *bundleId = [NSBundle mainBundle].bundleIdentifier;
        [SFHFKeychainUtils deleteItemForUsername:key andServiceName:bundleId error:nil];
    }
}


@end
