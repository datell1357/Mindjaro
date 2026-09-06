package com.maeumjaro.app.feature.customization

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.maeumjaro.app.core.PhraseCategory
import com.maeumjaro.app.core.PhraseId
import com.maeumjaro.app.core.PhraseTone
import com.maeumjaro.app.feature.analytics.Entitlement
import kotlinx.coroutines.launch

@Composable
fun CustomizationScreen(
    state: CustomizationUiState,
    onThemeSelected: (String) -> Unit,
    onSavePhrase: (String, PhraseTone, PhraseCategory) -> Unit,
    onUpdatePhrase: (PhraseId, String, PhraseTone, PhraseCategory) -> Unit,
    onArchivePhrase: (com.maeumjaro.app.core.PhraseId) -> Unit,
    onPresetChanged: (Int, Int) -> Unit,
    onPresetDeleted: (Int) -> Unit,
    modifier: Modifier = Modifier,
    errorMessage: String? = null,
) {
    var phraseText by remember { mutableStateOf("") }
    var selectedTone by remember { mutableStateOf(PhraseTone.NEUTRAL) }
    var selectedCategory by remember { mutableStateOf(PhraseCategory.AUTONOMY) }
    var editingPhraseId by remember { mutableStateOf<PhraseId?>(null) }
    val scrollState = rememberScrollState()
    val scope = rememberCoroutineScope()
    LaunchedEffect(state.phrases) {
        if (editingPhraseId != null && state.phrases.none { it.id == editingPhraseId && !it.archived }) {
            editingPhraseId = null
            phraseText = ""
            selectedTone = PhraseTone.NEUTRAL
            selectedCategory = PhraseCategory.AUTONOMY
        }
    }
    Column(modifier.padding(24.dp).verticalScroll(scrollState), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text("나만의 설정", style = MaterialTheme.typography.headlineMedium)
        Text(if (state.entitlement == Entitlement.PRO) "Pro 설정을 사용할 수 있어요." else "기본 설정을 사용 중이에요. Pro에서 더 많은 설정을 열 수 있어요.")
        Text("테마", style = MaterialTheme.typography.titleLarge)
        state.themes.forEach { option ->
            FilterChip(
                selected = option.isSelected,
                onClick = { if (!option.isLocked) onThemeSelected(option.theme.id) },
                label = { Text(if (option.isLocked) "${option.theme.id} · Pro" else option.theme.id) },
                enabled = !option.isLocked,
                modifier = Modifier.semantics { contentDescription = "테마 ${option.theme.id}" },
            )
        }
        Text("나만의 문구", style = MaterialTheme.typography.titleLarge)
        OutlinedTextField(
            value = phraseText,
            onValueChange = { phraseText = CustomPhraseInputPolicy.truncate(it) },
            label = { Text("문구") },
            supportingText = { Text("의료·효능 표현 없이 ${CustomPhraseInputPolicy.maxLength}자 이내 · ${phraseText.length}/${CustomPhraseInputPolicy.maxLength}") },
            modifier = Modifier.fillMaxWidth(),
            enabled = state.entitlement == Entitlement.PRO,
        )
        Text("문구 톤", style = MaterialTheme.typography.titleMedium)
        PhraseTone.entries.forEach { tone ->
            FilterChip(
                selected = selectedTone == tone,
                onClick = { selectedTone = tone },
                label = { Text(tone.label()) },
                enabled = state.entitlement == Entitlement.PRO,
            )
        }
        Text("문구 카테고리", style = MaterialTheme.typography.titleMedium)
        PhraseCategory.entries.forEach { category ->
            FilterChip(
                selected = selectedCategory == category,
                onClick = { selectedCategory = category },
                label = { Text(category.label()) },
                enabled = state.entitlement == Entitlement.PRO,
            )
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(
                onClick = {
                    editingPhraseId?.let { onUpdatePhrase(it, phraseText, selectedTone, selectedCategory) }
                        ?: onSavePhrase(phraseText, selectedTone, selectedCategory)
                },
                enabled = state.entitlement == Entitlement.PRO && phraseText.isNotBlank(),
            ) { Text(if (editingPhraseId == null) "문구 저장" else "문구 수정 저장") }
            if (editingPhraseId != null) {
                OutlinedButton(onClick = {
                    editingPhraseId = null
                    phraseText = ""
                    selectedTone = PhraseTone.NEUTRAL
                    selectedCategory = PhraseCategory.AUTONOMY
                }) { Text("취소") }
            }
        }
        state.phrases.filter { !it.archived }.forEach { phrase ->
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(phrase.text)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedButton(onClick = {
                            editingPhraseId = phrase.id
                            phraseText = phrase.text
                            selectedTone = phrase.tone
                            selectedCategory = phrase.category
                            scope.launch { scrollState.scrollTo(0) }
                        }, modifier = Modifier.semantics {
                            contentDescription = "문구 ${phrase.text} 편집"
                        }) { Text("편집") }
                        OutlinedButton(
                            onClick = { onArchivePhrase(phrase.id) },
                            modifier = Modifier.semantics {
                                contentDescription = "문구 ${phrase.text} 보관"
                            },
                        ) { Text("보관") }
                    }
                }
            }
        }
        Text("위젯별 강도", style = MaterialTheme.typography.titleLarge)
        Text(if (state.entitlement == Entitlement.PRO) "설치된 위젯별 강도를 설정할 수 있어요." else "위젯별 강도 지정은 Pro에서 사용할 수 있어요.")
        val widgetIds = WidgetPresetPresentation.ids(state.installedWidgetIds, state.widgetPresets)
        if (widgetIds.isEmpty()) {
            Text("설치된 마음자로 위젯이 없어요. 홈 화면에서 위젯을 먼저 추가해 주세요.")
        }
        widgetIds.forEach { widgetId ->
            val intensity = state.widgetPresets[widgetId]
            Column(Modifier.fillMaxWidth()) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(
                        WidgetPresetPresentation.label(widgetId, intensity, state.globalIntensity),
                    )
                    if (intensity != null) OutlinedButton(onClick = { onPresetDeleted(widgetId) }) { Text("전역으로") }
                    else OutlinedButton(
                        onClick = { onPresetChanged(widgetId, state.globalIntensity) },
                        enabled = state.entitlement == Entitlement.PRO,
                    ) { Text("고정하기") }
                }
                if (intensity != null) Slider(
                        value = intensity.toFloat(),
                        onValueChange = { onPresetChanged(widgetId, it.toInt().coerceIn(1, 5)) },
                        valueRange = 1f..5f,
                        steps = 3,
                        enabled = state.entitlement == Entitlement.PRO,
                        modifier = Modifier.semantics { contentDescription = "위젯 $widgetId 고정 강도" },
                    )
            }
        }
        (errorMessage ?: state.errorMessage)?.let { Text(it, color = MaterialTheme.colorScheme.error) }
    }
}

private fun PhraseTone.label(): String = when (this) {
    PhraseTone.GENTLE -> "부드럽게"
    PhraseTone.NEUTRAL -> "중립적으로"
    PhraseTone.FIRM -> "단호하게"
    PhraseTone.AUTOMATIC -> "자동"
}

private fun PhraseCategory.label(): String = when (this) {
    PhraseCategory.SEPARATION -> "감정과 거리 두기"
    PhraseCategory.IMPERMANENCE -> "지나감 바라보기"
    PhraseCategory.AUTONOMY -> "선택권"
    PhraseCategory.REDIRECT -> "다음 행동 고르기"
    PhraseCategory.NONJUDGMENT -> "판단 없이 보기"
}
