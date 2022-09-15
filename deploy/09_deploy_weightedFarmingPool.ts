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

  const policyCenterAddress = addressList[network.name].PolicyCenter;
  const factoryAddress = addressList[network.name].PriorityPoolFactory;

  // WeightedFarmingPool contract artifact
  const weightedFarmingPool = await deploy("WeightedFarmingPool", {
    contract: "WeightedFarmingPool",
    from: deployer,
    args: [policyCenterAddress, factoryAddress],
    log: true,
  });
  addressList[network.name].WeightedFarmingPool = weightedFarmingPool.address;

  console.log(
    "WeightedFarmingPool deployed to address: ",
    weightedFarmingPool.address,
    "\n"
  );

  // Store the address list after deployment
  storeAddressList(addressList);
};

func.tags = ["WeightedFarmingPool"];
export default func;
