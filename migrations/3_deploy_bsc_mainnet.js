const XbcMigration = artifacts.require("XbcMigration");
// const Utils = artifacts.require("Utils");
const { deployProxy } = require("@openzeppelin/truffle-upgrades");

module.exports = async function (deployer) {
  

  await deployProxy(
    XbcMigration,
    [], // initialize params
    {
      deployer,
   //   unsafeAllow: ["external-library-linking"],
      initializer: "initialize",
    }
  );
};
