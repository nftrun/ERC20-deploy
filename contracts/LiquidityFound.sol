// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./INonfungiblePositionManager.sol";
import "./ILiquidityFound.sol";

contract LiquidityFound is ILiquidityFound, AccessControl {
    INonfungiblePositionManager nfpm;
    IERC20Burnable token0;
    IERC20Burnable token1;
    IUniswapV3PoolState v3Pool;
    uint256 fee;
    int256 initTick;
    uint256 tokenCount;
    uint256 remintCount;
    int24 tickSpacing;
    // tokens[index] = tokenId
    mapping(uint256 => uint256) tokens;
    // remintTokens[index] = tokenId
    mapping(uint256 => uint256) remintTokens;
    // tokenIdx[tokenId] = index
    mapping(uint256 => uint256) tokenIdx;
    bytes32 public constant MANAGE_ROLE = keccak256("MANAGE_ROLE");

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MANAGE_ROLE, admin);
    }

    function setNfpm(address _nfpm) external onlyRole(DEFAULT_ADMIN_ROLE) {
        nfpm = INonfungiblePositionManager(_nfpm);
    }

    function setV3Pool(address pool) external onlyRole(DEFAULT_ADMIN_ROLE) {
        v3Pool = IUniswapV3PoolState(pool);
    }

    function setToken0(address _token0) external onlyRole(DEFAULT_ADMIN_ROLE) {
        token0 = IERC20Burnable(_token0);
    }

    function setToken1(address _token1) external onlyRole(DEFAULT_ADMIN_ROLE) {
        token1 = IERC20Burnable(_token1);
    }

    function setTickSpacing(int256 _tickSpacing) external onlyRole(DEFAULT_ADMIN_ROLE) {
        tickSpacing = int24(_tickSpacing);
    }

    function setFee(uint256 _fee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        fee = _fee;
    }

    function setInitTick(int256 _tick) external onlyRole(DEFAULT_ADMIN_ROLE) {
        initTick = _tick;
    }

    function approve0(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        token0.approve(address(nfpm), amount);
    }

    function approve1(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        token1.approve(address(nfpm), amount);
    }

    function mint(MintParams calldata params)
        external
        onlyRole(MANAGE_ROLE)
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        (tokenId, liquidity, amount0, amount1) = nfpm.mint(
            INonfungiblePositionManager.MintParams({
                token0: address(token0),
                token1: address(token1),
                fee: uint24(fee),
                tickLower: params.tickLower,
                tickUpper: params.tickUpper,
                amount0Desired: params.amount0Desired,
                amount1Desired: params.amount1Desired,
                amount0Min: params.amount0Min,
                amount1Min: params.amount1Min,
                recipient: address(this),
                deadline: params.deadline
            })
        );
        tokens[tokenCount] = tokenId;
        tokenCount += 1;
        emit NFTMint(tokenId, liquidity, amount0, amount1);
    }
    
    // startTick 起始的tick
    // tickspace 流动性区间的长度
    // num 创造多少个
    // amount0Desired, uint256 amount1Desired token0及token1的金额，金额不必对应，以最小的为准。
    function batchMint(int256 startTick, int256 tickSapce, uint256 num, uint256 amount0Desired, uint256 amount1Desired) external onlyRole(MANAGE_ROLE) {
        if (tickSapce > 0) {
            for (uint i = 0; i < num; ++i) {
                (uint256 tokenId, uint256 liquidity, uint256 amount0, uint256 amount1) = nfpm.mint(
                    INonfungiblePositionManager.MintParams({
                        token0: address(token0),
                        token1: address(token1),
                        fee: uint24(fee),
                        tickLower: int24(startTick),
                        tickUpper: int24(startTick + tickSapce),
                        amount0Desired: amount0Desired,
                        amount1Desired: amount1Desired,
                        amount0Min: 0,
                        amount1Min: 0,
                        recipient: address(this),
                        deadline: 0x100000000000000000000000000000000
                    })
                );
                tokens[tokenCount] = tokenId;
                tokenCount += 1;
                emit NFTMint(tokenId, liquidity, amount0, amount1);
                startTick += tickSapce;
            }
        } else {
            for (uint i = 0; i < num; ++i) {
                (uint256 tokenId, uint256 liquidity, uint256 amount0, uint256 amount1) = nfpm.mint(
                    INonfungiblePositionManager.MintParams({
                        token0: address(token0),
                        token1: address(token1),
                        fee: uint24(fee),
                        tickLower: int24(startTick + tickSapce),
                        tickUpper: int24(startTick),
                        amount0Desired: amount0Desired,
                        amount1Desired: amount1Desired,
                        amount0Min: 0,
                        amount1Min: 0,
                        recipient: address(this),
                        deadline: 0x100000000000000000000000000000000
                    })
                );
                tokens[tokenCount] = tokenId;
                tokenCount += 1;
                emit NFTMint(tokenId, liquidity, amount0, amount1);
                startTick += tickSapce;
            }
        }
    }
    
    // 只添加一种币
    function _mintRightSide(int256 tickUpper, uint256 amountDesired)
        private
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        (, int24 tickLower, , , , , ) = v3Pool.slot0();
        tickLower = tickLower / tickSpacing * tickSpacing;
        (tokenId, liquidity, amount0, amount1) = nfpm.mint(
            INonfungiblePositionManager.MintParams({
                token0: address(token0),
                token1: address(token1),
                fee: uint24(fee),
                tickLower: tickLower + tickSpacing,
                tickUpper: int24(tickUpper),
                amount0Desired: amountDesired,
                amount1Desired: amountDesired,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: 0x100000000000000000000000000000000
            })
        );
        remintTokens[remintCount] = tokenId;
        remintCount += 1;
        emit NFTMint(tokenId, liquidity, amount0, amount1);
    }

    function mintRightSide(int256 tickUpper, uint256 amountDesired)
        external
        onlyRole(MANAGE_ROLE)
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        return _mintRightSide(tickUpper, amountDesired);
    }

    // 只添加一种币
    function _mintLeftSide(int256 tickLower, uint256 amountDesired)
        private
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        (, int24 tickUpper, , , , , ) = v3Pool.slot0();
        tickUpper = tickUpper / tickSpacing * tickSpacing;
        (tokenId, liquidity, amount0, amount1) = nfpm.mint(
            INonfungiblePositionManager.MintParams({
                token0: address(token0),
                token1: address(token1),
                fee: uint24(fee),
                tickLower: int24(tickLower),
                tickUpper: tickUpper,
                amount0Desired: amountDesired,
                amount1Desired: amountDesired,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: 0x100000000000000000000000000000000
            })
        );
        remintTokens[remintCount] = tokenId;
        remintCount += 1;
        emit NFTMint(tokenId, liquidity, amount0, amount1);
    }

    function mintLeftSide(int256 tickLower, uint256 amountDesired)
        external
        onlyRole(MANAGE_ROLE)
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        return _mintLeftSide(tickLower, amountDesired);
    }

    function increaseLiquidity(IncreaseLiquidityParams calldata params)
        external
        onlyRole(MANAGE_ROLE)
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        (liquidity, amount0, amount1) = nfpm.increaseLiquidity(
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: params.tokenId,
                amount0Desired: params.amount0Desired,
                amount1Desired: params.amount1Desired,
                amount0Min: params.amount0Min,
                amount1Min: params.amount1Min,
                deadline: params.deadline
            })
        );
        emit liquidityIncrease(params.tokenId, liquidity, amount0, amount1);
    }

    function decreaseLiquidity(DecreaseLiquidityParams calldata params)
        external
        onlyRole(MANAGE_ROLE)
        returns (uint256 amount0, uint256 amount1)
    {
        (amount0, amount1) = nfpm.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: params.tokenId,
                liquidity: params.liquidity,
                amount0Min: params.amount0Min,
                amount1Min: params.amount1Min,
                deadline: params.deadline
            })
        );
        emit liquidityDecrease(params.tokenId, amount0, amount1);
    }

    function _collect(CollectParams memory params)
        private
        returns (uint256 amount0, uint256 amount1)
    {
        (amount0, amount1) = nfpm.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: params.tokenId,
                recipient: address(this),
                amount0Max: params.amount0Max,
                amount1Max: params.amount1Max
            })
        );
        emit liquidityDecrease(params.tokenId, amount0, amount1);
    }

    function collect(CollectParams calldata params)
        external
        onlyRole(MANAGE_ROLE)
        returns (uint256 amount0, uint256 amount1)
    {
        return _collect(params);
    }

    function burn0Mint1(uint256 idx) external
        onlyRole(MANAGE_ROLE)
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        tokenId = tokens[idx];
        (, , , , , , , liquidity, , , ,) = nfpm.positions(tokenId);
        (amount0, amount1) = nfpm.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: 18446744073709551616
            })
        );
        
        (amount0, amount1) = _collect(
            CollectParams({
                tokenId: tokenId,
                amount0Max: 0x80000000000000000000000000000000,
                amount1Max: 0x80000000000000000000000000000000
            })
        );
        if (amount1 > 0) {
            (, int24 tick0, , , , , ) = v3Pool.slot0();
            if (tick0 > initTick) {
                _mintLeftSide(initTick - 2*tickSpacing, amount1);
            } else {
                _mintRightSide(initTick + 2*tickSpacing, amount1);
            }
        }

        if (amount0 > 0) {
            token0.burn(amount0);
        }
    }

    function burn1Mint0(uint256 idx) external
        onlyRole(MANAGE_ROLE)
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        tokenId = tokens[idx];
        (, , , , , , , liquidity, , , ,) = nfpm.positions(tokenId);
        (amount0, amount1) = nfpm.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: 18446744073709551616
            })
        );
        
        (amount0, amount1) = _collect(
            CollectParams({
                tokenId: tokenId,
                amount0Max: 0x80000000000000000000000000000000,
                amount1Max: 0x80000000000000000000000000000000
            })
        );
        if (amount0 > 0) {
            (, int24 tick0, , , , , ) = v3Pool.slot0();
            if (tick0 > initTick) {
                _mintLeftSide(initTick - 2*tickSpacing, amount0);
            } else {
                _mintRightSide(initTick + 2*tickSpacing, amount0);
            }
        }

        if (amount1 > 0) {
            token1.burn(amount1);
        }
    }

    function burnNFT(uint256 tokenId) external onlyRole(MANAGE_ROLE) {
        uint256 index = tokenIdx[tokenId];
        tokenCount -= 1;
        tokens[index] = tokens[tokenCount];
        nfpm.burn(tokenId);
        emit NFTBurn(tokenId);
    }

    function burnToken0(uint256 amount) external onlyRole(MANAGE_ROLE) {
        token0.burn(amount);
        emit TokenBurn(address(token0), amount);
    }

    function burnToken1(uint256 amount) external onlyRole(MANAGE_ROLE) {
        token1.burn(amount);
        emit TokenBurn(address(token1), amount);
    }

    function getTokenCount() external view returns (uint256) {
        return tokenCount;
    }

    function getRemintCount() external view returns (uint256) {
        return remintCount;
    }

    function getTokenId(uint256 index) external view returns (uint256) {
        return tokens[index];
    }

    function getRemintTokenId(uint256 index) external view returns (uint256) {
        return remintTokens[index];
    }

    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token01,
            address token11,
            uint24 fee1,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) {
        return nfpm.positions(tokenId);
    }

    function balance0() external view returns (uint256) {
        return token0.balanceOf(address(this));
    }

    function balance1() external view returns (uint256) {
        return token1.balanceOf(address(this));
    }
    
    // getRatioAtTick(tick) <= ratio
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        ) {
        return v3Pool.slot0();
    }

    event NFTMint(uint256 indexed tokenId, uint256 liquidity, uint256 amount0, uint256 amount1);
    event liquidityIncrease(uint256 indexed tokenId, uint256 liquidity, uint256 amount0, uint256 amount1);
    event liquidityDecrease(uint256 indexed tokenId, uint256 amount0, uint256 amount1);
    event liquidityCollect(uint256 indexed tokenId, uint256 amount0, uint256 amount1);
    event NFTBurn(uint256 indexed tokenId);
    event TokenBurn(address indexed token, uint256 amount);
}