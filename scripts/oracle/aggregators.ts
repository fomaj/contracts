import { CKB_USD_AGG} from '../config';

export enum DENOMINATIONS {
    ETH = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE',
    USD = '0x0000000000000000000000000000000000000348',
    BTC = '0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB',
    CKB = '0x0000000000000000000000000000000000000001'
}

export enum ETH_MAINNET_DENOMINATIONS {
    DAI = '0x6b175474e89094c44da98b954eedeac495271d0f'
}

export const aggregators = [
    {
        description: 'CKB / USD',
        baseName: 'CKB',
        quoteName: 'USD',
        base: DENOMINATIONS.CKB,
        quote: DENOMINATIONS.USD,
        decimals: 8
    }
];

export const aggregatorsDeployed = [
    {
        ...aggregators[0],
        address: CKB_USD_AGG,
    }
];