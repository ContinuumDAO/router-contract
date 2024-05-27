const hre = require("hardhat");
const evn = require("../../output/env.json")

const fs = require("fs");

async function main() {
    const networkName = hre.network.name
    const chainId = hre.network.config.chainId
    console.log("Deploy Network name=", networkName);
    console.log("Network chain id=", chainId);

    console.log("C3Caller SQL:");
    let number = evn[networkName.toUpperCase()].INDEX

    console.log(`
        INSERT INTO caller_config (id, chain_id, address, contract_type, contract_version)
        VALUES
            (${number * 4}, ${chainId}, '${evn[networkName.toUpperCase()].C3Caller}', 'C3Caller', 'V1'),
            (${number * 4 + 1}, ${chainId}, '${evn[networkName.toUpperCase()].C3CallerProxy}', 'C3CallerProxy', 'V1'),
            (${number * 4 + 2}, ${chainId}, '${evn[networkName.toUpperCase()].C3CallerProxyImp}', 'C3CallerProxyImp', 'V1'),
            (${number * 4 + 3}, ${chainId}, '${evn[networkName.toUpperCase()].C3Governor}', 'C3Governor', 'V1');
    `)

    console.log(`
        INSERT INTO caller_mpc (config_id, caller_address, mpc_address, status)
            VALUES
        (${number * 4 + 1}, '${evn[networkName.toUpperCase()].C3CallerProxy}','0x5d0725Add79feD3f0E61851b3C4704148Ef9c7eA', 'ACTIVE'),
        (${number * 4 + 1}, '${evn[networkName.toUpperCase()].C3CallerProxy}','0xEef3d3678E1E739C6522EEC209Bede0197791339', 'INACTIVE');
    `)
    console.log(`
        INSERT INTO chain_config (chain_id, initial_height, confirmations, extra, chain_symbol)
        VALUES
            (${chainId}, '0', 2, '{"eip1559":false}', '${networkName}');
        `)

    console.log("Scaner SQL:");
    console.log(`
        INSERT INTO chain_config (chain_id, uri, chain_type, cron, start_bn, confirm_bn)
        VALUES
            (${chainId}, '${evn[networkName.toUpperCase()].URL}', 'evm', '32/40 * * * * ?', 0, 2);
    `)

    if (chainId == 421614) {
        console.log(`
        INSERT INTO event_config (target_addr, chain_id, event_key, start_bn, operate, comments)
        VALUES
            ('${evn[networkName.toUpperCase()].C3DappManager}', ${chainId}, '0xe16335fd7ccb686d02c1c6f5400a23f29fdafb67372e60497f1f387a9663328e, 0x6e806e4274e1ae2fda14f84ae0177d6248dd126572ee44f546d4645c41ee2f77, 0x5d9994a3de8f7f639b3ab61295e70425c258281ab88e6fc650afe50d0d2bd16c', '0', '2', 'SetDAppConfig,SetDappAddr,AddMpcAddr'),
            ('${evn[networkName.toUpperCase()].C3DappManager}', ${chainId}, '0xeaa18152488ce5959073c9c79c88ca90b3d96c00de1f118cfaad664c3dab06b9,0x9da6493a92039daf47d1f2d7a782299c5994c6323eb1e972f69c432089ec52bf', '0', '3', 'Deposit,Withdraw');
    `)
    }
    console.log(`
        INSERT INTO event_config (target_addr, chain_id, event_key, start_bn, operate, comments)
        VALUES
            ('${evn[networkName.toUpperCase()].C3Governor}', ${chainId}, '0x7066190a2751b8d939d2c201f8eb1ea9fa04b8616d0c26b6dcdee152cbdb3608', '0', '1', 'C3GovernorLog'),
            ('${evn[networkName.toUpperCase()].C3Caller}', ${chainId}, '0x88ca677ce66cb94eb6b03d7e06b1735c23eafde3090030bf7fb84711690a287e', '0', '1', 'LogC3Call'),
            ('${evn[networkName.toUpperCase()].TheiaRouterConfig}', ${chainId}, '0xb2fcbe1c1d185ca80230c812e8ddc6d1b10a441d37c49efc02142cb876f5a4b3', '0', '5', 'LogSetTokenConfig'),
            ('${evn[networkName.toUpperCase()].FeeManager}', ${chainId}, '0x1394cfab38f3fc78ed77ea6f9318782a446d96e7dc8e9a6b0149f6be25c08bcf,0xd640783e4a868b881e1c32d48b8037cc33f11c91feb83b38c99772302e28c3c1', '0', '6', 'AddFeeToken,SetLiqFee'),
            ('${evn[networkName.toUpperCase()].TheiaRouter}', ${chainId}, '0x1ad9ac7982ab5544e2bac3ac73dc72e9f821ce62200105a5e7f77b07bc230669,0x6999c67174aab1508cc0b367933d6ad1ebb316a7c6ca30a1f14ec553c5870efe', '0', '4', 'LogTheiaCross,LogTheiaVault,LogSwapFallback');
    `)

    console.log("Router SQL:");
    console.log(`
        INSERT INTO chain_config (chain_id, initial_height, confirmations, extra, chain_symbol, icon, chain_type, uri)
        VALUES
        ('${chainId}', '0', 2, '{"multicall":"","symbol":"","decimals":18,"explorer":""}', '${networkName}', '', 'evm', '${evn[networkName.toUpperCase()].URL}');
    `)
    console.log(`
        INSERT INTO fee_config (from_chain_id, to_chain_id, token_symbol, fixed_fee, fee_ccy, source_chain)
        VALUES
        ('${chainId}', '0', 'tUSDT', 5.0000, 'USDT', 1);
    `)
    console.log(`
        INSERT INTO router_config (chain_id, router_address, contract_version)
        VALUES
        ('${chainId}', '${evn[networkName.toUpperCase()].TheiaRouter}', 'v1');
    `)


    const tokensContents = fs.readFileSync('output/ERC20.txt', 'utf-8');

    tokensContents.split(/\r?\n/).forEach(line => {
        if (line.length == 0) {
            return;
        }
        const args = JSON.parse(line);
        if (args.chainId == chainId) {
            console.log(`
            INSERT INTO token_config (chain_id, token_name, token_symbol, decimals, address, underlying_token, contract_version, router_address, is_check) VALUES (
                '${args.chainId}',
                '${args.name}',
                '${args.symbol}',
                 ${args.decimals},
                '${args.address}',
                '${args.underlying}',
                'V1',
                '${args.router}',
                0
            );`);
        }

    });

}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

