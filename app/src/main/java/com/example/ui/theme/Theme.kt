package com.example.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// Pure Black and Grey Dark Color Scheme (Always Dark Mode)
private val BlackAndGreyColorScheme = darkColorScheme(
    primary = PureWhite,
    onPrimary = TrueBlack,
    primaryContainer = DarkGrey800,
    onPrimaryContainer = PureWhite,
    secondary = SilverGrey200,
    onSecondary = TrueBlack,
    secondaryContainer = DarkGrey850,
    onSecondaryContainer = PureWhite,
    tertiary = SilverGrey300,
    onTertiary = TrueBlack,
    background = TrueBlack,
    onBackground = PureWhite,
    surface = DarkGrey900,
    onSurface = PureWhite,
    surfaceVariant = DarkGrey800,
    onSurfaceVariant = LightGrey400,
    outline = DarkGrey700,
    outlineVariant = DarkGrey600,
    error = LightGrey400,
    onError = TrueBlack
)

@Composable
fun MyApplicationTheme(
    darkTheme: Boolean = true, // Always dark mode as requested
    dynamicColor: Boolean = false, // Always enforce custom black and grey palette
    content: @Composable () -> Unit
) {
    // Always use Black and Grey Dark theme
    MaterialTheme(
        colorScheme = BlackAndGreyColorScheme,
        typography = Typography,
        content = content
    )
}
