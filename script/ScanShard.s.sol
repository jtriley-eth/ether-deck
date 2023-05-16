// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.19;

import "lib/forge-std/src/Script.sol";

contract ScanShard is Script {
    using {toOp} for bytes1;

    function run() public {
        // SET THIS
        address shard;

        uint256 codeLen = shard.code.length;
        ScannerState memory state = newScannerState(shard.code);

        for (uint256 i; i < codeLen; i++) {
            Op op = state.bytecode[i].toOp();
            if (op == Op.NOOP) continue;
            if (!state.isScanning) {
                if (op == Op.JUMPDEST) state.isScanning = true;
                continue;
            }
            if (op == Op.SLOAD) state.hasSload = true;
            if (op == Op.STATICCALL) state.hasStaticcall = true;
            if (op == Op.SSTORE) state.hasSstore = true;
            if (op == Op.DELEGATECALL) state.hasDelegatecall = true;
            if (op == Op.CALL) state.hasCall = true;
            if (op == Op.CALLCODE) state.hasCallcode = true;
            if (op == Op.CREATE) state.hasCreate = true;
            if (op == Op.CREATE2) state.hasCreate2 = true;
            if (op == Op.SELFDESTRUCT) state.hasSelfdestruct = true;
            if (op == Op.LOGN) state.hasLogn = true;
        }

        string memory report = watDo(state);
        console.log("\n// --------------\n// SCANNER REPORT");
        console.log(bytes(report).length == 1 ? "\n[.] Nothing to report.\n" : report);
    }
}

enum Op
// NOOP
{
    NOOP,
    // TERMINAL
    STOP,
    RETURN,
    REVERT,
    INVALID,
    // INFORMATIONAL
    JUMPDEST,
    // READ-ONLY
    SLOAD,
    STATICCALL,
    // STATEFUL
    SSTORE,
    DELEGATECALL,
    CALL,
    CALLCODE,
    CREATE,
    CREATE2,
    SELFDESTRUCT,
    LOGN
}

using {isTerminal, isReadOnly, isStateful} for Op global;

function isTerminal(Op op) pure returns (bool) {
    return uint8(op) > 0 && uint8(op) < 5;
}

function isReadOnly(Op op) pure returns (bool) {
    return uint8(op) == 6 || uint8(op) == 7;
}

function isStateful(Op op) pure returns (bool) {
    return uint8(op) > 7;
}

function toOp(bytes1 i) pure returns (Op) {
    if (i == 0x00) return Op.STOP;
    else if (i == 0xf3) return Op.RETURN;
    else if (i == 0xfd) return Op.REVERT;
    else if (i == 0xfe) return Op.INVALID;
    else if (i == 0x5b) return Op.JUMPDEST;
    else if (i == 0x54) return Op.SLOAD;
    else if (i == 0xfa) return Op.STATICCALL;
    else if (i == 0x55) return Op.SSTORE;
    else if (i == 0xf4) return Op.DELEGATECALL;
    else if (i == 0xf1) return Op.CALL;
    else if (i == 0xf2) return Op.CALLCODE;
    else if (i == 0xf0) return Op.CREATE;
    else if (i == 0xfb) return Op.CREATE2;
    else if (i == 0xff) return Op.SELFDESTRUCT;
    else if (i >= 0xa0 && i <= 0xa4) return Op.LOGN;
    else return Op.NOOP;
}

struct ScannerState {
    bytes bytecode;
    bool isScanning;
    bool hasSload;
    bool hasStaticcall;
    bool hasSstore;
    bool hasDelegatecall;
    bool hasCall;
    bool hasCallcode;
    bool hasCreate;
    bool hasCreate2;
    bool hasSelfdestruct;
    bool hasLogn;
}

using {watDo} for ScannerState global;

function newScannerState(bytes memory bytecode) pure returns (ScannerState memory) {
    return ScannerState({
        bytecode: bytecode,
        isScanning: true,
        hasSload: false,
        hasStaticcall: false,
        hasSstore: false,
        hasDelegatecall: false,
        hasCall: false,
        hasCallcode: false,
        hasCreate: false,
        hasCreate2: false,
        hasSelfdestruct: false,
        hasLogn: false
    });
}

function watDo(ScannerState memory state) pure returns (string memory) {
    string memory report = "\n";
    if (state.hasSelfdestruct) {
        report = string.concat(report, "[!] SELFDESTRUCT: May destroy the deck and send its funds to any address.\n");
    }
    if (state.hasDelegatecall) {
        report = string.concat(
            report, "[!] DELEGATECALL: May make an external call that can read or write the deck's storage.\n"
        );
    }
    if (state.hasCallcode) {
        report = string.concat(
            report, "[!] CALLCODE: May make an external call that can read or write the deck's storage.\n"
        );
    }
    if (state.hasCall) {
        report = string.concat(report, "[!] CALL: May make an external call, including to the deck itself.\n");
    }
    if (state.hasSstore) {
        report = string.concat(report, "[!] SSTORE: May write to the deck's local storage.\n");
    }
    if (state.hasCreate) {
        report = string.concat(report, "[!] CREATE: May create an external contract that can execute arbitrary code.\n");
    }
    if (state.hasCreate2) {
        report =
            string.concat(report, "[!] CREATE2: May create an external contract that can execute arbitrary code.\n");
    }
    if (state.hasLogn) {
        report = string.concat(report, "[!] LOGN: May write to the deck's event log.\n");
    }
    if (state.hasSload) {
        report = string.concat(report, "[.] SLOAD: May read from the deck's storage.\n");
    }
    if (state.hasStaticcall) {
        report =
            string.concat(report, "[.] STATICCALL: May make an external read-only call. EVM disallows state changes.\n");
    }
    return report;
}
