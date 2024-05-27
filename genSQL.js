const fs = require("fs");

const tokensContents = fs.readFileSync('ERC20.txt', 'utf-8');

var router = {}
tokensContents.split(/\r?\n/).forEach(line => {
    if (line.length == 0) {
        return;
    }
    const args = JSON.parse(line);

    //     INSERT INTO `router_config` (`id`, `chain_id`, `router_address`, `contract_version`, `created_at`, `updated_at`)
    // VALUES
    // 	(3, '97', '0x53f5CdB1BDf9fA49e061FE28A9a3F38eB02ed038', 'v1', '2023-10-08 19:58:33', '2024-04-14 06:00:04');

    // INSERT INTO token_config (chain_id, token_name, token_symbol, decimals, address, underlying_token, contract_version, router_address, is_check, icon, created_at, updated_at) VALUES
    // ( '421614', 'theiaCTM', 'tCTM', 18, '0x101C0388823c1e0117b0A80d299ae900c9436272', '0x2A2a5e1e2475Bf35D8F3f85D8C736f376BDb1C02', 'V1', '0xC92291fbBe0711b6B34928cB1b09aba1f737DEfd', 0, 'https://forum.continuumdao.org/assets/uploads/system/site-logo.png', '2024-04-13 17:39:17', '2024-04-14 02:42:12');
    console.log(`INSERT INTO token_config (chain_id, token_name, token_symbol, decimals, address, underlying_token, contract_version, router_address, is_check) VALUES (
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

    if (!router[args.chainId]) {
        console.log(`INSERT INTO router_config ( chain_id, router_address, contract_version) VALUES (
            '${args.chainId}',
            '${args.router}',
            'v1'
        );`)
        router[args.chainId] = args.router
    }
});