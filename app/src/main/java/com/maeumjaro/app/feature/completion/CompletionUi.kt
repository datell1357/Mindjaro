package com.maeumjaro.app.feature.completion

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.maeumjaro.app.R
import com.maeumjaro.app.design.PrimaryAction
import com.maeumjaro.app.design.SecondaryAction
import com.maeumjaro.app.core.Phrase
import com.maeumjaro.app.data.local.StoredInjectionEvent
import com.maeumjaro.app.feature.injection.InjectionRoute
import com.maeumjaro.app.feature.injection.InjectionViewModel
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter

@Composable
fun InjectionCompletionRoute(
    viewModel: InjectionViewModel,
    onCompleted: (CompletionResult.Success) -> Unit,
    modifier: Modifier = Modifier,
) {
    val completion by viewModel.completionState.collectAsState()
    Box(modifier.fillMaxSize()) {
        InjectionRoute(viewModel)
        if (completion is CompletionUiState.Failed) {
            Card(Modifier.align(Alignment.BottomCenter).padding(20.dp).fillMaxWidth()) {
                Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text("완료를 저장하지 못했어요.", style = MaterialTheme.typography.titleMedium)
                    Text("기록은 아직 저장되지 않았어요. 같은 내용으로 다시 시도할 수 있어요.")
                    PrimaryAction("다시 시도", onClick = viewModel::retryCompletion)
                }
            }
        }
    }
    val success = (completion as? CompletionUiState.Completed)?.result
    LaunchedEffect(success?.attempt?.event?.id) {
        if (success != null) onCompleted(success)
    }
}

@Composable
fun CompletionScreen(
    event: StoredInjectionEvent,
    phrase: Phrase,
    onAgain: () -> Unit,
    onViewRecords: () -> Unit,
    modifier: Modifier = Modifier,
    projectionPending: Boolean = false,
) {
    val offset = ZoneOffset.ofTotalSeconds(event.timezoneOffsetMinutes * 60)
    val completionTime = event.completedAtUtc.atOffset(offset).format(DateTimeFormatter.ofPattern("a h:mm"))
    Column(
        modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        Image(
            painter = painterResource(R.drawable.maeumjaro_pen_2d_complete),
            contentDescription = null,
            modifier = Modifier.heightIn(max = 240.dp),
        )
        Text("마음 정리를 마쳤어요", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        Text("강도 ${event.intensity.value} · $completionTime", style = MaterialTheme.typography.titleMedium)
        Card(Modifier.fillMaxWidth()) {
            Text(phrase.text, Modifier.padding(20.dp), style = MaterialTheme.typography.bodyLarge)
        }
        if (projectionPending) {
            Text("기록은 저장됐어요. 홈 화면 표시는 다음 동기화에서 정리됩니다.", style = MaterialTheme.typography.bodySmall)
        }
        PrimaryAction("다시 실행", onClick = onAgain, modifier = Modifier.fillMaxWidth())
        SecondaryAction("기록 보기", onClick = onViewRecords, modifier = Modifier.fillMaxWidth())
    }
}
