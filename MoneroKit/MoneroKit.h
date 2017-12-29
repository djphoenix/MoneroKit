//
//  MoneroKit.h
//  MoneroKit
//
//  Created by Yury Popov on 07.12.2017.
//  Copyright © 2017 PhoeniX. All rights reserved.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Miner delegate provides callbacks for most important mining events
 */
@protocol MoneroMinerDelegate
/**
 * @brief Callback for result acceptance by pool
 * @param result   Result difficulty
 * @param workerId Worker identifier
 */
- (void)acceptedResult:(NSUInteger)result forWorker:(NSString*)workerId;
/**
 * @brief Callback for mining difficulty change by pool
 * @param difficulty New mining difficulty
 * @param workerId   Worker identifier
 */
- (void)difficultyChanged:(NSUInteger)difficulty forWorker:(NSString*)workerId;
/**
 * @brief Callback for new found block by pool
 * @param workerId Worker identifier
 */
- (void)blockFoundForWorker:(NSString*)workerId;
/**
 * @brief Callback for mining errors
 * @param error   Error object
 * @param stopped Flag that indicates that mining have been stopped
 */
- (void)miningError:(NSError*)error stopped:(BOOL)stopped;
@end

/**
 * @brief Worker descriptor
 */
@interface MoneroWorker : NSObject
- (instancetype)init NS_UNAVAILABLE;
/**
 * @brief Instantiate a new worker descriptor
 * @param identifier Worker identifier for use in callbacks
 * @param host       Mining pool hostname
 * @param port       Mining pool port
 * @param secure     Flag that indicates that pool uses SSL for connection
 * @param nicehash   Flag that indicates that pool uses Nicehash algorithm
 * @param wallet     Wallet address for pool payouts, or username
 * @param password   Password to use for authentication in mining pool
 * @param weight     Weight of worker for load-balancing
 */
+ (instancetype)workerWithIdentifier:(NSString*)identifier poolHost:(NSString*)host port:(uint16_t)port secure:(BOOL)secure nicehash:(BOOL)nicehash walletAddress:(NSString*)wallet password:(NSString*)password weight:(double)weight __SWIFT_UNAVAILABLE;
/**
 * @brief Instantiate a new worker descriptor
 * @param identifier Worker identifier for use in callbacks
 * @param host       Mining pool hostname
 * @param port       Mining pool port
 * @param secure     Flag that indicates that pool uses SSL for connection
 * @param nicehash   Flag that indicates that pool uses Nicehash algorithm
 * @param wallet     Wallet address for pool payouts, or username
 * @param password   Password to use for authentication in mining pool
 */
+ (instancetype)workerWithIdentifier:(NSString*)identifier poolHost:(NSString*)host port:(uint16_t)port secure:(BOOL)secure nicehash:(BOOL)nicehash walletAddress:(NSString*)wallet password:(NSString*)password __SWIFT_UNAVAILABLE;
/**
 * @brief Instantiate a new worker descriptor
 * @param identifier Worker identifier for use in callbacks
 * @param host       Mining pool hostname
 * @param port       Mining pool port
 * @param secure     Flag that indicates that pool uses SSL for connection
 * @param nicehash   Flag that indicates that pool uses Nicehash algorithm
 * @param wallet     Wallet address for pool payouts, or username
 */
+ (instancetype)workerWithIdentifier:(NSString*)identifier poolHost:(NSString*)host port:(uint16_t)port secure:(BOOL)secure nicehash:(BOOL)nicehash walletAddress:(NSString*)wallet __SWIFT_UNAVAILABLE;
/**
 * @brief Instantiate a new worker descriptor
 * @param identifier Worker identifier for use in callbacks
 * @param host       Mining pool hostname
 * @param port       Mining pool port
 * @param secure     Flag that indicates that pool uses SSL for connection
 * @param wallet     Wallet address for pool payouts, or username
 * @param password   Password to use for authentication in mining pool
 * @param weight     Weight of worker for load-balancing
 */
+ (instancetype)workerWithIdentifier:(NSString*)identifier poolHost:(NSString*)host port:(uint16_t)port secure:(BOOL)secure walletAddress:(NSString*)wallet password:(NSString*)password weight:(double)weight __SWIFT_UNAVAILABLE;
/**
 * @brief Instantiate a new worker descriptor
 * @param identifier Worker identifier for use in callbacks
 * @param host       Mining pool hostname
 * @param port       Mining pool port
 * @param secure     Flag that indicates that pool uses SSL for connection
 * @param wallet     Wallet address for pool payouts, or username
 * @param password   Password to use for authentication in mining pool
 */
+ (instancetype)workerWithIdentifier:(NSString*)identifier poolHost:(NSString*)host port:(uint16_t)port secure:(BOOL)secure walletAddress:(NSString*)wallet password:(NSString*)password __SWIFT_UNAVAILABLE;
/**
 * @brief Instantiate a new worker descriptor
 * @param identifier Worker identifier for use in callbacks
 * @param host       Mining pool hostname
 * @param port       Mining pool port
 * @param secure     Flag that indicates that pool uses SSL for connection
 * @param wallet     Wallet address for pool payouts, or username
 */
+ (instancetype)workerWithIdentifier:(NSString*)identifier poolHost:(NSString*)host port:(uint16_t)port secure:(BOOL)secure walletAddress:(NSString*)wallet __SWIFT_UNAVAILABLE;
/**
 * @brief Initializes a worker descriptor
 * @param identifier Worker identifier for use in callbacks
 * @param host       Mining pool hostname
 * @param port       Mining pool port
 * @param secure     Flag that indicates that pool uses SSL for connection
 * @param nicehash   Flag that indicates that pool uses Nicehash algorithm
 * @param wallet     Wallet address for pool payouts, or username
 * @param password   Password to use for authentication in mining pool
 * @param weight     Weight of worker for load-balancing
 */
- (instancetype)initWithIdentifier:(NSString*)identifier poolHost:(NSString*)host port:(uint16_t)port secure:(BOOL)secure nicehash:(BOOL)nicehash walletAddress:(NSString*)wallet password:(NSString*)password weight:(double)weight;
/**
 * @brief Initializes a worker descriptor
 * @param identifier Worker identifier for use in callbacks
 * @param host       Mining pool hostname
 * @param port       Mining pool port
 * @param secure     Flag that indicates that pool uses SSL for connection
 * @param nicehash   Flag that indicates that pool uses Nicehash algorithm
 * @param wallet     Wallet address for pool payouts, or username
 * @param password   Password to use for authentication in mining pool
 */
- (instancetype)initWithIdentifier:(NSString*)identifier poolHost:(NSString*)host port:(uint16_t)port secure:(BOOL)secure nicehash:(BOOL)nicehash walletAddress:(NSString*)wallet password:(NSString*)password;
/**
 * @brief Initializes a worker descriptor
 * @param identifier Worker identifier for use in callbacks
 * @param host       Mining pool hostname
 * @param port       Mining pool port
 * @param secure     Flag that indicates that pool uses SSL for connection
 * @param nicehash   Flag that indicates that pool uses Nicehash algorithm
 * @param wallet     Wallet address for pool payouts, or username
 */
- (instancetype)initWithIdentifier:(NSString*)identifier poolHost:(NSString*)host port:(uint16_t)port secure:(BOOL)secure nicehash:(BOOL)nicehash walletAddress:(NSString*)wallet;
/**
 * @brief Initializes a worker descriptor
 * @param identifier Worker identifier for use in callbacks
 * @param host       Mining pool hostname
 * @param port       Mining pool port
 * @param secure     Flag that indicates that pool uses SSL for connection
 * @param wallet     Wallet address for pool payouts, or username
 * @param password   Password to use for authentication in mining pool
 * @param weight     Weight of worker for load-balancing
 */
- (instancetype)initWithIdentifier:(NSString*)identifier poolHost:(NSString*)host port:(uint16_t)port secure:(BOOL)secure walletAddress:(NSString*)wallet password:(NSString*)password weight:(double)weight;
/**
 * @brief Initializes a worker descriptor
 * @param identifier Worker identifier for use in callbacks
 * @param host       Mining pool hostname
 * @param port       Mining pool port
 * @param secure     Flag that indicates that pool uses SSL for connection
 * @param wallet     Wallet address for pool payouts, or username
 * @param password   Password to use for authentication in mining pool
 */
- (instancetype)initWithIdentifier:(NSString*)identifier poolHost:(NSString*)host port:(uint16_t)port secure:(BOOL)secure walletAddress:(NSString*)wallet password:(NSString*)password;
/**
 * @brief Initializes a worker descriptor
 * @param identifier Worker identifier for use in callbacks
 * @param host       Mining pool hostname
 * @param port       Mining pool port
 * @param secure     Flag that indicates that pool uses SSL for connection
 * @param wallet     Wallet address for pool payouts, or username
 */
- (instancetype)initWithIdentifier:(NSString*)identifier poolHost:(NSString*)host port:(uint16_t)port secure:(BOOL)secure walletAddress:(NSString*)wallet;
/**
 * @brief Worker identifier for use in callbacks
 */
@property (atomic, copy) NSString *identifier;
/**
 * @brief Mining pool hostname
 */
@property (atomic, copy) NSString *poolHost;
/**
 * @brief Mining pool port
 */
@property (atomic) uint16_t poolPort;
/**
 * @brief Flag that indicates that pool uses SSL for connection
 */
@property (atomic) BOOL poolSecure;
/**
 * @brief Flag that indicates that pool uses Nicehash algorithm
 */
@property (atomic) BOOL nicehash;
/**
 * @brief Wallet address for pool payouts, or username
 */
@property (atomic, copy) NSString *walletAddress;
/**
 * @brief Password to use for authentication in mining pool
 */
@property (atomic, copy) NSString *password;
/**
 * @brief Weight of worker for load-balancing
 */
@property (atomic) double weight;
@end

/**
 * @brief Monero mining coordinator
 */
@interface MoneroMiner : NSObject
/**
 * @brief Extract base address from full address that includes additional parameters
 * @param walletAddress Full address that includes additional parameters (e.g. worker identifier and/or difficulty set)
 * @return Base wallet address
 */
+ (NSString*)baseAddress:(NSString*)walletAddress;
/**
 * @brief Mining events delegate
 */
@property (nullable, weak, nonatomic) id<MoneroMinerDelegate> delegate;
/**
 * @brief Mining workers
 * @discussion If more than one specified, uses load-balancing based on worker weights
 */
@property (nonatomic, copy) NSArray<MoneroWorker*> *workers;
/**
 * @brief CPU usage limit (0 ... 1)
 * @discussion Set to 0 to disable CPU mining, set to 1 to maximum CPU mining efficiency
 */
@property (nonatomic, setter=setCPULimit:) double cpuLimit;
/**
 * @brief Metal usage limit (0 ... 1)
 * @discussion Set to 0 to disable Metal mining, set to 1 to maximum Metal mining efficiency
 */
@property (nonatomic) double metalLimit;
/**
 * @brief Indicates that mining is currently active
 */
@property (nonatomic, readonly) BOOL active;
/**
 * @brief Reports current hash rate (hash / second)
 */
@property (nonatomic, readonly) double hashRate;
/**
 * @brief Start mining process
 */
- (void)startMining;
/**
 * @brief Stop mining process
 */
- (void)stopMining;
@end

NS_ASSUME_NONNULL_END
