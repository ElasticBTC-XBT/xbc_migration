const AIStaking = artifacts.require("AIStaking");
// const Utils = artifacts.require("Utils");
const { deployProxy } = require("@openzeppelin/truffle-upgrades");

module.exports = async function (deployer) {
  
  let PANCAKE_ROUTER = "0x10ED43C718714eb63d5aA57B78B54704E256024E"; // pancake v2

  if (process.env.PANCAKE_ROUTER != undefined) {
    PANCAKE_ROUTER = process.env.PANCAKE_ROUTER;
  }

  console.log(`PANCAKE_ROUTER ${PANCAKE_ROUTER}`);

  await deployProxy(
    AIStaking,
    [PANCAKE_ROUTER], // initialize params
    {
      deployer,
   //   unsafeAllow: ["external-library-linking"],
      initializer: "initialize",
    }
  );
};
