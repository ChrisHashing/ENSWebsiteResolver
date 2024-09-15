const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  const ENSWebsiteResolver = await hre.ethers.getContractFactory("ENSWebsiteResolver");
  const ensRegistryAddress = "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e"; // Mainnet ENS Registry address
  const feeRecipient = deployer.address; // Using deployer as initial fee recipient
  const resolver = await ENSWebsiteResolver.deploy(ensRegistryAddress, feeRecipient);

  await resolver.deployed();

  console.log("ENSWebsiteResolver deployed to:", resolver.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });