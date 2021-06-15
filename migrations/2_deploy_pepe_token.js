const PepeToken = artifacts.require("PepeToken");
const Utils = artifacts.require("Utils");
const { deployProxy } = require("@openzeppelin/truffle-upgrades");

module.exports = async function (deployer) {
  await deployer.deploy(Utils);
  await deployer.link(Utils, PepeToken);

  let PANCAKE_ROUTER = "0xD99D1c33F9fC3444f8101754aBC46c52416550D1";

  if (process.env.PANCAKE_ROUTER != undefined) {
    PANCAKE_ROUTER = process.env.PANCAKE_ROUTER;
  }

  console.log(`PANCAKE_ROUTER ${PANCAKE_ROUTER}`);

  await deployProxy(PepeToken, [PANCAKE_ROUTER], {
    deployer,
    unsafeAllow: ["external-library-linking"],
    initializer: "initialize",
  });
};
