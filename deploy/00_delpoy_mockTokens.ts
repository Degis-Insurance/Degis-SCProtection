import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

import { readAddressList, storeAddressList } from "../scripts/contractAddress";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, network } = hre;
  const { deploy } = deployments;

  network.name = network.name == "hardhat" ? "localhost" : network.name;

  if (network.name == "avax") {
    console.log("You are deploying mock tokens on mainnet!!!");
    return;
  }

  const { deployer } = await getNamedAccounts();

  console.log("\n-----------------------------------------------------------");
  console.log("-----  Network:  ", network.name);
  console.log("-----  Deployer: ", deployer);
  console.log("-----------------------------------------------------------\n");

  // Read address list from local file
  const addressList = readAddressList();

  // Proxy Admin contract artifact
  const mockDEG = await deploy("MockDEG", {
    contract: "MockDEG",
    from: deployer,
    args: [0, "DegisToken", 18, "DEG"],
    log: true,
  });
  addressList[network.name].MockDEG = mockDEG.address;

  console.log("mock degis token deployed to address: ", mockDEG.address, "\n");

  const mockShield = await deploy("MockSHIELD", {
    contract: "MockSHIELD",
    from: deployer,
    args: [0, "Shield", 6, "SHD"],
    log: true,
  });
  addressList[network.name].MockShield = mockShield.address;

  console.log(
    "mock shield token deployed to address: ",
    mockShield.address,
    "\n"
  );

  // Proxy Admin contract artifact
  const mockVeDEG = await deploy("MockVeDEG", {
    contract: "MockVeDEG",
    from: deployer,
    args: [0, "VoteEscrowedDegis", 18, "VeDEG"],
    log: true,
  });
  addressList[network.name].MockVeDEG = mockVeDEG.address;

  console.log(
    "mock vote escrowed degis token deployed to address: ",
    mockVeDEG.address,
    "\n"
  );

  // Store the address list after deployment
  storeAddressList(addressList);
};

func.tags = ["MockTokens"];
export default func;
