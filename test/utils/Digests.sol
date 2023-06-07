// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

library Digests {
    function _getMintDigest(
        string memory _name,
        string memory _version,
        address collection,
        address _proposer,
        address _recipient,
        uint256 _proposalId,
        uint256 _salt
    ) internal view returns (bytes32) {
        bytes32 DOMAIN_TYPEHASH = keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
        bytes32 MINT_TYPEHASH = keccak256("Mint(address proposer,address recipient,uint256 proposalId,uint256 salt)");

        return
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    keccak256(
                        abi.encode(
                            DOMAIN_TYPEHASH,
                            keccak256(bytes(_name)),
                            keccak256(bytes(_version)),
                            block.chainid,
                            collection
                        )
                    ),
                    keccak256(abi.encode(MINT_TYPEHASH, _proposer, _recipient, _proposalId, _salt))
                )
            );
    }

    function _getMintBatchDigest(
        string memory _name,
        string memory _version,
        address collection,
        address[] memory _proposers,
        address _recipient,
        uint256[] memory _proposalIds,
        uint256 _salt
    ) internal view returns (bytes32) {
        bytes32 DOMAIN_TYPEHASH = keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
        bytes32 MINT_BATCH_TYPEHASH = keccak256(
            "MintBatch(address[] proposers,address recipient,uint256[] proposalIds,uint256 salt)"
        );

        return
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    keccak256(
                        abi.encode(
                            DOMAIN_TYPEHASH,
                            keccak256(bytes(_name)),
                            keccak256(bytes(_version)),
                            block.chainid,
                            collection
                        )
                    ),
                    keccak256(abi.encode(MINT_BATCH_TYPEHASH, _proposers, _recipient, _proposalIds, _salt))
                )
            );
    }

    function _getDeployDigest(
        string memory _name,
        string memory _version,
        address factory,
        address _implem,
        bytes memory _initializer,
        uint256 _salt
    ) internal view returns (bytes32) {
        bytes32 DOMAIN_TYPEHASH = keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
        bytes32 DEPLOY_TYPEHASH = keccak256("Deploy(address implementation,bytes initializer,uint256 salt)");

        return
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    keccak256(
                        abi.encode(
                            DOMAIN_TYPEHASH,
                            keccak256(bytes(_name)),
                            keccak256(bytes(_version)),
                            block.chainid,
                            factory
                        )
                    ),
                    keccak256(abi.encode(DEPLOY_TYPEHASH, _implem, keccak256(_initializer), _salt))
                )
            );
    }
}
