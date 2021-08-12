const AIStaking = artifacts.require("AIStaking");
// const Utils = artifacts.require("Utils");
const { upgradeProxy } = require("@openzeppelin/truffle-upgrades");

module.exports = async function (deployer) {
    
  const proxyAddress = "0xc50323b2FB63A68cf5C039fEBAd6B8ECc6Be4328"; //mainnet
  await upgradeProxy(proxyAddress, AIStaking, {
    deployer,
    unsafeAllow: ["external-library-linking"],
  });
};
