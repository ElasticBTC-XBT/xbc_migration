const ClaimReward = artifacts.require("ClaimReward");
const Utils = artifacts.require("Utils");
const { upgradeProxy } = require("@openzeppelin/truffle-upgrades");

module.exports = async function (deployer) {
  await deployer.deploy(Utils);
  await deployer.link(Utils, ClaimReward);
  const proxyAddress = "0x8781413C768f207699D51f42b909c5d6A9D9aD36";
  await upgradeProxy(proxyAddress, ClaimReward, {
    deployer,
    unsafeAllow: ["external-library-linking"],
  });
};
