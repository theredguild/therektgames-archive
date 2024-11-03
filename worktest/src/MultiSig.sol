pragma solidity =0.8.19;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title MultiSig
 * @notice Distributed as part of a coding challenge. For educational purposes only.
 */
contract MultiSig is Ownable {
    receive() external payable {}

    uint8 public constant NUM_GROUPS = 2;
    uint8 public constant MAX_NUM_SIGNERS = 200;

    struct Signer {
        address addr;
        uint8 index;
        uint8 group;
    }

    struct Call {
        address target;
        uint256 value;
        bytes data;
    }

    mapping(address => Signer) s_signers;

    struct Config {
        Signer[] signers;
        uint8[NUM_GROUPS] groupQuorums;
        uint8[NUM_GROUPS] groupParents;
    }

    Config s_config;

    mapping(bytes32 => bool) s_seenSignedHashes;

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    function hashOperationBatch(Call[] calldata calls, bytes32 predecessor, bytes32 salt)
        public
        pure
        virtual
        returns (bytes32 hash)
    {
        return keccak256(abi.encode(calls, predecessor, salt));
    }

    function executeBatch(Call[] calldata calls, bytes32 predecessor, bytes32 salt, Signature[] calldata signatures)
        public
        payable
        virtual
    {
        bytes32 signedHash = hashOperationBatch(calls, predecessor, salt);

        if (s_seenSignedHashes[signedHash]) {
            revert SignedHashAlreadySeen();
        }

        {
            Signer memory signer;
            address prevAddress = address(0x0);
            uint8[NUM_GROUPS] memory groupVoteCounts;
            for (uint256 i = 0; i < signatures.length; i++) {
                Signature calldata sig = signatures[i];

                address signerAddress = ECDSA.recover(signedHash, sig.v, sig.r, sig.s);

                prevAddress = signerAddress;

                signer = s_signers[signerAddress];
                if (signer.addr != signerAddress) {
                    revert InvalidSigner();
                }
                uint8 group = signer.group;
                while (true) {
                    groupVoteCounts[group]++;
                    if (groupVoteCounts[group] != s_config.groupQuorums[group]) {
                        break;
                    }
                    if (group == 0) {
                        break;
                    }

                    group = s_config.groupParents[group];
                }
            }

            if (s_config.groupQuorums[0] == 0) {
                revert MissingConfig();
            }

            if (groupVoteCounts[0] < s_config.groupQuorums[0]) {
                revert InsufficientSigners();
            }
        }

        s_seenSignedHashes[signedHash] = true;

        for (uint256 i = 0; i < calls.length; ++i) {
            _execute(calls[i]);
            emit CallExecuted(signedHash, i, calls[i].target, calls[i].value, calls[i].data);
        }
    }

    function _execute(Call calldata call) internal virtual {
        (bool success,) = call.target.call{value: call.value}(call.data);
        require(success, "underlying transaction reverted");
    }

    function setConfig(
        address[] calldata signerAddresses,
        uint8[] calldata signerGroups,
        uint8[NUM_GROUPS] calldata groupQuorums,
        uint8[NUM_GROUPS] calldata groupParents
    ) external onlyOwner {
        if (signerAddresses.length == 0 || signerAddresses.length > MAX_NUM_SIGNERS) {
            revert OutOfBoundsNumOfSigners();
        }

        if (signerAddresses.length != signerGroups.length) {
            revert SignerGroupsLengthMismatch();
        }

        {
            uint8[NUM_GROUPS] memory groupChildrenCounts;

            for (uint256 i = 0; i < signerGroups.length; i++) {
                if (signerGroups[i] >= NUM_GROUPS) {
                    revert OutOfBoundsGroup();
                }
                groupChildrenCounts[signerGroups[i]]++;
            }

            for (uint256 j = 0; j < NUM_GROUPS; j++) {
                uint256 i = NUM_GROUPS - 1 - j;

                if ((i != 0 && groupParents[i] >= i) || (i == 0 && groupParents[i] != 0)) {
                    revert GroupTreeNotWellFormed();
                }
                bool disabled = groupQuorums[i] == 0;
                if (disabled) {
                    if (0 < groupChildrenCounts[i]) {
                        revert SignerInDisabledGroup();
                    }
                } else {
                    if (groupChildrenCounts[i] < groupQuorums[i]) {
                        revert OutOfBoundsGroupQuorum();
                    }
                    groupChildrenCounts[groupParents[i]]++;
                }
            }
        }

        Signer[] memory oldSigners = s_config.signers;

        for (uint256 i = 0; i < oldSigners.length; i++) {
            address oldSignerAddress = oldSigners[i].addr;
            delete s_signers[oldSignerAddress];
            s_config.signers.pop();
        }

        assert(s_config.signers.length == 0);
        s_config.groupQuorums = groupQuorums;
        s_config.groupParents = groupParents;

        address prevSigner = address(0x0);
        for (uint256 i = 0; i < signerAddresses.length; i++) {
            Signer memory signer = Signer({addr: signerAddresses[i], index: uint8(i), group: signerGroups[i]});
            s_signers[signerAddresses[i]] = signer;
            s_config.signers.push(signer);
            prevSigner = signerAddresses[i];
        }

        emit ConfigSet(s_config);
    }

    function getConfig() public view returns (Config memory) {
        return s_config;
    }

    /*
    * Events and Errors
    */

    event CallExecuted(bytes32 indexed id, uint256 indexed index, address target, uint256 value, bytes data);

    event ConfigSet(Config config);

    error OutOfBoundsNumOfSigners();

    error SignerGroupsLengthMismatch();

    error OutOfBoundsGroup();

    error GroupTreeNotWellFormed();

    error OutOfBoundsGroupQuorum();

    error SignerInDisabledGroup();

    error InvalidSigner();

    error InsufficientSigners();

    error MissingConfig();

    error SignedHashAlreadySeen();
}
