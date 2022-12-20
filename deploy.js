const hre = require("hardhat");

async function main() {

  // We get the contract to deploy
  const mytoken = await hre.ethers.getContractFactory("RunbitRand");
  // const dog = await mytoken.deploy("0x0A74fAF22FeA623630B9A00361C55f063D351180","0x9B202F188B0dd9618F44D304A77441A974C1f269", "0x2568D114d06fa03E11b451985778F71437e5e9cf", "0x340d592a978E6a176319b34A921F717fFAbf9f4C");
  const dog = await mytoken.deploy("0x8009609899128219507292930003719563843565");
  
  console.log("Start to deploy:");
  
  await dog.deployed();

  console.log("YourToken deployed to:", dog.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
