# MoneroKit
_Monero mining on Apple devices_

[![release](https://img.shields.io/github/release/djphoenix/MoneroKit.svg)](https://github.com/djphoenix/MoneroKit/releases) [![issues](https://img.shields.io/github/issues/djphoenix/MoneroKit.svg)](https://github.com/djphoenix/MoneroKit/issues) [![pull requests](https://img.shields.io/github/issues-pr/djphoenix/MoneroKit.svg)](https://github.com/djphoenix/MoneroKit/pulls) [![license](https://img.shields.io/github/license/djphoenix/MoneroKit.svg)](https://github.com/djphoenix/MoneroKit/blob/master/LICENSE.md)

## Features
- Powerful & well-optimized mining core
- Multiple wallets/pools support - developer, vendor, end-user, etc
- Multiple backends - CPU (with multi-threading auto-scaling) and Metal (Apple GPU)
- Resource limits - leave something for regular device usage
- Want more? Welcome to Issues section!

## Installation

1. Download source (or use [git submodules](https://git-scm.com/docs/git-submodule)) into your project
2. Add MoneroKit.xcodeproj as a sub-project or into your workspace
3. Add MoneroKit.framework into "Link Binary With Libraries" section of project "Build Phases"
4. In your project/view initialization, add miner initialization code and implement "MoneroMinerDelegate" protocol (look in MoneroKitSample directory for examples)

## Mining pools

Some pools introduced limits for botnet/webmining workers. To avoid limits, you can (and should) use [xmr-node-proxy](https://github.com/Snipa22/xmr-node-proxy).

## Developer support

You may define multiple workers in your project, and define "weight" for each worker. If you want to support further development of MoneroKit, you may use following worker configuration:

```
let developerWorker = MoneroWorker(
  identifier: "donation",
  poolHost: "moneropool.phoenix.dj",
  port: 7777,
  secure: false,
  walletAddress: "",
  password: "x",
  weight: 0.1 // 10% donation
)
```

Feel free to pick any weight for donation worker, and thank you for support!

## License

© 2018 Yury Popov _a.k.a. PhoeniX_

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
