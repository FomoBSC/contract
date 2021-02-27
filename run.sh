#!/bin/bash

npx hardhat compile
npx hardhat run --network testnet scripts/deploy.js
