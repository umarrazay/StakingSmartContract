
const { ethers } = require("hardhat");

async function main() {

  const [deployer] = await ethers.getSigners();

  console.log(`Deploying RWT contract with account: ${deployer.address}`);

  const MI = await ethers.getContractFactory("RWT");

  const mi = await MI.deploy();

  console.log(`Contract address: ${mi.address}`);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });