import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

import { readAddressList, storeAddressList } from "../scripts/contractAddress";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, network } = hre;
  const { deploy } = deployments;

  network.name = network.name == "hardhat" ? "localhost" : network.name;

  const { deployer } = await getNamedAccounts();

  console.log("\n-----------------------------------------------------------");
  console.log("-----  Network:  ", network.name);
  console.log("-----  Deployer: ", deployer);
  console.log("-----------------------------------------------------------\n");

  // Read address list from local file
  const addressList = readAddressList();

  // Executor contract artifact
  const executor = await deploy("Executor", {
    contract: "Executor",
    from: deployer,
    args: [],
    log: true,
  });
  addressList[network.name].Executor = executor.address;

  console.log("executor deployed to address: ", executor.address, "\n");

  // Store the address list after deployment
  storeAddressList(addressList);
};

func.tags = ["Executor"];
export default func;
