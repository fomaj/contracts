export interface Market {
    status?: Status;
    data?:   Data;
}

export interface Data {
    id?:                      string;
    symbol?:                  string;
    name?:                    string;
    slug?:                    string;
    contract_addresses?:      any[];
    _internal_temp_agora_id?: string;
    market_data?:             MarketData;
}

export interface MarketData {
    price_usd?:                                   number;
    price_btc?:                                   number;
    price_eth?:                                   number;
    volume_last_24_hours?:                        number;
    real_volume_last_24_hours?:                   number;
    volume_last_24_hours_overstatement_multiple?: number;
    percent_change_usd_last_1_hour?:              number;
    percent_change_btc_last_1_hour?:              number;
    percent_change_eth_last_1_hour?:              number;
    percent_change_usd_last_24_hours?:            number;
    percent_change_btc_last_24_hours?:            number;
    percent_change_eth_last_24_hours?:            number;
    ohlcv_last_1_hour?:                           OhlcvLastHour;
    ohlcv_last_24_hour?:                          OhlcvLastHour;
    last_trade_at?:                               Date;
}

export interface OhlcvLastHour {
    open?:   number;
    high?:   number;
    low?:    number;
    close?:  number;
    volume?: number;
}

export interface Status {
    elapsed?:   number;
    timestamp?: Date;
}
