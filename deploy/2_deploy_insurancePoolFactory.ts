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

  let degAddress: string, veDegAddress: string, shieldAddress: string;

  [degAddress, veDegAddress, shieldAddress] = getExternalTokenAddress(
    network.name
  );
  const reinsurancePoolAddress = addressList[network.name].ReinsurancePool;

  // Proxy Admin contract artifact
  const insurancePoolFactory = await deploy("InsurancePoolFactory", {
    contract: "InsurancePoolFactory",
    from: deployer,
    args: [degAddress, veDegAddress, shieldAddress, reinsurancePoolAddress],
    log: true,
  });
  addressList[network.name].InsurancePoolFactory = insurancePoolFactory.address;

  console.log("deployed to address: ", insurancePoolFactory.address, "\n");

  //   await hre.run("verify:verify", {
  //     address: insurancePoolFactory.address,
  //     constructorArguments: [],
  //   });

  // Store the address list after deployment
  storeAddressList(addressList);
};

func.tags = ["InsurancePoolFactory"];
export default func;
