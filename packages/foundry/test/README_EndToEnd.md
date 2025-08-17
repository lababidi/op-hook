# OpHook End-to-End Test

This test file (`EndToEnd.t.sol`) provides comprehensive testing for the OpHook contract's core functionality and integration components. The test focuses on validating the essential components that make up the OpHook system without requiring complex Uniswap V4 hook address validation.

## Prerequisites

1. **Dependencies**: Make sure all dependencies are installed:
   ```bash
   yarn install
   ```

## Running the Tests

### Run all tests:
```bash
cd packages/foundry
forge test --match-contract EndToEndTest -vv
```

### Run specific test:
```bash
# Test option price deployment
forge test --match-test test_OptionPriceDeployment -vv

# Test option price contract
forge test --match-test test_OptionPriceContract -vv

# Test mathematical functions
forge test --match-test test_MathematicalFunctions -vv

# Test option token interface compatibility
forge test --match-test test_OptionTokenInterfaceCompatibility -vv

# Test Permit2 integration
forge test --match-test test_Permit2Integration -vv

# Test hook permissions structure
forge test --match-test test_HookPermissions -vv

# Test whitelist logic
forge test --match-test test_WhitelistLogic -vv

# Test swap validation logic
forge test --match-test test_SwapValidationLogic -vv

# Test integration scenarios
forge test --match-test test_IntegrationScenarios -vv
```

## Test Coverage

The test suite covers:

1. **Option Price Contract**: Tests the deployment and basic functionality of the OptionPrice contract
2. **Option Price Integration**: Validates that the option price contract is ready for integration
3. **Mathematical Functions**: Tests the core mathematical functions (ln, expNeg, normCDF) used in pricing
4. **Option Token Interface**: Tests compatibility with the IOptionToken interface
5. **Permit2 Integration**: Validates the Permit2 address and integration points
6. **Hook Permissions**: Tests the Uniswap V4 hook permissions structure
7. **Whitelist Logic**: Tests the token whitelisting functionality
8. **Swap Validation**: Tests the swap validation logic used in beforeSwap
9. **Integration Scenarios**: Validates overall integration readiness

## Important Notes

- The tests focus on core functionality without requiring complex Uniswap V4 hook address validation
- Mock calls are used to simulate option token interactions
- The tests validate the mathematical foundations and business logic
- All tests run in a local environment without requiring forking mainnet
- The test structure allows for easy extension when full Uniswap V4 integration is ready

## Expected Output

When running the tests, you should see:
- All tests passing
- Console logs showing option prices, addresses, and test progress
- Validation that all core components are working correctly

## Test Results Example

```
[PASS] test_OptionPriceDeployment() (gas: 8389)
Logs:
  Option price contract deployed at: 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f

[PASS] test_OptionPriceContract() (gas: 9355)
Logs:
  Option price contract address: 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f
  Option price contract is ready for integration

[PASS] test_MathematicalFunctions() (gas: 86070)
Logs:
  All mathematical functions working correctly

[PASS] test_OptionTokenInterfaceCompatibility() (gas: 14493)
Logs:
  Option token interface compatibility test passed

[PASS] test_Permit2Integration() (gas: 6349)
Logs:
  Permit2 integration test passed
  Permit2 address: 0x000000000022D473030F116dDEE9F6B43aC78BA3

[PASS] test_HookPermissions() (gas: 7125)
Logs:
  Hook permissions structure test passed

[PASS] test_WhitelistLogic() (gas: 13590)
Logs:
  Whitelist logic test passed

[PASS] test_SwapValidationLogic() (gas: 5971)
Logs:
  Zero for one swap logic validated
  Swap validation logic test passed

[PASS] test_IntegrationScenarios() (gas: 16508)
Logs:
  Testing integration scenarios:
  1. Hook deployment and initialization
  2. Option token whitelisting
  3. Price calculation integration
  4. Swap execution flow
  5. Error handling and validation
  All integration scenarios validated
```

## Troubleshooting

If you encounter issues:

1. **Compilation Issues**: Make sure all dependencies are properly installed
2. **Mathematical Errors**: The Black-Scholes test uses conservative parameters to avoid overflow
3. **Mock Call Issues**: The option token interface tests use mock calls that should work in any environment

## Next Steps

To extend these tests for full OpHook integration:

1. **Deploy with Valid Hook Address**: Deploy the OpHook to an address with the correct permission bits set
2. **Set up Uniswap V4 Pool**: Create a real pool with the hook attached
3. **Deploy Option Tokens**: Create actual option tokens for testing
4. **Test Real Swaps**: Test actual swap transactions through the hook
5. **Add Integration Tests**: Test the full flow from option creation to swap execution

## Architecture Overview

The test validates these key components:

```
OpHook System Components:
├── OptionPrice Contract (Black-Scholes pricing)
├── IOptionToken Interface (Option token interactions)
├── Permit2 Integration (Token approvals)
├── Whitelist Logic (Token validation)
├── Swap Validation (beforeSwap logic)
└── Hook Permissions (Uniswap V4 integration)
```

This test suite ensures that all these components work correctly before attempting full Uniswap V4 integration.
