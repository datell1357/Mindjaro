package com.maeumjaro.app.feature.customization

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CustomizationUiContractTest {
    @Test
    fun inputPolicyKeepsUnicodePhraseAtMost120Characters() {
        val input = "마음".repeat(80)

        val bounded = CustomPhraseInputPolicy.truncate(input)

        assertEquals(CustomPhraseInputPolicy.maxLength, bounded.length)
        assertTrue(input.startsWith(bounded))
    }

    @Test
    fun inputPolicyLeavesShortPhraseUnchanged() {
        val input = "잠시 멈추고 다음 행동을 골라요"

        assertEquals(input, CustomPhraseInputPolicy.truncate(input))
    }
}
