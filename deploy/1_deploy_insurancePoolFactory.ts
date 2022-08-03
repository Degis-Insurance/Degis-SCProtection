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
  const insurancePoolFactory = await deploy("InsurancePoolFactory", {
    contract: "InsurancePoolFactory",
    from: deployer,
    args: [],
    log: true,
  });
  addressList[network.name].InsurancePoolFactory = insurancePoolFactory.address;

  console.log("\ndeployed to address: ", insurancePoolFactory.address);

  //   await hre.run("verify:verify", {
  //     address: insurancePoolFactory.address,
  //     constructorArguments: [],
  //   });

  // Store the address list after deployment
  storeAddressList(addressList);
};

func.tags = ["factory"];
export default func;
