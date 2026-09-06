package com.maeumjaro.app.feature.history.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.disabled
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.maeumjaro.app.design.PrimaryAction
import com.maeumjaro.app.design.SecondaryAction
import com.maeumjaro.app.feature.history.DayDetailState
import com.maeumjaro.app.feature.history.HeatmapCellState
import com.maeumjaro.app.feature.history.HeatmapMetric
import com.maeumjaro.app.feature.history.HistoryDashboardState
import com.maeumjaro.app.feature.history.HistoryRecordItem
import com.maeumjaro.app.feature.history.RecordDetailState
import java.time.LocalDate

@Composable
fun HistoryDashboard(
    state: HistoryDashboardState,
    onDaySelected: (LocalDate) -> Unit,
    onRecordSelected: (HistoryRecordItem) -> Unit,
    modifier: Modifier = Modifier,
) {
    var metric by remember { mutableStateOf(HeatmapMetric.COUNT) }
    Column(
        modifier = modifier.verticalScroll(rememberScrollState()).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text("나의 기록", style = MaterialTheme.typography.headlineMedium)
        SummaryCard(state)
        SectionTitle("최근 기록")
        if (state.latest.isEmpty()) Text("아직 기록이 없어요.", style = MaterialTheme.typography.bodyLarge)
        state.latest.forEach { record ->
            RecordRow(record, onClick = { onRecordSelected(record) })
        }
        SectionTitle(if (state.entitlement.name == "PRO") "최근 52주" else "최근 30일")
        state.visibleHistory.groupBy { it.date }.toSortedMap(reverseOrder()).forEach { (date, records) -> DayRow(date, records.size, onClick = { onDaySelected(date) }) }
        Text(state.sampleCopy, style = MaterialTheme.typography.bodyMedium)
        SectionTitle("${state.visibleHeatmapWeeks}주 기록")
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            FilterChip(metric == HeatmapMetric.COUNT, { metric = HeatmapMetric.COUNT }, label = { Text("횟수") })
            FilterChip(metric == HeatmapMetric.INTENSITY_SUM, { metric = HeatmapMetric.INTENSITY_SUM }, label = { Text("누적 강도") })
        }
        HeatmapGrid(state.heatmap, metric, onDaySelected)
    }
}

@Composable
private fun SummaryCard(state: HistoryDashboardState) {
    val day = state.todaySummary
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("오늘 · ${state.today}", style = MaterialTheme.typography.titleMedium)
            Text("${day.count}회", style = MaterialTheme.typography.headlineSmall)
            Text("누적 강도 ${day.intensitySum} · 평균 강도 ${"%.1f".format(day.averageIntensity)}", style = MaterialTheme.typography.bodyLarge)
        }
    }
}

@Composable
private fun SectionTitle(text: String) = Text(text, style = MaterialTheme.typography.titleLarge)

@Composable
private fun RecordRow(record: HistoryRecordItem, onClick: () -> Unit) {
    Card(
        Modifier.fillMaxWidth().heightIn(min = 64.dp).clickable(onClick = onClick).semantics(mergeDescendants = true) {
            contentDescription = "기록 ${record.date} ${record.time}, 강도 ${record.intensity.value}"
        },
    ) {
        Row(Modifier.padding(16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(
                "강도 ${record.intensity.value}",
                modifier = Modifier
                    .background(MaterialTheme.colorScheme.secondaryContainer, RoundedCornerShape(16.dp))
                    .padding(horizontal = 12.dp, vertical = 8.dp),
                color = MaterialTheme.colorScheme.onSecondaryContainer,
            )
            Column(Modifier.weight(1f)) {
                Text(record.time.toString(), style = MaterialTheme.typography.titleMedium)
                Text(record.date.toString(), style = MaterialTheme.typography.bodyMedium)
            }
        }
    }
}

@Composable
private fun DayRow(date: LocalDate, count: Int, onClick: () -> Unit) {
    OutlinedButton(onClick = onClick, Modifier.fillMaxWidth().heightIn(min = 52.dp)) {
        Text("$date  ·  ${count}회")
    }
}

@Composable
fun HeatmapGrid(
    cells: List<HeatmapCellState>,
    metric: HeatmapMetric,
    onDaySelected: (LocalDate) -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier.horizontalScroll(rememberScrollState()).semantics {
            contentDescription = when (metric) {
                HeatmapMetric.COUNT -> "히트맵 모드: 횟수"
                HeatmapMetric.INTENSITY_SUM -> "히트맵 모드: 누적 강도"
            }
        },
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        cells.take((cells.size / 7) * 7).chunked(7).forEach { week ->
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                week.forEach { cell ->
                    val level = cell.level(metric)
                    Box(
                        Modifier.size(48.dp)
                            .then(if (cell.enabled) Modifier.clickable { onDaySelected(cell.date) } else Modifier)
                            .semantics {
                                contentDescription = cell.semanticDescription
                                if (!cell.enabled) disabled()
                            },
                    ) {
                        Box(Modifier.size(18.dp).background(heatColor(level.value), RoundedCornerShape(3.dp)))
                    }
                }
            }
        }
    }
}

@Composable
private fun heatColor(level: Int): Color = when (level.coerceIn(0, 5)) {
    0 -> MaterialTheme.colorScheme.surfaceVariant
    1 -> Color(0xFFB9E4D0)
    2 -> Color(0xFF78CDA7)
    3 -> Color(0xFF3EA77C)
    4 -> Color(0xFF167A55)
    else -> Color(0xFF075238)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DayDetailSheet(
    detail: DayDetailState,
    onDismiss: () -> Unit,
    onRecordSelected: (HistoryRecordItem) -> Unit,
) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
    ) {
        Column(
            Modifier.verticalScroll(rememberScrollState()).padding(20.dp).padding(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text("${detail.date} 기록", style = MaterialTheme.typography.headlineSmall)
            Text("총 ${detail.count}회")
            Text("누적 강도 ${detail.intensitySum} · 평균 강도 ${"%.1f".format(detail.averageIntensity)}")
            if (detail.records.isEmpty()) Text("이 날의 기록이 없어요.")
            detail.records.forEach { record ->
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = 48.dp)
                        .semantics(mergeDescendants = true) {
                            contentDescription = "기록 ${record.date} ${record.time}, 강도 ${record.intensity.value}"
                        },
                    contentAlignment = androidx.compose.ui.Alignment.CenterStart,
                ) { Text("${record.time} · 강도 ${record.intensity.value}") }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RecordDetailSheet(
    detail: RecordDetailState,
    onDismiss: () -> Unit,
    onIntensityChanged: (Int) -> Unit,
    onDeleteConfirmed: () -> Unit,
) {
    var intensity by remember(detail.id, detail.intensity) { mutableIntStateOf(detail.intensity.value) }
    var showDeleteConfirmation by remember { mutableStateOf(false) }
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
    ) {
        Column(
            Modifier.fillMaxHeight(0.8f).verticalScroll(rememberScrollState()).padding(20.dp).navigationBarsPadding().padding(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text("기록 상세", style = MaterialTheme.typography.headlineSmall)
            Text("${detail.date} · ${detail.time}", style = MaterialTheme.typography.bodyLarge)
            Text("진입 경로: ${if (detail.source.name == "WIDGET") "위젯" else "앱"}")
            Text(detail.phraseText, style = MaterialTheme.typography.bodyLarge)
            Text("강도 $intensity", style = MaterialTheme.typography.titleMedium)
            Slider(value = intensity.toFloat(), onValueChange = { intensity = it.toInt().coerceIn(1, 5) }, valueRange = 1f..5f, steps = 3)
            PrimaryAction("강도 저장", onClick = { onIntensityChanged(intensity) })
            SecondaryAction("이 기록 삭제", onClick = { showDeleteConfirmation = true })
        }
    }
    if (showDeleteConfirmation) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirmation = false },
            title = { Text("기록을 삭제할까요?") },
            text = { Text("삭제한 기록은 되돌릴 수 없어요.") },
            confirmButton = { TextButton(onClick = { showDeleteConfirmation = false; onDeleteConfirmed() }) { Text("삭제") } },
            dismissButton = { TextButton(onClick = { showDeleteConfirmation = false }) { Text("취소") } },
        )
    }
}
