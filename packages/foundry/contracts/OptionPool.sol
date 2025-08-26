// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library SafeCast128 { function toUint128(uint256 x) internal pure returns (uint128){ require(x<=type(uint128).max,"overflow"); return uint128(x);} }

contract OptionPool {
    uint256 private constant Q128 = 0x100000000000000000000000000000000; // 2^128
    uint8 public immutable N; // cells <= 64

    constructor(uint8 n){ require(n>0 && n<=64,"bad N"); N=n; }

    // --- Per-cell state ---
    uint256[64] public cellL;              // active liquidity opted into cell
    uint256[64] public feeGrowth0X128;     // fees -> token0 per-liquidity
    uint256[64] public creditGrowth0X128;    // credited proceeds -> token0 per-liquidity
    uint256[64] public debtGrowth0X128;    // optional: socialize losses (subtract)
    uint256 public protocolFees0;          // undistributable token0

    // --- Positions ---
    struct Position {
        uint128 liquidity;
        uint64  cellMask;                  // which cells they opt into
        uint256 feeSum0LastX128;           // snapshot Σ feeGrowth over mask
        uint256 creditSum0LastX128;          // snapshot Σ creditGrowth over mask
        uint256 debtSum0LastX128;          // snapshot Σ debtGrowth over mask
        uint128 claimable0;                // realized token0 pending collect
        address optionToken;
    }
    mapping(bytes32=>Position) public positions;

    // --- internal sums ---
    function _sum(uint64 mask, uint256[64] storage arr) internal view returns(uint256 s){
        unchecked { for(uint8 i=0;i<N;++i) if((mask & (uint64(1)<<i))!=0) s+=arr[i]; }
    }

    function _updatePosition(bytes32 key) internal {
        Position storage p = positions[key];
        uint64 m = p.cellMask;
        uint256 feeNow  = _sum(m, feeGrowth0X128);
        uint256 creditNow = _sum(m, creditGrowth0X128);
        uint256 debtNow = _sum(m, debtGrowth0X128);

        if (p.liquidity == 0){
            p.feeSum0LastX128  = feeNow;
            p.creditSum0LastX128 = creditNow;
            p.debtSum0LastX128 = debtNow;
            return;
        }

        uint256 dFee  = feeNow  - p.feeSum0LastX128;
        uint256 dCredit = creditNow - p.creditSum0LastX128;
        uint256 dDebt = debtNow - p.debtSum0LastX128;

        // net growth = fees + credited - debts
        uint256 netGrowth = dFee + dCredit;
        if (dDebt > 0) {
            // cannot underflow since netGrowth, dDebt are uint256
            if (dDebt >= netGrowth) {
                // all net consumed by debt; realize zero but advance checkpoints
                netGrowth = 0;
            } else {
                netGrowth -= dDebt;
            }
        }

        if (netGrowth != 0){
            uint256 add0 = (uint256(p.liquidity) * netGrowth) / Q128;
            if (add0 != 0) p.claimable0 += SafeCast128.toUint128(add0);
        }

        p.feeSum0LastX128  = feeNow;
        p.creditSum0LastX128 = creditNow;
        p.debtSum0LastX128 = debtNow;
    }

    // --- LP ops ---
    function deposit(bytes32 key, uint128 deltaL, uint64 newMask) external {
        Position storage p = positions[key];
        _updatePosition(key);

        if (p.liquidity > 0 && p.cellMask != newMask){
            uint64 removed = p.cellMask & ~newMask;
            uint64 added   = newMask   & ~p.cellMask;
            if (removed != 0) for(uint8 i=0;i<N;++i) if((removed & (uint64(1)<<i))!=0) cellL[i]-=p.liquidity;
            if (added   != 0) for(uint8 i=0;i<N;++i) if((added   & (uint64(1)<<i))!=0) cellL[i]+=p.liquidity;
            p.cellMask = newMask;
            // reset snapshots to current for new mask
            p.feeSum0LastX128  = _sum(newMask, feeGrowth0X128);
            p.creditSum0LastX128 = _sum(newMask, creditGrowth0X128);
            p.debtSum0LastX128 = _sum(newMask, debtGrowth0X128);
        }

        if (deltaL > 0){
            p.liquidity += deltaL;
            if (p.liquidity == deltaL){ // new pos
                p.cellMask = newMask;
                p.feeSum0LastX128  = _sum(newMask, feeGrowth0X128);
                p.creditSum0LastX128 = _sum(newMask, creditGrowth0X128);
                p.debtSum0LastX128 = _sum(newMask, debtGrowth0X128);
            }
            for(uint8 i=0;i<N;++i) if((p.cellMask & (uint64(1)<<i))!=0) cellL[i]+=deltaL;
        }
    }

    function withdraw(bytes32 key, uint128 deltaL) external {
        Position storage p = positions[key];
        require(deltaL <= p.liquidity, "too much");
        _updatePosition(key);
        if (deltaL > 0){
            p.liquidity -= deltaL;
            for(uint8 i=0;i<N;++i) if((p.cellMask & (uint64(1)<<i))!=0) cellL[i]-=deltaL;
        }
    }

    function collect(bytes32 key, uint128 amount0Req) external returns (uint128 amt0){
        _updatePosition(key);
        Position storage p = positions[key];
        amt0 = amount0Req < p.claimable0 ? amount0Req : p.claimable0;
        if (amt0>0){
            p.claimable0 -= amt0;
            // transfer token0 to `to` here
        }
    }

    // --- Cell-side credits/debits ---
    function creditCellFee(uint8 cellId, uint256 fee0) external {
        require(cellId < N, "bad cell");
        uint256 L = cellL[cellId];
        if (L==0){ protocolFees0 += fee0; return; }
        feeGrowth0X128[cellId] += (fee0 * Q128) / L;
    }

    /// @notice credit extra proceeds (e.g., unwind/buyback cheaper than sale).
    function creditCellBank(uint8 cellId, uint256 credited0) external {
        require(cellId < N, "bad cell");
        uint256 L = cellL[cellId];
        if (L==0){ protocolFees0 += credited0; return; }
        creditGrowth0X128[cellId] += (credited0 * Q128) / L;
    }

    /// @notice Optional: socialize a loss (e.g., buyback cost > proceeds).
    function debitCellBank(uint8 cellId, uint256 loss0) external {
        require(cellId < N, "bad cell");
        uint256 L = cellL[cellId];
        if (L==0){ // nobody opted in; route to protocol buffer if you want
            protocolFees0 += 0; // no effect; decide policy
            return;
        }
        debtGrowth0X128[cellId] += (loss0 * Q128) / L;
    }

    // --- Views ---
    function pending(bytes32 key) external view returns (uint256){
        Position storage p = positions[key];
        uint64 m = p.cellMask;
        uint256 feeNow  = _sum(m, feeGrowth0X128);
        uint256 creditNow = _sum(m, creditGrowth0X128);
        uint256 debtNow = _sum(m, debtGrowth0X128);
        if (p.liquidity == 0) return p.claimable0;
        uint256 dFee  = feeNow  - p.feeSum0LastX128;
        uint256 dCredit = creditNow - p.creditSum0LastX128;
        uint256 dDebt = debtNow - p.debtSum0LastX128;
        uint256 netGrowth = dFee + dCredit;
        if (dDebt > netGrowth) netGrowth = 0; else netGrowth -= dDebt;
        return uint256(p.claimable0) + (uint256(p.liquidity) * netGrowth) / Q128;
    }
}
