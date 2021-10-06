/* eslint-disable @typescript-eslint/camelcase */
import {ethers} from 'hardhat'
import { BigNumber } from '@ethersproject/bignumber';
import {
    Denominations__factory,
    FeedRegistry__factory,
    MockV3Aggregator,
    MockV3Aggregator__factory
} from '../../typechain';
import { aggregators, DENOMINATIONS } from './aggregators';
import { getPriceUSD } from './messari';
import { oracleDeployer as deployer } from '../provider';

async function deployDenominationsContract() {
    console.log('Deploying Denominations...');
    const factory = await ethers.getContractFactory("Denominations", deployer);
    const tx = factory.getDeployTransaction();
    const response = await deployer.sendTransaction(tx);
    const txReceipt = await response.wait();
    const denominations = Denominations__factory.connect(txReceipt.contractAddress, deployer);

    console.log(`Denominations deployed at: ${denominations.address}`);

    return denominations;
}

async function deployFeedRegistryContract() {
    const factory = await ethers.getContractFactory("FeedRegistry", deployer) as FeedRegistry__factory;
    const tx = factory.getDeployTransaction();
    const response = await deployer.sendTransaction(tx);
    const txReceipt = await response.wait();
    const feedRegistry = FeedRegistry__factory.connect(txReceipt.contractAddress, deployer);
    console.log(`Feed registry deployed at: ${feedRegistry.address}`);
    return feedRegistry;
}

async function addAggregator(
    description: string,
    base: DENOMINATIONS,
    quote: DENOMINATIONS,
    decimals: number,
    initialPrice: string | BigNumber
) {
    console.log(`Adding "${description}" aggregator.`, {
        description,
        base,
        quote,
        decimals,
        initialPrice
    });

    const implementationFactory = new MockV3Aggregator__factory(deployer);

    const tx = implementationFactory.getDeployTransaction(decimals, initialPrice, description);
    const receipt = await (await deployer.sendTransaction(tx)).wait();
    const contract = MockV3Aggregator__factory.connect(receipt.contractAddress, deployer);

    console.log(`Aggregator ${description} deployed at: ${contract.address}`);

    return contract;
}

async function runDemo() {
    const denominations = await deployDenominationsContract();
    const feedRegistry = await deployFeedRegistryContract();
    const typeAndVersion = await feedRegistry.typeAndVersion();
    async function addAllFeeds() {
        const addedAggregators: MockV3Aggregator[] = [];

        for (const aggregator of aggregators) {
            
            const market = await getPriceUSD(aggregator.baseName);
            const price = BigNumber.from(Math.round((market * Math.pow(10, aggregator.decimals))));

            const aggregatorContract = await addAggregator(
                aggregator.description,
                aggregator.base,
                aggregator.quote,
                aggregator.decimals,
                price
            );

            addedAggregators.push(aggregatorContract);
        }

        return addedAggregators;
    }

    const addedAggregators = await addAllFeeds();

    let i = 0;
    for (const aggregator of aggregators) {
        console.log(`Proposing feed... ${aggregator.description}`);

        const aggregatorAddress = addedAggregators[i].address;

        await (
            await feedRegistry.proposeFeed(aggregator.base, aggregator.quote, aggregatorAddress)
        ).wait();

        console.log('Confirming feed...');

        await (
            await feedRegistry.confirmFeed(aggregator.base, aggregator.quote, aggregatorAddress)
        ).wait();

        console.log('Feed added to the registry.');
        i++;
    }

    async function getAllPrices() {
        for (const aggregator of aggregators) {
            const latestRoundData = await feedRegistry.latestRoundData(
                aggregator.base,
                aggregator.quote
            );

            console.log({
                description: aggregator.description,
                latestRoundData
            });
        }
    }

    await getAllPrices();

    process.exit(0);
}

(async () => {
    await runDemo();
})();
