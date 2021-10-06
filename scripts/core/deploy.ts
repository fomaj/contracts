import { writeFile } from 'fs/promises';
import {ethers} from 'hardhat'
import { AddressTranslator } from 'nervos-godwoken-integration';
import { deployer } from '../provider';
import { INTERVAL_SECONDS, BUFFER_SECONDS, MIN_BET, TRESSURRY_FEES, NERVOS_PROVIDER_URL, CKB_USD_AGG, MIN_STAKE, MIN_PRIZE_AMOUNT, TOKEN_TX_PERCENTAGE, BET_PRICE_RANGE, CLOSE_TIME_MULTIPLIER, FAUCET_TOKEN_AMOUNT } from '../config';
import { FMJFaucet__factory, FMJToken__factory, FomajPrizePool__factory, Fomaj__factory } from '../../typechain';
import { BigNumber } from '@ethersproject/abi/node_modules/@ethersproject/bignumber';

const addressTranslator = new AddressTranslator();
async function deployFomajContract() : Promise<string> {
    console.log("Deploying contract: Fomaj");
    const factory = await ethers.getContractFactory("Fomaj", deployer) as Fomaj__factory;
    const tx = factory.getDeployTransaction();
    tx.gasPrice = 0;
    tx.gasLimit = 1_000_000;
    const response = await deployer.sendTransaction(tx);
    const txReceipt =await response.wait();
    const address = txReceipt.contractAddress;
    console.log(`Contract deployed: ${address}`);
    return address;
}

async function deployToken(predictionContract: string, faucetAddress: string) : Promise<string> {
    console.log("Deploying contract: FMJToken");
    const factory = await ethers.getContractFactory("FMJToken") as FMJToken__factory;
    const tx = factory.getDeployTransaction(
        predictionContract,
         BigNumber.from(TOKEN_TX_PERCENTAGE as string),
         faucetAddress
         );
    tx.gasPrice = 0;
    tx.gasLimit = 1_000_000;
    const response = await deployer.sendTransaction(tx);
    const txReceipt = await response.wait();
    const address = txReceipt.contractAddress;
    console.log(`Contract deployed: ${address}`);
    return address;
}

async function kickOffFomaj(contractAddress: string, tokenAddress: string, prizePoolAddress: string) {
    const contract = Fomaj__factory.connect(contractAddress, deployer);
    
    (await contract.kickOff(
        {
            fmjToken: tokenAddress,
            oracle: CKB_USD_AGG as string,
            closeTimeMultiplier: parseInt(CLOSE_TIME_MULTIPLIER as string),
            betRange: parseInt(BET_PRICE_RANGE as string),
            minStakeAmount: parseInt(MIN_STAKE as string),
            stakeLockDuration: 15780000,
            bufferSeconds: parseInt(BUFFER_SECONDS as string),
            minBetAmount: parseInt(MIN_BET as string),
            intervalSeconds: parseInt(INTERVAL_SECONDS as string),
            prizePool: prizePoolAddress,
            minPrizeAmount:  parseInt(MIN_PRIZE_AMOUNT as string),
        }, {
            gasPrice: 0,
            gasLimit: 600_000
        }        
    )).wait();
    console.log("Kickoff success!");
}

async function deployFaucet(prediction: string) : Promise<string> {
    console.log("Deploying contract: Faucet");
    const factory = await ethers.getContractFactory("FMJFaucet") as FMJFaucet__factory;
    const tx = factory.getDeployTransaction(
        parseInt(FAUCET_TOKEN_AMOUNT as string)
    );
    tx.gasPrice = 0;
    tx.gasLimit = 1_000_000;
    const response = await deployer.sendTransaction(tx);
    const txReceipt = await response.wait();
    const address = txReceipt.contractAddress;
    console.log(`Contract deployed: ${address}`);
    return address;
}

async function deployPrizePool(prediction: string) : Promise<string> {
    console.log("Deploying contract: PrizePool");
    const factory = await ethers.getContractFactory("FomajPrizePool") as FomajPrizePool__factory;
    const tx = factory.getDeployTransaction(prediction);
    tx.gasPrice = 0;
    tx.gasLimit = 1_000_000;
    const response = await deployer.sendTransaction(tx);
    const txReceipt = await response.wait();
    const address = txReceipt.contractAddress;
    console.log(`Contract deployed: ${address}`);
    return address;
}

async function changeFaucetToken(address: string, tokenAddress: string) {
    console.log("Changing faucet token address");
    const contract = FMJFaucet__factory.connect(address, deployer);
    await (await contract.setToken(tokenAddress, {
        gasLimit: 6_000_000,
        gasPrice: 0
    })).wait();
    console.log("Token address set.");
}

async function setPrizepoolToken(address: string, tokenAddress: string) {
    console.log("Setting prize pool")
    const contract = FomajPrizePool__factory.connect(address, deployer);
    await (await contract.setToken(tokenAddress, {
        gasLimit: 6_000_000,
        gasPrice: 0
    })).wait();
    console.log("Prize pool set.");
}

async function excludePredictionContractFromFees(tokenAddress: string, predictionAddress: string) {
    console.log("Exluding Fomaj contract from fees")
    const contract = FMJToken__factory.connect(tokenAddress, deployer);
    await (await contract.excludeFromFees(predictionAddress, {
        gasLimit: 6_000_000,
        gasPrice: 0
    })).wait();
    console.log("Excluded");
}


async function main() {
    console.log(`Using RPC: ${NERVOS_PROVIDER_URL}`);
    const predictionAddress = await deployFomajContract();

    console.log("Waiting 30 seconds.")
    await new Promise((resolve) => setTimeout(resolve, 1000 * 30));
    const prizePoolAddress = await deployPrizePool(predictionAddress);

    console.log("Waiting 30 seconds.")
    await new Promise((resolve) => setTimeout(resolve, 1000 * 30));
    const faucetAddress = await deployFaucet(predictionAddress);

    console.log("Waiting 30 seconds.")
    await new Promise((resolve) => setTimeout(resolve, 1000 * 30));
    const FMJTokenAddress = await deployToken(prizePoolAddress, faucetAddress);

    console.log("Waiting 30 seconds.")
    await new Promise((resolve) => setTimeout(resolve, 1000 * 30));
    await setPrizepoolToken(prizePoolAddress, FMJTokenAddress);
    
    console.log("Waiting 30 seconds.")
    await new Promise((resolve) => setTimeout(resolve, 1000 * 30));
    await changeFaucetToken(faucetAddress, FMJTokenAddress);

    console.log("Waiting 30 seconds.")
    await new Promise((resolve) => setTimeout(resolve, 1000 * 30));
    await excludePredictionContractFromFees(FMJTokenAddress, predictionAddress);

    console.log("Waiting 30 seconds");
    await new Promise((resolve) => setTimeout(resolve, 1000 * 30));
    console.log("Execuing kickoff");
    await kickOffFomaj(predictionAddress, FMJTokenAddress, prizePoolAddress);

    await writeFile('./data.json', JSON.stringify({
        prediction: predictionAddress,
        token: FMJTokenAddress,
        prizePoolAddress,
    }, null, 2));
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });