package com.maeumjaro.app.feature.onboarding

import androidx.compose.foundation.Image
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import com.maeumjaro.app.R
import com.maeumjaro.app.content.SafetyCopy
import com.maeumjaro.app.design.PrimaryAction
import com.maeumjaro.app.design.SecondaryAction
import com.maeumjaro.app.design.DesignTokens

@Composable
fun OnboardingScreen(
    initialIntensity: Int,
    pinRequester: WidgetPinRequester,
    onComplete: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    var stepIndex by rememberSaveable { mutableIntStateOf(0) }
    var intensity by rememberSaveable { mutableIntStateOf(initialIntensity) }
    var fallbackVisible by rememberSaveable { mutableStateOf(false) }
    val step = OnboardingStep.entries[stepIndex]
    val titleFocusRequester = remember { FocusRequester() }

    LaunchedEffect(stepIndex) { titleFocusRequester.requestFocus() }

    LazyColumn(
        modifier = modifier.fillMaxSize().padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.spacedBy(DesignTokens.sectionGap),
    ) {
        item { Spacer(Modifier.height(DesignTokens.screenVertical)) }
        item {
            Text(
                text = stringResource(R.string.step_progress, stepIndex + 1),
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.primary,
            )
        }
        item {
            StepContent(
                step,
                intensity,
                onIntensity = { intensity = it },
                modifier = Modifier.focusRequester(titleFocusRequester).focusable(),
            )
        }
        if (step == OnboardingStep.Widget) {
            item {
                PrimaryAction(stringResource(R.string.request_widget), onClick = {
                    fallbackVisible = !pinRequester.request()
                })
            }
            if (fallbackVisible) {
                item {
                    Card(Modifier.fillMaxWidth()) {
                        Text(
                            text = stringResource(R.string.widget_manual_fallback),
                            modifier = Modifier.padding(20.dp),
                            style = MaterialTheme.typography.bodyLarge,
                        )
                    }
                }
            }
            item {
                SecondaryAction(stringResource(R.string.later), onClick = { onComplete(intensity) })
            }
            if (fallbackVisible) {
                item {
                    PrimaryAction(stringResource(R.string.finish), onClick = { onComplete(intensity) })
                }
            }
        } else {
            item {
                PrimaryAction(
                    label = stringResource(R.string.next),
                    onClick = { stepIndex = (stepIndex + 1).coerceAtMost(4) },
                )
            }
        }
        item { Spacer(Modifier.height(32.dp)) }
    }
}

@Composable
private fun StepContent(
    step: OnboardingStep,
    intensity: Int,
    onIntensity: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        if (step == OnboardingStep.UseFlow) {
            Image(
                painter = painterResource(R.drawable.maeumjaro_pen_2d_locked),
                contentDescription = stringResource(R.string.pen_image_description),
                modifier = Modifier.align(Alignment.CenterHorizontally).heightIn(max = 240.dp),
            )
        }
        Text(
            text = stringResource(step.titleResource),
            modifier = modifier.semantics { liveRegion = LiveRegionMode.Polite },
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
        )
        Text(
            text = if (step == OnboardingStep.Disclaimer) SafetyCopy.disclaimer
            else stringResource(step.bodyResource),
            modifier = if (step == OnboardingStep.Disclaimer) {
                Modifier.semantics { contentDescription = SafetyCopy.disclaimer }
            } else Modifier,
            style = MaterialTheme.typography.bodyLarge.copy(lineBreak = DesignTokens.koreanLineBreak),
            lineHeight = MaterialTheme.typography.bodyLarge.lineHeight,
        )
        if (step == OnboardingStep.Intensity) {
            IntensityPicker(intensity, onIntensity)
        }
    }
}

@Composable
private fun IntensityPicker(selected: Int, onSelected: (Int) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        val selectedDescription = stringResource(R.string.intensity_selected_state)
        (1..5).forEach { value ->
            val label = stringResource(R.string.intensity_label, value)
            OutlinedButton(
                onClick = { onSelected(value) },
                modifier = Modifier.size(56.dp).semantics {
                    contentDescription = label
                    if (value == selected) stateDescription = selectedDescription
                },
            ) {
                Text(value.toString())
            }
        }
    }
}

private val OnboardingStep.titleResource: Int
    get() = when (this) {
        OnboardingStep.Purpose -> R.string.onboarding_purpose_title
        OnboardingStep.UseFlow -> R.string.onboarding_flow_title
        OnboardingStep.Intensity -> R.string.onboarding_intensity_title
        OnboardingStep.Disclaimer -> R.string.onboarding_disclaimer_title
        OnboardingStep.Widget -> R.string.onboarding_widget_title
    }

private val OnboardingStep.bodyResource: Int
    get() = when (this) {
        OnboardingStep.Purpose -> R.string.onboarding_purpose_body
        OnboardingStep.UseFlow -> R.string.onboarding_flow_body
        OnboardingStep.Intensity -> R.string.onboarding_intensity_body
        OnboardingStep.Disclaimer -> R.string.onboarding_disclaimer_body
        OnboardingStep.Widget -> R.string.onboarding_widget_body
    }
