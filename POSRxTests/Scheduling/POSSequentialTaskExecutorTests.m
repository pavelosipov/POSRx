//
//  POSSequentialTaskExecutorTests.m
//  POSRx
//
//  Created by Osipov on 12/05/16.
//  Copyright © 2016 Pavel Osipov. All rights reserved.
//

#import <POSRx/POSRx.h>
#import <POSAllocationTracker/POSAllocationTracker.h>
#import <XCTest/XCTest.h>

@interface POSSequentialTaskExecutorTests : XCTestCase
@property (nonatomic, weak) NSMutableArray<POSTask *> *executorQueue;
@property (nonatomic) POSSequentialTaskExecutor *executor;
@end

@implementation POSSequentialTaskExecutorTests

- (void)setUp {
    [super setUp];
    NSMutableArray<POSTask *> *executorQueue = [NSMutableArray<POSTask *> new];
    self.executor = [[POSSequentialTaskExecutor alloc]
                     initWithScheduler:RACTargetQueueScheduler.pos_mainThreadScheduler
                     taskQueue:[[POSTaskQueueAdapter<NSMutableArray<POSTask *> *> alloc]
                                initWithScheduler:RACTargetQueueScheduler.pos_mainThreadScheduler
                                container:executorQueue
                                dequeueTopTaskBlock:^POSTask *(NSMutableArray<POSTask *> *queue) {
                                    POSTask *task = queue.lastObject;
                                    [queue removeLastObject];
                                    return task;
                                } dequeueTaskBlock:^(NSMutableArray<POSTask *> *queue, POSTask *task) {
                                    [queue removeObject:task];
                                } enqueueTaskBlock:^(NSMutableArray<POSTask *> *queue, POSTask *task) {
                                    [queue addObject:task];
                                }]];
    self.executorQueue = executorQueue;
}

- (void)tearDown {
    self.executor = nil;
    [self checkMemoryLeaks];
    [super tearDown];
}

- (void)checkMemoryLeaks {
    XCTAssert([POSAllocationTracker instanceCountForClass:POSSequentialTaskExecutor.class] == 0);
    XCTAssert([POSAllocationTracker instanceCountForClass:POSTask.class] == 0);
    XCTAssert([POSAllocationTracker instanceCountForClass:RACSignal.class] == 0);
    XCTAssert([POSAllocationTracker instanceCountForClass:RACDisposable.class] == 0);
}

- (void)testMemoryLeaksAbsenceWhenExecutingInfiniteTask {
    XCTestExpectation *expectation = [self expectationWithDescription:@"e"];
    [_executor submitTask:[POSTask createTask:^RACSignal *(id task) {
        return [RACSignal never];
    }]];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.executor = nil;
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testExecutorSubmitSignalShouldEmitTaskExecutionValues {
    XCTestExpectation *expectation = [self expectationWithDescription:@"e"];
    POSTask *task = [POSTask createTask:^RACSignal *(id task) {
        return [RACSignal return:@7];
    }];
    __block NSNumber *taskResult = nil;
    [[_executor submitTask:task] subscribeNext:^(id value) {
        taskResult = value;
    } completed:^{
        XCTAssertEqualObjects(taskResult, @7);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testExecutorSubmitSignalShouldEmitTaskExecutionErrors {
    XCTestExpectation *expectation = [self expectationWithDescription:@"e"];
    POSTask *task = [POSTask createTask:^RACSignal *(id task) {
        return [RACSignal error:[NSError errorWithDomain:@"ru.mail.cloud.test" code:123 userInfo:nil]];
    }];
    [[_executor submitTask:task] subscribeError:^(NSError *error) {
        XCTAssertEqualObjects(error.domain, @"ru.mail.cloud.test");
        XCTAssertTrue(error.code == 123);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testExecutorSubmitMethodShouldExecuteTaskWithoutSubscriptions {
    XCTestExpectation *expectation = [self expectationWithDescription:@"e"];
    POSTask *task = [POSTask createTask:^RACSignal *(id task) {
        return [RACSignal return:@7];
    }];
    [task.values subscribeNext:^(id value) {
        XCTAssertEqualObjects(value, @7);
        [expectation fulfill];
    }];
    [_executor submitTask:task];
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testExecutorShouldExecuteLimitedNumberOfTasks {
    XCTestExpectation *expectation = [self expectationWithDescription:@"e"];
    NSInteger maxConcurrentTaskCount = 2;
    _executor.maxConcurrentTaskCount = maxConcurrentTaskCount;
    __block NSInteger taskCount = 20;
    __block NSInteger executionCount = 0;
    __block NSInteger completionCount = 0;
    for (int i = 0; i < taskCount; ++i) {
        [[_executor submitTask:[POSTask createTask:^RACSignal *(id task) {
            ++executionCount;
            XCTAssertTrue(executionCount <= maxConcurrentTaskCount - 1);
            return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
                return [RACScheduler.mainThreadScheduler schedule:^{
                    [subscriber sendCompleted];
                }];
            }];
        }]] subscribeCompleted:^{
            --executionCount;
            ++completionCount;
            if (completionCount == taskCount) {
                [expectation fulfill];
            }
        }];
    }
    [_executor submitTask:[POSTask createTask:^RACSignal *(id task) {
        return [RACSignal never];
    }]];
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testExecutorShouldScheduleTaskExecutionAfterLimitIncrement {
    XCTestExpectation *expectation = [self expectationWithDescription:@"e"];
    _executor.maxConcurrentTaskCount = 0;
    [[_executor submitTask:[POSTask createTask:^RACSignal *(id task) {
        return [RACSignal empty];
    }]] subscribeCompleted:^{
        [expectation fulfill];
    }];
    [_executor schedule:^{
        self.executor.maxConcurrentTaskCount = 1;
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testExecutorShouldReclaimTaskWhenSubmitionBlockIsDisposing {
    XCTestExpectation *expectation = [self expectationWithDescription:@"e"];
    @weakify(expectation);
    RACDisposable *disposable = [[_executor submitTask:[POSTask createTask:^RACSignal *(id task) {
        return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
            return [RACDisposable disposableWithBlock:^{
                @strongify(expectation);
                [expectation fulfill];
            }];
        }];
    }]] subscribeCompleted:^{
        XCTAssertTrue(!@"Task should not be executed.");
    }];
    RACScheduler *scheduler = _executor.scheduler;
    [scheduler schedule:^{ // skip executor processing tasks runloop iteration.
        [scheduler schedule:^{ // skip task subscription runloop iteration.
            [disposable dispose];
        }];
    }];
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void)testExecutorShouldDequeueReclaimedTasks {
    RACDisposable *disposable = [[_executor submitTask:[POSTask createTask:^RACSignal *(id task) {
        return [RACSignal never];
    }]] subscribeCompleted:^{
        XCTAssertTrue(!@"Task should not be executed.");
    }];
    XCTAssertTrue(_executorQueue.count == 1);
    [disposable dispose];
    XCTAssertTrue(_executorQueue.count == 0);
    XCTestExpectation *expectation = [self expectationWithDescription:@"e"];
    [_executor schedule:^{
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void)testExecutorShouldNotExecuteOneTaskMultipleTimes {
    XCTestExpectation *expectation = [self expectationWithDescription:@"e"];
    const NSInteger submisionCount = 10;
    __block NSInteger executeCount = 0;
    POSTask *task = [POSTask createTask:^RACSignal *(id task) {
        ++executeCount;
        return [RACSignal never];
    }];
    _executor.maxConcurrentTaskCount = submisionCount;
    for (int i = 0; i < submisionCount; ++i) {
        [_executor submitTask:task];
    }
    [_executor.scheduler schedule:^{ // skip executor processing tasks runloop iteration.
        XCTAssertTrue(executeCount == 1);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

@end