//
//  TransitProxyTests.m
//  TransitTestsIOS
//
//  Created by Heiko Behrens on 08.02.13.
//  Copyright (c) 2013 BeamApp. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "Transit.h"
#import "Transit+Private.h"
#import "OCMock.h"


@interface FakeNativeProxyForTest : TransitProxy

@end

@implementation FakeNativeProxyForTest

-(void)dispose {
    if(self.rootContext && self.proxyId) {
        [self.rootContext releaseNativeProxy:self];
    }
    [self clearRootContextAndProxyId];
}
@end

@interface TransitContextTests : SenTestCase

@end

@implementation TransitContextTests {
    NSUInteger _transitContextLivingInstanceCountBefore;
}

-(void)setUp {
    [super setUp];
    _transitContextLivingInstanceCountBefore = _TRANSIT_CONTEXT_LIVING_INSTANCE_COUNT;
}

-(void)tearDown {
    STAssertEquals(_transitContextLivingInstanceCountBefore, _TRANSIT_CONTEXT_LIVING_INSTANCE_COUNT, @"no garbage context created");
    [super tearDown];
}

-(void)testJsRepresentationForProxy {
    TransitContext *context = [TransitContext new];
    NSString* actual = [context jsRepresentationForProxyWithId:@"someId"];
    STAssertEqualObjects(@"transit.retained[\"someId\"]", actual, @"proxy representation");
}

-(TransitProxy*)stubWithContext:(TransitContext*)context proxyId:(NSString*)proxyId {
    id proxy = [OCMockObject mockForClass:TransitProxy.class];
    [[[proxy stub] andReturn:context] rootContext];
    [[[proxy stub] andReturn:proxyId] proxyId];
    return proxy;
}

-(void)testSingleNativeRetain {
    @autoreleasepool {
        TransitContext *context = TransitContext.new;
        TransitProxy *proxy = [self stubWithContext:context proxyId:@"someId"];
        
        STAssertEqualObjects(context.retainedNativeProxies, (@{}), @"nothing retained");
        [context retainNativeProxy:proxy];
        STAssertEqualObjects(context.retainedNativeProxies, (@{@"someId":proxy}), @"correctly retained");
        
        // manually reset retained objects to get rid of mocks.
        // See tests with FakeNativeProxyForTest to see that this isn't needed for real TransitProxies
        [context.retainedNativeProxies removeAllObjects];
    }
}

-(void)testMultipleNativeRetains {
    @autoreleasepool {
        TransitContext *context = TransitContext.new;
        TransitProxy *p1 = [self stubWithContext:context proxyId:@"id1"];
        TransitProxy *p2 = [self stubWithContext:context proxyId:@"id2"];
        [context retainNativeProxy:p1];
        [context retainNativeProxy:p2];
        STAssertEqualObjects(context.retainedNativeProxies, (@{@"id1":p1, @"id2":p2}), @"retains both");
        
        // manually reset retained objects to get rid of mocks.
        // See tests with FakeNativeProxyForTest to see that this isn't needed for real TransitProxies
        [context.retainedNativeProxies removeAllObjects];
    }
}

-(void)testMutipleNativeRetainsForSameObjectWithoutEffect {
    @autoreleasepool {
        TransitContext *context = TransitContext.new;
        TransitProxy *proxy = [self stubWithContext:context proxyId:@"someId"];
        
        [context retainNativeProxy:proxy];
        STAssertEquals((NSUInteger)1, context.retainedNativeProxies.count, @"retains one object");
        [context retainNativeProxy:proxy];
        STAssertEquals((NSUInteger)1, context.retainedNativeProxies.count, @"still retains object");
        
        // manually reset retained objects to get rid of mocks.
        // See tests with FakeNativeProxyForTest to see that this isn't needed for real TransitProxies
        [context.retainedNativeProxies removeAllObjects];
    }
}

-(void)testNativeRetainRelease {
    @autoreleasepool {
        TransitContext *context = TransitContext.new;
        TransitProxy *proxy = [self stubWithContext:context proxyId:@"someId"];
        
        STAssertEqualObjects(context.retainedNativeProxies, (@{}), @"nothing retained");
        [context retainNativeProxy:proxy];
        STAssertEqualObjects(context.retainedNativeProxies, (@{@"someId":proxy}), @"correctly retained");
        [context releaseNativeProxy:proxy];
        STAssertEqualObjects(context.retainedNativeProxies, (@{}), @"nothing retained anymore");
    }
}

-(void)testCannotReleaseNonRetained {
    @autoreleasepool {
        TransitContext *context = TransitContext.new;
        TransitProxy *proxy =  [self stubWithContext:context proxyId:@"someId"];
        
        STAssertEqualObjects(context.retainedNativeProxies, (@{}), @"nothing retained");
        [context releaseNativeProxy:proxy];
        STAssertEqualObjects(context.retainedNativeProxies, (@{}), @"still, nothing retained");
    }
}

-(void)testDisposesNativeProxiesOnDispose {
    @autoreleasepool {
        TransitContext *context = TransitContext.new;
        TransitProxy *proxy = [self stubWithContext:context proxyId:@"someId"];
        
        [[(OCMockObject*)proxy expect] dispose];
        [context retainNativeProxy:proxy];
        [context dispose];
        [(OCMockObject*)proxy verify];
        
        // manually reset retained objects to get rid of mocks.
        // See tests with FakeNativeProxyForTest to see that this isn't needed for real TransitProxies
        [context.retainedNativeProxies removeAllObjects];
    }
}

-(TransitProxy*)createAndReleaseContextButReturnNativeProxy {
    TransitProxy *proxy;

    @autoreleasepool {
        TransitContext* context = TransitContext.new;
        STAssertEquals(1L, CFGetRetainCount((__bridge CFTypeRef)context), @"single ref");
        proxy = [[FakeNativeProxyForTest alloc]initWithRootContext:context proxyId:@"someId"];
        STAssertEquals(1L, CFGetRetainCount((__bridge CFTypeRef)context), @"still, single ref to context");
        STAssertEquals(1L, CFGetRetainCount((__bridge CFTypeRef)proxy), @"var keeps ref to proxy");
        
        [context retainNativeProxy:proxy];
    }
    STAssertEquals(1L, CFGetRetainCount((__bridge CFTypeRef)proxy), @"var keeps ref to proxy");
    
    return proxy;
}

-(void)testNoRetainCyclesAndDisposesNativeProxies {
    __weak TransitProxy* proxy;
    @autoreleasepool {
        proxy = [self createAndReleaseContextButReturnNativeProxy];
        
        STAssertTrue(proxy.disposed, @"proxy has been disposed");
        STAssertNil(proxy.rootContext, @"hence, does not keep reference to context anymore");
    }
    STAssertNil(proxy, @"proxy is free");
}

-(void)testDoNotReplaceSimpleObjectsWithMarkers {
    TransitContext* context = TransitContext.new;
    STAssertEqualObjects(@42, [context recursivelyReplaceMarkersWithProxies:@42], @"do nothing on numbers");
    STAssertEqualObjects(@"foobar", [context recursivelyReplaceMarkersWithProxies:@"foobar"], @"do nothing on simple string");
}

-(void)testReplaceMarkerStrings {
    TransitContext* context = TransitContext.new;
    
    NSString* marker = [NSString stringWithFormat:@"%@%@", _TRANSIT_MARKER_PREFIX_OBJECT_PROXY_, @"someId"];
    id proxy = [context recursivelyReplaceMarkersWithProxies:marker];
    STAssertTrue([proxy isKindOfClass:TransitProxy.class], @"object proxy");
    STAssertFalse([proxy isKindOfClass:TransitJSFunction.class], @"function proxy");
    STAssertEqualObjects(@"someId", [proxy proxyId], @"extracts proxy id");

    marker = [NSString stringWithFormat:@"%@%@", _TRANSIT_MARKER_PREFIX_JS_FUNCTION_, @"someId"];
    proxy = [context recursivelyReplaceMarkersWithProxies:marker];
    STAssertTrue([proxy isKindOfClass:TransitProxy.class], @"object proxy");
    STAssertTrue([proxy isKindOfClass:TransitJSFunction.class], @"function proxy");
    STAssertEqualObjects(@"someId", [proxy proxyId], @"extracts proxy id");
}

-(void)testDetectsMarkerStringsInComplexObject {
    TransitContext* context = TransitContext.new;
    
    NSString* marker = [NSString stringWithFormat:@"%@%@", _TRANSIT_MARKER_PREFIX_JS_FUNCTION_, @"someId"];
    id detected = [context recursivelyReplaceMarkersWithProxies:@[@1, @"two", @{@"three":@3, @4: marker}]];
    STAssertEqualObjects(@1, detected[0], @"one");
    STAssertEqualObjects(@"two", detected[1], @"two");
    STAssertEqualObjects(@3, detected[2][@"three"], @"three");
    id proxy = detected[2][@4];
    STAssertTrue([proxy isKindOfClass:TransitJSFunction.class], @"function proxy");
    STAssertEqualObjects(@"someId", [proxy proxyId], @"extracts proxy id");
}

-(void)testInvokeNativeWithMissingFunction {
    TransitContext* context = TransitContext.new;
    id result = [context invokeNativeDescription:@{@"nativeId":@"missing"}];
    STAssertTrue([result isKindOfClass:NSError.class], @"missing native functions results in error");
}

-(void)testInvokeNativeWithThisArgVariations {
    @autoreleasepool {
        TransitContext* context = TransitContext.new;
        TransitFunction *func = [[TransitNativeFunction alloc] initWithRootContext:context nativeId:@"someId" block:^id(TransitProxy *thisArg, NSArray *arguments) {
            
            return thisArg;
        }];
        
        // js: this == undefined
        id result = [func callWithThisArg:nil arguments:@[]];
        STAssertTrue(result == context, @"undefined");
        
        // js: this == null
        result = [func callWithThisArg:nil arguments:@[]];
        STAssertTrue(result == context, @"null");
        
        // js: this == "3", e.g. transit.nativeFunc("someId").apply("3");
        result = [func callWithThisArg:@"3" arguments:@[]];
        STAssertTrue([result isKindOfClass:TransitProxy.class], @"is proxy");
        STAssertEqualObjects(@"3", [(TransitProxy*)result value], @"wraps '3'");
    }
}


@end
