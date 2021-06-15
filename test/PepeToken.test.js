// test/Box.test.js
// Load dependencies
const { expect } = require("chai");

// Load compiled artifacts
const PepeToken = artifacts.require("PepeToken");

// Start test block
contract("PepeToken", function () {
  beforeEach(async function () {
    // Deploy a new Box contract for each test
    this.pepeToken = await PepeToken.new();
  });

  // Test case
  it("retrieve returns a value previously stored", async function () {
    // Store a value
    await this.pepeToken.setLimitHoldPercentage(50);

    // Test if the returned value is the same one
    // Note that we need to use strings to compare the 256 bit integers
    expect((await this.pepeToken.limitHoldPercentage()).toString()).to.equal(
      "50"
    );
  });
});
