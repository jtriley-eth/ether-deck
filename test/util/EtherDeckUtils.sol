// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.19;

struct Sig {
    uint8 v;
    bytes32 r;
    bytes32 s;
}

using { toPacked } for Sig global;

function toPacked(Sig memory sig) pure returns (bytes memory) {
    return abi.encodePacked(sig.v, sig.r, sig.s);
}

type EtherDeck is address;

using {toAddress, setAuth} for EtherDeck global;

function setAuth(
    EtherDeck deck,
    address account,
    bool authorized
) returns (bool success, bytes memory retdata) {
    (success, retdata) = deck.toAddress().call(
        abi.encodePacked(bytes4(0x00000001), account, authorized)
    );
}

function setThreshold(
    EtherDeck deck,
    uint8 threshold
) returns (bool success, bytes memory retdata) {
    (success, retdata) = deck.toAddress().call(
        abi.encodePacked(bytes4(0x00000002), threshold)
    );
}

function setShard(
    EtherDeck deck,
    bytes4 shard,
    address account
) returns (bool success, bytes memory retdata) {
    (success, retdata) = deck.toAddress().call(
        abi.encodePacked(bytes4(0x00000003), shard, account)
    );
}

function syscall(
    EtherDeck deck,
    uint256 id,
    address target,
    uint88 value,
    uint64 deadline,
    bytes memory payload,
    Sig[] memory signatures
) returns (bool success, bytes memory retdata) {
    bytes memory packedSigs;
    for (uint256 i; i < signatures.length; i++)
        packedSigs = abi.encodePacked(packedSigs, signatures[i].toPacked());
    (success, retdata) = deck.toAddress().call(
        abi.encodePacked(
            bytes4(0x00000004),
            id,
            target,
            value,
            deadline,
            uint32(payload.length),
            payload,
            packedSigs
        )
    );
}

function toAddress(EtherDeck deck) pure returns (address) {
    return EtherDeck.unwrap(deck);
}
