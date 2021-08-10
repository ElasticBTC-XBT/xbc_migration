const AIStaking = artifacts.require("AIStaking");
// const Utils = artifacts.require("Utils");
const { deployProxy } = require("@openzeppelin/truffle-upgrades");

module.exports = async function (deployer) {
  
  let PANCAKE_ROUTER = "0x10ED43C718714eb63d5aA57B78B54704E256024E"; // pancake v2
  let CAKE = "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82"; // cake
  let CAKE_MASTER_CHEF = "0x73feaa1eE314F8c655E354234017bE2193C9E24E"; // cake master chef

  if (process.env.PANCAKE_ROUTER != undefined) {
    PANCAKE_ROUTER = process.env.PANCAKE_ROUTER;
  }

  console.log(`PANCAKE_ROUTER ${PANCAKE_ROUTER}`);

  await deployProxy(
    AIStaking,
    [PANCAKE_ROUTER,CAKE,CAKE_MASTER_CHEF], // initialize params
    {
      deployer,
   //   unsafeAllow: ["external-library-linking"],
      initializer: "initialize",
    }
  );
};
