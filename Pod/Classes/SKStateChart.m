//
//  SKStateChart.m
//  Pods
//
//  Created by Shaheen Ghiassy on 1/19/15.
//
//

#import "SKStateChart.h"
#import "NSMutableArray+Queue.h"
#import "SKTypeDefs.h"


@interface SKStateChart ()

@property (nonatomic, strong) SKState *rootState;
@property (nonatomic, strong, readwrite) SKState *currentState;

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
        [self transitionCurrentStateToSubState:_rootState];
    }

    return self;
}

- (SKState *)initializeDictionaryAsATree:(NSDictionary *)stateTree withStateName:(NSString *)name andParentState:(SKState *)parentState {
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
    // Find node using BFS search
    SKState *toState = [self breadthFirstSearchOfState:goToState fromState:self.rootState];

    // Before proceding make sure that we actual found a state of that name
    if (toState == nil) {
        return;
    }

    // Build path from node to parent for goToState
    NSArray *pathToRoot = [self pathToRootFromState:toState];

    // Now traverse up to root from current state
    // If the traversed node equals one in the path build previously - exit
    BOOL commonParentFound = [pathToRoot containsObject:self.currentState.name];

    while (!commonParentFound) {
        [self popCurrentStateToParentState];
        commonParentFound = [pathToRoot containsObject:self.currentState.name];
    }

    // Once we have traversed to the common anscetor - we now go doing until we reach the goToState
    NSInteger index = [pathToRoot indexOfObject:self.currentState.name];
    for (NSInteger i = index - 1; i >= 0; i--) {
        NSString *nextState = [pathToRoot objectAtIndex:i];
        SKState *subState = [self.currentState subState:nextState];
        NSAssert(subState != nil, @"Child state not found from givenState");
        [self transitionCurrentStateToSubState:subState];
    }
}

- (NSArray *)pathToRootFromState:(SKState *)startState {
    NSMutableArray *pathToRoot = [[NSMutableArray alloc] init];
    SKState *curPointer = startState;

    while (curPointer != nil) {
        [pathToRoot addObject:curPointer.name];
        curPointer = curPointer.parentState;
    }

    return [[NSArray alloc] initWithArray:pathToRoot];
}

- (SKState *)breadthFirstSearchOfState:(NSString *)goToState fromState:(SKState *)root {
    NSMutableArray *queue = [[NSMutableArray alloc] init];
    SKState *curPointer = root;
    SKState *foundState = nil;

    if (curPointer != nil) {
        [queue enqueue:curPointer];

        while (queue.count != 0 && foundState == nil) {
            curPointer = [queue dequeue];

            if ([curPointer.name isEqualToString:goToState]) {
                foundState = curPointer;
                break;
            }

            NSDictionary *subStates = [curPointer getSubStates];
            for (id key in subStates) {
                SKState *subState = [subStates objectForKey:key];
                [queue enqueue:subState];
            }
        }
    }

    return foundState;
}

#pragma mark - State Transition Methods

- (void)transitionCurrentStateToSubState:(SKState *)subState {
    _currentState = subState;

    MessageBlock enterBlock = [subState blockForMessage:@"enterState"];

    if (enterBlock) {
        enterBlock(self);
    }
}

- (void)popCurrentStateToParentState {
    MessageBlock exitBlock = [_currentState blockForMessage:@"exitState"]; // Must grab exit block before changing state

    _currentState = _currentState.parentState;

    if (exitBlock) {
        exitBlock(self);
    }
}

@end
