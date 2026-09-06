package com.maeumjaro.app.widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.LocalSize
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.provideContent
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.semantics.contentDescription
import androidx.glance.semantics.semantics
import androidx.glance.text.Text
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.DpSize
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import com.maeumjaro.app.feature.customization.InstalledWidgetInventory

/** Layout contract consumed by the Glance widget. */
enum class WidgetLayout { TWO_BY_TWO, FOUR_BY_TWO }

object WidgetLayoutSpec {
    fun forWidthDp(widthDp: Int): WidgetLayout =
        if (widthDp < 180) WidgetLayout.TWO_BY_TWO else WidgetLayout.FOUR_BY_TWO
}

/** Stable actions; widget actions never carry an intensity value. */
object WidgetActionContract {
    const val ACTION_START = "com.maeumjaro.app.widget.START"
    const val ACTION_ADJUST_INTENSITY = "com.maeumjaro.app.widget.ADJUST_INTENSITY"
    const val EXTRA_DELTA = "com.maeumjaro.app.widget.DELTA"

    fun startIntent(): Intent = WidgetLaunchIntentFactory.intent().setAction(ACTION_START)
}

class MaeumjaroWidget : GlanceAppWidget() {
    override val sizeMode: SizeMode = SizeMode.Responsive(
        setOf(
            DpSize(160.dp, 160.dp),
            DpSize(250.dp, 160.dp),
        ),
    )

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val appWidgetId = GlanceAppWidgetManager(context).getAppWidgetId(id)
        val gateway = WidgetStateFactory.create(context, appWidgetId = appWidgetId)
        provideContent { MaeumjaroWidgetContent(gateway) }
    }
}

class MaeumjaroWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = MaeumjaroWidget()

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        val pendingResult = goAsync()
        CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
            try {
                deleteWidgetPresets(context, appWidgetIds)
            } finally {
                pendingResult.finish()
            }
        }
    }
}

/** Testable, atomic cleanup seam for the BroadcastReceiver callback. */
suspend fun deleteWidgetPresets(context: Context, appWidgetIds: IntArray) {
    com.maeumjaro.app.data.settings.AppStateStoreProvider.get(context)
        .deleteWidgetPresets(appWidgetIds.toList())
}

/** Inventory adapter used by customization; the feature remains injectable in tests. */
class AndroidInstalledWidgetInventory(private val context: Context) : InstalledWidgetInventory {
    override suspend fun ids(): List<Int> {
        val manager = GlanceAppWidgetManager(context.applicationContext)
        return manager.getGlanceIds(MaeumjaroWidget::class.java)
            .map { manager.getAppWidgetId(it) }
            .filter { it > 0 }
            .distinct()
            .sorted()
    }
}

private object WidgetParameters {
    val delta = ActionParameters.Key<Int>("delta")
}

class ChangeWidgetIntensityAction : ActionCallback {
    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters,
    ) {
        val value = parameters[WidgetParameters.delta] ?: return
        if (value != -1 && value != 1) return
        val appWidgetId = GlanceAppWidgetManager(context).getAppWidgetId(glanceId)
        withContext(Dispatchers.IO) {
            WidgetStateFactory.create(context, appWidgetId = appWidgetId).changeIntensity(value)
        }
        MaeumjaroWidget().update(context, glanceId)
        withContext(Dispatchers.IO) { AndroidAllInstancesWidgetUpdater(context).updateAll() }
    }
}

/** Starts the app after atomically applying this widget's Pro preset, if one exists. */
class StartWidgetAction : ActionCallback {
    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters,
    ) {
        val appWidgetId = GlanceAppWidgetManager(context).getAppWidgetId(glanceId)
        WidgetLaunchPipeline(
            prepare = {
                withContext(Dispatchers.IO) {
                    com.maeumjaro.app.data.settings.AppStateStoreProvider.get(context)
                        .prepareLaunch(appWidgetId, System.currentTimeMillis())
                }
            },
            refresh = { withContext(Dispatchers.IO) { AndroidAllInstancesWidgetUpdater(context).updateAll() } },
            launch = {
                context.startActivity(
                    WidgetLaunchIntentFactory.intent(WidgetLaunchAuthenticator.issue())
                        .setAction(WidgetActionContract.ACTION_START)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
            },
        ).run()
    }
}

/** Explicit ordering seam: persistence, widget refresh, then foreground launch. */
class WidgetLaunchPipeline(
    private val prepare: suspend () -> Unit,
    private val refresh: suspend () -> Unit,
    private val launch: () -> Unit,
) {
    suspend fun run() {
        prepare()
        refresh()
        launch()
    }
}

@Composable
private fun MaeumjaroWidgetContent(gateway: WidgetStateGateway) {
    val state by gateway.state.collectAsState(initial = WidgetState(3, 0, 0))
    val layout = WidgetLayoutSpec.forWidthDp(LocalSize.current.width.value.toInt())
    if (layout == WidgetLayout.TWO_BY_TWO) {
        CompactWidgetContent(state)
    } else {
        WideWidgetContent(state)
    }
}

@Composable
private fun CompactWidgetContent(state: WidgetState) {
    val decrease = if (state.intensity > 1) {
        GlanceModifier.clickable(actionRunCallback<ChangeWidgetIntensityAction>(actionParametersOf(WidgetParameters.delta to -1)))
    } else GlanceModifier
    val increase = if (state.intensity < 5) {
        GlanceModifier.clickable(actionRunCallback<ChangeWidgetIntensityAction>(actionParametersOf(WidgetParameters.delta to 1)))
    } else GlanceModifier
    Column(
        modifier = GlanceModifier.fillMaxSize().padding(4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("마음자로")
        Text("${state.todayCount}회 · ${if (state.usesPreset) "고정" else "전역"} 강도 ${state.intensity}")
        Spacer(GlanceModifier.height(2.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("−", GlanceModifier.width(48.dp).height(48.dp).then(decrease).semantics {
                contentDescription = "강도 낮추기"
            })
            Text("${state.intensity}", GlanceModifier.width(40.dp).height(48.dp))
            Text("+", GlanceModifier.width(48.dp).height(48.dp).then(increase).semantics {
                contentDescription = "강도 높이기"
            })
        }
        Spacer(GlanceModifier.height(2.dp))
        Text("시작", GlanceModifier.width(120.dp).height(48.dp)
            .clickable(actionRunCallback<StartWidgetAction>())
            .semantics { contentDescription = "마음자로 시작" })
    }
}

@Composable
private fun WideWidgetContent(state: WidgetState) {
    Column(
        modifier = GlanceModifier.fillMaxSize().padding(4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("마음자로 · 오늘의 기록")
        Spacer(GlanceModifier.height(2.dp))
        Text(state.summary)
        Spacer(GlanceModifier.height(2.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            val decrease = if (state.intensity > 1) {
                GlanceModifier.clickable(actionRunCallback<ChangeWidgetIntensityAction>(actionParametersOf(WidgetParameters.delta to -1)))
            } else GlanceModifier
            val increase = if (state.intensity < 5) {
                GlanceModifier.clickable(actionRunCallback<ChangeWidgetIntensityAction>(actionParametersOf(WidgetParameters.delta to 1)))
            } else GlanceModifier
            Text("−", GlanceModifier.width(48.dp).height(48.dp).then(decrease).semantics {
                contentDescription = "강도 낮추기"
            })
            Spacer(GlanceModifier.width(12.dp))
            Text(if (state.usesPreset) "고정 강도 ${state.intensity}" else "전역 강도 ${state.intensity}")
            Spacer(GlanceModifier.width(12.dp))
            Text("+", GlanceModifier.width(48.dp).height(48.dp).then(increase).semantics {
                contentDescription = "강도 높이기"
            })
        }
        Spacer(GlanceModifier.height(2.dp))
        Text("시작", GlanceModifier.width(120.dp).height(48.dp)
            .clickable(actionRunCallback<StartWidgetAction>())
            .semantics { contentDescription = "마음자로 시작" })
    }
}

/** Single seam used by completion/foreground code to refresh every installed instance. */
fun interface AllInstancesWidgetUpdater {
    suspend fun updateAll()
}

class AndroidAllInstancesWidgetUpdater(private val context: Context) : AllInstancesWidgetUpdater {
    override suspend fun updateAll() {
        val appContext = context.applicationContext
        val manager = AppWidgetManager.getInstance(appContext)
        val provider = ComponentName(appContext, MaeumjaroWidgetReceiver::class.java)
        val ids = manager.getAppWidgetIds(provider)
        if (ids.isNotEmpty()) {
            appContext.sendBroadcast(
                Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                    .setComponent(provider)
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids),
            )
        }
    }
}

object WidgetLaunchIntentFactory {
    const val SOURCE = "widget"
    const val EXTRA_AUTH_TOKEN = "com.maeumjaro.app.widget.AUTH_TOKEN"
    fun intent(authToken: String? = null): Intent = Intent().apply {
        setClassName("com.maeumjaro.app", "com.maeumjaro.app.MainActivity")
        putExtra(com.maeumjaro.app.MainActivity.EXTRA_SOURCE, SOURCE)
        authToken?.let { putExtra(EXTRA_AUTH_TOKEN, it) }
        addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
    }
}

/** Process-local, one-use proof that the launch was issued by our widget callback. */
object WidgetLaunchAuthenticator {
    private val issued = ConcurrentHashMap.newKeySet<String>()

    fun issue(): String = UUID.randomUUID().toString().also(issued::add)

    fun consume(token: String?): Boolean = token != null && issued.remove(token)
}
