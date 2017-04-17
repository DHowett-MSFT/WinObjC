//******************************************************************************
//
// Copyright (c) Microsoft. All rights reserved.
//
// This code is licensed under the MIT License (MIT).
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//******************************************************************************

#import "_NSAutoContentAccessingProxy.h"

#import <Foundation/NSObject.h>
#import <Foundation/NSInvocation.h>

@interface _NSAutoContentAccessingProxy () {
    NSObject<NSDiscardableContent>* _object;
}
@end

@implementation _NSAutoContentAccessingProxy
+ (instancetype)proxyForObject:(NSObject<NSDiscardableContent>*)object {
    return [[[self alloc] initWithDiscardableObject:object] autorelease];
}

- (instancetype)initWithDiscardableObject:(NSObject<NSDiscardableContent>*)object {
    // NSProxy subclasses must not call [super init].
    _object = [object retain];
    [object beginContentAccess];
    return self;
}

- (void)dealloc {
    [_object endContentAccess];
    [_object release];
    [super dealloc];
}

- (NSMethodSignature*)methodSignatureForSelector:(SEL)selector {
    return [_object methodSignatureForSelector:selector];
}

- (void)forwardInvocation:(NSInvocation*)invocation {
    [invocation setTarget:_object];
    [invocation invoke];
}
@end