const { numberToHex } = require('viem')
const { privateKeyToAccount } = require('viem/accounts')

// script to create a new account starting with 0xc0de
// @authot RedGuildIntern
// @date 2024-10-01 (yyyy-mm-dd)
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