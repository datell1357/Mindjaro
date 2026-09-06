package com.maeumjaro.app.feature.settings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import com.maeumjaro.app.R
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp

data class SettingsUiState(
    val intensity: Int = 3,
    val hapticEnabled: Boolean = true,
    val soundEnabled: Boolean = false,
    val reducedMotionEnabled: Boolean = false,
    val phraseToneLabel: String = "자동",
    val deleteStatus: SettingsDeleteStatus = SettingsDeleteStatus.Idle,
    val intensityStatus: SettingsOperationStatus = SettingsOperationStatus.Idle,
    val exportStatus: SettingsOperationStatus = SettingsOperationStatus.Idle,
)

enum class SettingsDeleteStatus { Idle, Deleting, DatabaseFailure, ProjectionPending }
enum class SettingsOperationStatus { Idle, Working, Failure }

@Composable
fun SettingsScreen(
    state: SettingsUiState,
    onIntensityChanged: (Int) -> Unit,
    onHapticChanged: (Boolean) -> Unit,
    onSoundChanged: (Boolean) -> Unit,
    onReducedMotionChanged: (Boolean) -> Unit,
    onPhraseToneChanged: () -> Unit,
    onExport: () -> Unit,
    onDeleteAll: () -> Unit,
    onOpenPro: () -> Unit,
    modifier: Modifier = Modifier,
    onOpenCustomization: () -> Unit = {},
    onOpenAnalytics: () -> Unit = {},
    onRetryDeleteAll: () -> Unit = onDeleteAll,
    onRetryIntensity: () -> Unit = {},
    onRetryExport: () -> Unit = {},
) {
    var showDeleteConfirmation by remember { mutableStateOf(false) }
    Column(modifier.padding(24.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(18.dp)) {
        Text(stringResource(R.string.settings_title), style = MaterialTheme.typography.headlineMedium)
        Text(stringResource(R.string.settings_body))
        Text("기본 강도 ${state.intensity}")
        Slider(
            value = state.intensity.toFloat(),
            onValueChange = { onIntensityChanged(it.toInt().coerceIn(1, 5)) },
            valueRange = 1f..5f,
            steps = 3,
            modifier = Modifier.fillMaxWidth().semantics { contentDescription = "기본 강도" },
        )
        if (state.intensityStatus == SettingsOperationStatus.Failure) {
            Text("강도 설정을 저장했지만 홈 화면 동기화에 실패했어요.")
            TextButton(onClick = onRetryIntensity) { Text("다시 시도") }
        }
        SettingSwitch("햅틱", state.hapticEnabled, onHapticChanged)
        SettingSwitch("소리", state.soundEnabled, onSoundChanged)
        SettingSwitch("동작 줄이기", state.reducedMotionEnabled, onReducedMotionChanged)
        ActionText("문구 톤: ${state.phraseToneLabel}", onPhraseToneChanged)
        HorizontalDivider()
        Text("안전 안내", style = MaterialTheme.typography.titleMedium)
        Text("의료기기나 의약품이 아니며 진단이나 치료를 위한 앱이 아니에요. 화면 속 표현은 자기조절을 위한 가상 의식입니다.")
        Text("위젯 설정 도움말: 홈 화면을 길게 누르고 위젯 메뉴에서 마음자로를 선택하세요.")
        ActionText("Pro 안내", onOpenPro)
        ActionText("상세 분석", onOpenAnalytics)
        ActionText("나만의 설정", onOpenCustomization)
        ActionText("전체 기록 내보내기", onExport)
        if (state.exportStatus == SettingsOperationStatus.Failure) {
            Text("기록을 내보내지 못했어요. 다시 시도해 주세요.")
            TextButton(onClick = onRetryExport) { Text("다시 시도") }
        }
        ActionText("모든 기록 삭제", onClick = { showDeleteConfirmation = true })
        when (state.deleteStatus) {
            SettingsDeleteStatus.DatabaseFailure -> {
                Text("기록을 삭제하지 못했어요. 저장소를 확인한 뒤 다시 시도해 주세요.")
                TextButton(onClick = onRetryDeleteAll, modifier = Modifier.heightIn(min = 48.dp)) { Text("다시 시도") }
            }
            SettingsDeleteStatus.Deleting -> Text("기록을 삭제하는 중…")
            SettingsDeleteStatus.ProjectionPending -> Text("기록은 삭제됐어요. 홈 화면 표시는 다음 동기화에서 정리됩니다.")
            SettingsDeleteStatus.Idle -> Unit
        }
    }
    if (showDeleteConfirmation) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirmation = false },
            title = { Text("모든 기록을 삭제할까요?") },
            text = { Text("삭제한 기록은 복구할 수 없어요.") },
            confirmButton = {
                TextButton(
                    onClick = { showDeleteConfirmation = false; onDeleteAll() },
                    modifier = Modifier.heightIn(min = 48.dp),
                ) { Text("삭제") }
            },
            dismissButton = {
                TextButton(
                    onClick = { showDeleteConfirmation = false },
                    modifier = Modifier.heightIn(min = 48.dp),
                ) { Text("취소") }
            },
        )
    }
}

@Composable
private fun SettingSwitch(label: String, checked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label)
        Switch(checked, onCheckedChange, modifier = Modifier.semantics { contentDescription = label })
    }
}

@Composable
private fun ActionText(label: String, onClick: () -> Unit) {
    androidx.compose.material3.TextButton(
        onClick = onClick,
        modifier = Modifier.heightIn(min = 48.dp),
    ) { Text(label) }
}
