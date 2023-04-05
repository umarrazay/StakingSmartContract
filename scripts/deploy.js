
const { ethers } = require("hardhat");

async function main() {

  const [deployer] = await ethers.getSigners();

  console.log(`Deploying contract with account: ${deployer.address}`);

  const MI = await ethers.getContractFactory("Staking");

  // const STK = "0x6c531eCf3f26c9Ff6c014586E5f82c3E542368d7";
  // const RWT = "0x8232619a7005c7aA1e350beF0E2F44B19a6c276C";
  // const NFT = "0x3286049699Ab800A7375bD78fD10E7F6Ac488CcB";


  // const NFT = "0x3286049699Ab800A7375bD78fD10E7F6Ac488CcB";
  
  const mi = await MI.deploy("0x6c531eCf3f26c9Ff6c014586E5f82c3E542368d7","0x8232619a7005c7aA1e350beF0E2F44B19a6c276C","0x3286049699Ab800A7375bD78fD10E7F6Ac488CcB");

  console.log(`Contract address: ${mi.address}`);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });