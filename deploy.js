const hre = require("hardhat");

async function main() {

  // We get the contract to deploy
  const mytoken = await hre.ethers.getContractFactory("DogToken");
  const dog = await mytoken.deploy();

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
