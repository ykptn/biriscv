# Test Results - MUL with delayed result usage

## Test Description
This test performs:
1. A multiplication (5 × 8 = 40)
2. 20 unrelated instructions
3. Uses the mul result in an addition (40 + 100 = 140)

## Results

### Standard MUL Instruction
- **Total cycles: 56**
- Test: PASSED
- Configuration: SUPPORT_MULDIV(1), SUPPORT_MUL_BYPASS(1), SUPPORT_DUAL_ISSUE(0)

### MULE Instruction (Custom)
- **Total cycles: 56**
- Test: PASSED
- Configuration: SUPPORT_MULDIV(1), SUPPORT_MUL_BYPASS(1), SUPPORT_DUAL_ISSUE(0)

## Conclusion
Both MUL and MULE instructions completed the test in **56 cycles** with no performance difference. This indicates that when using the result after 20 unrelated instructions, both multipliers have completed their operation and the bypass mechanism works equally well for both.
