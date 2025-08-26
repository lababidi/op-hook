# todo list
- create _decimalsOffset() of 18
- keep track of loaned assets
- modify totalAssets to include loaned assets
- on redemption, modify the loaned assets to account for PnL
- keep track of cash, and cash proceeds from option sales
- on redemption, convert certain amount of cash to Underlying using uniswap [need to keep track of which cash is ready for redemption, need uniswap pool for underlying swap]
- implement balanceof all the options of the hook/vault