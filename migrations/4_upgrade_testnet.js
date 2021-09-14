const XbcMigration = artifacts.require("XbcMigration");
// const Utils = artifacts.require("Utils");
const { upgradeProxy } = require("@openzeppelin/truffle-upgrades");

module.exports = async function (deployer) {
  // await deployer.deploy(Utils);
  // await deployer.link(Utils, ClaimReward);
  // const proxyAddress = "0x8781413C768f207699D51f42b909c5d6A9D9aD36"; testnet
  const proxyAddress = "0x8AB58dd7aC92Ee5088a34556bED11Be7B74B2ab0"; //mainnet
  await upgradeProxy(proxyAddress, XbcMigration, {
    deployer,
    unsafeAllow: ["external-library-linking"],
  });
};
