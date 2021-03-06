//
//  POSSequentialTaskExecutor.h
//  POSRx
//
//  Created by Pavel Osipov on 10/05/16.
//  Copyright © 2016 Pavel Osipov. All rights reserved.
//

#import "POSTask.h"
#import "POSTaskQueue.h"

NS_ASSUME_NONNULL_BEGIN

///
/// Special executor which executes only limited number of tasks concurrently.
///
@interface POSSequentialTaskExecutor<TaskType> : POSBlockExecutor <POSTaskExecutor>

/// @brief      Maximum number of tasks which can be executed simultaneously.
/// @discussion The default value is 1.
@property (nonatomic) NSInteger maxExecutingTasksCount;

/// @brief      Current number of executing tasks.
/// @discussion That property is a performant alias for executingTasks.count
@property (nonatomic, readonly) NSUInteger executingTasksCount;

/// RACSignal of NSNumber which informs about updates of executingTasksCount property.
@property (nonatomic, readonly) RACSignal *executingTasksCountSignal;

/// Array of currently executing tasks.
@property (nonatomic, readonly, copy) NSArray<TaskType> *executingTasks;

/// Tries to execute pending tasks from taskQueue.
- (void)executePendingTasks;

- (instancetype)initWithScheduler:(RACTargetQueueScheduler *)scheduler
                        taskQueue:(id<POSTaskQueue>)taskQueue;

- (instancetype)initWithUnderlyingExecutor:(id<POSTaskExecutor>)executor
                                 taskQueue:(id<POSTaskQueue>)taskQueue;

@end

NS_ASSUME_NONNULL_END
