//
//  SKStateChart.m
//  Pods
//
//  Created by Shaheen Ghiassy on 1/19/15.
//
//

#import "SKStateChart.h"
#import "SKState.h"


@interface SKStateChart ()

@property (nonatomic, copy) NSDictionary *stateChart;

@property (nonatomic, strong) SKState *rootState;
@property (nonatomic, strong) SKState *currentState;

@end


static NSString *kDefaultRootStateName = @"root";
static NSString *kSubStringKey = @"subStates";


@implementation SKStateChart

#pragma mark - Object Lifecycle

- (instancetype)initWithStateChart:(NSDictionary *)stateChart {
    self = [super init];

    if (self) {
        NSDictionary *rootTree = [stateChart objectForKey:kDefaultRootStateName];
        NSAssert(rootTree != nil, @"The stateChart you input does not have a root state");
        _rootState = [self initializeDictionaryAsATree:rootTree withStateName:kDefaultRootStateName andParentState:nil];

        [self didEnterState:_rootState];
    }

    return self;
}

- (SKState *)initializeDictionaryAsATree:(NSDictionary *)stateTree withStateName:(NSString *)name andParentState:(SKState *)parentState {
//    stateTree = stateTree.mutableCopy; // Cast the dictionary to a mutable copy
    SKState *state = [[SKState alloc] init];
    state.name = name;
    state.parentState = parentState;

    for (id key in stateTree) {
        id value = [stateTree valueForKey:key];

        if ([key isEqualToString:kSubStringKey]) {
            NSDictionary *subStates = (NSDictionary *)value;

            for (id stateKey in subStates) {
                NSDictionary *subTree = [subStates objectForKey:stateKey];
                SKState *subState = [self initializeDictionaryAsATree:subTree withStateName:stateKey andParentState:state];
                [state setSubState:subState];
            }
        } else {
            [state setEvent:key forBlock:value];
        }
    }

    NSString *description = state.description;

    NSLog(@"%@", description);
    return state;
}

#pragma mark - Messages

- (void)sendMessage:(NSString *)message {
    SKState *statePointer = self.currentState;
    MessageBlock messageBlock = [statePointer blockForMessage:message];

    while (statePointer != nil && messageBlock == nil) {
        statePointer = statePointer.parentState;
        messageBlock = [statePointer blockForMessage:message];
    }

    if (messageBlock) {
        messageBlock(self);
    }
}

- (void)goToState:(NSString *)goToState {
    NSDictionary *subStates = [self.currentState getSubStates];
    SKState *newState = [subStates objectForKey:goToState];

    if (newState != nil) {
        [self didExitState:self.currentState];
        self.currentState = newState;
        [self didEnterState:self.currentState];
    }
}

#pragma mark - State Event Methods

- (void)didEnterState:(SKState *)state {
    MessageBlock enterBlock = [state blockForMessage:@"enterState"];

    if (enterBlock) {
        enterBlock(self);
    }

    _currentState = state;
}

- (void)didExitState:(SKState *)state {
    MessageBlock exitBlock = [state blockForMessage:@"exitState"];

    if (exitBlock) {
        exitBlock(self);
    }
}

#pragma mark - Getters

- (NSString *)currentStateName {
    return [self.currentState.name copy];
}

@end
