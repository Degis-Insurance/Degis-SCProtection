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

  console.log("\nmock degis token deployed to address: ", mockDEG.address);

  const mockShield = await deploy("MockSHIELD", {
    contract: "MockSHIELD",
    from: deployer,
    args: [0, "Shield", 18, "SHD"],
    log: true,
  });
  addressList[network.name].MockShield = mockShield.address;

  console.log("\nmock shield token deployed to address: ", mockShield.address);

  // Proxy Admin contract artifact
  const mockVeDEG = await deploy("MockVeDEG", {
    contract: "MockVeDEG",
    from: deployer,
    args: [0, "VoteEscrowedDegis", 18, "VeDEG"],
    log: true,
  });
  addressList[network.name].MockVeDEG = mockVeDEG.address;

  console.log(
    "\nmock vote escrowed degis token deployed to address: ",
    mockVeDEG.address
  );

  //   await hre.run("verify:verify", {
  //     address: insurancePoolFactory.address,
  //     constructorArguments: [],
  //   });

  // Store the address list after deployment
  storeAddressList(addressList);
};

func.tags = ["MockTokens"];
export default func;
