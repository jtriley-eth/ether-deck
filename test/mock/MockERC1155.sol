// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.19;

interface IERC1155Receiver {
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes memory data
    ) external returns (bytes4);

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) external returns (bytes4);
}

contract MockERC1155 {
    error CallbackFailed();

    function callOnERC1155Received(
        address target,
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes memory data
    ) public {
        if (
            IERC1155Receiver(target).onERC1155Received(
                operator,
                from,
                id,
                value,
                data
            ) != IERC1155Receiver.onERC1155Received.selector
        ) revert CallbackFailed();
    }

    function callOnERC1155BatchReceived(
        address target,
        address operator,
        address from,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) public {
        if (
            IERC1155Receiver(target).onERC1155BatchReceived(
                operator,
                from,
                ids,
                values,
                data
            ) != IERC1155Receiver.onERC1155BatchReceived.selector
        ) revert CallbackFailed();
    }
}
