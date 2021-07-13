const AIStaking = artifacts.require("AIStaking");
const Utils = artifacts.require("Utils");
const { deployProxy } = require("@openzeppelin/truffle-upgrades");

module.exports = async function (deployer) {
  // await deployer.deploy(Utils);
  // await deployer.link(Utils, AIStaking);

  await deployProxy(
    AIStaking,
    [], // initialize params
    {
      deployer,
   //   unsafeAllow: ["external-library-linking"],
      initializer: "initialize",
    }
  );
};
