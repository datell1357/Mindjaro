package com.maeumjaro.app.design

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import com.maeumjaro.app.feature.analytics.Entitlement

private val LightColors = lightColorScheme(
    primary = Navy,
    onPrimary = Color.White,
    secondary = Mint,
    tertiary = Violet,
    background = CanvasLight,
    onBackground = TextLight,
    surface = AppLight,
    onSurface = TextLight,
    surfaceVariant = SoftLight,
    onSurfaceVariant = TextSecondaryLight,
    outline = BorderLight,
)

private val DarkColors = darkColorScheme(
    primary = Color(0xFFB9C8F0),
    onPrimary = Color(0xFF102044),
    secondary = Mint,
    tertiary = Color(0xFFCAC4FF),
    background = CanvasDark,
    onBackground = TextDark,
    surface = AppDark,
    onSurface = TextDark,
    surfaceVariant = SoftDark,
    onSurfaceVariant = TextSecondaryDark,
    outline = BorderDark,
)

@Composable
fun MaeumjaroTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    themeId: String = "default",
    entitlement: Entitlement = Entitlement.FREE,
    content: @Composable () -> Unit,
) {
    val useDusk = entitlement == Entitlement.PRO && themeId == "dusk"
    MaterialTheme(
        colorScheme = if (darkTheme || useDusk) DarkColors else LightColors,
        typography = DesignTokens.typography,
        content = content,
    )
}
