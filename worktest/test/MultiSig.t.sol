// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/MultiSig.sol";

contract MultiSigTest is Test {
    MultiSig public multisig;

    uint8 constant GROUP0_QUORUM = 2;
    uint8 constant GROUP1_QUORUM = 1;

    // All groups have the root as parent
    uint8 constant GROUP0_PARENT = 0;
    uint8 constant GROUP1_PARENT = 0;

    uint8 constant MAX_NUM_GROUPS = 2;

    uint8 constant SIGNERS_AMOUNT = 5;
    uint8 constant NUM_SUBGROUPS = 1;

    uint8[MAX_NUM_GROUPS] groupQuorums;
    uint8[MAX_NUM_GROUPS] groupParents;

    uint8[] groups;
    address[] signers;
    bytes32[] privateKeys;

    MultiSig.Config config;
    MultiSig.Call[] internal calls;
    address internal constant MULTISIG_OWNER = 0x1232117A6dEd3a4B844206D8f892e2733A71c843;

    bytes32 internal constant NO_PREDECESSOR = bytes32("");
    bytes32 internal constant EMPTY_SALT = bytes32("");

    function setUp() public {
        vm.startPrank(MULTISIG_OWNER);

        multisig = new MultiSig();
        (signers, privateKeys) = getAddressesAndPrivKeys();

        // Assign the required quorum in each group
        groupQuorums[0] = GROUP0_QUORUM;
        groupQuorums[1] = GROUP1_QUORUM;

        // Assign signers to groups
        for (uint8 i = 1; i <= SIGNERS_AMOUNT; i++) {
            // Plus one because we don't want signers in root group
            if (i < 2) {
                groups.push(0);
            } else {
                groups.push(1);
            }
        }

        for (uint8 i = 0; i < SIGNERS_AMOUNT; i++) {
            config.signers.push(
                MultiSig.Signer({
                    addr: signers[i],
                    index: i,
                    group: groups[i]
                })
            );
        }
        config.groupQuorums = groupQuorums;
        config.groupParents = groupParents;

        multisig.setConfig(signers, groups, groupQuorums, groupParents);

        vm.stopPrank();
    }

    function test_executeBatch() public {
        vm.startPrank(address(1));
        vm.deal(address(multisig), 2);

        MultiSig.Call[] memory call;
        call = _singletonCalls(MultiSig.Call({target: address(1), value: 1, data: "0x"}));

        // hash and sign
        bytes32 id = multisig.hashOperationBatch(call, NO_PREDECESSOR, EMPTY_SALT);
        MultiSig.Signature[] memory signatures = signBatch(privateKeys, id);

        // execute
        multisig.executeBatch(call, NO_PREDECESSOR, EMPTY_SALT, signatures);

        vm.stopPrank();
    }

    function getAddressesAndPrivKeys() public returns (address[] memory addresses, bytes32[] memory privKeys) {
        string[] memory cmd = new string[](2);
        cmd[0] = "python3";
        cmd[1] = "./script/gen_addresses_keys.py";
        bytes memory result = vm.ffi(cmd);
        (addresses, privKeys) = abi.decode(result, (address[], bytes32[]));
    }

    function _singletonCalls(MultiSig.Call memory call) internal pure returns (MultiSig.Call[] memory) {
        MultiSig.Call[] memory _calls = new MultiSig.Call[](1);
        _calls[0] = call;
        return _calls;
    }

    function signBatch(bytes32[] storage keys, bytes32 id) internal returns (MultiSig.Signature[] memory result) {
        result = new MultiSig.Signature[](SIGNERS_AMOUNT);
        for (uint256 i = 0; i < SIGNERS_AMOUNT; i++) {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(uint256(keys[i]), id);
            address signer = ecrecover(id, v, r, s);
            assertTrue(signer == signers[i], "invalid signature");
            result[i] = MultiSig.Signature({v: v, r: r, s: s});
        }
        return result;
    }
}
