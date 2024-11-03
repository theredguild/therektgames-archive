const { numberToHex } = require('viem')
const { privateKeyToAccount } = require('viem/accounts')

// script to create a new account starting with 0xc0de
// @authot RedGuildIntern
// @date 2008-10-31T00:00:00.000Z
	const start = Math.round(new Date().getTime() / 1000);

let i = start;
while(1) {
    if(i % 1000000 === 0) {
        console.log(`i: ${i}`);
    }
    let priv = numberToHex(i, { size: 32 }) 
    const account = privateKeyToAccount(priv); 
    let w = account;
    if (w.address.toLowerCase().startsWith('0xc0de')) {
        console.log(`Found it! ${account.address}`);
        console.log(`Private key: ${priv}`);
        break;
    }
    i++;
}
