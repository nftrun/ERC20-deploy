const hre = require("hardhat");

async function main() {

  // We get the contract to deploy
  const mytoken = await hre.ethers.getContractFactory("RunbitProxy");
  const dog = await mytoken.deploy("0xFC65F798a8F7adf48bE45737b2517242C61829b1","0x3BB5AE1048869a4ee16CB5059eAca74303ADc201", "0xb048Ac124c7F78f4f3AbA48d0ea022Ff2B12e279", "0x00000000008783C915c33B0D7cA46139fB3cF690");
  // const dog = await mytoken.deploy("0x8009609899128219507292930003719563843565");
  
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
