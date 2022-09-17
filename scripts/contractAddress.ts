/**
 * Remember to use this function in the root path of your hardhat project
 */

import * as fs from "fs";

///
/// Deployed Contract Address Info Record
///
export const readAddressList = function () {
  // const filePath = __dirname + "/address.json"
  return JSON.parse(fs.readFileSync("info/address.json", "utf-8"));
};

export const storeAddressList = function (addressList: object) {
  fs.writeFileSync(
    "info/address.json",
    JSON.stringify(addressList, null, "\t")
  );
};

export const clearAddressList = function () {
  const emptyList = {};
  fs.writeFileSync("info/address.json", JSON.stringify(emptyList, null, "\t"));
};

///
/// Onboard proposal list info
///
export const readProposalList = function () {
  return JSON.parse(fs.readFileSync("info/proposals.json", "utf-8"));
};

export const storeProposalList = function (proposalList: object) {
  fs.writeFileSync(
    "info/proposals.json",
    JSON.stringify(proposalList, null, "\t")
  );
};

export const readReportList = function () {
  return JSON.parse(fs.readFileSync("info/reports.json", "utf-8"));
};

export const storeReportList = function (reportList: object) {
  fs.writeFileSync("info/reports.json", JSON.stringify(reportList, null, "\t"));
};

///
/// Priority Pool Info Record
///
export const readPriorityPoolList = function () {
  return JSON.parse(fs.readFileSync("info/PriorityPool.json", "utf-8"));
};

export const storePriorityPoolList = function (priorityPoolList: object) {
  fs.writeFileSync(
    "info/PriorityPool.json",
    JSON.stringify(priorityPoolList, null, "\t")
  );
};

///
/// Signer Info Record
///
export const readImpList = function () {
  return JSON.parse(fs.readFileSync("info/implementation.json", "utf-8"));
};

export const storeImpList = function (impList: object) {
  fs.writeFileSync(
    "info/implementation.json",
    JSON.stringify(impList, null, "\t")
  );
};

export const getLinkAddress = function (networkName: string) {
  const linkAddress = {
    avax: "0x5947BB275c521040051D82396192181b413227A3",
    fuji: "0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846",
    localhost: "0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846",
  };

  const obj = JSON.parse(JSON.stringify(linkAddress));

  return obj[networkName];
};

export const readILMList = function () {
  return JSON.parse(fs.readFileSync("info/ILM.json", "utf-8"));
};

export const storeILMList = function (ILMList: object) {
  fs.writeFileSync("info/ILM.json", JSON.stringify(ILMList, null, "\t"));
};

export const getExternalTokenAddress = function (chain: string) {
  const addressList = readAddressList();
  if (chain == "avax") {
    return [
      addressList[chain].DegisToken,
      addressList[chain].VoteEscrowedDegis,
      addressList[chain].Shield,
    ];
  } else {
    return [
      addressList[chain].MockDEG,
      addressList[chain].MockVeDEG,
      addressList[chain].MockShield,
    ];
  }
};
