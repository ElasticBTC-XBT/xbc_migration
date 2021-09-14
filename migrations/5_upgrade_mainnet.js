const XbcMigration = artifacts.require("XbcMigration");
// const Utils = artifacts.require("Utils");
const { upgradeProxy } = require("@openzeppelin/truffle-upgrades");

module.exports = async function (deployer) {
    
  const proxyAddress = "0x77C6BB15eac53C710964b19911A59DA473412847"; //mainnet
  await upgradeProxy(proxyAddress, XbcMigration, {
    deployer,
    unsafeAllow: ["external-library-linking"],
  });
};
