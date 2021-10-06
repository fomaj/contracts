import { BigNumber } from "@ethersproject/abi/node_modules/@ethersproject/bignumber";
import axios from "axios";
import { MESSARI_API_KEY } from "./../config";
import { Market } from "./types/messari";

export const getPriceUSD = async (currency: string): Promise<number> => {
    const result = await axios.get<Market>(
        `https://data.messari.io/api/v1/assets/${currency}/metrics/market-data`,
        {
            headers: {
                'x-messari-api-key' : MESSARI_API_KEY
            }
        }
    );
    const data = result.data.data.market_data.price_usd;
    if(!data) {
        console.error("Data not found!")
        throw new Error("No data");
    }
    return data;
}