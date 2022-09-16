import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

import {
  getExternalTokenAddress,
  readAddressList,
  storeAddressList,
} from "../scripts/contractAddress";

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

  const [, , shieldAddress] = getExternalTokenAddress(network.name);

  const executorAddress = addressList[network.name].Executor;
  const policyCenterAddress = addressList[network.name].PolicyCenter;

  // Treasury contract artifact
  const treasury = await deploy("Treasury", {
    contract: "Treasury",
    from: deployer,
    args: [shieldAddress, executorAddress, policyCenterAddress],
    log: true,
  });
  addressList[network.name].Treasury = treasury.address;

  console.log("Treasury deployed to address: ", treasury.address, "\n");

  // Store the address list after deployment
  storeAddressList(addressList);
};

func.tags = ["Treasury"];
export default func;
