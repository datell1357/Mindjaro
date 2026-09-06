package com.maeumjaro.app.feature.analytics

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp

/** A factual, local-only Pro report. No outcome, health, or success interpretation is added here. */
@Composable
fun ProAnalyticsScreen(
    report: AnalyticsReport,
    onExportJson: () -> Unit,
    modifier: Modifier = Modifier,
    exportStatus: JsonExportStatus = JsonExportStatus.Idle,
    onRetryExport: () -> Unit = onExportJson,
) {
    Column(
        modifier = modifier.verticalScroll(rememberScrollState()).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text("상세 기록 분석", style = MaterialTheme.typography.headlineMedium)
        Text("${report.period.start} ~ ${report.period.end} · 총 ${report.totalCount}회")
        SampleNotice(report.sampleTier)

        if (report.sampleTier.ordinal >= SampleTier.SUMMARY.ordinal) {
            DistributionCard("3시간대별 기록", report.threeHourCounts, listOf("00–02시", "03–05시", "06–08시", "09–11시", "12–14시", "15–17시", "18–20시", "21–23시"))
            DistributionCard("요일별 기록", report.weekdayCounts, listOf("월요일", "화요일", "수요일", "목요일", "금요일", "토요일", "일요일"))
            DistributionCard("강도별 기록", report.intensityCounts, (1..5).map { "강도 $it" })
        }

        report.comparison?.let { comparison ->
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("최근 4주와 이전 4주", style = MaterialTheme.typography.titleMedium)
                    ComparisonRow("최근 4주", comparison.recent)
                    ComparisonRow("이전 4주", comparison.previous)
                    Text("각 기간의 기록 수와 활동 일수를 비교해요.", style = MaterialTheme.typography.bodySmall)
                }
            }
        }

        TextButton(
            onClick = if (exportStatus == JsonExportStatus.Working) ({}) else onExportJson,
            modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp),
        ) { Text(if (exportStatus == JsonExportStatus.Working) "JSON을 준비하는 중" else "JSON으로 내보내기") }
        if (exportStatus == JsonExportStatus.Failure) {
            Text("JSON 내보내기에 실패했어요. 기록은 변경되지 않았어요.")
            TextButton(onClick = onRetryExport) { Text("다시 시도") }
        }
    }
}

enum class JsonExportStatus { Idle, Working, Failure }

@Composable
private fun SampleNotice(tier: SampleTier) {
    val copy = when (tier) {
        SampleTier.NEEDS_MORE -> "기록이 더 필요해요"
        SampleTier.EARLY -> "현재 기록 수를 바탕으로 예비 분포만 보여드려요."
        SampleTier.SUMMARY -> "현재 기록 수를 바탕으로 시간대·요일·강도 분포를 보여드려요."
        SampleTier.COMPARISON -> "최근 4주와 이전 4주의 기록을 함께 비교해요."
    }
    Text(copy, style = MaterialTheme.typography.bodyLarge)
}

@Composable
private fun DistributionCard(title: String, values: List<Int>, labels: List<String>) {
    val max = values.maxOrNull()?.coerceAtLeast(1) ?: 1
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(title, style = MaterialTheme.typography.titleMedium)
            values.zip(labels).forEach { (value, label) ->
                Row(
                    Modifier.fillMaxWidth().semantics { contentDescription = "$label, ${value}회" },
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Text(label, modifier = Modifier.weight(1f))
                    LinearProgressIndicator(
                        progress = { value.toFloat() / max },
                        modifier = Modifier.weight(1.5f),
                    )
                    Text("${value}회")
                }
            }
        }
    }
}

@Composable
private fun ComparisonRow(label: String, summary: PeriodSummary) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label)
        Text("${summary.count}회 · ${summary.activeDays}일 활동")
    }
}
