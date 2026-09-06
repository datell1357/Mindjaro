package com.maeumjaro.app.design

import androidx.compose.material3.Typography
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.text.style.LineBreak

object DesignTokens {
    val screenHorizontal = 20.dp
    val screenVertical = 28.dp
    val contentGap = 16.dp
    val sectionGap = 20.dp
    val bodyLineHeight = 1.35f
    val koreanLineBreak = LineBreak(
        strategy = LineBreak.Strategy.HighQuality,
        strictness = LineBreak.Strictness.Strict,
        wordBreak = LineBreak.WordBreak.Phrase,
    )
    val typography = Typography().run {
        copy(
            headlineMedium = headlineMedium.copy(fontSize = 28.sp, lineHeight = 36.sp),
            bodyLarge = bodyLarge.copy(fontSize = 18.sp, lineHeight = 27.sp),
            labelLarge = labelLarge.copy(fontSize = 14.sp, lineHeight = 20.sp),
        )
    }
}
