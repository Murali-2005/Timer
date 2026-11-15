package com.example.ui.theme

import androidx.compose.ui.graphics.Color

// Pure Pitch Black & Monochrome Grey Design System
val TrueBlack = Color(0xFF000000)
val DarkGrey950 = Color(0xFF0A0A0A)
val DarkGrey900 = Color(0xFF121214)
val DarkGrey850 = Color(0xFF18181B)
val DarkGrey800 = Color(0xFF222226)
val DarkGrey700 = Color(0xFF2E2E33)
val DarkGrey600 = Color(0xFF3F3F46)
val MidGrey500 = Color(0xFF71717A)
val LightGrey400 = Color(0xFFA1A1AA)
val SilverGrey300 = Color(0xFFD4D4D8)
val SilverGrey200 = Color(0xFFE4E4E7)
val PureWhite = Color(0xFFFFFFFF)

// Semantic Dark Palette Mappings
val Slate950 = TrueBlack       // Pure pitch black AMOLED background
val Slate900 = DarkGrey900     // Primary card/surface dark grey
val Slate850 = DarkGrey850     // Secondary elevated surface
val Slate800 = DarkGrey800     // Inner container dark grey
val Slate700 = DarkGrey700     // Outline and divider graphite grey
val Slate600 = DarkGrey600     // Muted surface grey
val Slate400 = LightGrey400    // Secondary text silver grey
val Slate200 = SilverGrey200   // Primary highlight silver
val Slate100 = PureWhite       // High-contrast pure white

// Monochrome Accents (Grey & Black theme)
val CyanAccent = PureWhite     // Primary crisp white indicator
val CyanGlow = SilverGrey200   // Luminous silver
val AmberAccent = LightGrey400 // Muted silver-grey
val AmberLight = SilverGrey200 // Crisp silver
val EmeraldBreak = SilverGrey300 // Calm silver break indicator
val EmeraldLight = PureWhite   // Pure white highlight
val RoseDeter = DarkGrey600    // Subtle dark graphite for pause/alert
val IndigoPrimary = SilverGrey200
val VioletDeep = LightGrey400

// Lighter Button Styling for minimal distraction from timer
val ButtonLightGrey = Color(0xFFD4D4D8)         // Light silver grey
val ButtonLightGreyDisabled = Color(0xFF1E1E22) // Inactive button dark tone
val ButtonLightText = Color(0xFF18181B)         // Dark charcoal label
val ButtonDisabledText = Color(0xFF52525B)      // Subdued inactive label
