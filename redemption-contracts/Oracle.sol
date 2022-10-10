// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;

abstract contract Oracle {
    address private _oracle;

    event OracleTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOracle(msg.sender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function oracle() public view virtual returns (address) {
        return _oracle;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOracle() {
        require(oracle() == msg.sender, "Oracle: caller is not the oracle");
        _;
    }

    function renounceOracle() public virtual onlyOracle {
        _transferOracle(address(0));
    }

    function transferOracle(address newOracle) public virtual onlyOracle {
        require(newOracle != address(0), "Oracle: new oracle is the zero address");
        _transferOracle(newOracle);
    }

    function _transferOracle(address newOracle) internal virtual {
        address oldOracle = _oracle;
        _oracle = newOracle;
        emit OracleTransferred(oldOracle, newOracle);
    }
}