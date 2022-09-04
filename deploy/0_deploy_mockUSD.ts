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
  const mockUSDC = await deploy("MockERC20", {
    contract: "MockERC20",
    from: deployer,
    args: ["MockUSDC", "MockUSDC", 6],
    log: true,
  });
  addressList[network.name].MockUSDC = mockUSDC.address;

  console.log("mock usdc token deployed to address: ", mockUSDC.address, "\n");

  // Store the address list after deployment
  storeAddressList(addressList);
};

func.tags = ["MockUSDC"];
export default func;
