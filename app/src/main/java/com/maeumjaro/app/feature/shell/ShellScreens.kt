package com.maeumjaro.app.feature.shell

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.maeumjaro.app.R
import com.maeumjaro.app.content.SafePhraseCatalog
import com.maeumjaro.app.content.SafetyCopy
import com.maeumjaro.app.core.Phrase
import com.maeumjaro.app.design.PrimaryAction
import com.maeumjaro.app.design.SecondaryAction
import com.maeumjaro.app.design.DesignTokens

@Composable
fun RecordsScreen(intensity: Int, navigate: (ShellAction) -> Unit) {
    ScreenColumn {
        Image(
            painter = painterResource(R.drawable.maeumjaro_pen_2d_locked),
            contentDescription = stringResource(R.string.pen_image_description),
            modifier = Modifier.align(Alignment.CenterHorizontally).heightIn(max = 220.dp),
        )
        ScreenHeading(R.string.records_title, R.string.records_empty)
        StatusCard(stringResource(R.string.current_intensity, intensity))
        PrimaryAction(stringResource(R.string.open_injection), onClick = { navigate(ShellAction.Injection) })
        SecondaryAction(stringResource(R.string.view_record_detail), onClick = { navigate(ShellAction.RecordDetail) })
        SecondaryAction(stringResource(R.string.open_settings), onClick = { navigate(ShellAction.Settings) })
        SecondaryAction(stringResource(R.string.open_safety), onClick = { navigate(ShellAction.Safety) })
        SecondaryAction(stringResource(R.string.open_pro), onClick = { navigate(ShellAction.Pro) })
        SecondaryAction(
            stringResource(R.string.open_customization),
            onClick = { navigate(ShellAction.Customization) },
        )
    }
}

@Composable
fun RouteShell(title: Int, body: Int, onBack: () -> Unit, image: Int? = null) {
    ScreenColumn {
        image?.let { resource ->
            Image(
                painter = painterResource(resource),
                contentDescription = null,
                modifier = Modifier.align(Alignment.CenterHorizontally).heightIn(max = 220.dp),
            )
        }
        ScreenHeading(title, body)
        SecondaryAction(stringResource(R.string.back_to_records), onClick = onBack)
    }
}

@Composable
fun CompletionShell(
    onBack: () -> Unit,
    phrase: Phrase = SafePhraseCatalog.fallback,
) {
    ScreenColumn {
        Image(
            painter = painterResource(R.drawable.maeumjaro_pen_2d_complete),
            contentDescription = null,
            modifier = Modifier.align(Alignment.CenterHorizontally).heightIn(max = 220.dp),
        )
        Text(
            text = stringResource(R.string.completion_title),
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
        )
        StatusCard(SafePhraseCatalog.resolve(phrase).text)
        SecondaryAction(stringResource(R.string.back_to_records), onClick = onBack)
    }
}

@Composable
fun SafetyShell(onBack: () -> Unit) {
    ScreenColumn {
        Text(
            text = stringResource(R.string.safety_title),
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
        )
        StatusCard(SafetyCopy.disclaimer)
        SecondaryAction(stringResource(R.string.back_to_records), onClick = onBack)
    }
}

@Composable
private fun ScreenColumn(content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = DesignTokens.screenHorizontal, vertical = DesignTokens.screenVertical),
        verticalArrangement = Arrangement.spacedBy(DesignTokens.contentGap),
        content = content,
    )
}

@Composable
private fun ScreenHeading(title: Int, body: Int) {
    Text(
        text = stringResource(title),
        style = MaterialTheme.typography.headlineMedium,
        fontWeight = FontWeight.Bold,
    )
    Text(
        text = stringResource(body),
        style = MaterialTheme.typography.bodyLarge.copy(lineBreak = DesignTokens.koreanLineBreak),
    )
}

@Composable
private fun StatusCard(text: String) {
    Card(Modifier.fillMaxWidth()) {
        Text(
            text = text,
            modifier = Modifier.padding(20.dp),
            style = MaterialTheme.typography.bodyLarge.copy(lineBreak = DesignTokens.koreanLineBreak),
        )
    }
}

enum class ShellAction {
    Settings,
    Injection,
    RecordDetail,
    Safety,
    Pro,
    Customization,
}
