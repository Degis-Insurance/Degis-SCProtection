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

  // Proxy Admin contract artifact
  const reinsurancePool = await deploy("ReinsurancePool", {
    contract: "ReinsurancePool",
    from: deployer,
    args: [],
    log: true,
  });
  addressList[network.name].ReinsurancePool = reinsurancePool.address;

  console.log(
    "\nreinsurance pool deployed to address: ",
    reinsurancePool.address
  );

  //   await hre.run("verify:verify", {
  //     address: insurancePoolFactory.address,
  //     constructorArguments: [],
  //   });

  // Store the address list after deployment
  storeAddressList(addressList);
};

func.tags = ["ReinsurancePool"];
export default func;
