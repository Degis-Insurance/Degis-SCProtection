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

  const priorityPoolFactoryAddress =
    addressList[network.name].PriorityPoolFactory;
  const protectionPoolAddress = addressList[network.name].ProtectionPool;

  // PremiumRewardPool contract artifact
  const premiumRewardPool = await deploy("PremiumRewardPool", {
    contract: "PremiumRewardPool",
    from: deployer,
    args: [shieldAddress, priorityPoolFactoryAddress, protectionPoolAddress],
    log: true,
  });
  addressList[network.name].PremiumRewardPool = premiumRewardPool.address;

  console.log(
    "Premium reward pool deployed to address: ",
    premiumRewardPool.address,
    "\n"
  );

  // Store the address list after deployment
  storeAddressList(addressList);
};

func.tags = ["PremiumRewardPool"];
export default func;
