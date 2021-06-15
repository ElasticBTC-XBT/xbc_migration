// test/Box.proxy.test.js
// Load dependencies
const { expect } = require("chai");
const { deployProxy } = require("@openzeppelin/truffle-upgrades");

// Load compiled artifacts
const PepeToken = artifacts.require("PepeToken");

// Start test block
contract("Box (proxy)", function () {
  beforeEach(async function () {
    // Deploy a new Box contract for each test
    this.pepeToken = await deployProxy(PepeToken);
  });

  // Test case
  it("retrieve returns a value previously initialized", async function () {
    // Test if the returned value is the same one
    // Note that we need to use strings to compare the 256 bit integers
    // expect((await this.pepeToken.retrieve()).toString()).to.equal("42");
  });
});
