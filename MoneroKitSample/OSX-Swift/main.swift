//
//  main.swift
//  MoneroKitSample-OSX-Swift
//
//  Created by Yury Popov on 10.01.2018.
//

import Foundation
import MoneroKit

class Delegate: MoneroMinerDelegate {
  func acceptedResult(_ result: UInt, forWorker workerId: String) {
    print("Result: \(result)")
  }
  
  func difficultyChanged(_ difficulty: UInt, forWorker workerId: String) {
    print("Difficulty: \(difficulty)")
  }
  
  func blockFound(forWorker workerId: String) {
    print("New block")
  }
  
  func miningError(_ error: Error, stopped: Bool) {
    print("Error: \(error)\(stopped ? " (mining stopped)" : "")")
  }
}

let delegate = Delegate()

let worker = MoneroWorker(
  identifier: "default",
  poolHost: "moneropool.phoenix.dj",
  port: 7777,
  secure: false,
  walletAddress: "",
  password: "x",
  weight: 1
)

let miner = MoneroMiner()
miner.workers = [worker]
miner.cpuLimit = 1
miner.metalLimit = 0.9
miner.delegate = delegate
miner.startMining()

while miner.active {
  Thread.sleep(forTimeInterval: 1)
  print("Hash rate: \(String(format: "%.01f", miner.hashRate))")
}
