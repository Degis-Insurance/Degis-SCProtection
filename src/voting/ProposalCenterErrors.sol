// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface ProposalCenterErrors {
    error NotActiveReport();
    // Not enough veDEG balance when voting
    error NotEnoughVeDEG();
}
