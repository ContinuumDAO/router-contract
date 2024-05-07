const hre = require("hardhat");
const evn = require("../../env.json")

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
            (${number * 3}, ${chainId}, '${evn[networkName.toUpperCase()].C3Caller}', 'C3Caller', 'V1'),
            (${number * 3 + 1}, ${chainId}, '${evn[networkName.toUpperCase()].C3CallerProxy}', 'C3CallerProxy', 'V1'),
            (${number * 3 + 2}, ${chainId}, '${evn[networkName.toUpperCase()].C3CallerProxyImp}', 'C3CallerProxyImp', 'V1');
    `)
    console.log(`
        INSERT INTO caller_mpc (config_id, caller_address, mpc_address, status)
            VALUES
        (${number * 3 + 1}, '${evn[networkName.toUpperCase()].C3CallerProxy}','${evn[networkName.toUpperCase()].MPC}', 'INACTIVE'),
        (${number * 3 + 1}, '${evn[networkName.toUpperCase()].C3CallerProxy}','0xEef3d3678E1E739C6522EEC209Bede0197791339', 'ACTIVE');
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

    console.log(`
        INSERT INTO event_config (target_addr, chain_id, event_key, start_bn, operate, comments)
        VALUES
            ('${evn[networkName.toUpperCase()].TheiaRouter}', ${chainId}, '0x4ede268e681d4c81cf82d6edce6f182b4eabb18454177230bece9fd6c558bf27,0x426aa7a6606173343756985e002a132b5ec1d8ecbe4d498d1319bce44b288d23,0xa58a98921fbe8956cf5123f851baf0fce3d990f8103c2ad7e25e60222a21fce0', '0', '4', 'LogSwapOut,LogSwapIn,LogSwapFallback'),
            ('${evn[networkName.toUpperCase()].C3Caller}', ${chainId}, '0x2074205b2acdda95fc2a518526af428cd0531423009ce72c46a8083b1333e466', '0', '1', 'LogC3Call');
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


    const tokensContents = fs.readFileSync('ERC20.txt', 'utf-8');

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


function upData(key, obj) {
    readFile(filePath, 'utf-8', (err, data) => {
        if (err) throw err
        let res = JSON.parse(data)

        res[key] = Object.assign(res[key], obj)

        writeFile(filePath, JSON.stringify(res, null, 4), err => {
            if (err) throw err
        })
    })
}