//
//  ViewController.m
//  MoneroKitSample-iOS
//
//  Created by Yury Popov on 10.01.2018.
//

@import UIKit;

@import MoneroKit;

@interface ViewController : UIViewController <MoneroMinerDelegate>
@property (atomic, strong) MoneroMiner *miner;
@property (atomic, strong) NSTimer *hashrateTimer;
@property (atomic, strong) NSDateFormatter *dateFormatter;

@property (nonatomic, weak) IBOutlet UILabel *hashRateLabel;
@property (nonatomic, weak) IBOutlet UILabel *difficultyLabel;
@property (nonatomic, weak) IBOutlet UILabel *lastBlockLabel;
@property (nonatomic, weak) IBOutlet UILabel *lastResultLabel;
@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  
  self.dateFormatter = [NSDateFormatter new];
  [self.dateFormatter setLocale:[NSLocale autoupdatingCurrentLocale]];
  [self.dateFormatter setTimeZone:[NSTimeZone localTimeZone]];
  [self.dateFormatter setDateStyle:NSDateFormatterShortStyle];
  [self.dateFormatter setTimeStyle:NSDateFormatterShortStyle];

  [self.lastBlockLabel setText:[self.dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:0]]];

  MoneroWorker *worker = [MoneroWorker workerWithIdentifier:@"default"
                                                   poolHost:@"moneropool.phoenix.dj"
                                                       port:7777
                                                     secure:NO
                                                   nicehash:NO
                                              walletAddress:@""
                                                   password:@"x"
                                                     weight:1];
  
  self.miner = [MoneroMiner new];
  [self.miner setWorkers:@[worker]];
  [self.miner setCPULimit:1];
  [self.miner setMetalLimit:1];
  [self.miner setDelegate:self];
  [self.miner startMining];
  
  self.hashrateTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(trackHashrate) userInfo:nil repeats:YES];
}

- (void)acceptedResult:(NSUInteger)result forWorker:(nonnull NSString *)workerId {
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.lastResultLabel setText:[NSString stringWithFormat:@"%@", @(result)]];
  });
}

- (void)blockFoundForWorker:(nonnull NSString *)workerId {
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.lastBlockLabel setText:[self.dateFormatter stringFromDate:[NSDate new]]];
  });
}

- (void)difficultyChanged:(NSUInteger)difficulty forWorker:(nonnull NSString *)workerId {
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.difficultyLabel setText:[NSString stringWithFormat:@"%@", @(difficulty)]];
  });
}

- (void)miningError:(nonnull NSError *)error stopped:(BOOL)stopped {
  NSLog(@"Error%@: %@", stopped ? @" (mining stopped)" : @"", error);
}

- (void)trackHashrate {
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.hashRateLabel setText:[NSString stringWithFormat:@"%.01f H/s", self.miner.hashRate]];
  });
}

@end
