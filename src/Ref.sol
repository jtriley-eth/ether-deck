// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.19;

struct SysCall {
    address target;
    uint88 value;
    uint8 sigs;
    bytes data;
}

struct Mod {
    bytes4 selector;
    address target;
}

struct Sig {
    uint8 v;
    bytes32 r;
    bytes32 s;
}

error Auth();
error Threshold();
error Deadline();

contract EtherDeck {
    event SysCallQueued(uint256 id, address target, uint88 value, bytes data);
    event SysCallSig(address signer, uint256 id);

    uint256 internal _id;
    uint8 internal _threshold;
    mapping(address account => bool authorization) internal _auth;
    mapping(bytes4 selector => address target) internal _mods;

    constructor(uint8 threshold, address[] memory auths, Mod[] memory mods) {
        if (threshold > auths.length) revert Threshold();
        _threshold = threshold;
        for (uint256 i = 0; i < auths.length; i++) {
            _auth[auths[i]] = true;
        }
        for (uint256 i = 0; i < mods.length; i++) {
            _mods[mods[i].selector] = mods[i].target;
        }
    }

    function computeHash(
        uint256 id,
        address target,
        uint88 value,
        uint64 deadline,
        bytes calldata data
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    keccak256(
                        abi.encodePacked(id, target, value, deadline, data)
                    )
                )
            );
    }

    function setAuth(address account, bool authorization) public {
        if (msg.sender != address(this)) revert Auth();
        _auth[account] = authorization;
    }

    function setThreshold(uint8 threshold) public {
        if (msg.sender != address(this)) revert Auth();
        _threshold = threshold;
    }

    function setMod(bytes4 selector, address target) public {
        if (msg.sender != address(this)) revert Auth();
        _mods[selector] = target;
    }

    function syscall(
        uint256 id,
        address target,
        uint88 value,
        uint64 deadline,
        bytes calldata data,
        Sig[] calldata sigs
    ) public {
        if (sigs.length < _threshold) revert Threshold();
        if (deadline < block.timestamp) revert Deadline();
        bytes32 hash = computeHash(id, target, value, deadline, data);

        address lastSigner = address(0);
        for (uint256 i; i < sigs.length; i++) {
            address signer = ecrecover(hash, sigs[i].v, sigs[i].r, sigs[i].s);
            if (!_auth[signer] || signer <= lastSigner) revert Auth();
            lastSigner = signer;
        }

        (bool success, ) = target.call{value: value}(data);
        if (!success) revert();
    }

    fallback() external {
        address target = _mods[msg.sig];
        if (target == address(0)) return;
        (bool success, bytes memory r) = target.delegatecall(msg.data);
        if (!success) revert();
    }
}
