const ClaimReward = artifacts.require("ClaimReward");
const Utils = artifacts.require("Utils");

module.exports = async function (deployer) {
  await deployer.deploy(Utils);
  await deployer.link(Utils, ClaimReward);

  await deployer.deploy(
    ClaimReward,
    "0xeE67b3c7348CfbF1E17777717DDfacED799FeBaE",
    "0xD99D1c33F9fC3444f8101754aBC46c52416550D1",
    "0x5704ACFAe90Dca975CC4AF7d7bd8d056e9bEe87C"
  );
};
