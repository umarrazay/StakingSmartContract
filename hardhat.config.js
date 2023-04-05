require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-gas-reporter");
require("dotenv").config();

module.exports = {
  solidity: {
    version: "0.8.18",
    settings: {
    optimizer: {
    enabled: true,
    runs: 200
  }
}

},

networks: {
    mumbai: {
    url: process.env.ALCHEMY_URL || "",
    accounts:
    process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
},

gasReporter: {
  enabled: process.env.REPORT_GAS !== undefined,
  currency: "USD",
},

etherscan: {
  apiKey: process.env.MUMBAISCAN_API_KEY,
},
};