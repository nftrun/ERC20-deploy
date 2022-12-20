// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20Burnable is IERC20 {
    function burn(uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;
    function mint(address to, uint256 amount) external;
    function balanceOf(address user) external view returns(uint256);
}

interface ILiquidityFound {
    struct MintParams {
        int24 tickLower;
        int24 tickUpper;
        uint128 deadline;
        uint128 amount0Desired;
        uint128 amount1Desired;
        uint128 amount0Min;
        uint128 amount1Min;
    }

    struct CollectParams {
        uint256 tokenId;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    struct IncreaseLiquidityParams {
        uint192 tokenId;
        uint64  deadline;
        uint128 amount0Desired;
        uint128 amount1Desired;
        uint128 amount0Min;
        uint128 amount1Min;
    }

    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint128 deadline;
        uint128 amount0Min;
        uint128 amount1Min;
    }
}
