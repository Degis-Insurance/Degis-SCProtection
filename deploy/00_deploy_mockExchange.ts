import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

import { readAddressList, storeAddressList } from "../scripts/contractAddress";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, network } = hre;
  const { deploy } = deployments;

  network.name = network.name == "hardhat" ? "localhost" : network.name;

  if (network.name == "avax") {
    console.log("\nYou are deploying mock exchange on mainnet!!!");
    console.log("No need for this deployment, skipping...... \n");
    return;
  }

  const { deployer } = await getNamedAccounts();

  console.log("\n-----------------------------------------------------------");
  console.log("-----  Network:  ", network.name);
  console.log("-----  Deployer: ", deployer);
  console.log("-----------------------------------------------------------\n");

  // Read address list from local file
  const addressList = readAddressList();

  // MockExchange contract artifact
  const exchange = await deploy("MockExchange", {
    contract: "MockExchange",
    from: deployer,
    args: [],
    log: true,
  });
  addressList[network.name].MockExchange = exchange.address;

  console.log("mock exchange deployed to address: ", exchange.address, "\n");

  // Store the address list after deployment
  storeAddressList(addressList);
};

func.tags = ["MockExchange"];
export default func;
