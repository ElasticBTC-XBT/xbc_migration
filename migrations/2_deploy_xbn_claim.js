const ClaimReward = artifacts.require("ClaimReward");
const Utils = artifacts.require("Utils");
const { deployProxy } = require("@openzeppelin/truffle-upgrades");

module.exports = async function (deployer) {
  await deployer.deploy(Utils);
  await deployer.link(Utils, ClaimReward);

  await deployProxy(
    ClaimReward,
    [
      "0xee67b3c7348cfbf1e17777717ddfaced799febae",
      "0xd99d1c33f9fc3444f8101754abc46c52416550d1",
    ],
    {
      deployer,
      unsafeAllow: ["external-library-linking"],
      initializer: "initialize",
    }
  );
};
