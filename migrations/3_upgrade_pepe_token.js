const PepeToken = artifacts.require("PepeToken");
const Utils = artifacts.require("Utils");
const { upgradeProxy } = require("@openzeppelin/truffle-upgrades");

module.exports = async function (deployer) {
  await deployer.deploy(Utils);
  await deployer.link(Utils, PepeToken);
  const proxyAddress = "0xC2EF213bDD60a316700c5edBA540Ea17b920f59D";
  await upgradeProxy(proxyAddress, PepeToken, {
    deployer,
    unsafeAllow: ["external-library-linking"],
  });
};
