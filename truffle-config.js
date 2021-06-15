require("dotenv").config();

const HDWalletProvider = require("@truffle/hdwallet-provider");

const privateKeys = [process.env.PRIVATE_KEY]; // private keys
module.exports = {
  /**
   * Networks define how you connect to your ethereum client and let you set the
   * defaults web3 uses to send transactions. If you don't specify one truffle
   * will spin up a development blockchain for you on port 9545 when you
   * run `develop` or `test`. You can ask a truffle command to use a specific
   * network from the command line, e.g
   *
   * $ truffle test --network <network-name>
   */

  networks: {
    bsc_testnet: {
      provider: () =>
        new HDWalletProvider(
          privateKeys,
          "https://data-seed-prebsc-1-s2.binance.org:8545"
        ),
      network_id: 97,
      confirmations: 3,
      timeoutBlocks: 200,
      // gas: 5000000,
      gasPrice: 10e9,
      skipDryRun: true,

      // networkCheckTimeout: 90000,
      // Resolve time out error
      // https://github.com/trufflesuite/truffle/issues/3356#issuecomment-721352724
    },
    bsc: {
      provider: () =>
        new HDWalletProvider(privateKeys, "https://bsc-dataseed1.binance.org"),
      network_id: 56,
      confirmations: 10,
      timeoutBlocks: 200,
      // gas: 10000000,
      gasPrice: 5000000000, //5gwei
    },
    bsc_mainnet_fork: {
      provider: () =>
        new HDWalletProvider(['0xfc87f123834ae64aa8d53f6007f7bd1fde780a09c77b45fa49c630073a86cf31'], "HTTP://0.0.0.0:8545"), // privatekey for: legend used tumble chase apology drastic program fringe identify match million outer
      network_id: 56,
      confirmations: 2,
      timeoutBlocks: 100,
      gasPrice: 20000000000,//20gwei
    },
    // Useful for testing. The `development` name is special - truffle uses it by default
    // if it's defined here and no other network is specified at the command line.
    // You should run a client (like ganache-cli, geth or parity) in a separate terminal
    // tab if you use this network and you must also set the `host`, `port` and `network_id`
    // options below to some value.
    //
    // development: {
    //  host: "127.0.0.1",     // Localhost (default: none)
    //  port: 8545,            // Standard Ethereum port (default: none)
    //  network_id: "*",       // Any network (default: none)
    // },
    // Another network with more advanced options...
    // advanced: {
    // port: 8777,             // Custom port
    // network_id: 1342,       // Custom network
    // gas: 8500000,           // Gas sent with each transaction (default: ~6700000)
    // gasPrice: 20000000000,  // 20 gwei (in wei) (default: 100 gwei)
    // from: <address>,        // Account to send txs from (default: accounts[0])
    // websocket: true        // Enable EventEmitter interface for web3 (default: false)
    // },
    // Useful for deploying to a public network.
    // NB: It's important to wrap the provider as a function.
    // ropsten: {
    // provider: () => new HDWalletProvider(mnemonic, `https://ropsten.infura.io/v3/YOUR-PROJECT-ID`),
    // network_id: 3,       // Ropsten's id
    // gas: 5500000,        // Ropsten has a lower block limit than mainnet
    // confirmations: 2,    // # of confs to wait between deployments. (default: 0)
    // timeoutBlocks: 200,  // # of blocks before a deployment times out  (minimum/default: 50)
    // skipDryRun: true     // Skip dry run before migrations? (default: false for public nets )
    // },
    // Useful for private networks
    // private: {
    // provider: () => new HDWalletProvider(mnemonic, `https://network.io`),
    // network_id: 2111,   // This network is yours, in the cloud.
    // production: true    // Treats this network as if it was a public net. (default: false)
    // }
  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
    // timeout: 100000
  },

  // Configure your compilers
  compilers: {
    solc: {
      version: "0.6.8", // Fetch exact version from solc-bin (default: truffle's version)
      // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
      settings: {
        // See the solidity docs for advice about optimization and evmVersion
        optimizer: {
          enabled: true,
          runs: 200,
        },
        // evmVersion: "byzantium",
      },
    },
  },

  // Truffle DB is currently disabled by default; to enable it, change enabled: false to enabled: true
  //
  // Note: if you migrated your contracts prior to enabling this field in your Truffle project and want
  // those previously migrated contracts available in the .db directory, you will need to run the following:
  // $ truffle migrate --reset --compile-all

  db: {
    enabled: false,
  },
  plugins: ["truffle-contract-size"],
};
