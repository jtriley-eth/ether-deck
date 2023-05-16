// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.19;

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes memory data
    ) external returns (bytes4);
}

contract MockERC721 {
    error CallbackFailed();

    function callOnERC721Received(
        address target,
        address operator,
        address from,
        uint256 tokenId,
        bytes memory data
    ) public {
        if (
            IERC721Receiver(target).onERC721Received(
                operator,
                from,
                tokenId,
                data
            ) != IERC721Receiver.onERC721Received.selector
        ) revert CallbackFailed();
    }
}
