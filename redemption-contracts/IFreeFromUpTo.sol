
interface IFreeFromUpTo {
    function freeFromUpTo(address from, uint256 value) external;
    function mint(uint256 value) external;
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint);
}